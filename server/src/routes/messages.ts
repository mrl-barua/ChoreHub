import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticate, AuthRequest } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

// Get message history (paginated)
router.get('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const familyId = String(req.query.familyId || '');
    const before = req.query.before ? String(req.query.before) : undefined;
    const limit = Math.min(parseInt(String(req.query.limit || '50')), 100);

    if (!familyId) {
      res.status(400).json({ error: 'familyId is required' });
      return;
    }

    // Verify membership
    const member = await prisma.familyMember.findUnique({
      where: { familyId_userId: { familyId, userId: req.userId! } },
    });
    if (!member) {
      res.status(403).json({ error: 'Not a member of this family' });
      return;
    }

    const messages = await prisma.message.findMany({
      where: {
        familyId,
        ...(before ? { createdAt: { lt: new Date(before) } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    // Get user info for messages
    const userIds = [...new Set(messages.map((m) => m.userId))];
    const users = await prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, displayName: true, username: true },
    });

    // Get chore info for messages with attachments
    const choreIds = messages.map((m) => m.choreId).filter((id): id is string => id !== null);
    const chores = choreIds.length > 0
      ? await prisma.chore.findMany({
          where: { id: { in: choreIds } },
          select: { id: true, title: true, status: true, category: true, assignedTo: true },
        })
      : [];

    const result = messages.map((m) => ({
      ...m,
      createdAt: m.createdAt.toISOString(),
      userName: users.find((u) => u.id === m.userId)?.displayName || 'Unknown',
      chore: m.choreId ? chores.find((c) => c.id === m.choreId) || null : null,
    }));

    // Return in chronological order (oldest first)
    res.json(result.reverse());
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
