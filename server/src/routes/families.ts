import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticate, AuthRequest } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

router.post('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id, name } = req.body;
    if (!name) {
      res.status(400).json({ error: 'Family name is required' });
      return;
    }

    const family = await prisma.family.create({
      data: { id: id || undefined, name, createdBy: req.userId! },
    });

    await prisma.familyMember.create({
      data: { familyId: family.id, userId: req.userId!, role: 'admin' },
    });

    res.status(201).json(family);
  } catch (error) {
    console.error('Create family error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const memberships = await prisma.familyMember.findMany({
      where: { userId: req.userId },
      include: { family: true },
    });

    res.json(memberships.map((m) => ({ ...m.family, role: m.role })));
  } catch (error) {
    console.error('Get families error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:id/members', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const id = String(req.params.id);

    const isMember = await prisma.familyMember.findUnique({
      where: { familyId_userId: { familyId: id, userId: req.userId! } },
    });
    if (!isMember) {
      res.status(403).json({ error: 'Not a member of this family' });
      return;
    }

    const members = await prisma.familyMember.findMany({
      where: { familyId: id },
    });

    const userIds = members.map((m) => m.userId);
    const users = await prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, username: true, displayName: true },
    });

    const result = members.map((m) => ({
      ...m,
      user: users.find((u) => u.id === m.userId),
    }));

    res.json(result);
  } catch (error) {
    console.error('Get members error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
