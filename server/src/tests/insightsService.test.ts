import { describe, it, expect } from 'vitest';
import {
  countByUserId,
  computeTimingPatterns,
  computeEngagementScores,
  computeFairnessIndex,
  detectDriftAlerts,
} from '../services/insightsService';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
// Jan 7 2024 is a Sunday
const sunday20 = new Date('2024-01-07T20:00:00Z');
// Jan 8 2024 is a Monday
const monday08 = new Date('2024-01-08T08:00:00Z');

// ---------------------------------------------------------------------------
// countByUserId
// ---------------------------------------------------------------------------
describe('countByUserId', () => {
  it('empty array → {}', () => {
    expect(countByUserId([])).toEqual({});
  });

  it('all same userId → { u1: 3 }', () => {
    const history = [
      { choreId: 'c1', userId: 'u1', createdAt: sunday20 },
      { choreId: 'c1', userId: 'u1', createdAt: sunday20 },
      { choreId: 'c1', userId: 'u1', createdAt: sunday20 },
    ];
    expect(countByUserId(history)).toEqual({ u1: 3 });
  });

  it('multiple users → { u1: 2, u2: 1 }', () => {
    const history = [
      { choreId: 'c1', userId: 'u1', createdAt: sunday20 },
      { choreId: 'c1', userId: 'u1', createdAt: sunday20 },
      { choreId: 'c1', userId: 'u2', createdAt: sunday20 },
    ];
    expect(countByUserId(history)).toEqual({ u1: 2, u2: 1 });
  });
});

// ---------------------------------------------------------------------------
// computeTimingPatterns
// ---------------------------------------------------------------------------
describe('computeTimingPatterns', () => {
  it('chore with 4 completions → excluded from result', () => {
    const chores = [{ id: 'c1', title: 'Vacuum' }];
    const history90d = Array.from({ length: 4 }, () => ({
      choreId: 'c1',
      userId: 'u1',
      createdAt: sunday20,
    }));
    expect(computeTimingPatterns(chores, history90d)).toEqual([]);
  });

  it('chore with 6 completions (5 on Sunday, 1 on Monday) → bestDayOfWeek=0', () => {
    const chores = [{ id: 'c1', title: 'Vacuum' }];
    const history90d = [
      ...Array.from({ length: 5 }, () => ({ choreId: 'c1', userId: 'u1', createdAt: sunday20 })),
      { choreId: 'c1', userId: 'u1', createdAt: monday08 },
    ];
    const result = computeTimingPatterns(chores, history90d);
    expect(result).toHaveLength(1);
    expect(result[0].bestDayOfWeek).toBe(0);
  });

  it('6 Sunday completions all at 20:00 → bestHour=20, label "Sunday evening"', () => {
    const chores = [{ id: 'c1', title: 'Vacuum' }];
    const history90d = Array.from({ length: 6 }, () => ({
      choreId: 'c1',
      userId: 'u1',
      createdAt: sunday20,
    }));
    const result = computeTimingPatterns(chores, history90d);
    expect(result[0].bestHour).toBe(20);
    expect(result[0].label).toBe('Sunday evening');
  });

  it('bestHour is modal on bestDayOfWeek only: Sun@20 x3, Mon@8 x5 → bestDayOfWeek=0, bestHour=20', () => {
    const chores = [{ id: 'c1', title: 'Vacuum' }];
    // 5 Mondays at 08 → they would win global modal day (5 vs 3),
    // but Sunday has only 3, so Monday is actually the modal day here.
    // Wait — let's re-read the spec: we need Sunday to win. So let's use Sun x5, Mon x3.
    const history90d = [
      ...Array.from({ length: 5 }, () => ({ choreId: 'c1', userId: 'u1', createdAt: sunday20 })),
      ...Array.from({ length: 3 }, () => ({ choreId: 'c1', userId: 'u1', createdAt: monday08 })),
    ];
    // bestDayOfWeek = Sunday (0), because 5 > 3
    // bestHour = modal hour among the 5 Sunday entries = 20
    const result = computeTimingPatterns(chores, history90d);
    expect(result[0].bestDayOfWeek).toBe(0);
    expect(result[0].bestHour).toBe(20);
  });

  it('empty history90d → []', () => {
    const chores = [{ id: 'c1', title: 'Vacuum' }];
    expect(computeTimingPatterns(chores, [])).toEqual([]);
  });

  it('results sorted descending by choreSampleSize', () => {
    const chores = [
      { id: 'c1', title: 'Dishes' },
      { id: 'c2', title: 'Vacuum' },
    ];
    const history90d = [
      // c1 has 5 completions
      ...Array.from({ length: 5 }, () => ({ choreId: 'c1', userId: 'u1', createdAt: sunday20 })),
      // c2 has 8 completions — should rank first
      ...Array.from({ length: 8 }, () => ({ choreId: 'c2', userId: 'u1', createdAt: sunday20 })),
    ];
    const result = computeTimingPatterns(chores, history90d);
    expect(result[0].choreTitle).toBe('Vacuum');
    expect(result[0].choreSampleSize).toBe(8);
    expect(result[1].choreTitle).toBe('Dishes');
    expect(result[1].choreSampleSize).toBe(5);
  });

  it('timezone offset shifts UTC Monday 01:00 to Sunday 20:00 for UTC-5 user', () => {
    // A UTC-5 family does dishes at 20:00 local Sunday.
    // Stored as UTC Monday 01:00.
    const mondayAt01utc = new Date('2024-01-08T01:00:00Z'); // Monday UTC
    const chores = [{ id: 'c1', title: 'Dishes' }];
    const history90d = Array.from({ length: 6 }, () => ({
      choreId: 'c1',
      userId: 'u1',
      createdAt: mondayAt01utc,
    }));

    // Without offset: Monday (1)
    const utcResult = computeTimingPatterns(chores, history90d, 0);
    expect(utcResult[0].bestDayOfWeek).toBe(1);

    // With UTC-5 offset (-300 min): Sunday (0), hour 20
    const localResult = computeTimingPatterns(chores, history90d, -300);
    expect(localResult[0].bestDayOfWeek).toBe(0);
    expect(localResult[0].bestHour).toBe(20);
    expect(localResult[0].label).toBe('Sunday evening');
  });
});

