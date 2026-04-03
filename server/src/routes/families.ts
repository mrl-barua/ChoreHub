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

// Weekly summary
router.get('/:id/weekly-summary', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const familyId = String(req.params.id);
    const isMember = await prisma.familyMember.findUnique({
      where: { familyId_userId: { familyId, userId: req.userId! } },
    });
    if (!isMember) { res.status(403).json({ error: 'Forbidden' }); return; }

    const now = new Date();
    const thisWeekStart = new Date(now); thisWeekStart.setDate(now.getDate() - now.getDay() + 1); thisWeekStart.setHours(0,0,0,0);
    const lastWeekStart = new Date(thisWeekStart); lastWeekStart.setDate(thisWeekStart.getDate() - 7);
    const lastWeekEnd = new Date(thisWeekStart);

    const [thisWeekCount, lastWeekCount, thisWeekHistory] = await Promise.all([
      prisma.choreHistory.count({ where: { familyId, action: { startsWith: 'completed' }, createdAt: { gte: thisWeekStart } } }),
      prisma.choreHistory.count({ where: { familyId, action: { startsWith: 'completed' }, createdAt: { gte: lastWeekStart, lt: lastWeekEnd } } }),
      prisma.choreHistory.findMany({ where: { familyId, action: { startsWith: 'completed' }, createdAt: { gte: thisWeekStart } } }),
    ]);

    // Top contributor
    const contributorCount: Record<string, number> = {};
    thisWeekHistory.forEach((h: any) => { contributorCount[h.userId] = (contributorCount[h.userId] || 0) + 1; });
    const topContributorId = Object.entries(contributorCount).sort(([, a], [, b]) => b - a)[0];
    let topContributor = null;
    if (topContributorId) {
      const user = await prisma.user.findUnique({ where: { id: topContributorId[0] }, select: { displayName: true } });
      topContributor = { userId: topContributorId[0], displayName: user?.displayName || 'Unknown', count: topContributorId[1] };
    }

    // Top category
    const choreIds = thisWeekHistory.map((h: any) => h.choreId);
    const chores = choreIds.length > 0
      ? await prisma.chore.findMany({ where: { id: { in: choreIds } }, select: { category: true } })
      : [];
    const catCount: Record<string, number> = {};
    chores.forEach((c: any) => { catCount[c.category] = (catCount[c.category] || 0) + 1; });
    const topCat = Object.entries(catCount).sort(([, a], [, b]) => b - a)[0];

    const changePercent = lastWeekCount > 0 ? Math.round(((thisWeekCount - lastWeekCount) / lastWeekCount) * 100) : 0;

    res.json({
      totalCompletedThisWeek: thisWeekCount,
      totalCompletedLastWeek: lastWeekCount,
      changePercent,
      topContributor,
      topCategory: topCat ? topCat[0] : null,
      topCategoryCount: topCat ? topCat[1] : 0,
    });
  } catch (error) {
    console.error('Weekly summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Leave family (self) or remove member (admin only)
router.delete('/:id/members/:userId', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const familyId = String(req.params.id);
    const targetUserId = String(req.params.userId);

    const requester = await prisma.familyMember.findUnique({
      where: { familyId_userId: { familyId, userId: req.userId! } },
    });
    if (!requester) {
      res.status(403).json({ error: 'Not a member of this family' });
      return;
    }

    const isSelf = targetUserId === req.userId;
    if (!isSelf && requester.role !== 'admin') {
      res.status(403).json({ error: 'Only admins can remove other members' });
      return;
    }

    // Don't allow the last admin to leave
    if (isSelf && requester.role === 'admin') {
      const adminCount = await prisma.familyMember.count({
        where: { familyId, role: 'admin' },
      });
      if (adminCount <= 1) {
        // Check if there are other members to transfer admin to
        const otherMembers = await prisma.familyMember.findMany({
          where: { familyId, userId: { not: req.userId! } },
        });
        if (otherMembers.length > 0) {
          // Transfer admin to the next member
          await prisma.familyMember.update({
            where: { id: otherMembers[0].id },
            data: { role: 'admin' },
          });
        }
      }
    }

    await prisma.familyMember.delete({
      where: { familyId_userId: { familyId, userId: targetUserId } },
    });

    // Unassign chores that were assigned to the removed user
    await prisma.chore.updateMany({
      where: { familyId, assignedTo: targetUserId },
      data: { assignedTo: null, assignmentStatus: 'unassigned' },
    });

    res.json({ success: true });
  } catch (error) {
    console.error('Remove member error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
