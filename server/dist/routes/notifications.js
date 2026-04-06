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
exports.default = router;
