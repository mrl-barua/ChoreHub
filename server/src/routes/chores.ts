import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticate, AuthRequest } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

async function verifyFamilyMembership(userId: string, familyId: string): Promise<boolean> {
  const member = await prisma.familyMember.findUnique({
    where: { familyId_userId: { familyId, userId } },
  });
  return !!member;
}

async function recordHistory(choreId: string, familyId: string, userId: string, action: string) {
  await prisma.choreHistory.create({
    data: { choreId, familyId, userId, action },
  });
}

router.post('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id, familyId, title, category, timeSlot, assignedTo, status, dueDate, priority, description, recurrence } = req.body;

    if (!familyId || !title || !category) {
      res.status(400).json({ error: 'familyId, title, and category are required' });
      return;
    }

    if (!(await verifyFamilyMembership(req.userId!, familyId))) {
      res.status(403).json({ error: 'Not a member of this family' });
      return;
    }

    const chore = await prisma.chore.create({
      data: {
        id: id || undefined,
        familyId,
        title,
        category,
        timeSlot: timeSlot || null,
        assignedTo: assignedTo || null,
        assignmentStatus: assignedTo ? 'pending_acceptance' : 'unassigned',
        priority: priority || 'medium',
        description: description || null,
        recurrence: recurrence || null,
        status: status || 'pending',
        dueDate: dueDate ? new Date(dueDate) : null,
        createdBy: req.userId!,
      },
    });

    await recordHistory(chore.id, familyId, req.userId!, 'created');
    if (assignedTo) {
      await recordHistory(chore.id, familyId, req.userId!, 'assigned');
    }

    res.status(201).json(chore);
  } catch (error) {
    console.error('Create chore error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const familyId = String(req.query.familyId || '');
    if (!familyId) {
      res.status(400).json({ error: 'familyId query parameter is required' });
      return;
    }

    if (!(await verifyFamilyMembership(req.userId!, familyId))) {
      res.status(403).json({ error: 'Not a member of this family' });
      return;
    }

    const chores = await prisma.chore.findMany({
      where: { familyId },
      orderBy: { createdAt: 'desc' },
    });

    res.json(chores);
  } catch (error) {
    console.error('Get chores error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const id = String(req.params.id);
    const chore = await prisma.chore.findUnique({ where: { id } });

    if (!chore) {
      res.status(404).json({ error: 'Chore not found' });
      return;
    }

    if (!(await verifyFamilyMembership(req.userId!, chore.familyId))) {
      res.status(403).json({ error: 'Not a member of this family' });
      return;
    }

    const { title, category, timeSlot, assignedTo, status, dueDate, priority, description, recurrence } = req.body;

    let assignmentStatus: string | undefined;
    if (assignedTo !== undefined) {
      assignmentStatus = assignedTo ? 'pending_acceptance' : 'unassigned';
    }

    const updated = await prisma.chore.update({
      where: { id },
      data: {
        ...(title !== undefined && { title }),
        ...(category !== undefined && { category }),
        ...(timeSlot !== undefined && { timeSlot }),
        ...(assignedTo !== undefined && { assignedTo }),
        ...(assignmentStatus !== undefined && { assignmentStatus }),
        ...(status !== undefined && { status }),
        ...(dueDate !== undefined && { dueDate: dueDate ? new Date(dueDate) : null }),
        ...(priority !== undefined && { priority }),
        ...(description !== undefined && { description: description || null }),
        ...(recurrence !== undefined && { recurrence: recurrence || null }),
      },
    });

    // Record history for status changes
    if (status !== undefined && status !== chore.status) {
      if (status === 'done') {
        await recordHistory(id, chore.familyId, req.userId!, 'completed');
      } else if (status === 'pending' && chore.status === 'done') {
        await recordHistory(id, chore.familyId, req.userId!, 'reopened');
      }
    }
    if (assignedTo !== undefined && assignedTo !== chore.assignedTo && assignedTo) {
      await recordHistory(id, chore.familyId, req.userId!, 'assigned');
    }

    res.json(updated);
  } catch (error) {
    console.error('Update chore error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/:id/assignment', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const id = String(req.params.id);
    const { assignmentStatus } = req.body;

    if (!assignmentStatus || !['accepted', 'declined'].includes(assignmentStatus)) {
      res.status(400).json({ error: 'assignmentStatus must be "accepted" or "declined"' });
      return;
    }

    const chore = await prisma.chore.findUnique({ where: { id } });
    if (!chore) {
      res.status(404).json({ error: 'Chore not found' });
      return;
    }

    if (chore.assignedTo !== req.userId) {
      res.status(403).json({ error: 'Only the assigned user can respond to this assignment' });
      return;
    }

    if (chore.assignmentStatus !== 'pending_acceptance') {
      res.status(400).json({ error: 'Assignment has already been responded to' });
      return;
    }

    const updated = await prisma.chore.update({
      where: { id },
      data: { assignmentStatus },
    });

    await recordHistory(id, chore.familyId, req.userId!, assignmentStatus);

    res.json(updated);
  } catch (error) {
    console.error('Update assignment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const id = String(req.params.id);
    const chore = await prisma.chore.findUnique({ where: { id } });

    if (!chore) {
      res.status(404).json({ error: 'Chore not found' });
      return;
    }

    if (!(await verifyFamilyMembership(req.userId!, chore.familyId))) {
      res.status(403).json({ error: 'Not a member of this family' });
      return;
    }

    await prisma.chore.delete({ where: { id } });
    res.json({ success: true });
  } catch (error) {
    console.error('Delete chore error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
