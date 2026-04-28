import cron from 'node-cron';
import { PrismaClient } from '@prisma/client';
import { createNotification } from '../services/notification';

const prisma = new PrismaClient();

export function startDueSoonReminder() {
  cron.schedule('*/15 * * * *', async () => {
    try {
      const now = new Date();
      const windowStart = new Date(now.getTime() + 30 * 60 * 1000);
      const windowEnd = new Date(now.getTime() + 90 * 60 * 1000);
      const chores = await prisma.chore.findMany({
        where: {
          status: 'pending',
          dueSoonReminderSentAt: null,
          dueDate: { gte: windowStart, lte: windowEnd },
          assignedTo: { not: null },
        },
      });
      for (const chore of chores) {
        await createNotification(
          chore.assignedTo!,
          chore.familyId,
          'chore_due_soon',
          'Chore due soon',
          `"${chore.title}" is due in about an hour`,
          JSON.stringify({ choreId: chore.id })
        );
        await prisma.chore.update({
          where: { id: chore.id },
          data: { dueSoonReminderSentAt: now },
        });
      }
    } catch (e) {
      console.error('[dueSoonReminder]', e);
    }
  });
}
