import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticate, AuthRequest } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

router.get('/pull', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const since = String(req.query.since || '');
    const sinceDate = since ? new Date(since) : new Date(0);

    const memberships = await prisma.familyMember.findMany({
      where: { userId: req.userId },
    });
    const familyIds = memberships.map((m) => m.familyId);

    if (familyIds.length === 0) {
      res.json({ families: [], familyMembers: [], chores: [], invitations: [], users: [], choreHistory: [] });
      return;
    }

    const [families, familyMembers, chores, invitations, choreHistory] = await Promise.all([
      prisma.family.findMany({
        where: { id: { in: familyIds }, updatedAt: { gt: sinceDate } },
      }),
      prisma.familyMember.findMany({
        where: { familyId: { in: familyIds }, joinedAt: { gt: sinceDate } },
      }),
      prisma.chore.findMany({
        where: { familyId: { in: familyIds }, updatedAt: { gt: sinceDate } },
      }),
      prisma.invitation.findMany({
        where: {
          OR: [{ toUserId: req.userId }, { fromUserId: req.userId }],
          updatedAt: { gt: sinceDate },
        },
      }),
      prisma.choreHistory.findMany({
        where: { familyId: { in: familyIds }, createdAt: { gt: sinceDate } },
        orderBy: { createdAt: 'desc' },
        take: 100,
      }),
    ]);

    const userIds = new Set<string>();
    familyMembers.forEach((m) => userIds.add(m.userId));
    chores.forEach((c) => {
      userIds.add(c.createdBy);
      if (c.assignedTo) userIds.add(c.assignedTo);
    });
    invitations.forEach((i) => {
      userIds.add(i.fromUserId);
      userIds.add(i.toUserId);
    });
    choreHistory.forEach((h) => userIds.add(h.userId));

    const users = await prisma.user.findMany({
      where: { id: { in: Array.from(userIds) } },
      select: { id: true, username: true, displayName: true, email: true, createdAt: true, updatedAt: true },
    });

    res.json({ families, familyMembers, chores, invitations, users, choreHistory });
  } catch (error) {
    console.error('Sync pull error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/push', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { families, chores, invitations, choreHistory } = req.body;

    if (families?.length) {
      for (const family of families) {
        await prisma.family.upsert({
          where: { id: family.id },
          create: { id: family.id, name: family.name, createdBy: req.userId! },
          update: { name: family.name },
        });

        const existingMember = await prisma.familyMember.findUnique({
          where: { familyId_userId: { familyId: family.id, userId: req.userId! } },
        });
        if (!existingMember) {
          await prisma.familyMember.create({
            data: { familyId: family.id, userId: req.userId!, role: 'admin' },
          });
        }
      }
    }

    if (chores?.length) {
      for (const chore of chores) {
        await prisma.chore.upsert({
          where: { id: chore.id },
          create: {
            id: chore.id,
            familyId: chore.familyId,
            title: chore.title,
            category: chore.category,
            timeSlot: chore.timeSlot || null,
            assignedTo: chore.assignedTo || null,
            assignmentStatus: chore.assignmentStatus || (chore.assignedTo ? 'pending_acceptance' : 'unassigned'),
            priority: chore.priority || 'medium',
            description: chore.description || null,
            recurrence: chore.recurrence || null,
            status: chore.status || 'pending',
            dueDate: chore.dueDate ? new Date(chore.dueDate) : null,
            createdBy: req.userId!,
          },
          update: {
            title: chore.title,
            category: chore.category,
            timeSlot: chore.timeSlot || null,
            assignedTo: chore.assignedTo || null,
            assignmentStatus: chore.assignmentStatus || undefined,
            priority: chore.priority || undefined,
            description: chore.description !== undefined ? (chore.description || null) : undefined,
            recurrence: chore.recurrence !== undefined ? (chore.recurrence || null) : undefined,
            status: chore.status || 'pending',
            dueDate: chore.dueDate ? new Date(chore.dueDate) : null,
          },
        });
      }
    }

    if (invitations?.length) {
      for (const inv of invitations) {
        if (inv.status === 'accepted' || inv.status === 'declined') {
          const existing = await prisma.invitation.findUnique({ where: { id: inv.id } });
          if (existing && existing.status === 'pending') {
            await prisma.invitation.update({
              where: { id: inv.id },
              data: { status: inv.status },
            });
            if (inv.status === 'accepted') {
              const alreadyMember = await prisma.familyMember.findUnique({
                where: { familyId_userId: { familyId: existing.familyId, userId: existing.toUserId } },
              });
              if (!alreadyMember) {
                await prisma.familyMember.create({
                  data: { familyId: existing.familyId, userId: existing.toUserId, role: 'member' },
                });
              }
            }
          }
        }
      }
    }

    if (choreHistory?.length) {
      for (const h of choreHistory) {
        const existing = await prisma.choreHistory.findUnique({ where: { id: h.id } });
        if (!existing) {
          await prisma.choreHistory.create({
            data: {
              id: h.id,
              choreId: h.choreId,
              familyId: h.familyId,
              userId: h.userId,
              action: h.action,
              createdAt: new Date(h.createdAt),
            },
          });
        }
      }
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Sync push error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
