// Routes: GET / POST /mend / POST /title for the kid motivation loop.
// Mounted at /api/me/progression with the `authenticate` middleware applied
// at the mount site (see src/index.ts).
//
// Style notes:
// - Manual field validation only (no zod / no joi) per CLAUDE.md.
// - All progression mutations go through the shared progressionDataService so
//   the same writes can run inside a $transaction in the chore-completion path.
// - Lazy streak evaluation: every GET re-runs streakService.evaluateStreak
//   against the user's local TZ window since lastStreakEvalAt and persists
//   any state change. No daily cron.

import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticate, AuthRequest } from '../middleware/auth';
import {
  loadProgressionState,
  persistProgression,
  loadDayCompletionsForUser,
  type ProgressionState,
} from '../services/progressionDataService';
import {
  levelFromXp,
  xpToNextLevel,
  unlocksUpToLevel,
  type UnlockKey,
} from '../services/progressionService';
import { evaluateStreak } from '../services/streakService';

const prisma = new PrismaClient();

// ---------------------------------------------------------------------------
// Constants — Mend pricing & cooldown
// ---------------------------------------------------------------------------
// The Mend mechanic restores a broken streak (currentStreak set back to 1)
// for a one-shot XP cost, available at most once per cooldown window. The
// cooldown halves once the kid is high enough level (PRD: "halved to 7 at
// Lvl 10"). All durations live as constants so a tuning change is one edit.
const MEND_XP_COST = 50;
const MEND_COOLDOWN_DAYS = 14;
const MEND_COOLDOWN_DAYS_AT_LVL_10 = 7;
const LVL_10_THRESHOLD = 10;
const DISPLAY_TITLE_MIN_LEVEL = 5;

const MS_PER_DAY = 24 * 60 * 60 * 1000;

function mendCooldownDaysFor(level: number): number {
  return level >= LVL_10_THRESHOLD ? MEND_COOLDOWN_DAYS_AT_LVL_10 : MEND_COOLDOWN_DAYS;
}

// ---------------------------------------------------------------------------
// Local helpers
// ---------------------------------------------------------------------------

function toLocalYmd(now: Date, tzOffsetMinutes: number): string {
  const local = new Date(now.getTime() + tzOffsetMinutes * 60_000);
  const y = local.getUTCFullYear();
  const m = local.getUTCMonth() + 1;
  const d = local.getUTCDate();
  return `${y.toString().padStart(4, '0')}-${m.toString().padStart(2, '0')}-${d.toString().padStart(2, '0')}`;
}

/**
 * Run the streak service against the user's persisted state and the
 * day-completions window since `lastStreakEvalAt`. Returns the (possibly
 * updated) progression state plus the `mendEligible` flag. Persists any
 * change in the same call so reads stay in sync with the canonical state.
 *
 * Note: this is called by every endpoint in this router (the "lazy
 * evaluation" pattern from the PRD). It is the single place that consumes
 * streak freezes / breaks the streak.
 */
async function evaluateAndPersistStreak(
  state: ProgressionState,
  userId: string,
  tzOffsetMinutes: number,
  now: Date,
): Promise<{ state: ProgressionState; mendEligible: boolean }> {
  const lastEvalAt = state.lastStreakEvalAt;

  // Build the day-completions window: from lastEvalAt's local day (exclusive)
  // up to today (exclusive — today is in-progress).
  const todayYmd = toLocalYmd(now, tzOffsetMinutes);
  const sinceLocalYmd = lastEvalAt
    ? toLocalYmd(lastEvalAt, tzOffsetMinutes)
    : null;

  const dayCompletions = await loadDayCompletionsForUser(
    prisma,
    userId,
    sinceLocalYmd,
    todayYmd,
    tzOffsetMinutes,
  );

  const result = evaluateStreak({
    lastEvalAt,
    currentStreak: state.currentStreak,
    longestStreak: state.longestStreak,
    freezesAvailable: state.freezesAvailable,
    dayCompletions,
    tzOffsetMinutes,
    now,
  });

  // Detect any change worth persisting.
  const streakChanged =
    result.newCurrentStreak !== state.currentStreak ||
    result.newLongestStreak !== state.longestStreak ||
    result.newFreezesAvailable !== state.freezesAvailable;

  // Always advance lastStreakEvalAt to `now` once we have actually walked
  // any days — that way idempotent re-reads on the same day are cheap.
  const advanceEvalAt = result.daysProcessed > 0 || lastEvalAt === null;

  let nextState: ProgressionState = state;
  if (streakChanged || advanceEvalAt) {
    await persistProgression(prisma, userId, {
      currentStreak: result.newCurrentStreak,
      longestStreak: result.newLongestStreak,
      freezesAvailable: result.newFreezesAvailable,
      lastStreakEvalAt: now,
    });
    nextState = {
      ...state,
      currentStreak: result.newCurrentStreak,
      longestStreak: result.newLongestStreak,
      freezesAvailable: result.newFreezesAvailable,
      lastStreakEvalAt: now,
    };
  }

  return { state: nextState, mendEligible: result.mendEligible };
}

