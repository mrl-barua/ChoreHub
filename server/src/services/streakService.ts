// Pure functions — no Prisma dependency, no I/O, no Date.now().
// All time inputs come via `now` and `tzOffsetMinutes`. See insightsService.ts
// for the same UTC↔local timezone-shift convention used here.
//
// This module implements the "Streak service" from PRD-kid-motivation-loop.md:
// - A streak day in user-local TZ counts when dueCount > 0 AND completed >= due,
//   OR dueCount === 0 (zero-due auto-pass).
// - Misses consume one streak freeze if available; otherwise the streak breaks.
// - mendEligible is true iff a break occurred AND the user's local "today" is
//   exactly one calendar day after the broken day.

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type DayCompletion = {
  /** Calendar date in user-local TZ, format YYYY-MM-DD. */
  date: string;
  dueCount: number;
  completedCount: number;
};

export type StreakInput = {
  /** When this user's streak was last evaluated; null on first run. */
  lastEvalAt: Date | null;
  /** Their persisted streak going into this evaluation. */
  currentStreak: number;
  longestStreak: number;
  /** Freezes they currently hold (caller enforces 0..2 cap). */
  freezesAvailable: number;
  /**
   * Sorted ascending by date. Each entry covers a single calendar day from
   * the day after lastEvalAt up to (but not including) today's in-progress day.
   */
  dayCompletions: DayCompletion[];
  /** User's local-tz offset at "now"; same convention as insightsService. */
  tzOffsetMinutes: number;
  /** Current instant; injected for testability. */
  now: Date;
};

export type StreakResult = {
  newCurrentStreak: number;
  newLongestStreak: number;
  newFreezesAvailable: number;
  freezesConsumed: number;
  /** Count of dayCompletions actually consumed. */
  daysProcessed: number;
  /** YYYY-MM-DD of the missed day that broke the streak, or null. */
  brokenAt: string | null;
  /** True iff a break occurred AND today is exactly one day after brokenAt. */
  mendEligible: boolean;
};

// ---------------------------------------------------------------------------
// Local helpers (kept private; not exported)
// ---------------------------------------------------------------------------

/**
 * Convert a UTC instant + tzOffsetMinutes into the user's local YYYY-MM-DD.
 * Uses the same "shift then read UTC fields" trick as insightsService.ts.
 */
function toLocalYmd(now: Date, tzOffsetMinutes: number): string {
  const offsetMs = tzOffsetMinutes * 60_000;
  const local = new Date(now.getTime() + offsetMs);
  const y = local.getUTCFullYear();
  const m = local.getUTCMonth() + 1;
  const d = local.getUTCDate();
  return `${y.toString().padStart(4, '0')}-${m.toString().padStart(2, '0')}-${d.toString().padStart(2, '0')}`;
}

/**
 * Add `days` calendar days to a YYYY-MM-DD string and return the new
 * YYYY-MM-DD string. Operates at UTC noon to avoid any DST/edge concerns —
 * the input/output are pure date strings, never instants.
 */
function addDays(ymd: string, days: number): string {
  const [y, m, d] = ymd.split('-').map((s) => parseInt(s, 10));
  // Use UTC noon as a safe anchor; we only read back y/m/d so DST is irrelevant.
  const anchor = new Date(Date.UTC(y, m - 1, d, 12, 0, 0));
  anchor.setUTCDate(anchor.getUTCDate() + days);
  const yy = anchor.getUTCFullYear();
  const mm = anchor.getUTCMonth() + 1;
  const dd = anchor.getUTCDate();
  return `${yy.toString().padStart(4, '0')}-${mm.toString().padStart(2, '0')}-${dd.toString().padStart(2, '0')}`;
}

/**
 * A day "completes" the streak iff:
 *   - dueCount === 0 (zero-due auto-pass), OR
 *   - dueCount > 0 AND completedCount >= dueCount.
 */
function isDayCompleted(d: DayCompletion): boolean {
  if (d.dueCount === 0) return true;
  return d.completedCount >= d.dueCount;
}

// ---------------------------------------------------------------------------
// evaluateStreak
// ---------------------------------------------------------------------------

/**
 * Pure streak evaluation. See top-of-file comment for the full contract.
 *
 * Decisions made beyond the PRD:
 * - Out-of-order dayCompletions: sorted defensively (ascending by `date`)
 *   rather than thrown. Callers should sort, but a stable copy here avoids
 *   surprising bugs in glue code.
 * - A dayCompletion equal to "today" is dropped defensively before walking;
 *   today is in-progress and the caller is responsible for excluding it.
 * - We do NOT enforce the 0..2 freeze cap here. If the caller passes 5
 *   freezes we will consume up to 5 misses. Cap enforcement is the caller's
 *   job (see PRD: caps are awarded at Lvl 3 / Lvl 7).
 */
export function evaluateStreak(input: StreakInput): StreakResult {
  const {
    lastEvalAt,
    currentStreak,
    longestStreak,
    freezesAvailable,
    dayCompletions,
    tzOffsetMinutes,
    now,
  } = input;

  const todayYmd = toLocalYmd(now, tzOffsetMinutes);

  // Defensive copy: sort ascending by date and drop any entry equal to today.
  const days = dayCompletions
    .filter((d) => d.date !== todayYmd)
    .slice()
    .sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));

  // First-ever eval with no data, OR ordinary idempotent no-op when there's
  // simply nothing to process (no full day has elapsed since lastEvalAt).
  // Both produce identical no-op output.
  if (days.length === 0) {
    return {
      newCurrentStreak: currentStreak,
      newLongestStreak: longestStreak,
      newFreezesAvailable: freezesAvailable,
      freezesConsumed: 0,
      daysProcessed: 0,
      brokenAt: null,
      mendEligible: false,
    };
  }

  // lastEvalAt is currently unused beyond signaling "first run" semantics,
  // which the caller already encodes by the contents of dayCompletions.
  // It is kept on the type for parity with the persisted User row.
  void lastEvalAt;

  let runningStreak = currentStreak;
  let runningLongest = longestStreak;
  let freezes = freezesAvailable;
  let freezesConsumed = 0;
  let daysProcessed = 0;
  let brokenAt: string | null = null;

  for (const day of days) {
    daysProcessed += 1;

    if (isDayCompleted(day)) {
      runningStreak += 1;
      if (runningStreak > runningLongest) runningLongest = runningStreak;
      continue;
    }

    // Missed day.
    if (freezes > 0) {
      freezes -= 1;
      freezesConsumed += 1;
      // Streak does not increment but does not break — continue walking.
      continue;
    }

    // No freezes left — streak breaks here. Stop processing further days.
    runningStreak = 0;
    brokenAt = day.date;
    break;
  }

  // longestStreak never decreases — fold in the prior persisted value too.
  const newLongestStreak = Math.max(runningLongest, currentStreak, longestStreak);

  // mendEligible iff a break occurred AND today is exactly one calendar day
  // after the broken day.
  const mendEligible = brokenAt !== null && addDays(brokenAt, 1) === todayYmd;

  return {
    newCurrentStreak: brokenAt !== null ? 0 : runningStreak,
    newLongestStreak,
    newFreezesAvailable: freezes,
    freezesConsumed,
    daysProcessed,
    brokenAt,
    mendEligible,
  };
}
