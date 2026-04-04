import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticate, AuthRequest } from '../middleware/auth';

const router = Router();
const prisma = new PrismaClient();

// List notifications for current user
router.get('/', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const limit = Math.min(parseInt(String(req.query.limit || '50')), 100);
    const notifications = await prisma.notification.findMany({
      where: { userId: req.userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
    res.json(notifications.map((n: any) => ({ ...n, createdAt: n.createdAt.toISOString() })));
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Unread count
router.get('/unread-count', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const count = await prisma.notification.count({
      where: { userId: req.userId, read: false },
    });
    res.json({ count });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Mark single as read
router.patch('/:id/read', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    await prisma.notification.update({
      where: { id: String(req.params.id) },
      data: { read: true },
    });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Mark all as read
router.post('/read-all', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    await prisma.notification.updateMany({
      where: { userId: req.userId, read: false },
      data: { read: true },
    });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
