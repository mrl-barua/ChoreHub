// Thin Prisma wrapper around the kid-motivation-loop progression state.
//
// Not a "repository" in the strict DDD sense — this is the project's existing
// pattern of co-locating data-access helpers under `services/` (see CLAUDE.md:
// "no separate controller/repository layer"). The intent of this module is to
// (a) keep the route handlers free of Prisma model-shape knowledge, and (b)
// accept either the global PrismaClient or a transaction client so the same
// helpers work inside `prisma.$transaction(async (tx) => ...)`.
//
// All time-bucketing helpers receive `tzOffsetMinutes` and follow the same
// "shift-then-read-UTC-fields" convention as insightsService.ts so day
// boundaries match the user's local calendar.

import { PrismaClient, Prisma } from '@prisma/client';

// Either the root client or a transaction client. We type-alias both so the
// same helpers can run inside `prisma.$transaction(async (tx) => ...)`.
export type PrismaLike = PrismaClient | Prisma.TransactionClient;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type ProgressionState = {
  xp: number;
  level: number;
  currentStreak: number;
  longestStreak: number;
  lastStreakEvalAt: Date | null;
  freezesAvailable: number;
  lastMendAt: Date | null;
  displayTitle: string | null;
  badges: string[];
};

export type ProgressionUpdate = Partial<{
  xp: number;
  level: number;
  currentStreak: number;
  longestStreak: number;
  lastStreakEvalAt: Date | null;
  freezesAvailable: number;
  lastMendAt: Date | null;
  displayTitle: string | null;
}>;

export type DayCompletionRow = {
  /** Calendar date in user-local TZ, format YYYY-MM-DD. */
  date: string;
  dueCount: number;
  completedCount: number;
};

// ---------------------------------------------------------------------------
// loadProgressionState
// ---------------------------------------------------------------------------
// Returns the denormalized progression columns from the User row plus the list
// of badge keys this user has earned. Throws if the user does not exist (the
// caller should already be authenticated, so this should never be hit in
// normal flows).
export async function loadProgressionState(
  prismaOrTx: PrismaLike,
  userId: string,
): Promise<ProgressionState> {
  const [user, badges] = await Promise.all([
    prismaOrTx.user.findUnique({
      where: { id: userId },
      select: {
        xp: true,
        level: true,
        currentStreak: true,
        longestStreak: true,
        lastStreakEvalAt: true,
        freezesAvailable: true,
        lastMendAt: true,
        displayTitle: true,
      },
    }),
    prismaOrTx.userBadge.findMany({
      where: { userId },
      select: { badgeKey: true },
    }),
  ]);

  if (!user) {
    throw new Error(`User ${userId} not found`);
  }

  return {
    xp: user.xp,
    level: user.level,
    currentStreak: user.currentStreak,
    longestStreak: user.longestStreak,
    lastStreakEvalAt: user.lastStreakEvalAt,
    freezesAvailable: user.freezesAvailable,
    lastMendAt: user.lastMendAt,
    displayTitle: user.displayTitle,
    badges: badges.map((b) => b.badgeKey),
  };
}

// ---------------------------------------------------------------------------
// persistProgression
// ---------------------------------------------------------------------------
// Writes a partial set of progression columns. No-op if the update object is
// empty so callers can decide late whether they actually need to persist.
export async function persistProgression(
  prismaOrTx: PrismaLike,
  userId: string,
  updates: ProgressionUpdate,
): Promise<void> {
  if (Object.keys(updates).length === 0) return;
  await prismaOrTx.user.update({
    where: { id: userId },
    data: updates,
  });
}

// ---------------------------------------------------------------------------
// addBadges
// ---------------------------------------------------------------------------
// Inserts one row per new badge key. `skipDuplicates` makes this safe under
// retries / concurrent completions: the unique index on (userId, badgeKey)
// guarantees idempotency without needing an explicit pre-check.
export async function addBadges(
  prismaOrTx: PrismaLike,
  userId: string,
  newBadgeKeys: string[],
): Promise<void> {
  if (newBadgeKeys.length === 0) return;
  await prismaOrTx.userBadge.createMany({
    data: newBadgeKeys.map((badgeKey) => ({ userId, badgeKey })),
    skipDuplicates: true,
  });
}

// ---------------------------------------------------------------------------
// loadDayCompletionsForUser
// ---------------------------------------------------------------------------
// Returns one row per local-tz calendar day strictly between `sinceLocalDate`
// (exclusive — start at the day AFTER) and `untilLocalDate` (exclusive —
// today's in-progress day is not included). If `sinceLocalDate` is null we
// fall back to a 30-day lookback window: the streak service will still walk
// only the days it cares about, but bounding the SQL prevents pathologically
// long queries on first-ever evaluations.
//
// Implementation: two parallel `groupBy` queries, one over `Chore.dueDate`
// (local-day-of-due-date → due count) and one over `ChoreHistory` joined to
// `Chore.assignedTo = userId AND action LIKE 'completed%'`
// (local-day-of-completion → completed count). We chose `groupBy` over a raw
// SQL union because:
//   - it stays type-safe under Prisma's generated client,
//   - chore volume per kid is small (tens per day at most), so the in-memory
//     aggregation cost is negligible, and
//   - it portable across PostgreSQL versions without `to_char` / `date_trunc`
//     dialect choices.
//
// We translate UTC timestamps to local YYYY-MM-DD in app code rather than in
// SQL, again matching insightsService's "shift then read UTC fields" pattern.
const LOOKBACK_DAYS_FALLBACK = 30;

