"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const client_1 = require("@prisma/client");
const auth_1 = require("../middleware/auth");
const router = (0, express_1.Router)();
const prisma = new client_1.PrismaClient();
router.get('/search', auth_1.authenticate, async (req, res) => {
    try {
        const query = req.query.q;
        if (!query || query.length < 2) {
            res.status(400).json({ error: 'Search query must be at least 2 characters' });
            return;
        }
        const users = await prisma.user.findMany({
            where: {
                AND: [
                    { id: { not: req.userId } },
                    {
                        OR: [
                            { username: { contains: query, mode: 'insensitive' } },
                            { displayName: { contains: query, mode: 'insensitive' } },
                        ],
                    },
                ],
            },
            select: { id: true, username: true, displayName: true },
            take: 20,
        });
        res.json(users);
    }
    catch (error) {
        console.error('User search error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Update profile
router.patch('/me', auth_1.authenticate, async (req, res) => {
    try {
        const { displayName, avatarUrl } = req.body;
        const data = {};
        if (displayName)
            data.displayName = displayName;
        if (avatarUrl !== undefined)
            data.avatarUrl = avatarUrl;
        const user = await prisma.user.update({
            where: { id: req.userId },
            data,
            select: { id: true, username: true, displayName: true, email: true },
        });
        res.json(user);
    }
    catch (error) {
        console.error('Update profile error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Change password
router.post('/me/change-password', auth_1.authenticate, async (req, res) => {
    try {
        const { currentPassword, newPassword } = req.body;
        if (!currentPassword || !newPassword || newPassword.length < 6) {
            res.status(400).json({ error: 'New password must be at least 6 characters' });
            return;
        }
        const user = await prisma.user.findUnique({ where: { id: req.userId } });
        if (!user) {
            res.status(404).json({ error: 'User not found' });
            return;
        }
        const bcrypt = require('bcryptjs');
        const valid = await bcrypt.compare(currentPassword, user.password);
        if (!valid) {
            res.status(401).json({ error: 'Current password is incorrect' });
            return;
        }
        const hashed = await bcrypt.hash(newPassword, 10);
        await prisma.user.update({ where: { id: req.userId }, data: { password: hashed } });
        res.json({ success: true });
    }
    catch (error) {
        console.error('Change password error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Get personal stats
router.get('/me/stats', auth_1.authenticate, async (req, res) => {
    try {
        const userId = req.userId;
        // Get all families user belongs to
        const memberships = await prisma.familyMember.findMany({
            where: { userId },
            select: { familyId: true },
        });
        const familyIds = memberships.map(m => m.familyId);
        const [totalCompleted, totalAssigned, totalCreated] = await Promise.all([
            prisma.choreHistory.count({ where: { userId, action: 'completed' } }),
            prisma.chore.count({ where: { assignedTo: userId, familyId: { in: familyIds } } }),
            prisma.chore.count({ where: { createdBy: userId, familyId: { in: familyIds } } }),
        ]);
        // Category breakdown for this user
        const completedHistory = await prisma.choreHistory.findMany({
            where: { userId, action: 'completed' },
            select: { choreId: true },
        });
        const choreIds = completedHistory.map(h => h.choreId);
        const completedChores = choreIds.length > 0
            ? await prisma.chore.findMany({
                where: { id: { in: choreIds } },
                select: { category: true },
            })
            : [];
        const categoryCount = {};
        completedChores.forEach((c) => {
            categoryCount[c.category] = (categoryCount[c.category] || 0) + 1;
        });
        const topCategory = Object.entries(categoryCount).sort(([, a], [, b]) => b - a)[0];
        // Streak
        const userHistory = await prisma.choreHistory.findMany({
            where: { userId, action: 'completed' },
            orderBy: { createdAt: 'desc' },
            select: { createdAt: true },
        });
        const uniqueDays = Array.from(new Set(userHistory.map((h) => h.createdAt.toISOString().substring(0, 10))));
        let streak = 0;
        let checkDate = new Date();
        for (const dayStr of uniqueDays) {
            const day = new Date(dayStr);
            const diffMs = new Date(checkDate.getFullYear(), checkDate.getMonth(), checkDate.getDate()).getTime()
                - new Date(day.getFullYear(), day.getMonth(), day.getDate()).getTime();
            const diffDays = Math.round(diffMs / 86400000);
            if (diffDays <= 1) {
                streak++;
                checkDate = day;
            }
            else {
                break;
            }
        }
        res.json({
            totalCompleted,
            totalAssigned,
            totalCreated,
            currentStreak: streak,
            topCategory: topCategory ? topCategory[0] : null,
            topCategoryCount: topCategory ? topCategory[1] : 0,
        });
    }
    catch (error) {
        console.error('Stats error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Get stats for any user (for member drill-down)
router.get('/:userId/stats', auth_1.authenticate, async (req, res) => {
    try {
        const targetUserId = String(req.params.userId);
        const familyId = String(req.query.familyId || '');
        if (!familyId) {
            res.status(400).json({ error: 'familyId required' });
            return;
        }
        // Verify both users are members
        const [requesterMember, targetMember] = await Promise.all([
            prisma.familyMember.findUnique({ where: { familyId_userId: { familyId, userId: req.userId } } }),
            prisma.familyMember.findUnique({ where: { familyId_userId: { familyId, userId: targetUserId } } }),
        ]);
        if (!requesterMember || !targetMember) {
            res.status(403).json({ error: 'Forbidden' });
            return;
        }
        const [totalCompleted, totalAssigned] = await Promise.all([
            prisma.choreHistory.count({ where: { userId: targetUserId, familyId, action: { startsWith: 'completed' } } }),
            prisma.chore.count({ where: { assignedTo: targetUserId, familyId } }),
        ]);
        // Category breakdown
        const completedHistory = await prisma.choreHistory.findMany({
            where: { userId: targetUserId, familyId, action: { startsWith: 'completed' } },
            select: { choreId: true },
        });
        const choreIds = completedHistory.map((h) => h.choreId);
        const completedChores = choreIds.length > 0
            ? await prisma.chore.findMany({ where: { id: { in: choreIds } }, select: { category: true } })
            : [];
        const categoryBreakdown = {};
        completedChores.forEach((c) => { categoryBreakdown[c.category] = (categoryBreakdown[c.category] || 0) + 1; });
        const topCat = Object.entries(categoryBreakdown).sort(([, a], [, b]) => b - a)[0];
        // Weekly completions
        const now = new Date();
        const weekStart = new Date(now);
        weekStart.setDate(now.getDate() - now.getDay() + 1);
        weekStart.setHours(0, 0, 0, 0);
        const weekHistory = await prisma.choreHistory.findMany({
            where: { userId: targetUserId, familyId, action: { startsWith: 'completed' }, createdAt: { gte: weekStart } },
        });
        const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const weeklyCompletions = dayNames.map((name, i) => {
            const d = new Date(weekStart);
            d.setDate(weekStart.getDate() + i);
            const ds = d.toISOString().substring(0, 10);
            return { dayName: name, completed: weekHistory.filter((h) => h.createdAt.toISOString().substring(0, 10) === ds).length };
        });
        // Streak
        const allHistory = await prisma.choreHistory.findMany({
            where: { userId: targetUserId, familyId, action: { startsWith: 'completed' } },
            orderBy: { createdAt: 'desc' },
            select: { createdAt: true },
        });
        const uniqueDays = Array.from(new Set(allHistory.map((h) => h.createdAt.toISOString().substring(0, 10))));
        let streak = 0;
        let checkDate = new Date();
        for (const dayStr of uniqueDays) {
            const day = new Date(dayStr);
            const diff = Math.round((new Date(checkDate.getFullYear(), checkDate.getMonth(), checkDate.getDate()).getTime()
                - new Date(day.getFullYear(), day.getMonth(), day.getDate()).getTime()) / 86400000);
            if (diff <= 1) {
                streak++;
                checkDate = day;
            }
            else
                break;
        }
        res.json({
            totalCompleted, totalAssigned, currentStreak: streak,
            topCategory: topCat ? topCat[0] : null, topCategoryCount: topCat ? topCat[1] : 0,
            weeklyCompletions, categoryBreakdown,
        });
    }
    catch (error) {
        console.error('Member stats error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
router.get('/me', auth_1.authenticate, async (req, res) => {
    try {
        const user = await prisma.user.findUnique({
            where: { id: req.userId },
            select: { id: true, username: true, displayName: true, email: true },
        });
        if (!user) {
            res.status(404).json({ error: 'User not found' });
            return;
        }
        res.json(user);
    }
    catch (error) {
        console.error('Get me error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Avatar upload
const multer_1 = __importDefault(require("multer"));
const path_1 = __importDefault(require("path"));
const avatarStorage = multer_1.default.diskStorage({
    destination: path_1.default.join(__dirname, '../../uploads'),
    filename: (_req, file, cb) => cb(null, `avatar-${Date.now()}-${Math.round(Math.random() * 1e6)}${path_1.default.extname(file.originalname)}`),
});
const avatarUpload = (0, multer_1.default)({ storage: avatarStorage, limits: { fileSize: 5 * 1024 * 1024 } });
router.post('/me/avatar', auth_1.authenticate, avatarUpload.single('avatar'), async (req, res) => {
    try {
        if (!req.file) {
            res.status(400).json({ error: 'No image provided' });
            return;
        }
        const avatarUrl = `/uploads/${req.file.filename}`;
        await prisma.user.update({ where: { id: req.userId }, data: { avatarUrl } });
        res.json({ avatarUrl });
    }
    catch (error) {
        console.error('Avatar upload error:', error);
        res.status(500).json({ error: 'Upload failed' });
    }
});
exports.default = router;
