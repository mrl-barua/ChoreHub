"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const client_1 = require("@prisma/client");
const auth_1 = require("../middleware/auth");
const notification_1 = require("../services/notification");
const multer_1 = __importDefault(require("multer"));
const path_1 = __importDefault(require("path"));
const fs_1 = __importDefault(require("fs"));
const router = (0, express_1.Router)();
const prisma = new client_1.PrismaClient();
// Setup multer for image uploads
const uploadDir = path_1.default.join(__dirname, '..', '..', 'uploads');
if (!fs_1.default.existsSync(uploadDir)) {
    fs_1.default.mkdirSync(uploadDir, { recursive: true });
}
const storage = multer_1.default.diskStorage({
    destination: (_req, _file, cb) => cb(null, uploadDir),
    filename: (_req, file, cb) => {
        const ext = path_1.default.extname(file.originalname);
        cb(null, `${Date.now()}-${Math.random().toString(36).substring(7)}${ext}`);
    },
});
const upload = (0, multer_1.default)({
    storage,
    limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
    fileFilter: (_req, file, cb) => {
        const allowed = /\.(jpg|jpeg|png|gif|webp)$/i;
        if (allowed.test(path_1.default.extname(file.originalname))) {
            cb(null, true);
        }
        else {
            cb(new Error('Only image files are allowed'));
        }
    },
});
// Get message history (paginated)
router.get('/', auth_1.authenticate, async (req, res) => {
    try {
        const familyId = String(req.query.familyId || '');
        const before = req.query.before ? String(req.query.before) : undefined;
        const limit = Math.min(parseInt(String(req.query.limit || '50')), 100);
        const search = req.query.search ? String(req.query.search) : undefined;
        if (!familyId) {
            res.status(400).json({ error: 'familyId is required' });
            return;
        }
        // Verify membership
        const member = await prisma.familyMember.findUnique({
            where: { familyId_userId: { familyId, userId: req.userId } },
        });
        if (!member) {
            res.status(403).json({ error: 'Not a member of this family' });
            return;
        }
        const messages = await prisma.message.findMany({
            where: {
                familyId,
                deletedAt: null,
                ...(before ? { createdAt: { lt: new Date(before) } } : {}),
                ...(search ? { text: { contains: search, mode: 'insensitive' } } : {}),
            },
            orderBy: { createdAt: 'desc' },
            take: limit,
        });
        // Get user info for messages
        const userIds = Array.from(new Set(messages.map((m) => m.userId)));
        const users = await prisma.user.findMany({
            where: { id: { in: userIds } },
            select: { id: true, displayName: true, username: true },
        });
        // Get chore info for messages with attachments
        const choreIds = messages
            .map((m) => m.choreId)
            .filter((id) => id !== null);
        const chores = choreIds.length > 0
            ? await prisma.chore.findMany({
                where: { id: { in: choreIds } },
                select: { id: true, title: true, status: true, category: true, assignedTo: true },
            })
            : [];
        // Get reply-to messages
        const replyToIds = messages
            .map((m) => m.replyToId)
            .filter((id) => id !== null);
        const replyMessages = replyToIds.length > 0
            ? await prisma.message.findMany({
                where: { id: { in: replyToIds } },
                select: { id: true, text: true, userId: true },
            })
            : [];
        const replyUserIds = Array.from(new Set(replyMessages.map((m) => m.userId)));
        const replyUsers = replyUserIds.length > 0
            ? await prisma.user.findMany({
                where: { id: { in: replyUserIds } },
                select: { id: true, displayName: true },
            })
            : [];
        // Get read receipts for these messages
        const messageIds = messages.map((m) => m.id);
        const readReceipts = await prisma.messageReadReceipt.findMany({
            where: { messageId: { in: messageIds } },
        });
        // Group read receipts by messageId
        const readReceiptMap = {};
        for (const rr of readReceipts) {
            if (!readReceiptMap[rr.messageId])
                readReceiptMap[rr.messageId] = [];
            readReceiptMap[rr.messageId].push(rr.userId);
        }
        const result = messages.map((m) => {
            const replyMsg = m.replyToId ? replyMessages.find((r) => r.id === m.replyToId) : null;
            const replyUser = replyMsg ? replyUsers.find((u) => u.id === replyMsg.userId) : null;
            return {
                id: m.id,
                familyId: m.familyId,
                userId: m.userId,
                text: m.text,
                choreId: m.choreId,
                mentions: m.mentions,
                replyToId: m.replyToId,
                imageUrl: m.imageUrl,
                reactions: m.reactions,
                createdAt: m.createdAt.toISOString(),
                userName: users.find((u) => u.id === m.userId)?.displayName || 'Unknown',
                chore: m.choreId ? chores.find((c) => c.id === m.choreId) || null : null,
                replyTo: replyMsg
                    ? { id: replyMsg.id, text: replyMsg.text, userId: replyMsg.userId, userName: replyUser?.displayName || 'Unknown' }
                    : null,
                readBy: readReceiptMap[m.id] || [],
            };
        });
        // Return in chronological order (oldest first)
        res.json(result.reverse());
    }
    catch (error) {
        console.error('Get messages error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Send message via REST (for offline sync)
router.post('/send', auth_1.authenticate, async (req, res) => {
    try {
        const { id, familyId, text, choreId, mentions, replyToId, imageUrl, createdAt } = req.body;
        if (!familyId || !text) {
            res.status(400).json({ error: 'familyId and text are required' });
            return;
        }
        // Verify membership
        const member = await prisma.familyMember.findUnique({
            where: { familyId_userId: { familyId, userId: req.userId } },
        });
        if (!member) {
            res.status(403).json({ error: 'Not a member of this family' });
            return;
        }
        // Upsert — don't fail if message already exists (sent via socket)
        const message = await prisma.message.upsert({
            where: { id },
            create: {
                id,
                familyId,
                userId: req.userId,
                text,
                choreId: choreId || null,
                mentions: mentions || null,
                replyToId: replyToId || null,
                imageUrl: imageUrl || null,
                createdAt: createdAt ? new Date(createdAt) : new Date(),
            },
            update: {}, // If it exists, don't overwrite
        });
        // Mention detection — fire-and-forget, errors must not break the response
        try {
            const mentionMatches = text.match(/@([a-zA-Z0-9_]+)/g) ?? [];
            if (mentionMatches.length) {
                const usernames = mentionMatches.map((m) => m.slice(1));
                // Get family members for this family, then filter by username
                const familyMembers = await prisma.familyMember.findMany({
                    where: { familyId: message.familyId },
                    select: { userId: true },
                });
                const familyUserIds = familyMembers.map((fm) => fm.userId);
                const mentioned = await prisma.user.findMany({
                    where: { username: { in: usernames }, id: { in: familyUserIds } },
                });
                const sender = await prisma.user.findUnique({ where: { id: req.userId }, select: { displayName: true } });
                for (const u of mentioned) {
                    if (u.id !== req.userId) {
                        (0, notification_1.createNotification)(u.id, familyId, 'mention', 'You were mentioned', `${sender?.displayName ?? 'Someone'} mentioned you`, JSON.stringify({ messageId: message.id, familyId: message.familyId }));
                    }
                }
            }
        }
        catch (mentionErr) {
            console.error('[messages] mention notification failed:', mentionErr);
        }
        res.json({ success: true });
    }
    catch (error) {
        console.error('Send message error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// Upload image
router.post('/upload', auth_1.authenticate, upload.single('image'), async (req, res) => {
    try {
        if (!req.file) {
            res.status(400).json({ error: 'No image provided' });
            return;
        }
        const imageUrl = `/uploads/${req.file.filename}`;
        res.json({ imageUrl });
    }
    catch (error) {
        console.error('Upload error:', error);
        res.status(500).json({ error: 'Upload failed' });
    }
});
// Get unread count for a family
router.get('/unread', auth_1.authenticate, async (req, res) => {
    try {
        const familyId = String(req.query.familyId || '');
        if (!familyId) {
            res.status(400).json({ error: 'familyId is required' });
            return;
        }
        const member = await prisma.familyMember.findUnique({
            where: { familyId_userId: { familyId, userId: req.userId } },
        });
        if (!member) {
            res.status(403).json({ error: 'Not a member of this family' });
            return;
        }
        // Count messages NOT sent by the user that don't have a read receipt
        const unreadMessages = await prisma.message.findMany({
            where: {
                familyId,
                deletedAt: null,
                userId: { not: req.userId },
            },
            select: { id: true },
        });
        const readCount = await prisma.messageReadReceipt.count({
            where: {
                userId: req.userId,
                messageId: { in: unreadMessages.map((m) => m.id) },
            },
        });
        res.json({ unreadCount: unreadMessages.length - readCount });
    }
    catch (error) {
        console.error('Unread count error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
exports.default = router;
