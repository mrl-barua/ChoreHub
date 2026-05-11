import { describe, it, expect } from 'vitest';
import {
  evaluateStreak,
  type DayCompletion,
  type StreakInput,
} from '../services/streakService';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
// Most tests anchor "today" at 2026-04-30 in the user's local TZ. With
// tzOffsetMinutes=0 and now=2026-04-30T12:00:00Z, the user's today is
// 2026-04-30 — so any dayCompletion dated 2026-04-29 or earlier is in the
// past and will be processed.
const NOW_UTC0 = new Date('2026-04-30T12:00:00Z');

function makeInput(overrides: Partial<StreakInput> = {}): StreakInput {
  return {
    lastEvalAt: null,
    currentStreak: 0,
    longestStreak: 0,
    freezesAvailable: 0,
    dayCompletions: [],
    tzOffsetMinutes: 0,
    now: NOW_UTC0,
    ...overrides,
  };
}

const completed = (date: string, due = 1, done = 1): DayCompletion => ({
  date,
  dueCount: due,
  completedCount: done,
});
const missed = (date: string, due = 1, done = 0): DayCompletion => ({
  date,
  dueCount: due,
  completedCount: done,
});
const zeroDue = (date: string): DayCompletion => ({
  date,
  dueCount: 0,
  completedCount: 0,
});

// ---------------------------------------------------------------------------
// 1. First-ever eval
// ---------------------------------------------------------------------------
describe('evaluateStreak — first-ever eval', () => {
  it('lastEvalAt=null and dayCompletions=[] → no-op, mendEligible=false', () => {
    const result = evaluateStreak(
      makeInput({ lastEvalAt: null, dayCompletions: [] }),
    );
    expect(result).toEqual({
      newCurrentStreak: 0,
      newLongestStreak: 0,
      newFreezesAvailable: 0,
      freezesConsumed: 0,
      daysProcessed: 0,
      brokenAt: null,
      mendEligible: false,
    });
  });
});