// ---------------------------------------------------------------------------
// computeEngagementScores
// ---------------------------------------------------------------------------
describe('computeEngagementScores', () => {
  const members = [{ userId: 'u1', name: 'Alice' }];

  it('prevWeekCount=0, thisWeekCount=5 → trend=5.0, driftAlert=false', () => {
    const thisWeek = Array.from({ length: 5 }, () => ({
      choreId: 'c1',
      userId: 'u1',
      createdAt: sunday20,
    }));
    const result = computeEngagementScores(members, thisWeek, []);
    expect(result[0].trend).toBe(5);
    expect(result[0].driftAlert).toBe(false);
  });

  it('prevWeekCount=10, thisWeekCount=4 → trend≈-0.6, driftAlert=true', () => {
    const thisWeek = Array.from({ length: 4 }, () => ({
      choreId: 'c1',
      userId: 'u1',
      createdAt: sunday20,
    }));
    const prevWeek = Array.from({ length: 10 }, () => ({
      choreId: 'c1',
      userId: 'u1',
      createdAt: sunday20,
    }));
    const result = computeEngagementScores(members, thisWeek, prevWeek);
    expect(result[0].trend).toBeCloseTo(-0.6, 1);
    expect(result[0].driftAlert).toBe(true);
  });

  it('prevWeekCount=0, thisWeekCount=0 → trend=0, driftAlert=false', () => {
    const result = computeEngagementScores(members, [], []);
    expect(result[0].trend).toBe(0);
    expect(result[0].driftAlert).toBe(false);
  });

  it('member in members[] but 0 completions → appears in result with both counts=0', () => {
    const result = computeEngagementScores(members, [], []);
    expect(result).toHaveLength(1);
    expect(result[0].userId).toBe('u1');
    expect(result[0].thisWeekCount).toBe(0);
    expect(result[0].prevWeekCount).toBe(0);
  });

  it('userId in history but not in members[] → name="Former member", no crash', () => {
    const thisWeek = [{ choreId: 'c1', userId: 'u999', createdAt: sunday20 }];
    const result = computeEngagementScores([], thisWeek, []);
    const former = result.find((r) => r.userId === 'u999');
    expect(former).toBeDefined();
    expect(former?.name).toBe('Former member');
  });
});

