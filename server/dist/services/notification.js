"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createNotification = createNotification;
const client_1 = require("@prisma/client");
const fcm_1 = require("./fcm");
const prisma = new client_1.PrismaClient();
async function createNotification(userId, familyId, type, title, body, data) {
    const notification = await prisma.notification.create({
        data: { userId, familyId, type, title, body, data },
    });
    // Push notification dispatch — errors here must never break the DB write
    try {
        const prefs = await prisma.notificationPreference.upsert({
            where: { userId },
            update: {},
            create: { userId },
        });
        if (!prefs.pushEnabled)
            return notification;
        // Map notification type → preference field
        const typeToField = {
            chore_assigned: 'choreAssigned',
            chore_completed: 'choreCompleted',
            chore_due_soon: 'choreDueSoon',
            mention: 'mention',
            swap_request: 'swap',
            swap_accepted: 'swap',
            swap_declined: 'swap',
            swap_cancelled: 'swap',
            challenge_complete: 'pushEnabled', // always on if pushEnabled
            daily_summary: 'dailySummary',
        };
        const field = typeToField[type];
        if (field && !prefs[field])
            return notification;
        if ((0, fcm_1.isInQuietHours)(prefs, new Date()))
            return notification;
        const extraData = data ? JSON.parse(data) : {};
        await (0, fcm_1.sendPush)(userId, title, body ?? '', {
            type,
            notificationId: notification.id,
            ...Object.fromEntries(Object.entries(extraData).map(([k, v]) => [k, String(v)])),
        });
    }
    catch (pushErr) {
        console.error('[notification] push dispatch failed:', pushErr);
    }
    return notification;
}
