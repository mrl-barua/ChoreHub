"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = createFamiliesRouter;
const express_1 = require("express");
const client_1 = require("@prisma/client");
const auth_1 = require("../middleware/auth");
const insightsService_1 = require("../services/insightsService");
const prisma = new client_1.PrismaClient();
function createFamiliesRouter(io) {
    const router = (0, express_1.Router)();
    router.post('/', auth_1.authenticate, async (req, res) => {
        try {
            const { id, name } = req.body;
            if (!name) {
                res.status(400).json({ error: 'Family name is required' });
                return;
            }
            const family = await prisma.family.create({
                data: { id: id || undefined, name, createdBy: req.userId },
            });
            await prisma.familyMember.create({
                data: { familyId: family.id, userId: req.userId, role: 'admin' },
            });
            res.status(201).json(family);
        }
        catch (error) {
            console.error('Create family error:', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    });
    router.get('/', auth_1.authenticate, async (req, res) => {
        try {
            const memberships = await prisma.familyMember.findMany({
                where: { userId: req.userId },
                include: { family: true },
            });
            res.json(memberships.map((m) => ({ ...m.family, role: m.role })));
        }
        catch (error) {
            console.error('Get families error:', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    });
    router.get('/:id/members', auth_1.authenticate, async (req, res) => {
        try {
            const id = String(req.params.id);
            const isMember = await prisma.familyMember.findUnique({
                where: { familyId_userId: { familyId: id, userId: req.userId } },
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
        }
        catch (error) {
            console.error('Get members error:', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    });
    // Weekly summary
    router.get('/:id/weekly-summary', auth_1.authenticate, async (req, res) => {
        try {
            const familyId = String(req.params.id);
            const isMember = await prisma.familyMember.findUnique({
                where: { familyId_userId: { familyId, userId: req.userId } },
            });
            if (!isMember) {
                res.status(403).json({ error: 'Forbidden' });
                return;
            }
            const now = new Date();
            const thisWeekStart = new Date(now);
            thisWeekStart.setDate(now.getDate() - now.getDay() + 1);
            thisWeekStart.setHours(0, 0, 0, 0);
            const lastWeekStart = new Date(thisWeekStart);
            lastWeekStart.setDate(thisWeekStart.getDate() - 7);
            const lastWeekEnd = new Date(thisWeekStart);
            const [thisWeekCount, lastWeekCount, thisWeekHistory] = await Promise.all([
                prisma.choreHistory.count({ where: { familyId, action: { startsWith: 'completed' }, createdAt: { gte: thisWeekStart } } }),
                prisma.choreHistory.count({ where: { familyId, action: { startsWith: 'completed' }, createdAt: { gte: lastWeekStart, lt: lastWeekEnd } } }),
                prisma.choreHistory.findMany({ where: { familyId, action: { startsWith: 'completed' }, createdAt: { gte: thisWeekStart } } }),
            ]);
            // Top contributor
            const contributorCount = {};
            thisWeekHistory.forEach((h) => { contributorCount[h.userId] = (contributorCount[h.userId] || 0) + 1; });
            const topContributorId = Object.entries(contributorCount).sort(([, a], [, b]) => b - a)[0];
            let topContributor = null;
            if (topContributorId) {
                const user = await prisma.user.findUnique({ where: { id: topContributorId[0] }, select: { displayName: true } });
                topContributor = { userId: topContributorId[0], displayName: user?.displayName || 'Unknown', count: topContributorId[1] };
            }
            // Top category
            const choreIds = thisWeekHistory.map((h) => h.choreId);
            const chores = choreIds.length > 0
                ? await prisma.chore.findMany({ where: { id: { in: choreIds } }, select: { category: true } })
                : [];
            const catCount = {};
            chores.forEach((c) => { catCount[c.category] = (catCount[c.category] || 0) + 1; });
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
        }
        catch (error) {
            console.error('Weekly summary error:', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    });
    // Leave family (self) or remove member (admin only)
    router.delete('/:id/members/:userId', auth_1.authenticate, async (req, res) => {
        try {
            const familyId = String(req.params.id);
            const targetUserId = String(req.params.userId);
            const requester = await prisma.familyMember.findUnique({
                where: { familyId_userId: { familyId, userId: req.userId } },
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
                        where: { familyId, userId: { not: req.userId } },
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
            // Cancel pending swaps involving the removed user
            const affectedSwaps = await prisma.choreSwapRequest.findMany({
                where: {
                    familyId,
                    status: 'pending',
                    OR: [{ fromUserId: targetUserId }, { toUserId: targetUserId }],
                },
            });
            if (affectedSwaps.length > 0) {
                await prisma.choreSwapRequest.updateMany({
                    where: {
                        familyId,
                        status: 'pending',
                        OR: [{ fromUserId: targetUserId }, { toUserId: targetUserId }],
                    },
                    data: { status: 'cancelled' },
                });
                for (const s of affectedSwaps) {
                    io.to(`family:${familyId}`).emit('swap_request_updated', {
                        swapRequestId: s.id,
                        choreId: s.choreId,
                        status: 'cancelled',
                        actorUserId: req.userId,
                    });
                }
            }
            res.json({ success: true });
        }
        catch (error) {
            console.error('Remove member error:', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    });
    // Update family name
    router.patch('/:id', auth_1.authenticate, async (req, res) => {
        try {
            const familyId = String(req.params.id);
            const { name } = req.body;
            const member = await prisma.familyMember.findUnique({
                where: { familyId_userId: { familyId, userId: req.userId } },
            });
            if (!member || member.role !== 'admin') {
                res.status(403).json({ error: 'Admin only' });
                return;
            }
            const updated = await prisma.family.update({ where: { id: familyId }, data: { name } });
            res.json(updated);
        }
        catch (error) {
            res.status(500).json({ error: 'Internal server error' });
        }
    });
    // Change member role
    router.patch('/:id/members/:userId/role', auth_1.authenticate, async (req, res) => {
        try {
            const familyId = String(req.params.id);
            const targetUserId = String(req.params.userId);
            const { role } = req.body;
            if (!['admin', 'member'].includes(role)) {
                res.status(400).json({ error: 'Role must be admin or member' });
                return;
            }
            const requester = await prisma.familyMember.findUnique({
                where: { familyId_userId: { familyId, userId: req.userId } },
            });
            if (!requester || requester.role !== 'admin') {
                res.status(403).json({ error: 'Admin only' });
                return;
            }
            const updated = await prisma.familyMember.update({
                where: { familyId_userId: { familyId, userId: targetUserId } },
                data: { role },
            });
            res.json(updated);
        }
        catch (error) {
            res.status(500).json({ error: 'Internal server error' });
        }
    });
    // Create family challenge
    router.post('/:id/challenges', auth_1.authenticate, async (req, res) => {
        try {
            const familyId = String(req.params.id);
            const { title, targetCount, endDate } = req.body;
            const member = await prisma.familyMember.findUnique({
                where: { familyId_userId: { familyId, userId: req.userId } },
            });
            if (!member) {
                res.status(403).json({ error: 'Forbidden' });
                return;
            }
            const challenge = await prisma.familyChallenge.create({
                data: {
                    familyId,
                    title: title || 'Family Challenge',
                    targetCount: targetCount || 20,
                    startDate: new Date(),
                    endDate: endDate ? new Date(endDate) : new Date(Date.now() + 7 * 86400000),
                    createdBy: req.userId,
                },
            });
            res.status(201).json({ ...challenge, startDate: challenge.startDate.toISOString(), endDate: challenge.endDate.toISOString(), createdAt: challenge.createdAt.toISOString() });
        }
        catch (error) {
            res.status(500).json({ error: 'Internal server error' });
        }
    });
    // List challenges
    router.get('/:id/challenges', auth_1.authenticate, async (req, res) => {
        try {
            const familyId = String(req.params.id);
            const challenges = await prisma.familyChallenge.findMany({
                where: { familyId },
                orderBy: { createdAt: 'desc' },
            });
            // Update currentCount from completed chores count
            const result = [];
            for (const c of challenges) {
                const count = await prisma.choreHistory.count({
                    where: { familyId, action: { startsWith: 'completed' }, createdAt: { gte: c.startDate, lte: c.endDate } },
                });
                if (count !== c.currentCount) {
                    await prisma.familyChallenge.update({ where: { id: c.id }, data: { currentCount: count } });
                }
                result.push({ ...c, currentCount: count, startDate: c.startDate.toISOString(), endDate: c.endDate.toISOString(), createdAt: c.createdAt.toISOString() });
            }
            res.json(result);
        }
        catch (error) {
            res.status(500).json({ error: 'Internal server error' });
        }
    });
    // Insights
    router.get('/:id/insights', auth_1.authenticate, async (req, res) => {
        try {
            const familyId = String(req.params.id);
            // Verify membership
            const isMember = await prisma.familyMember.findUnique({
                where: { familyId_userId: { familyId, userId: req.userId } },
            });
            if (!isMember) {
                res.status(403).json({ error: 'Not a member of this family' });
                return;
            }
            const now = new Date();
            const d90 = new Date(now);
            d90.setDate(now.getDate() - 90);
            const d14 = new Date(now);
            d14.setDate(now.getDate() - 14);
            // This week: Monday to now
            const thisWeekStart = new Date(now);
            thisWeekStart.setDate(now.getDate() - now.getDay() + 1);
            thisWeekStart.setHours(0, 0, 0, 0);
            const prevWeekStart = new Date(thisWeekStart);
            prevWeekStart.setDate(thisWeekStart.getDate() - 7);
            const [members, chores, history90d, history14d, thisWeekHistory, prevWeekHistory] = await Promise.all([
                prisma.familyMember.findMany({ where: { familyId }, include: { family: true } }),
                prisma.chore.findMany({ where: { familyId }, select: { id: true, title: true } }),
                prisma.choreHistory.findMany({ where: { familyId, action: { startsWith: 'completed' }, createdAt: { gte: d90 } } }),
                prisma.choreHistory.findMany({ where: { familyId, action: { startsWith: 'completed' }, createdAt: { gte: d14 } } }),
                prisma.choreHistory.findMany({ where: { familyId, action: { startsWith: 'completed' }, createdAt: { gte: thisWeekStart } } }),
                prisma.choreHistory.findMany({ where: { familyId, action: { startsWith: 'completed' }, createdAt: { gte: prevWeekStart, lt: thisWeekStart } } }),
            ]);
            // Resolve member names
            const memberUserIds = members.map((m) => m.userId);
            const users = await prisma.user.findMany({
                where: { id: { in: memberUserIds } },
                select: { id: true, displayName: true },
            });
            const userMap = Object.fromEntries(users.map((u) => [u.id, u.displayName]));
            const memberEntries = members.map((m) => ({ userId: m.userId, name: userMap[m.userId] || 'Unknown' }));
            const tzOffsetMinutes = parseInt(req.query.tzOffsetMinutes) || 0;
            const timingSuggestions = (0, insightsService_1.computeTimingPatterns)(chores, history90d, tzOffsetMinutes);
            const currentMemberIds = new Set(memberEntries.map((m) => m.userId));
            const memberScores = (0, insightsService_1.computeEngagementScores)(memberEntries, thisWeekHistory, prevWeekHistory)
                .filter((s) => currentMemberIds.has(s.userId));
            const fairness = (0, insightsService_1.computeFairnessIndex)(memberEntries, history14d);
            const driftAlerts = (0, insightsService_1.detectDriftAlerts)(memberScores);
            res.json({
                familySampleSize: history14d.length,
                timingSuggestions,
                memberScores,
                fairnessScore: fairness.score,
                fairnessDistribution: fairness.distribution,
                driftAlerts,
            });
        }
        catch (error) {
            console.error('Insights error:', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    });
    // Reschedule a chore based on a suggested timing pattern
    router.patch('/:id/chores/:choreId/reschedule', auth_1.authenticate, async (req, res) => {
        try {
            const familyId = String(req.params.id);
            const choreId = String(req.params.choreId);
            const userId = req.userId;
            const { dayOfWeek, hour } = req.body;
            if (!Number.isInteger(dayOfWeek) || dayOfWeek < 0 || dayOfWeek > 6) {
                res.status(400).json({ error: 'dayOfWeek must be an integer between 0 and 6' });
                return;
            }
            if (!Number.isInteger(hour) || hour < 0 || hour > 23) {
                res.status(400).json({ error: 'hour must be an integer between 0 and 23' });
                return;
            }
            const isMember = await prisma.familyMember.findUnique({
                where: { familyId_userId: { familyId, userId } },
            });
            if (!isMember) {
                res.status(403).json({ error: 'Not a member of this family' });
                return;
            }
            const chore = await prisma.chore.findFirst({ where: { id: choreId, familyId } });
            if (!chore) {
                res.status(404).json({ error: 'Chore not found' });
                return;
            }
            const tzOffsetMinutes = parseInt(req.body.tzOffsetMinutes) || 0;
            const now = new Date();
            // Shift to the user's local time for day/hour comparisons.
            const localNow = new Date(now.getTime() + tzOffsetMinutes * 60000);
            const daysUntil = (dayOfWeek - localNow.getUTCDay() + 7) % 7;
            const nextLocalDate = new Date(localNow);
            nextLocalDate.setUTCDate(localNow.getUTCDate() + (daysUntil === 0 && localNow.getUTCHours() >= hour ? 7 : daysUntil));
            nextLocalDate.setUTCHours(hour, 0, 0, 0);
            // Convert the local target back to UTC for storage.
            const nextDate = new Date(nextLocalDate.getTime() - tzOffsetMinutes * 60000);
            const updatedChore = await prisma.chore.update({
                where: { id: choreId },
                data: { dueDate: nextDate },
            });
            res.json({ dueDate: updatedChore.dueDate });
        }
        catch (error) {
            console.error('Reschedule chore error:', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    });
    return router;
}
