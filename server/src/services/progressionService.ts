// Pure functions — no Prisma dependency, no I/O, no Date.now().
// Single source of truth for the level curve, the unlock ladder, and XP
// awarding rules for the kid motivation loop.

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
export const XP_PER_LEVEL_MULTIPLIER = 50;
export const BASE_XP_PER_CHORE = 10;
export const ON_TIME_BONUS_XP = 5;
export const STREAK_DAY_BONUS_XP = 10;

// Hard cap to avoid pathological loops. Levels beyond this are clamped.
const MAX_LEVEL = 100;

// Stable internal identifiers — never rename, these end up in stored data.
export type UnlockKey =
  | 'STREAK_MEND'
  | 'STREAK_FREEZE'
  | 'DISPLAY_TITLE'
  | 'MEND_COOLDOWN_HALVED';

// Single source of truth for the unlock ladder. Adding or tuning a level
// reward is a single edit here.
// Levels not present in this map award no progression unlock (they may award
// cosmetic category badges, which are handled by the badge service).
export const LEVEL_UNLOCKS: Record<number, UnlockKey[]> = {
  2: ['STREAK_MEND'],
  3: ['STREAK_FREEZE'],
  5: ['DISPLAY_TITLE'],
  7: ['STREAK_FREEZE'],
  10: ['MEND_COOLDOWN_HALVED'],
};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
export type AwardXpInput = {
  currentXp: number;
  choreCompleted: boolean;
  isOnTime: boolean;
  completedStreakDay: boolean;
};

export type AwardXpBreakdown = {
  base: number;
  onTime: number;
  streakDay: number;
};

export type AwardXpResult = {
  xpAwarded: number;
  newXp: number;
  previousLevel: number;
  newLevel: number;
  leveledUp: boolean;
  unlocksGained: UnlockKey[];
  breakdown: AwardXpBreakdown;
};

export type XpToNextLevelResult = {
  currentLevel: number;
  xpIntoLevel: number;
  xpForNext: number;
  xpRemaining: number;
};

// ---------------------------------------------------------------------------
// levelFromXp
// ---------------------------------------------------------------------------
// Cumulative XP required to reach level N is 25 * N * (N - 1).
// Inverting: given xp, level = floor((1 + sqrt(1 + xp / (XP_PER_LEVEL_MULTIPLIER / 2))) / 2)
// Or equivalently: floor((1 + sqrt(1 + 8 * xp / XP_PER_LEVEL_MULTIPLIER / 2)) / 2)
// We solve 25 * L * (L - 1) <= xp  →  L <= (1 + sqrt(1 + xp/12.5)) / 2
// To dodge floating-point edge cases at exact boundaries, we verify the
// candidate level against the cumulative formula and adjust by ±1 if needed.
export function levelFromXp(xp: number): number {
  if (xp <= 0) return 1;

  // Closed-form starting guess from inverting cumulative = 25 * L * (L - 1).
  const guess = Math.floor((1 + Math.sqrt(1 + xp / 12.5)) / 2);

  // Defensively bracket against fp imprecision: try guess-1, guess, guess+1.
  let level = Math.max(1, guess);
  while (level < MAX_LEVEL && cumulativeXpForLevel(level + 1) <= xp) {
    level += 1;
  }
  while (level > 1 && cumulativeXpForLevel(level) > xp) {
    level -= 1;
  }
  return Math.min(level, MAX_LEVEL);
}

// Cumulative XP required to *reach* (i.e., be at) the given level.
// reaching level 1 = 0 XP, reaching level 2 = 50 XP, reaching level 3 = 150 XP.
function cumulativeXpForLevel(level: number): number {
  if (level <= 1) return 0;
  return (XP_PER_LEVEL_MULTIPLIER / 2) * level * (level - 1);
}

// ---------------------------------------------------------------------------
// xpToNextLevel
// ---------------------------------------------------------------------------
export function xpToNextLevel(xp: number): XpToNextLevelResult {
  const currentLevel = levelFromXp(xp);
  const xpAtCurrent = cumulativeXpForLevel(currentLevel);
  const xpAtNext = cumulativeXpForLevel(currentLevel + 1);

  const xpIntoLevel = xp - xpAtCurrent;
  const xpForNext = xpAtNext - xpAtCurrent;
  const xpRemaining = Math.max(0, xpAtNext - xp);

  return { currentLevel, xpIntoLevel, xpForNext, xpRemaining };
}

// ---------------------------------------------------------------------------
// awardXp
// ---------------------------------------------------------------------------
// Calculates total XP awarded for a single completion event, sums it onto
// currentXp, computes new level, and returns any unlocks gained between
// previousLevel + 1 and newLevel inclusive.
//
// Note on the "choreCompleted=false but streakDay=true" case: this is
// intentionally legal. The streak-day bonus is conceptually awardable
// separately at end-of-day evaluation (e.g., when the last due chore was
// already completed earlier in the day and the streak roll happens later).
// In that case base = 0 and the on-time bonus is suppressed (it has no
// chore to attach to), but the streak-day bonus passes through.
export function awardXp(input: AwardXpInput): AwardXpResult {
  const { currentXp, choreCompleted, isOnTime, completedStreakDay } = input;

  const base = choreCompleted ? BASE_XP_PER_CHORE : 0;
  const onTime = choreCompleted && isOnTime ? ON_TIME_BONUS_XP : 0;
  const streakDay = completedStreakDay ? STREAK_DAY_BONUS_XP : 0;

  const xpAwarded = base + onTime + streakDay;
  const newXp = currentXp + xpAwarded;

  const previousLevel = levelFromXp(currentXp);
  const newLevel = levelFromXp(newXp);
  const leveledUp = newLevel > previousLevel;

  const unlocksGained: UnlockKey[] = [];
  if (leveledUp) {
    for (let lvl = previousLevel + 1; lvl <= newLevel; lvl += 1) {
      const unlocksAtLevel = LEVEL_UNLOCKS[lvl];
      if (unlocksAtLevel) {
        unlocksGained.push(...unlocksAtLevel);
      }
    }
  }

  return {
    xpAwarded,
    newXp,
    previousLevel,
    newLevel,
    leveledUp,
    unlocksGained,
    breakdown: { base, onTime, streakDay },
  };
}

// ---------------------------------------------------------------------------
// unlocksForLevel
// ---------------------------------------------------------------------------
// Returns the unlocks awarded specifically AT the given level (not cumulative).
export function unlocksForLevel(level: number): UnlockKey[] {
  const entry = LEVEL_UNLOCKS[level];
  return entry ? [...entry] : [];
}

// ---------------------------------------------------------------------------
// unlocksUpToLevel
// ---------------------------------------------------------------------------
// Returns all unlocks earned by reaching the given level (cumulative).
// Order is ascending by level. Within a level the order matches LEVEL_UNLOCKS.
export function unlocksUpToLevel(level: number): UnlockKey[] {
  const result: UnlockKey[] = [];
  for (let lvl = 2; lvl <= level; lvl += 1) {
    const unlocksAtLevel = LEVEL_UNLOCKS[lvl];
    if (unlocksAtLevel) {
      result.push(...unlocksAtLevel);
    }
  }
  return result;
}
