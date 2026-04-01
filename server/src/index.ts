import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { createServer } from 'http';
import { Server } from 'socket.io';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';
import authRoutes from './routes/auth';
import userRoutes from './routes/users';
import familyRoutes from './routes/families';
import choreRoutes from './routes/chores';
import invitationRoutes from './routes/invitations';
import syncRoutes from './routes/sync';
import messageRoutes from './routes/messages';

dotenv.config();

const app = express();
const httpServer = createServer(app);
const prisma = new PrismaClient();
const PORT = process.env.PORT || 3000;

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
  socket.on('send_message', async (data: { id: string; familyId: string; text: string; choreId?: string; mentions?: string }) => {
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

      io.to(`family:${data.familyId}`).emit('new_message', {
        id: message.id,
        familyId: message.familyId,
        userId: message.userId,
        text: message.text,
        choreId: message.choreId,
        mentions: message.mentions,
        chore: choreData,
        createdAt: message.createdAt.toISOString(),
        userName: user?.displayName || 'Unknown',
      });
    } catch (err) {
      console.error('Error sending message:', err);
      socket.emit('message_error', { id: data.id, error: 'Failed to send message' });
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
app.use('/api/families', familyRoutes);
app.use('/api/chores', choreRoutes);
app.use('/api/invitations', invitationRoutes);
app.use('/api/sync', syncRoutes);
app.use('/api/messages', messageRoutes);

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok' });
});

httpServer.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});

export default app;
