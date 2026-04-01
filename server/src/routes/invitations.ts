import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticate, AuthRequest } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

router.post('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id, familyId, toUserId } = req.body;

    if (!familyId || !toUserId) {
      res.status(400).json({ error: 'familyId and toUserId are required' });
      return;
    }

    const membership = await prisma.familyMember.findUnique({
      where: { familyId_userId: { familyId, userId: req.userId! } },
    });
    if (!membership) {
      res.status(403).json({ error: 'Not a member of this family' });
      return;
    }

    const alreadyMember = await prisma.familyMember.findUnique({
      where: { familyId_userId: { familyId, userId: toUserId } },
    });
    if (alreadyMember) {
      res.status(409).json({ error: 'User is already a member of this family' });
      return;
    }

    const existingInvite = await prisma.invitation.findFirst({
      where: { familyId, toUserId, status: 'pending' },
    });
    if (existingInvite) {
      res.status(409).json({ error: 'Invitation already pending for this user' });
      return;
    }

    const invitation = await prisma.invitation.create({
      data: { id: id || undefined, familyId, fromUserId: req.userId!, toUserId },
    });

    res.status(201).json(invitation);
  } catch (error) {
    console.error('Create invitation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/incoming', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const invitations = await prisma.invitation.findMany({
      where: { toUserId: req.userId, status: 'pending' },
      orderBy: { createdAt: 'desc' },
    });

    const familyIds = [...new Set(invitations.map((i) => i.familyId))];
    const fromUserIds = [...new Set(invitations.map((i) => i.fromUserId))];

    const [families, fromUsers] = await Promise.all([
      prisma.family.findMany({ where: { id: { in: familyIds } }, select: { id: true, name: true } }),
      prisma.user.findMany({ where: { id: { in: fromUserIds } }, select: { id: true, username: true, displayName: true } }),
    ]);

    const result = invitations.map((inv) => ({
      ...inv,
      family: families.find((f) => f.id === inv.familyId),
      fromUser: fromUsers.find((u) => u.id === inv.fromUserId),
    }));

    res.json(result);
  } catch (error) {
    console.error('Get invitations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/:id', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const id = String(req.params.id);
    const { status } = req.body;

    if (!status || !['accepted', 'declined'].includes(status)) {
      res.status(400).json({ error: 'Status must be "accepted" or "declined"' });
      return;
    }

    const invitation = await prisma.invitation.findUnique({ where: { id } });
    if (!invitation) {
      res.status(404).json({ error: 'Invitation not found' });
      return;
    }

    if (invitation.toUserId !== req.userId) {
      res.status(403).json({ error: 'Not authorized to update this invitation' });
      return;
    }

    if (invitation.status !== 'pending') {
      res.status(400).json({ error: 'Invitation has already been responded to' });
      return;
    }

    const updated = await prisma.invitation.update({
      where: { id },
      data: { status },
    });

    if (status === 'accepted') {
      await prisma.familyMember.create({
        data: { familyId: invitation.familyId, userId: req.userId!, role: 'member' },
      });
    }

    res.json(updated);
  } catch (error) {
    console.error('Update invitation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
