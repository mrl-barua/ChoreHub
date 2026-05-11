"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const client_1 = require("@prisma/client");
const auth_1 = require("../middleware/auth");
const router = (0, express_1.Router)();
const prisma = new client_1.PrismaClient();
// List notifications for current user
router.get('/', auth_1.authenticate, async (req, res) => {
    try {
        const limit = Math.min(parseInt(String(req.query.limit || '50')), 100);
        const notifications = await prisma.notification.findMany({
            where: { userId: req.userId },
            orderBy: { createdAt: 'desc' },
            take: limit,
        });
        res.json(notifications.map((n) => ({ ...n, createdAt: n.createdAt.toISOString() })));
    }
    catch (error) {
        console.error('Get notifications error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Unread count
router.get('/unread-count', auth_1.authenticate, async (req, res) => {
    try {
        const count = await prisma.notification.count({
            where: { userId: req.userId, read: false },
        });
        res.json({ count });
    }
    catch (error) {
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Mark single as read
router.patch('/:id/read', auth_1.authenticate, async (req, res) => {
    try {
        await prisma.notification.update({
            where: { id: String(req.params.id) },
            data: { read: true },
        });
        res.json({ success: true });
    }
    catch (error) {
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Mark all as read
router.post('/read-all', auth_1.authenticate, async (req, res) => {
    try {
        await prisma.notification.updateMany({
            where: { userId: req.userId, read: false },
            data: { read: true },
        });
        res.json({ success: true });
    }
    catch (error) {
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /api/notifications/device-token
router.post('/device-token', auth_1.authenticate, async (req, res) => {
    const { token, platform } = req.body;
    if (!token || !platform) {
        res.status(400).json({ error: 'token and platform required' });
        return;
    }
    try {
        const deviceToken = await prisma.deviceToken.upsert({
            where: { token },
            update: { userId: req.userId, lastSeenAt: new Date() },
            create: { userId: req.userId, token, platform },
        });
        res.json(deviceToken);
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to register device token' });
    }
});
// DELETE /api/notifications/device-token/:token
router.delete('/device-token/:token', auth_1.authenticate, async (req, res) => {
    const token = String(req.params.token);
    try {
        await prisma.deviceToken.deleteMany({ where: { token, userId: req.userId } });
        res.json({ success: true });
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to remove device token' });
    }
});
// GET /api/notifications/preferences
router.get('/preferences', auth_1.authenticate, async (req, res) => {
    try {
        const prefs = await prisma.notificationPreference.upsert({
            where: { userId: req.userId },
            update: {},
            create: { userId: req.userId },
        });
        res.json(prefs);
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to fetch preferences' });
    }
});
// PATCH /api/notifications/preferences
router.patch('/preferences', auth_1.authenticate, async (req, res) => {
    const allowed = ['pushEnabled', 'choreAssigned', 'choreCompleted', 'choreDueSoon', 'mention', 'swap', 'dailySummary', 'quietHoursStart', 'quietHoursEnd'];
    const updates = {};
    for (const key of allowed) {
        if (req.body[key] !== undefined)
            updates[key] = req.body[key];
    }
    try {
        const prefs = await prisma.notificationPreference.upsert({
            where: { userId: req.userId },
            update: updates,
            create: { userId: req.userId, ...updates },
        });
        res.json(prefs);
    }
    catch (e) {
        res.status(500).json({ error: 'Failed to update preferences' });
    }
});
exports.default = router;
