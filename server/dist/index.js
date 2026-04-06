"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const dotenv_1 = __importDefault(require("dotenv"));
const path_1 = __importDefault(require("path"));
const http_1 = require("http");
const socket_io_1 = require("socket.io");
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const client_1 = require("@prisma/client");
const auth_1 = __importDefault(require("./routes/auth"));
const users_1 = __importDefault(require("./routes/users"));
const families_1 = __importDefault(require("./routes/families"));
const chores_1 = __importDefault(require("./routes/chores"));
const invitations_1 = __importDefault(require("./routes/invitations"));
const sync_1 = __importDefault(require("./routes/sync"));
const messages_1 = __importDefault(require("./routes/messages"));
const notifications_1 = __importDefault(require("./routes/notifications"));
dotenv_1.default.config();
const app = (0, express_1.default)();
const httpServer = (0, http_1.createServer)(app);
const prisma = new client_1.PrismaClient();
const PORT = process.env.PORT || 3000;
// Serve uploaded images
app.use('/uploads', express_1.default.static(path_1.default.join(__dirname, '..', 'uploads')));
// Socket.IO setup
const io = new socket_io_1.Server(httpServer, {
    cors: { origin: '*', methods: ['GET', 'POST'] },
});
// Socket.IO auth middleware - verify JWT
io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    if (!token) {
        return next(new Error('Authentication required'));
    }
    try {
        const payload = jsonwebtoken_1.default.verify(token, process.env.JWT_SECRET);
        socket.data.userId = payload.userId;
        next();
    }
    catch {
        next(new Error('Invalid token'));
    }
});
// Socket.IO connection handler
io.on('connection', async (socket) => {
    const userId = socket.data.userId;
    console.log(`User ${userId} connected via Socket.IO`);
    // Join all family rooms this user belongs to
    try {
        const memberships = await prisma.familyMember.findMany({
            where: { userId },
            select: { familyId: true },
        });
        for (const m of memberships) {
            socket.join(`family:${m.familyId}`);
        }
    }
    catch (err) {
        console.error('Error joining family rooms:', err);
    }
    // Handle sending messages
    socket.on('send_message', async (data) => {
        try {
            const member = await prisma.familyMember.findUnique({
                where: { familyId_userId: { familyId: data.familyId, userId } },
            });
            if (!member)
                return;
            const user = await prisma.user.findUnique({
                where: { id: userId },
                select: { displayName: true, username: true },
            });
            const message = await prisma.message.create({
                data: {
                    id: data.id,
                    familyId: data.familyId,
                    userId,
                    text: data.text,
                    choreId: data.choreId || null,
                    mentions: data.mentions || null,
                    replyToId: data.replyToId || null,
                    imageUrl: data.imageUrl || null,
                },
            });
            // If chore attached, fetch chore details for the broadcast
            let choreData = null;
            if (message.choreId) {
                const chore = await prisma.chore.findUnique({
                    where: { id: message.choreId },
                    select: { id: true, title: true, status: true, category: true, assignedTo: true },
                });
                choreData = chore;
            }
            // If reply, fetch the original message
            let replyTo = null;
            if (message.replyToId) {
                const original = await prisma.message.findUnique({
                    where: { id: message.replyToId },
                });
                if (original) {
                    const originalUser = await prisma.user.findUnique({
                        where: { id: original.userId },
                        select: { displayName: true },
                    });
                    replyTo = {
                        id: original.id,
                        text: original.text,
                        userId: original.userId,
                        userName: originalUser?.displayName || 'Unknown',
                    };
                }
            }
            io.to(`family:${data.familyId}`).emit('new_message', {
                id: message.id,
                familyId: message.familyId,
                userId: message.userId,
                text: message.text,
                choreId: message.choreId,
                mentions: message.mentions,
                replyToId: message.replyToId,
                imageUrl: message.imageUrl,
                reactions: message.reactions,
                chore: choreData,
                replyTo,
                createdAt: message.createdAt.toISOString(),
                userName: user?.displayName || 'Unknown',
            });
        }
        catch (err) {
            console.error('Error sending message:', err);
            socket.emit('message_error', { id: data.id, error: 'Failed to send message' });
        }
    });
    // Handle reactions
    socket.on('toggle_reaction', async (data) => {
        try {
            const message = await prisma.message.findUnique({ where: { id: data.messageId } });
            if (!message)
                return;
            let reactions = {};
            if (message.reactions) {
                try {
                    reactions = JSON.parse(message.reactions);
                }
                catch { }
            }
            if (!reactions[data.emoji]) {
                reactions[data.emoji] = [];
            }
            const idx = reactions[data.emoji].indexOf(userId);
            if (idx >= 0) {
                reactions[data.emoji].splice(idx, 1);
                if (reactions[data.emoji].length === 0)
                    delete reactions[data.emoji];
            }
            else {
                reactions[data.emoji].push(userId);
            }
            const reactionsStr = Object.keys(reactions).length > 0 ? JSON.stringify(reactions) : null;
            await prisma.message.update({
                where: { id: data.messageId },
                data: { reactions: reactionsStr },
            });
            io.to(`family:${data.familyId}`).emit('reaction_updated', {
                messageId: data.messageId,
                reactions: reactionsStr,
            });
        }
        catch (err) {
            console.error('Error toggling reaction:', err);
        }
    });
    // Handle read receipts
    socket.on('mark_read', async (data) => {
        try {
            for (const messageId of data.messageIds) {
                await prisma.messageReadReceipt.upsert({
                    where: { messageId_userId: { messageId, userId } },
                    create: { messageId, userId },
                    update: { readAt: new Date() },
                });
            }
            io.to(`family:${data.familyId}`).emit('messages_read', {
                userId,
                messageIds: data.messageIds,
            });
        }
        catch (err) {
            console.error('Error marking read:', err);
        }
    });
    // Handle delete message
    socket.on('delete_message', async (data) => {
        try {
            const message = await prisma.message.findUnique({ where: { id: data.messageId } });
            if (!message || message.userId !== userId)
                return;
            await prisma.message.update({
                where: { id: data.messageId },
                data: { deletedAt: new Date() },
            });
            io.to(`family:${data.familyId}`).emit('message_deleted', {
                messageId: data.messageId,
            });
        }
        catch (err) {
            console.error('Error deleting message:', err);
        }
    });
    // Handle typing indicator
    socket.on('typing', (data) => {
        socket.to(`family:${data.familyId}`).emit('user_typing', {
            userId,
            familyId: data.familyId,
        });
    });
    // Handle stop typing
    socket.on('stop_typing', (data) => {
        socket.to(`family:${data.familyId}`).emit('user_stop_typing', {
            userId,
            familyId: data.familyId,
        });
    });
    socket.on('disconnect', () => {
        console.log(`User ${userId} disconnected`);
    });
});
app.use((0, helmet_1.default)());
app.use((0, cors_1.default)());
app.use(express_1.default.json());
app.use('/api/auth', auth_1.default);
app.use('/api/users', users_1.default);
app.use('/api/families', families_1.default);
app.use('/api/chores', chores_1.default);
app.use('/api/invitations', invitations_1.default);
app.use('/api/sync', sync_1.default);
app.use('/api/messages', messages_1.default);
app.use('/api/notifications', notifications_1.default);
app.get('/api/health', (_req, res) => {
    res.json({ status: 'ok' });
});
httpServer.listen(Number(PORT), '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
});
exports.default = app;
