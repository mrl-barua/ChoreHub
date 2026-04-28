import cron from 'node-cron';
import { PrismaClient } from '@prisma/client';
import { createNotification } from '../services/notification';

const prisma = new PrismaClient();

export function startDailySummary() {
  cron.schedule('0 7 * * *', async () => {
    try {
      const now = new Date();
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const todayEnd = new Date(todayStart.getTime() + 24 * 60 * 60 * 1000);

      const users = await prisma.notificationPreference.findMany({
        where: { dailySummary: true, pushEnabled: true },
        select: { userId: true },
      });

      for (const { userId } of users) {
        const total = await prisma.chore.count({
          where: { assignedTo: userId, status: 'pending', dueDate: { gte: todayStart, lt: todayEnd } },
        });
        const overdue = await prisma.chore.count({
          where: { assignedTo: userId, status: 'pending', dueDate: { lt: todayStart } },
        });
        if (total > 0 || overdue > 0) {
          // Fetch a familyId for this user to satisfy the notification model
          const membership = await prisma.familyMember.findFirst({
            where: { userId },
            select: { familyId: true },
          });
          const familyId = membership?.familyId ?? '';
          await createNotification(
            userId,
            familyId,
            'daily_summary',
            'Daily chore summary',
            `You have ${total} chore${total !== 1 ? 's' : ''} today${overdue > 0 ? `, ${overdue} overdue` : ''}`,
            JSON.stringify({})
          );
        }
      }
    } catch (e) {
      console.error('[dailySummary]', e);
    }
  });
}
