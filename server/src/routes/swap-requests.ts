import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { Server } from 'socket.io';
import { authenticate, AuthRequest } from '../middleware/auth';
import { createNotification } from '../services/notification';

const prisma = new PrismaClient();

export default function createSwapRequestsRouter(io: Server): Router {
  const router = Router();

  // POST / — create a swap request
  router.post('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { id, choreId, toUserId, message } = req.body;

      if (!choreId) {
        res.status(400).json({ error: 'choreId is required' });
        return;
      }

      const chore = await prisma.chore.findUnique({ where: { id: choreId } });
      if (!chore) {
        res.status(404).json({ error: 'Chore not found' });
        return;
      }

      if (chore.assignedTo !== req.userId) {
        res.status(403).json({ error: 'Only the assigned user can request a swap' });
        return;
      }

      const callerMembership = await prisma.familyMember.findUnique({
        where: { familyId_userId: { familyId: chore.familyId, userId: req.userId! } },
      });
      if (!callerMembership) {
        res.status(403).json({ error: 'Not a member of this family' });
        return;
      }

      if (chore.status === 'done') {
        res.status(400).json({ error: 'Chore is already completed' });
        return;
      }

      if (toUserId && toUserId === req.userId) {
        res.status(400).json({ error: 'Cannot swap with yourself' });
        return;
      }

      if (toUserId) {
        const recipientMembership = await prisma.familyMember.findUnique({
          where: { familyId_userId: { familyId: chore.familyId, userId: toUserId } },
        });
        if (!recipientMembership) {
          res.status(400).json({ error: 'Recipient is not a family member' });
          return;
        }
      }

      const existing = await prisma.choreSwapRequest.findFirst({
        where: { choreId, fromUserId: req.userId!, status: 'pending' },
      });
      if (existing) {
        res.status(409).json({ error: 'A pending swap request already exists for this chore' });
        return;
      }

      const resolvedToUserId = toUserId || null;

      const swap = await prisma.choreSwapRequest.create({
        data: {
          id: id || undefined,
          choreId,
          fromUserId: req.userId!,
          toUserId: resolvedToUserId,
          familyId: chore.familyId,
          status: 'pending',
          message: message || null,
        },
      });

      const [swapChore, fromUser] = await Promise.all([
        prisma.chore.findUnique({ where: { id: swap.choreId } }),
        prisma.user.findUnique({
          where: { id: swap.fromUserId },
          select: { id: true, username: true, displayName: true },
        }),
      ]);

      // Emit Socket.IO event to the family room
      io.to(`family:${swap.familyId}`).emit('swap_request_created', {
        swapRequest: swap,
        choreId: swap.choreId,
        fromUserId: swap.fromUserId,
        toUserId: swap.toUserId,
      });

      // Send notifications
      const fromName = fromUser?.displayName ?? 'Someone';

      if (resolvedToUserId) {
        // Targeted swap — notify the specific recipient
        const targetedBody = `${fromName} wants to swap '${chore.title}'`;
        await createNotification(
          resolvedToUserId,
          swap.familyId,
          'swap_request',
          'Swap request',
          targetedBody,
          JSON.stringify({ swapRequestId: swap.id, choreId: swap.choreId, fromUserId: swap.fromUserId }),
        );
      } else {
        // Open swap — notify every family member except the requester
        const members = await prisma.familyMember.findMany({
          where: { familyId: swap.familyId, userId: { not: req.userId! } },
        });
        const openBody = `${fromName} is asking someone to take '${chore.title}'`;
        for (const member of members) {
          await createNotification(
            member.userId,
            swap.familyId,
            'swap_request',
            'Open swap request',
            openBody,
            JSON.stringify({ swapRequestId: swap.id, choreId: swap.choreId, open: true }),
          );
        }
      }

      res.status(201).json({ ...swap, chore: swapChore, fromUser });
    } catch (error) {
      console.error('Create swap request error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  // GET /incoming — pending swaps targeting the caller (direct or open)
  router.get('/incoming', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const memberships = await prisma.familyMember.findMany({ where: { userId: req.userId } });
      const familyIds = memberships.map((m) => m.familyId);

      const swaps = await prisma.choreSwapRequest.findMany({
        where: {
          status: 'pending',
          fromUserId: { not: req.userId! },
          OR: [
            { toUserId: req.userId! },
            { toUserId: null as any, familyId: { in: familyIds } },
          ],
        },
        orderBy: { createdAt: 'desc' },
      });

      const choreIds = [...new Set(swaps.map((s) => s.choreId))];
      const fromUserIds = [...new Set(swaps.map((s) => s.fromUserId))];

      const [chores, fromUsers] = await Promise.all([
        prisma.chore.findMany({ where: { id: { in: choreIds } } }),
        prisma.user.findMany({
          where: { id: { in: fromUserIds } },
          select: { id: true, username: true, displayName: true },
        }),
      ]);

      const result = swaps.map((s) => ({
        ...s,
        chore: chores.find((c) => c.id === s.choreId),
        fromUser: fromUsers.find((u) => u.id === s.fromUserId),
      }));

      res.json(result);
    } catch (error) {
      console.error('Get incoming swaps error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  // GET /outgoing — swaps initiated by the caller
  router.get('/outgoing', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const swaps = await prisma.choreSwapRequest.findMany({
        where: { fromUserId: req.userId! },
        orderBy: { createdAt: 'desc' },
        take: 50,
      });

      const choreIds = [...new Set(swaps.map((s) => s.choreId))];
      const toUserIds = [...new Set(swaps.map((s) => s.toUserId).filter((id): id is string => id !== null))];

      const [chores, toUsers] = await Promise.all([
        prisma.chore.findMany({ where: { id: { in: choreIds } } }),
        toUserIds.length > 0
          ? prisma.user.findMany({
              where: { id: { in: toUserIds } },
              select: { id: true, username: true, displayName: true },
            })
          : Promise.resolve([]),
      ]);

      const result = swaps.map((s) => ({
        ...s,
        chore: chores.find((c) => c.id === s.choreId),
        toUser: s.toUserId ? toUsers.find((u) => u.id === s.toUserId) : null,
      }));

      res.json(result);
    } catch (error) {
      console.error('Get outgoing swaps error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  // GET /by-chore/:choreId — all swaps for a specific chore
  router.get('/by-chore/:choreId', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const choreId = String(req.params.choreId);

      const chore = await prisma.chore.findUnique({ where: { id: choreId } });
      if (!chore) {
        res.status(404).json({ error: 'Chore not found' });
        return;
      }

      const membership = await prisma.familyMember.findUnique({
        where: { familyId_userId: { familyId: chore.familyId, userId: req.userId! } },
      });
      if (!membership) {
        res.status(403).json({ error: 'Not a member of this family' });
        return;
      }

      const swaps = await prisma.choreSwapRequest.findMany({
        where: { choreId },
        orderBy: { createdAt: 'desc' },
      });

      const fromUserIds = [...new Set(swaps.map((s) => s.fromUserId))];
      const toUserIds = [...new Set(swaps.map((s) => s.toUserId).filter((id): id is string => id !== null))];
      const allUserIds = [...new Set([...fromUserIds, ...toUserIds])];

      const users = await prisma.user.findMany({
        where: { id: { in: allUserIds } },
        select: { id: true, username: true, displayName: true },
      });

      const result = swaps.map((s) => ({
        ...s,
        chore,
        fromUser: users.find((u) => u.id === s.fromUserId),
        toUser: s.toUserId ? users.find((u) => u.id === s.toUserId) : null,
      }));

      res.json(result);
    } catch (error) {
      console.error('Get swaps by chore error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  // PATCH /:id — accept, decline, or cancel a swap request
  router.patch('/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const swapId = String(req.params.id);
      const { status: newStatus } = req.body;

      if (!newStatus || !['accepted', 'declined', 'cancelled'].includes(newStatus)) {
        res.status(400).json({ error: 'Status must be "accepted", "declined", or "cancelled"' });
        return;
      }

      const swap = await prisma.choreSwapRequest.findUnique({ where: { id: swapId } });
      if (!swap) {
        res.status(404).json({ error: 'Swap request not found' });
        return;
      }

      if (swap.status !== 'pending') {
        res.status(409).json({ error: 'Swap is no longer pending' });
        return;
      }

      if (newStatus === 'accepted' || newStatus === 'declined') {
        if (swap.toUserId !== null) {
          if (swap.toUserId !== req.userId) {
            res.status(403).json({ error: 'Not authorized to respond to this swap request' });
            return;
          }
        } else {
          // Open request — any family member except the requester may accept/decline
          const membership = await prisma.familyMember.findUnique({
            where: { familyId_userId: { familyId: swap.familyId, userId: req.userId! } },
          });
          if (!membership || req.userId === swap.fromUserId) {
            res.status(403).json({ error: 'Not authorized to respond to this swap request' });
            return;
          }
        }
      }

      if (newStatus === 'cancelled') {
        if (swap.fromUserId !== req.userId) {
          res.status(403).json({ error: 'Only the requester can cancel a swap request' });
          return;
        }
      }

      // Fetch the chore for notification bodies
      const chore = await prisma.chore.findUnique({ where: { id: swap.choreId } });

      if (newStatus === 'accepted') {
        let updatedChore: Awaited<ReturnType<typeof prisma.chore.update>> | null = null;

        try {
          await prisma.$transaction(async (tx) => {
            const result = await tx.choreSwapRequest.updateMany({
              where: { id: swapId, status: 'pending' },
              data: { status: 'accepted', toUserId: req.userId! },
            });

            if (result.count === 0) {
              throw new Error('ALREADY_RESPONDED');
            }

            updatedChore = await tx.chore.update({
              where: { id: swap.choreId },
              data: { assignedTo: req.userId!, assignmentStatus: 'accepted' },
            });

            await tx.choreHistory.create({
              data: {
                choreId: swap.choreId,
                familyId: swap.familyId,
                userId: req.userId!,
                action: 'swap_accepted',
              },
            });

            await tx.choreSwapRequest.updateMany({
              where: { choreId: swap.choreId, status: 'pending', id: { not: swapId } },
              data: { status: 'cancelled' },
            });
          });
        } catch (txError) {
          if (txError instanceof Error && txError.message === 'ALREADY_RESPONDED') {
            res.status(409).json({ error: 'Already responded' });
            return;
          }
          throw txError;
        }

        const updatedSwap = await prisma.choreSwapRequest.findUnique({ where: { id: swapId } });

        // Emit Socket.IO event
        io.to(`family:${swap.familyId}`).emit('swap_request_updated', {
          swapRequestId: swap.id,
          choreId: swap.choreId,
          status: newStatus,
          actorUserId: req.userId,
          chore: updatedChore,
        });

        // Send notification to the original requester
        const actorUser = await prisma.user.findUnique({
          where: { id: req.userId! },
          select: { displayName: true },
        });
        const actorName = actorUser?.displayName ?? 'Someone';
        const choreTitle = chore?.title ?? 'a chore';
        const acceptBody = `${actorName} took '${choreTitle}'`;
        await createNotification(
          swap.fromUserId,
          swap.familyId,
          'swap_accepted',
          'Swap accepted',
          acceptBody,
          JSON.stringify({ swapRequestId: swap.id, choreId: swap.choreId, newAssigneeId: req.userId }),
        );

        res.json(updatedSwap);
        return;
      }

      // declined or cancelled — simple update
      const updatedSwap = await prisma.choreSwapRequest.update({
        where: { id: swapId },
        data: { status: newStatus },
      });

      // Emit Socket.IO event
      io.to(`family:${swap.familyId}`).emit('swap_request_updated', {
        swapRequestId: swap.id,
        choreId: swap.choreId,
        status: newStatus,
        actorUserId: req.userId,
      });

      // Send notification
      const actorUser = await prisma.user.findUnique({
        where: { id: req.userId! },
        select: { displayName: true },
      });
      const actorName = actorUser?.displayName ?? 'Someone';
      const choreTitle = chore?.title ?? 'a chore';

      if (newStatus === 'declined') {
        const declineBody = `${actorName} declined to swap '${choreTitle}'`;
        await createNotification(
          swap.fromUserId,
          swap.familyId,
          'swap_declined',
          'Swap declined',
          declineBody,
          JSON.stringify({ swapRequestId: swap.id, choreId: swap.choreId }),
        );
      } else if (newStatus === 'cancelled' && swap.toUserId) {
        // Only notify the targeted recipient on cancellation
        const cancelBody = `${actorName} cancelled the swap on '${choreTitle}'`;
        await createNotification(
          swap.toUserId,
          swap.familyId,
          'swap_cancelled',
          'Swap cancelled',
          cancelBody,
          JSON.stringify({ swapRequestId: swap.id, choreId: swap.choreId }),
        );
      }

      res.json(updatedSwap);
    } catch (error) {
      console.error('Update swap request error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  return router;
}