/**
 * Project the persisted state plus the lazy mend-eligibility flag into the
 * API contract from the PRD's "API contracts" section.
 */
function projectProgressionResponse(
  state: ProgressionState,
  mendEligible: boolean,
  now: Date,
) {
  const next = xpToNextLevel(state.xp);
  const cooldownDays = mendCooldownDaysFor(state.level);

  let mendCooldownRemainingSec = 0;
  if (state.lastMendAt) {
    const elapsedMs = now.getTime() - state.lastMendAt.getTime();
    const cooldownMs = cooldownDays * MS_PER_DAY;
    const remainingMs = cooldownMs - elapsedMs;
    if (remainingMs > 0) {
      mendCooldownRemainingSec = Math.ceil(remainingMs / 1000);
    }
  }

  const unlocks: UnlockKey[] = unlocksUpToLevel(state.level);

  return {
    xp: state.xp,
    level: state.level,
    xpToNextLevel: next.xpRemaining,
    currentStreak: state.currentStreak,
    longestStreak: state.longestStreak,
    freezesAvailable: state.freezesAvailable,
    mendEligible,
    mendCooldownRemainingSec,
    badges: state.badges,
    displayTitle: state.displayTitle,
    unlocks,
  };
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

const router = Router();

// GET /api/me/progression
// Returns the API-contract shape from PRD "API contracts". Lazily re-evaluates
// the streak before responding so the kid never sees stale state.
router.get(
  '/',
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.userId!;
      const tzOffsetMinutes =
        parseInt(String(req.query.tzOffsetMinutes ?? '0'), 10) || 0;
      const now = new Date();

      const initialState = await loadProgressionState(prisma, userId);
      const { state, mendEligible } = await evaluateAndPersistStreak(
        initialState,
        userId,
        tzOffsetMinutes,
        now,
      );

      res.json(projectProgressionResponse(state, mendEligible, now));
    } catch (error) {
      console.error('Get progression error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  },
);

// POST /api/me/progression/mend
// Spend MEND_XP_COST XP to restore a broken streak (currentStreak goes to 1,
// not back to the prior peak — kids re-earn). Validates eligibility, balance,
// and cooldown. Status codes per PRD:
//   200 — success, returns the new progression state
//   400 — not Mend-eligible (no recent break, or the break is older than 1 day)
//   402 — insufficient XP
//   429 — cooldown still active
router.post(
  '/mend',
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.userId!;
      const tzOffsetMinutes =
        parseInt(String(req.query.tzOffsetMinutes ?? req.body?.tzOffsetMinutes ?? '0'), 10) || 0;
      const now = new Date();

      // Step 1: lazy evaluation refreshes the streak, freezes, mendEligible.
      const initialState = await loadProgressionState(prisma, userId);
      const { state, mendEligible } = await evaluateAndPersistStreak(
        initialState,
        userId,
        tzOffsetMinutes,
        now,
      );

      // Step 2: gate on eligibility, balance, cooldown — IN THAT ORDER.
      // The PRD assigns each gate its own status code.
      if (!mendEligible) {
        res.status(400).json({
          error: 'Not eligible to mend',
          reason: 'NOT_ELIGIBLE',
        });
        return;
      }

      if (state.xp < MEND_XP_COST) {
        res.status(402).json({
          error: 'Insufficient XP',
          reason: 'INSUFFICIENT_XP',
        });
        return;
      }

      const cooldownDays = mendCooldownDaysFor(state.level);
      if (state.lastMendAt) {
        const elapsedMs = now.getTime() - state.lastMendAt.getTime();
        const cooldownMs = cooldownDays * MS_PER_DAY;
        if (elapsedMs < cooldownMs) {
          res.status(429).json({
            error: 'Mend cooldown active',
            reason: 'COOLDOWN_ACTIVE',
          });
          return;
        }
      }

      // Step 3: apply the mend in a single transaction. Decisions:
      //   - currentStreak resets to 1 (the kid restarts their streak from
      //     scratch). The PRD did not want a "free pass back to your prior
      //     peak" because that would make Mend feel infinite — the cost
      //     exists to make recovery earned, not to make it cheap.
      //   - Level may drop because xp went down; reapply levelFromXp.
      //   - lastMendAt records the spend so the cooldown can be enforced
      //     against future requests.
      const newXp = state.xp - MEND_XP_COST;
      const newLevel = levelFromXp(newXp);

      await prisma.$transaction(async (tx) => {
        await persistProgression(tx, userId, {
          xp: newXp,
          level: newLevel,
          currentStreak: 1,
          lastMendAt: now,
        });
      });

      // Step 4: respond with the post-mend state. We rebuild it locally rather
      // than re-querying — the writes above are the canonical truth and badges
      // / displayTitle didn't change.
      const restoredState: ProgressionState = {
        ...state,
        xp: newXp,
        level: newLevel,
        currentStreak: 1,
        lastMendAt: now,
      };

      // mendEligible is now false — we just consumed it.
      res.json(projectProgressionResponse(restoredState, false, now));
    } catch (error) {
      console.error('Mend error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  },
);

// POST /api/me/progression/title
// Set the display title (badge key) shown under the kid's name. Pass
// `{ badgeKey: null }` to clear. Validates:
//   - level >= 5 (the DISPLAY_TITLE unlock; PRD level ladder)
//   - the kid has actually earned that badge (when badgeKey is non-null)
router.post(
  '/title',
  authenticate,
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.userId!;
      const tzOffsetMinutes =
        parseInt(String(req.query.tzOffsetMinutes ?? req.body?.tzOffsetMinutes ?? '0'), 10) || 0;
      const now = new Date();

      // Manual field validation: badgeKey must be present in body and either
      // a non-empty string or null.
      const hasBadgeKeyField = Object.prototype.hasOwnProperty.call(
        req.body || {},
        'badgeKey',
      );
      if (!hasBadgeKeyField) {
        res.status(400).json({ error: 'badgeKey is required' });
        return;
      }
      const rawBadgeKey = req.body.badgeKey;
      if (rawBadgeKey !== null && typeof rawBadgeKey !== 'string') {
        res.status(400).json({ error: 'badgeKey must be a string or null' });
        return;
      }
      const badgeKey: string | null =
        rawBadgeKey === null || rawBadgeKey === ''
          ? null
          : (rawBadgeKey as string);

      // Lazy streak evaluation so the response below is fresh.
      const initialState = await loadProgressionState(prisma, userId);
      const { state, mendEligible } = await evaluateAndPersistStreak(
        initialState,
        userId,
        tzOffsetMinutes,
        now,
      );

      // Gate on level — the DISPLAY_TITLE unlock is at level 5.
      if (state.level < DISPLAY_TITLE_MIN_LEVEL) {
        res.status(403).json({
          error: `Display title unlocks at level ${DISPLAY_TITLE_MIN_LEVEL}`,
        });
        return;
      }

      // If a non-null badge is being set, validate ownership.
      if (badgeKey !== null && !state.badges.includes(badgeKey)) {
        res.status(400).json({ error: 'You have not earned that badge' });
        return;
      }

      await persistProgression(prisma, userId, { displayTitle: badgeKey });

      const updatedState: ProgressionState = { ...state, displayTitle: badgeKey };
      res.json(projectProgressionResponse(updatedState, mendEligible, now));
    } catch (error) {
      console.error('Set title error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  },
);

export default router;