// ---------------------------------------------------------------------------
// 2. Single completed day extends streak
// ---------------------------------------------------------------------------
describe('evaluateStreak — single completed day', () => {
  it('currentStreak=5 + one completed day → 6, freezes unchanged, no break', () => {
    const result = evaluateStreak(
      makeInput({
        currentStreak: 5,
        longestStreak: 5,
        freezesAvailable: 1,
        dayCompletions: [completed('2026-04-29', 3, 3)],
      }),
    );
    expect(result.newCurrentStreak).toBe(6);
    expect(result.newLongestStreak).toBe(6);
    expect(result.newFreezesAvailable).toBe(1);
    expect(result.freezesConsumed).toBe(0);
    expect(result.brokenAt).toBeNull();
    expect(result.daysProcessed).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// 3. Zero-due auto-pass
// ---------------------------------------------------------------------------
describe('evaluateStreak — zero-due auto-pass', () => {
  it('day with dueCount=0 increments streak', () => {
    const result = evaluateStreak(
      makeInput({
        currentStreak: 2,
        dayCompletions: [zeroDue('2026-04-29')],
      }),
    );
    expect(result.newCurrentStreak).toBe(3);
    expect(result.daysProcessed).toBe(1);
    expect(result.brokenAt).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// 4. All due completed
// ---------------------------------------------------------------------------
describe('evaluateStreak — all due completed', () => {
  it('dueCount=3 completedCount=3 → streak +1', () => {
    const result = evaluateStreak(
      makeInput({
        currentStreak: 4,
        dayCompletions: [completed('2026-04-29', 3, 3)],
      }),
    );
    expect(result.newCurrentStreak).toBe(5);
  });
});

// ---------------------------------------------------------------------------
// 5. Partial completion is a miss
// ---------------------------------------------------------------------------
describe('evaluateStreak — partial completion is a miss', () => {
  it('dueCount=3 completedCount=2 with freeze available → consumes freeze', () => {
    const result = evaluateStreak(
      makeInput({
        currentStreak: 7,
        freezesAvailable: 1,
        dayCompletions: [missed('2026-04-29', 3, 2)],
      }),
    );
    expect(result.newCurrentStreak).toBe(7); // unchanged
    expect(result.newFreezesAvailable).toBe(0);
    expect(result.freezesConsumed).toBe(1);
    expect(result.brokenAt).toBeNull();
  });

  it('dueCount=3 completedCount=2 with no freeze → breaks', () => {
    const result = evaluateStreak(
      makeInput({
        currentStreak: 7,
        freezesAvailable: 0,
        dayCompletions: [missed('2026-04-29', 3, 2)],
      }),
    );
    expect(result.newCurrentStreak).toBe(0);
    expect(result.brokenAt).toBe('2026-04-29');
  });
});

// ---------------------------------------------------------------------------
// 6. Single missed day with 1 freeze
// ---------------------------------------------------------------------------
describe('evaluateStreak — single missed day with freeze', () => {
  it('streak unchanged, freeze 1 → 0, no break', () => {
    const result = evaluateStreak(
      makeInput({
        currentStreak: 10,
        longestStreak: 12,
        freezesAvailable: 1,
        dayCompletions: [missed('2026-04-29')],
      }),
    );
    expect(result.newCurrentStreak).toBe(10);
    expect(result.newFreezesAvailable).toBe(0);
    expect(result.freezesConsumed).toBe(1);
    expect(result.brokenAt).toBeNull();
    expect(result.mendEligible).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// 7. Single missed day with 0 freezes — mend eligibility
// ---------------------------------------------------------------------------
describe('evaluateStreak — missed day with 0 freezes', () => {
  it('streak resets to 0, brokenAt set, mendEligible=true when today follows', () => {
    // Missed 2026-04-29, today=2026-04-30 → mendEligible=true.
    const result = evaluateStreak(
      makeInput({
        currentStreak: 5,
        freezesAvailable: 0,
        dayCompletions: [missed('2026-04-29')],
      }),
    );
    expect(result.newCurrentStreak).toBe(0);
    expect(result.brokenAt).toBe('2026-04-29');
    expect(result.mendEligible).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// 8. Multiple consecutive misses with freezes=2 → 3rd miss breaks
// ---------------------------------------------------------------------------
describe('evaluateStreak — multiple consecutive misses', () => {
  it('freezes=2 consumes both, third miss breaks; subsequent days NOT processed', () => {
    const result = evaluateStreak(
      makeInput({
        currentStreak: 8,
        longestStreak: 8,
        freezesAvailable: 2,
        dayCompletions: [
          missed('2026-04-26'),
          missed('2026-04-27'),
          missed('2026-04-28'),
          missed('2026-04-29'), // should NOT be processed — break stops walk
        ],
      }),
    );
    expect(result.freezesConsumed).toBe(2);
    expect(result.newFreezesAvailable).toBe(0);
    expect(result.brokenAt).toBe('2026-04-28');
    expect(result.newCurrentStreak).toBe(0);
    // Walked: 4-26 (freeze), 4-27 (freeze), 4-28 (break). Day 4 untouched.
    expect(result.daysProcessed).toBe(3);
  });
});

// ---------------------------------------------------------------------------
// 9. mendEligible boundary — break 2 days ago
// ---------------------------------------------------------------------------
describe('evaluateStreak — mendEligible boundary (break 2 days ago)', () => {
  it('break 2 days before today → mendEligible=false', () => {
    // Today=2026-04-30. Break on 2026-04-28 (followed by completed 4-29 in
    // the past — but break stops the walk, so we just place the missed day
    // earlier in the list).
    const result = evaluateStreak(
      makeInput({
        currentStreak: 5,
        freezesAvailable: 0,
        dayCompletions: [
          missed('2026-04-28'),
          completed('2026-04-29'), // not processed because break stops walk
        ],
      }),
    );
    expect(result.brokenAt).toBe('2026-04-28');
    expect(result.mendEligible).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// 10. mendEligible boundary — break yesterday
// ---------------------------------------------------------------------------
describe('evaluateStreak — mendEligible boundary (break yesterday)', () => {
  it('break on the day immediately before today → mendEligible=true', () => {
    const result = evaluateStreak(
      makeInput({
        currentStreak: 5,
        freezesAvailable: 0,
        dayCompletions: [missed('2026-04-29')],
      }),
    );
    expect(result.brokenAt).toBe('2026-04-29');
    expect(result.mendEligible).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// 11. Timezone — UTC+0
// ---------------------------------------------------------------------------
describe('evaluateStreak — timezone UTC+0', () => {
  it('now=2026-04-30T01:00:00Z, offset=0 → today=2026-04-30, processes thru 4-29', () => {
    const result = evaluateStreak(
      makeInput({
        now: new Date('2026-04-30T01:00:00Z'),
        tzOffsetMinutes: 0,
        currentStreak: 0,
        dayCompletions: [completed('2026-04-29')],
      }),
    );
    // 4-29 is yesterday in UTC+0 → processed.
    expect(result.daysProcessed).toBe(1);
    expect(result.newCurrentStreak).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// 12. Timezone — UTC-5 (mirrors insightsService.test.ts:121)
// ---------------------------------------------------------------------------
describe('evaluateStreak — timezone UTC-5', () => {
  it('now=2026-04-30T01:00Z, offset=-300 → user-local 2026-04-29T20:00, today=2026-04-29', () => {
    // Mirrors the insightsService test: UTC Monday 01:00 → local Sunday 20:00.
    // For us: UTC 2026-04-30T01:00 → local 2026-04-29T20:00 → today=2026-04-29.
    // Therefore a dayCompletion dated 2026-04-29 must be DROPPED (it is today
    // for this user) and only days through 2026-04-28 are processed.
    const result = evaluateStreak(
      makeInput({
        now: new Date('2026-04-30T01:00:00Z'),
        tzOffsetMinutes: -300,
        currentStreak: 0,
        dayCompletions: [
          completed('2026-04-28'), // yesterday for UTC-5 user → processed
          completed('2026-04-29'), // today for UTC-5 user → dropped
        ],
      }),
    );
    expect(result.daysProcessed).toBe(1);
    expect(result.newCurrentStreak).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// 13. Timezone — UTC+14 (Kiribati)
// ---------------------------------------------------------------------------
describe('evaluateStreak — timezone UTC+14 Kiribati', () => {
  it('now=2026-04-29T11:00Z, offset=+840 → user-local 2026-04-30T01:00, today=2026-04-30', () => {
    const result = evaluateStreak(
      makeInput({
        now: new Date('2026-04-29T11:00:00Z'),
        tzOffsetMinutes: 840,
        currentStreak: 0,
        dayCompletions: [
          completed('2026-04-29'), // yesterday for UTC+14 user → processed
        ],
      }),
    );
    expect(result.daysProcessed).toBe(1);
    expect(result.newCurrentStreak).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// 14. Timezone — UTC-12
// ---------------------------------------------------------------------------
describe('evaluateStreak — timezone UTC-12', () => {
  it('now=2026-04-30T11:00Z, offset=-720 → user-local 2026-04-29T23:00, today=2026-04-29', () => {
    const result = evaluateStreak(
      makeInput({
        now: new Date('2026-04-30T11:00:00Z'),
        tzOffsetMinutes: -720,
        currentStreak: 0,
        dayCompletions: [
          completed('2026-04-28'), // yesterday for UTC-12 user → processed
          completed('2026-04-29'), // today for UTC-12 user → dropped
        ],
      }),
    );
    expect(result.daysProcessed).toBe(1);
    expect(result.newCurrentStreak).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// 15. Idempotency — second call with same inputs is a no-op
// ---------------------------------------------------------------------------
describe('evaluateStreak — idempotency', () => {
  it('two calls with same empty dayCompletions both return identical no-op', () => {
    const input = makeInput({
      lastEvalAt: new Date('2026-04-30T12:00:00Z'),
      currentStreak: 7,
      longestStreak: 7,
      freezesAvailable: 1,
      dayCompletions: [],
    });
    const a = evaluateStreak(input);
    const b = evaluateStreak(input);
    expect(a).toEqual(b);
    expect(a).toEqual({
      newCurrentStreak: 7,
      newLongestStreak: 7,
      newFreezesAvailable: 1,
      freezesConsumed: 0,
      daysProcessed: 0,
      brokenAt: null,
      mendEligible: false,
    });
  });
});

// ---------------------------------------------------------------------------
// 16. longestStreak monotonicity
// ---------------------------------------------------------------------------
describe('evaluateStreak — longestStreak monotonicity', () => {
  it('input longest=10, run reaches 8 → newLongestStreak stays 10', () => {
    const result = evaluateStreak(
      makeInput({
        currentStreak: 7,
        longestStreak: 10,
        dayCompletions: [completed('2026-04-29')],
      }),
    );
    expect(result.newCurrentStreak).toBe(8);
    expect(result.newLongestStreak).toBe(10);
  });
});

// ---------------------------------------------------------------------------
// 17. longestStreak update
// ---------------------------------------------------------------------------
describe('evaluateStreak — longestStreak update', () => {
  it('input longest=10, run reaches 12 → newLongestStreak=12', () => {
    const result = evaluateStreak(
      makeInput({
        currentStreak: 9,
        longestStreak: 10,
        dayCompletions: [
          completed('2026-04-26'),
          completed('2026-04-27'),
          completed('2026-04-28'),
          completed('2026-04-29'),
        ],
      }),
    );
    // 9 → 10 → 11 → 12 → 13. longest = 13.
    expect(result.newCurrentStreak).toBe(13);
    expect(result.newLongestStreak).toBe(13);
  });
});

// ---------------------------------------------------------------------------
// 18. Defensive — a day matching "today" is dropped
// ---------------------------------------------------------------------------
describe('evaluateStreak — drops "today" defensively', () => {
  it('dayCompletion equal to today is ignored, rest still processed', () => {
    const result = evaluateStreak(
      makeInput({
        // today=2026-04-30 (UTC+0, now=...T12:00Z)
        currentStreak: 0,
        dayCompletions: [
          completed('2026-04-29'),
          completed('2026-04-30'), // today — must be dropped
        ],
      }),
    );
    expect(result.daysProcessed).toBe(1);
    expect(result.newCurrentStreak).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// 19. Freeze cap — caller's job, we just consume what's given
// ---------------------------------------------------------------------------
describe('evaluateStreak — freeze cap not enforced here', () => {
  it('with 5 freezes available, 5 consecutive misses each consume one freeze', () => {
    // Documents the decision: this module does NOT clamp freezesAvailable.
    // The caller (PRD: ladder awards Freeze #1 at Lvl 3, #2 at Lvl 7, cap 2)
    // is responsible for respecting the cap.
    const result = evaluateStreak(
      makeInput({
        currentStreak: 3,
        freezesAvailable: 5,
        dayCompletions: [
          missed('2026-04-25'),
          missed('2026-04-26'),
          missed('2026-04-27'),
          missed('2026-04-28'),
          missed('2026-04-29'),
        ],
      }),
    );
    expect(result.freezesConsumed).toBe(5);
    expect(result.newFreezesAvailable).toBe(0);
    expect(result.newCurrentStreak).toBe(3); // unchanged — no break
    expect(result.brokenAt).toBeNull();
    expect(result.daysProcessed).toBe(5);
  });
});

// ---------------------------------------------------------------------------
// 20. brokenAt exact YYYY-MM-DD on freeze=0 break
// ---------------------------------------------------------------------------
describe('evaluateStreak — brokenAt exact value', () => {
  it('streak break with freezes=0 sets brokenAt to the missed day YYYY-MM-DD', () => {
    const result = evaluateStreak(
      makeInput({
        currentStreak: 4,
        freezesAvailable: 0,
        dayCompletions: [
          completed('2026-04-27'),
          completed('2026-04-28'),
          missed('2026-04-29'),
        ],
      }),
    );
    expect(result.brokenAt).toBe('2026-04-29');
    expect(result.newCurrentStreak).toBe(0);
    // Walked all three (last one breaks).
    expect(result.daysProcessed).toBe(3);
  });
});

// ---------------------------------------------------------------------------
// Defensive — out-of-order input is sorted, not rejected
// ---------------------------------------------------------------------------
describe('evaluateStreak — out-of-order dayCompletions', () => {
  it('out-of-order input is sorted defensively, not thrown', () => {
    const result = evaluateStreak(
      makeInput({
        currentStreak: 0,
        dayCompletions: [
          completed('2026-04-29'),
          completed('2026-04-27'),
          completed('2026-04-28'),
        ],
      }),
    );
    expect(result.daysProcessed).toBe(3);
    expect(result.newCurrentStreak).toBe(3);
  });
});
