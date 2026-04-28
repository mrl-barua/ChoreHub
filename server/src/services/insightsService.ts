// Pure functions — no Prisma dependency. All data is passed in by the caller.

export type HistoryEntry = { choreId: string; userId: string; createdAt: Date };
export type ChoreEntry = { id: string; title: string };
export type MemberEntry = { userId: string; name: string };

export type TimingPatternResult = {
  choreId: string;
  choreTitle: string;
  bestDayOfWeek: number;
  bestHour: number;
  label: string;
  choreSampleSize: number;
};

export type EngagementScoreResult = {
  userId: string;
  name: string;
  thisWeekCount: number;
  prevWeekCount: number;
  trend: number;
  driftAlert: boolean;
};

export type FairnessIndexResult = {
  score: number | null;
  distribution: Record<string, number> | null;
};

export type DriftAlertResult = {
  userId: string;
  name: string;
  drop: number;
};

// ---------------------------------------------------------------------------
// countByUserId
// ---------------------------------------------------------------------------
export function countByUserId(history: HistoryEntry[]): Record<string, number> {
  const result: Record<string, number> = {};
  for (const entry of history) {
    result[entry.userId] = (result[entry.userId] || 0) + 1;
  }
  return result;
}

// ---------------------------------------------------------------------------
// computeTimingPatterns
// ---------------------------------------------------------------------------
const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function getTimeOfDay(hour: number): string {
  if (hour >= 5 && hour <= 11) return 'morning';
  if (hour >= 12 && hour <= 16) return 'afternoon';
  if (hour >= 17 && hour <= 21) return 'evening';
  return 'night';
}

function modalValue(values: number[]): number {
  const freq: Record<number, number> = {};
  for (const v of values) {
    freq[v] = (freq[v] || 0) + 1;
  }
  let best = values[0];
  let bestCount = 0;
  for (const [k, c] of Object.entries(freq)) {
    if (c > bestCount) {
      bestCount = c;
      best = Number(k);
    }
  }
  return best;
}

export function computeTimingPatterns(
  chores: ChoreEntry[],
  history90d: HistoryEntry[],
  tzOffsetMinutes = 0,
): TimingPatternResult[] {
  const offsetMs = tzOffsetMinutes * 60_000;
  const results: TimingPatternResult[] = [];

  for (const chore of chores) {
    const completions = history90d.filter((h) => h.choreId === chore.id);
    if (completions.length < 5) continue;

    // Shift each UTC timestamp by the client's offset so getUTCDay/getUTCHours
    // return the user's local day and hour.
    const localDates = completions.map((h) => new Date(h.createdAt.getTime() + offsetMs));

    const daysOfWeek = localDates.map((d) => d.getUTCDay());
    const bestDayOfWeek = modalValue(daysOfWeek);

    // Modal hour — only among completions on the best day
    const onBestDay = localDates.filter((d) => d.getUTCDay() === bestDayOfWeek);
    const hours = onBestDay.map((d) => d.getUTCHours());
    const bestHour = modalValue(hours);

    const dayName = DAY_NAMES[bestDayOfWeek];
    const timeOfDay = getTimeOfDay(bestHour);
    const label = `${dayName} ${timeOfDay}`;

    results.push({ choreId: chore.id, choreTitle: chore.title, bestDayOfWeek, bestHour, label, choreSampleSize: completions.length });
  }

  return results.sort((a, b) => b.choreSampleSize - a.choreSampleSize);
}

// ---------------------------------------------------------------------------
// computeEngagementScores
// ---------------------------------------------------------------------------
export function computeEngagementScores(
  members: MemberEntry[],
  thisWeekHistory: HistoryEntry[],
  prevWeekHistory: HistoryEntry[],
): EngagementScoreResult[] {
  // Collect all userIds that appear in history but may not be current members
  const knownUserIds = new Set(members.map((m) => m.userId));
  const historyUserIds = new Set([
    ...thisWeekHistory.map((h) => h.userId),
    ...prevWeekHistory.map((h) => h.userId),
  ]);

  // Build combined list: current members + former members from history
  const allEntries: MemberEntry[] = [
    ...members,
    ...[...historyUserIds]
      .filter((uid) => !knownUserIds.has(uid))
      .map((uid) => ({ userId: uid, name: 'Former member' })),
  ];

  const thisCounts = countByUserId(thisWeekHistory);
  const prevCounts = countByUserId(prevWeekHistory);

  return allEntries.map((member) => {
    const thisWeekCount = thisCounts[member.userId] || 0;
    const prevWeekCount = prevCounts[member.userId] || 0;

    let trend: number;
    if (prevWeekCount > 0) {
      trend = (thisWeekCount - prevWeekCount) / prevWeekCount;
    } else if (thisWeekCount > 0) {
      trend = thisWeekCount; // raw count, always positive
    } else {
      trend = 0;
    }

    const driftAlert = trend < -0.20;

    return { userId: member.userId, name: member.name, thisWeekCount, prevWeekCount, trend, driftAlert };
  });
}

// ---------------------------------------------------------------------------
// computeFairnessIndex
// ---------------------------------------------------------------------------
export function computeFairnessIndex(
  members: MemberEntry[],
  history14d: HistoryEntry[],
): FairnessIndexResult {
  if (members.length === 1) {
    return { score: null, distribution: null };
  }

  const total = history14d.length;
  if (total === 0) {
    return { score: 100, distribution: {} };
  }

  const counts = countByUserId(history14d);
  const expected = total / members.length;

  const distribution: Record<string, number> = {};
  let normalizedDeviation = 0;

  for (const member of members) {
    const actual = counts[member.userId] || 0;
    distribution[member.userId] = Math.round((actual / total) * 100);
    normalizedDeviation += Math.abs(actual - expected);
  }

  normalizedDeviation /= total;
  const score = Math.max(0, Math.min(100, Math.round((1 - normalizedDeviation) * 100)));

  return { score, distribution };
}

// ---------------------------------------------------------------------------
// detectDriftAlerts
// ---------------------------------------------------------------------------
export function detectDriftAlerts(
  scores: ReturnType<typeof computeEngagementScores>,
): DriftAlertResult[] {
  return scores
    .filter((s) => s.trend < -0.20)
    .map((s) => ({ userId: s.userId, name: s.name, drop: Math.abs(s.trend) }));
}
