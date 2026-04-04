import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export async function createNotification(
  userId: string,
  familyId: string,
  type: string,
  title: string,
  body: string,
  data?: string,
) {
  return prisma.notification.create({
    data: { userId, familyId, type, title, body, data },
  });
}