export async function loadDayCompletionsForUser(
  prismaOrTx: PrismaLike,
  userId: string,
  sinceLocalDate: string | null,
  untilLocalDate: string,
  tzOffsetMinutes: number,
): Promise<DayCompletionRow[]> {
  // Compute the UTC instant range we need to scan.
  // sinceLocalDate is exclusive — start at the day AFTER. We translate the
  // user's local "start-of-day-after-since" into a UTC instant.
  // untilLocalDate is exclusive — stop at start-of-untilLocalDate (today).
  const offsetMs = tzOffsetMinutes * 60_000;

  const fromLocalYmd = sinceLocalDate
    ? addDaysYmd(sinceLocalDate, 1)
    : addDaysYmd(untilLocalDate, -LOOKBACK_DAYS_FALLBACK);

  const fromUtc = ymdToUtcInstant(fromLocalYmd, offsetMs);
  const toUtc = ymdToUtcInstant(untilLocalDate, offsetMs);

  if (fromUtc.getTime() >= toUtc.getTime()) {
    // Nothing to walk — caller is up-to-date.
    return [];
  }

  // Pull due-per-day buckets (rows where dueDate falls in window AND the chore
  // was assigned to this user) and completed-per-day buckets (history rows
  // for this user with completed* actions in the window) in parallel.
  const [dueRows, completedRows] = await Promise.all([
    prismaOrTx.chore.findMany({
      where: {
        assignedTo: userId,
        dueDate: { gte: fromUtc, lt: toUtc },
      },
      select: { dueDate: true },
    }),
    prismaOrTx.choreHistory.findMany({
      where: {
        userId,
        action: { startsWith: 'completed' },
        createdAt: { gte: fromUtc, lt: toUtc },
      },
      select: { createdAt: true },
    }),
  ]);

  // Bucket both streams into local-day buckets keyed by YYYY-MM-DD.
  const dueByDay: Record<string, number> = {};
  for (const row of dueRows) {
    if (!row.dueDate) continue;
    const ymd = utcInstantToLocalYmd(row.dueDate, offsetMs);
    dueByDay[ymd] = (dueByDay[ymd] || 0) + 1;
  }

  const completedByDay: Record<string, number> = {};
  for (const row of completedRows) {
    const ymd = utcInstantToLocalYmd(row.createdAt, offsetMs);
    completedByDay[ymd] = (completedByDay[ymd] || 0) + 1;
  }

  // Walk every calendar day from fromLocalYmd up to (exclusive) untilLocalDate
  // and emit one row per day so the streak service sees a contiguous sequence.
  const out: DayCompletionRow[] = [];
  let cursor = fromLocalYmd;
  while (cursor < untilLocalDate) {
    out.push({
      date: cursor,
      dueCount: dueByDay[cursor] || 0,
      completedCount: completedByDay[cursor] || 0,
    });
    cursor = addDaysYmd(cursor, 1);
  }
  return out;
}

// ---------------------------------------------------------------------------
// loadCompletionsByCategoryForUser
// ---------------------------------------------------------------------------
// Counts ChoreHistory rows where this user *performed* the completion (so a
// reassigned chore is credited to whoever actually clicked done, not to its
// current `assignedTo`). Joined to Chore for the category. Returns a map of
// category → count, suitable to feed badgeService.checkBadges.
export async function loadCompletionsByCategoryForUser(
  prismaOrTx: PrismaLike,
  userId: string,
): Promise<Record<string, number>> {
  // Pull all completion events by this user; for each, look up the chore's
  // category. We do not use Prisma's relation include here because Chore is
  // not declared as a relation field on ChoreHistory in schema.prisma — so we
  // batch-load chores by id and join in memory.
  const history = await prismaOrTx.choreHistory.findMany({
    where: {
      userId,
      action: { startsWith: 'completed' },
    },
    select: { choreId: true },
  });

  if (history.length === 0) return {};

  const choreIds = Array.from(new Set(history.map((h) => h.choreId)));
  const chores = await prismaOrTx.chore.findMany({
    where: { id: { in: choreIds } },
    select: { id: true, category: true },
  });
  const categoryById = new Map(chores.map((c) => [c.id, c.category]));

  const result: Record<string, number> = {};
  for (const h of history) {
    const category = categoryById.get(h.choreId);
    if (!category) continue; // chore deleted; skip this completion
    result[category] = (result[category] || 0) + 1;
  }
  return result;
}