// ---------------------------------------------------------------------------
// computeFairnessIndex
// ---------------------------------------------------------------------------
describe('computeFairnessIndex', () => {
  it('memberCount=1 → { score: null, distribution: null }', () => {
    const result = computeFairnessIndex([{ userId: 'u1', name: 'Alice' }], []);
    expect(result).toEqual({ score: null, distribution: null });
  });

  it('total=0 (no completions in 14d) → { score: 100, distribution: {} }', () => {
    const members = [
      { userId: 'u1', name: 'Alice' },
      { userId: 'u2', name: 'Bob' },
    ];
    const result = computeFairnessIndex(members, []);
    expect(result).toEqual({ score: 100, distribution: {} });
  });

  it('2 members, 5 completions each → score=100', () => {
    const members = [
      { userId: 'u1', name: 'Alice' },
      { userId: 'u2', name: 'Bob' },
    ];
    const history = [
      ...Array.from({ length: 5 }, () => ({ choreId: 'c1', userId: 'u1', createdAt: sunday20 })),
      ...Array.from({ length: 5 }, () => ({ choreId: 'c1', userId: 'u2', createdAt: sunday20 })),
    ];
    const result = computeFairnessIndex(members, history);
    expect(result.score).toBe(100);
  });

  it('2 members, 9 and 1 completions → score=20', () => {
    const members = [
      { userId: 'u1', name: 'Alice' },
      { userId: 'u2', name: 'Bob' },
    ];
    const history = [
      ...Array.from({ length: 9 }, () => ({ choreId: 'c1', userId: 'u1', createdAt: sunday20 })),
      ...Array.from({ length: 1 }, () => ({ choreId: 'c1', userId: 'u2', createdAt: sunday20 })),
    ];
    // total=10, expected=5 each
    // |9-5| + |1-5| = 4+4 = 8; normalized = 8/10 = 0.8; score = (1-0.8)*100 = 20
    const result = computeFairnessIndex(members, history);
    expect(result.score).toBe(20);
  });

  it('3 members, 60/30/10 split → score=47 (normalized MAD, not max-min range)', () => {
    // Documents the formula: sum(|actual - expected|) / total, NOT maxShare - minShare.
    // max-min formula would give (0.6 - 0.1) * 100 = 50. This formula gives 47.
    const members = [
      { userId: 'u1', name: 'Alice' },
      { userId: 'u2', name: 'Bob' },
      { userId: 'u3', name: 'Carol' },
    ];
    const history = [
      ...Array.from({ length: 6 }, () => ({ choreId: 'c1', userId: 'u1', createdAt: sunday20 })),
      ...Array.from({ length: 3 }, () => ({ choreId: 'c1', userId: 'u2', createdAt: sunday20 })),
      ...Array.from({ length: 1 }, () => ({ choreId: 'c1', userId: 'u3', createdAt: sunday20 })),
    ];
    const result = computeFairnessIndex(members, history);
    expect(result.score).toBe(47);
  });

  it('3 members at ~33% each → distribution values are integers, sum near 100', () => {
    const members = [
      { userId: 'u1', name: 'Alice' },
      { userId: 'u2', name: 'Bob' },
      { userId: 'u3', name: 'Carol' },
    ];
    // 10 completions split 4/3/3
    const history = [
      ...Array.from({ length: 4 }, () => ({ choreId: 'c1', userId: 'u1', createdAt: sunday20 })),
      ...Array.from({ length: 3 }, () => ({ choreId: 'c1', userId: 'u2', createdAt: sunday20 })),
      ...Array.from({ length: 3 }, () => ({ choreId: 'c1', userId: 'u3', createdAt: sunday20 })),
    ];
    const result = computeFairnessIndex(members, history);
    expect(result.distribution).not.toBeNull();
    const sum = Object.values(result.distribution!).reduce((a, b) => a + b, 0);
    expect(sum).toBeGreaterThanOrEqual(99);
    expect(sum).toBeLessThanOrEqual(101);
  });
});

// ---------------------------------------------------------------------------
// detectDriftAlerts
// ---------------------------------------------------------------------------
describe('detectDriftAlerts', () => {
  it('trend=-0.20 → NOT in alerts (boundary: strictly < -0.20)', () => {
    const scores = [
      { userId: 'u1', name: 'Alice', thisWeekCount: 8, prevWeekCount: 10, trend: -0.20, driftAlert: false },
    ];
    expect(detectDriftAlerts(scores)).toHaveLength(0);
  });

  it('trend=-0.21 → IS in alerts, drop=0.21', () => {
    const scores = [
      { userId: 'u1', name: 'Alice', thisWeekCount: 0, prevWeekCount: 10, trend: -0.21, driftAlert: true },
    ];
    const result = detectDriftAlerts(scores);
    expect(result).toHaveLength(1);
    expect(result[0].drop).toBeCloseTo(0.21, 2);
  });

  it('trend=+0.50 → NOT in alerts', () => {
    const scores = [
      { userId: 'u1', name: 'Alice', thisWeekCount: 15, prevWeekCount: 10, trend: 0.5, driftAlert: false },
    ];
    expect(detectDriftAlerts(scores)).toHaveLength(0);
  });

  it('empty input → []', () => {
    expect(detectDriftAlerts([])).toEqual([]);
  });
});
