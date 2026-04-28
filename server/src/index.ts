import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import path from 'path';
import { createServer } from 'http';
import { Server } from 'socket.io';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';
import authRoutes from './routes/auth';
import userRoutes from './routes/users';
import createFamiliesRouter from './routes/families';
import createChoresRouter from './routes/chores';
import invitationRoutes from './routes/invitations';
import syncRoutes from './routes/sync';
import messageRoutes from './routes/messages';
import notificationRoutes from './routes/notifications';
import createSwapRequestsRouter from './routes/swap-requests';

dotenv.config();

const app = express();
const httpServer = createServer(app);
const prisma = new PrismaClient();
const PORT = process.env.PORT || 3000;

// Serve uploaded images
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// Socket.IO setup
const io = new Server(httpServer, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
});

// Socket.IO auth middleware - verify JWT
io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  if (!token) {
    return next(new Error('Authentication required'));
  }
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as { userId: string };
    socket.data.userId = payload.userId;
    next();
  } catch {
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
  } catch (err) {
    console.error('Error joining family rooms:', err);
  }

  // Handle sending messages
  socket.on('send_message', async (data: { id: string; familyId: string; text: string; choreId?: string; mentions?: string; replyToId?: string; imageUrl?: string }) => {
    try {
      const member = await prisma.familyMember.findUnique({
        where: { familyId_userId: { familyId: data.familyId, userId } },
      });
      if (!member) return;

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
    } catch (err) {
      console.error('Error sending message:', err);
      socket.emit('message_error', { id: data.id, error: 'Failed to send message' });
    }
  });

  // Handle reactions
  socket.on('toggle_reaction', async (data: { messageId: string; familyId: string; emoji: string }) => {
    try {
      const message = await prisma.message.findUnique({ where: { id: data.messageId } });
      if (!message) return;

      let reactions: Record<string, string[]> = {};
      if (message.reactions) {
        try { reactions = JSON.parse(message.reactions); } catch {}
      }

      if (!reactions[data.emoji]) {
        reactions[data.emoji] = [];
      }

      const idx = reactions[data.emoji].indexOf(userId);
      if (idx >= 0) {
        reactions[data.emoji].splice(idx, 1);
        if (reactions[data.emoji].length === 0) delete reactions[data.emoji];
      } else {
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
    } catch (err) {
      console.error('Error toggling reaction:', err);
    }
  });

  // Handle read receipts
  socket.on('mark_read', async (data: { messageIds: string[]; familyId: string }) => {
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
    } catch (err) {
      console.error('Error marking read:', err);
    }
  });

  // Handle delete message
  socket.on('delete_message', async (data: { messageId: string; familyId: string }) => {
    try {
      const message = await prisma.message.findUnique({ where: { id: data.messageId } });
      if (!message || message.userId !== userId) return;

      await prisma.message.update({
        where: { id: data.messageId },
        data: { deletedAt: new Date() },
      });

      io.to(`family:${data.familyId}`).emit('message_deleted', {
        messageId: data.messageId,
      });
    } catch (err) {
      console.error('Error deleting message:', err);
    }
  });

  // Handle typing indicator
  socket.on('typing', (data: { familyId: string }) => {
    socket.to(`family:${data.familyId}`).emit('user_typing', {
      userId,
      familyId: data.familyId,
    });
  });

  // Handle stop typing
  socket.on('stop_typing', (data: { familyId: string }) => {
    socket.to(`family:${data.familyId}`).emit('user_stop_typing', {
      userId,
      familyId: data.familyId,
    });
  });

  socket.on('disconnect', () => {
    console.log(`User ${userId} disconnected`);
  });
});

app.use(helmet());
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/families', createFamiliesRouter(io));
app.use('/api/chores', createChoresRouter(io));
app.use('/api/invitations', invitationRoutes);
app.use('/api/sync', syncRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/swap-requests', createSwapRequestsRouter(io));

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok' });
});

httpServer.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});

export default app;
