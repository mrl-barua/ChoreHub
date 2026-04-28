import * as admin from 'firebase-admin';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

let initialized = false;

function ensureInitialized() {
  if (initialized) return;
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) {
    console.warn('[FCM] FIREBASE_SERVICE_ACCOUNT_JSON not set — push disabled');
    return;
  }
  let credential: admin.credential.Credential;
  try {
    // Support both inline JSON and a file path
    if (raw.trim().startsWith('{')) {
      credential = admin.credential.cert(JSON.parse(raw));
    } else {
      credential = admin.credential.cert(raw);
    }
    admin.initializeApp({ credential });
    initialized = true;
  } catch (e) {
    console.error('[FCM] Failed to initialize:', e);
  }
}

export function isInQuietHours(
  prefs: { quietHoursStart?: string | null; quietHoursEnd?: string | null },
  now: Date
): boolean {
  const start = prefs.quietHoursStart ?? '22:00';
  const end = prefs.quietHoursEnd ?? '07:00';
  const [sh, sm] = start.split(':').map(Number);
  const [eh, em] = end.split(':').map(Number);
  const nowMins = now.getHours() * 60 + now.getMinutes();
  const startMins = sh * 60 + sm;
  const endMins = eh * 60 + em;
  if (startMins > endMins) {
    // wrap-around: e.g. 22:00–07:00
    return nowMins >= startMins || nowMins < endMins;
  }
  return nowMins >= startMins && nowMins < endMins;
}

export async function sendPush(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<void> {
  ensureInitialized();
  if (!initialized) return;
  try {
    const tokens = await prisma.deviceToken.findMany({ where: { userId }, select: { token: true } });
    if (!tokens.length) return;
    const result = await admin.messaging().sendEachForMulticast({
      tokens: tokens.map((t) => t.token),
      notification: { title, body },
      data,
      android: { priority: 'high' },
    });
    const staleTokens = result.responses
      .map((r, i) => ({ r, token: tokens[i].token }))
      .filter(({ r }) => r.error?.code === 'messaging/registration-token-not-registered')
      .map(({ token }) => token);
    if (staleTokens.length) {
      await prisma.deviceToken.deleteMany({ where: { token: { in: staleTokens } } });
    }
  } catch (e) {
    console.error('[FCM] sendPush error:', e);
  }
}
