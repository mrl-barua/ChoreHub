"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createNotification = createNotification;
const client_1 = require("@prisma/client");
const prisma = new client_1.PrismaClient();
async function createNotification(userId, familyId, type, title, body, data) {
    return prisma.notification.create({
        data: { userId, familyId, type, title, body, data },
    });
}