// ---------------------------------------------------------------------------
// Local helpers — date math on YYYY-MM-DD strings
// ---------------------------------------------------------------------------

function addDaysYmd(ymd: string, days: number): string {
  const [y, m, d] = ymd.split('-').map((s) => parseInt(s, 10));
  const anchor = new Date(Date.UTC(y, m - 1, d, 12, 0, 0));
  anchor.setUTCDate(anchor.getUTCDate() + days);
  const yy = anchor.getUTCFullYear();
  const mm = anchor.getUTCMonth() + 1;
  const dd = anchor.getUTCDate();
  return `${yy.toString().padStart(4, '0')}-${mm.toString().padStart(2, '0')}-${dd.toString().padStart(2, '0')}`;
}

// Convert a local YYYY-MM-DD into the UTC instant that represents that local
// day's midnight. Mirror of `utcInstantToLocalYmd` below.
function ymdToUtcInstant(ymd: string, offsetMs: number): Date {
  const [y, m, d] = ymd.split('-').map((s) => parseInt(s, 10));
  // The local midnight is at (y, m-1, d, 0, 0) in user-local TZ.
  // Constructing it as a UTC instant first and then subtracting the offset
  // gives us the matching real UTC moment.
  const localMidnightAsUtc = Date.UTC(y, m - 1, d, 0, 0, 0);
  return new Date(localMidnightAsUtc - offsetMs);
}

function utcInstantToLocalYmd(when: Date, offsetMs: number): string {
  const local = new Date(when.getTime() + offsetMs);
  const y = local.getUTCFullYear();
  const m = local.getUTCMonth() + 1;
  const d = local.getUTCDate();
  return `${y.toString().padStart(4, '0')}-${m.toString().padStart(2, '0')}-${d.toString().padStart(2, '0')}`;
}

// ---------------------------------------------------------------------------
// awardProgressionForCompletion
// ---------------------------------------------------------------------------
// Shared helper used by both the POST /:id/complete path and the PATCH /:id
// path that transitions to status='done'. Awards XP, evaluates level-up,
// checks for newly-earned category badges, and persists everything inside
// the caller's transaction. The streak-day bonus is intentionally NOT awarded
// here — it is awarded lazily at the next GET /api/me/progression call when
// end-of-day evaluation determines whether all due-today chores were
// completed (see PRD: "Storage and evaluation strategy").
//
// Idempotency: this helper does NOT itself check `chore.status` — the caller
// is responsible for only invoking it when the chore is genuinely
// transitioning from non-done to done. That gate piggybacks on the chore
// status update inside the same transaction.
//
// Returns a small DTO suitable for the API response's optional `progression`
// field. Sockets/notifications must be emitted by the caller AFTER the
// transaction commits.

import {
  awardXp,
  unlocksForLevel,
  type UnlockKey,
} from './progressionService';
import { checkBadges } from './badgeService';

export type ProgressionAwardResult = {
  xpAwarded: number;
  leveledUp: boolean;
  newLevel?: number;
  unlocksGained: UnlockKey[];
  streakIncremented: boolean;
  badgesEarned: string[];
};

export async function awardProgressionForCompletion(
  tx: PrismaLike,
  userId: string,
  choreDueDate: Date | null,
  now: Date,
): Promise<ProgressionAwardResult> {
  // 1. Load current progression state (xp/level + earned badge keys).
  const state = await loadProgressionState(tx, userId);

  // 2. Compute on-time-ness: dueDate must exist AND now must precede it.
  //    Chores without a dueDate cannot earn the on-time bonus.
  const isOnTime = choreDueDate != null && now.getTime() < choreDueDate.getTime();

  // 3. Award XP for this single completion. Streak-day bonus is deferred
  //    (awarded lazily at end-of-day evaluation in GET /api/me/progression).
  const award = awardXp({
    currentXp: state.xp,
    choreCompleted: true,
    isOnTime,
    completedStreakDay: false,
  });

  // 4. Compute newly-earned category badges. Important: we recount completions
  //    by category INCLUDING the just-recorded completion, so call this AFTER
  //    the ChoreHistory row was inserted by the caller.
  const completionsByCategory = await loadCompletionsByCategoryForUser(tx, userId);
  const newBadges = checkBadges({
    completionsByCategory,
    existingBadgeKeys: state.badges,
  });

  // 5. Persist everything in the same transaction.
  await persistProgression(tx, userId, {
    xp: award.newXp,
    level: award.newLevel,
  });
  if (newBadges.length > 0) {
    await addBadges(tx, userId, newBadges);
  }

  return {
    xpAwarded: award.xpAwarded,
    leveledUp: award.leveledUp,
    newLevel: award.leveledUp ? award.newLevel : undefined,
    unlocksGained: award.unlocksGained,
    streakIncremented: false, // deferred to end-of-day evaluation
    badgesEarned: newBadges,
  };
}

// Re-export for symmetry with route imports.
export { unlocksForLevel };
