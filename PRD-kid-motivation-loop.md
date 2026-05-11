# PRD: Kid Motivation Loop — Streak, Level, and Agency Unlocks

## Problem Statement

When a kid in ChoreHub finishes a chore, almost nothing happens. There's a brief confetti animation and a haptic buzz, then the chore disappears from their list. The next chore reminder will arrive eventually, but in the meantime there is no reason — emotionally, narratively, or functionally — for the kid to come back to the app or feel that the work they just did was theirs.

The recent investments in reminders (FCM push notifications, the Android home widget, the swap-request flow) all attack the *front* of the chore loop: getting the kid to start a chore. None of them address the *back* of the loop: what happens *after* a chore is done, what makes the next day worth showing up for, or what gives the kid an identity inside the app that is theirs and not the family's.

In its current state ChoreHub trains kids to see notifications as a source of obligation and the app as a list of things their parent wants them to do. There is no personal sense of progress, no reward that survives the act of completion, and no continuity between Tuesday and Wednesday other than that the chore list resets. The "gamification (challenges and streaks)" mentioned in the project's own documentation refers only to a family-wide `FamilyChallenge` counter; there is no streak in the schema, no XP, no level, no badge, and no per-kid progression of any kind.

## Solution

We add a kid-personal progression layer on top of chore completion — a streak (the daily spine), an XP/level system (the long arc and unlock currency), and a small set of *agency unlocks* that the level system gates. The unlocks are deliberately additive: they expand what the kid can do inside the app rather than gating functionality that already exists.

The feedback loop has three nested time horizons:

- **Per-chore moment** — the existing confetti + haptic, now joined by a clear XP award and a "+10 XP" surface that the kid sees and feels.
- **Daily** — a streak that increments when all of the kid's `dueDate=today` chores are complete, auto-passes on zero-due days, and is protected by streak freezes (earned via leveling) and a one-shot Mend recovery (XP-priced, with a cooldown).
- **Long arc** — a single global level driven by cumulative XP, displayed alongside cosmetic per-category badges. Hitting a new level is a full-screen takeover moment with confetti and an unlock announcement.

Streak, level, and badges are visible to the family (siblings, parents) so the system has social texture. The recovery mechanics — freeze count and mend availability — are kid-private, so the system never produces a public shame surface.

## User Stories

### Daily loop — the streak

1. As a kid, I want to see my current streak the moment I open the app, so that I immediately know what I'm protecting today.
2. As a kid, I want my streak to advance when I complete every chore that is due today, so that the streak reflects whether I actually did my job.
3. As a kid, I want days with zero chores due to auto-pass without breaking my streak, so that I'm not punished for parental scheduling gaps, weekends, sick days, or vacations.
4. As a kid, I want overdue chores from previous days to *not* count against today's streak, so that the streak goalpost doesn't move backwards on me.
5. As a kid, when I complete the last chore due today, I want a distinct "streak day complete" affirmation that is bigger than a single-chore confetti, so that finishing the day feels meaningful.
6. As a kid, I want my streak window to use my device timezone, so that a flight or a vacation doesn't accidentally break my streak.
7. As a kid moving across timezones, I want the system to handle the transition gracefully without giving me a "double day" or a "lost day," so that the streak's integrity is preserved.

### Streak protection — freezes and mend

8. As a kid, I want a "Streak Freeze" to silently absorb one missed day before my streak breaks, so that one off-day doesn't erase weeks of work.
9. As a kid, I want freezes to be earned (at Lvl 3 and Lvl 7, capped at 2), so that protection feels like a reward rather than charity.
10. As a kid, I want my freeze count to be visible only to me, so that siblings can't shame me about how close I am to using one.
11. As a kid, when my freezes run out and I miss a day, I want a one-time "save your streak?" prompt the next day, so that I have a redemption path instead of giving up.
12. As a kid, I want the Mend prompt to require completing today's chores plus a small XP cost, so that recovery is earned rather than free.
13. As a kid, I want the Mend cooldown (14 days, halved to 7 at Lvl 10) to be invisible to others, so that the recovery surface stays private.
14. As a kid, I want Mend to unlock only at Lvl 2 so I have at least one meaningful play before recovery is available, so that the early game has a clean shape.

### Long arc — XP, levels, unlocks

15. As a kid, I want to earn XP for every chore I complete, so that progress accumulates even on days my streak breaks.
16. As a kid, I want an on-time bonus when I finish a chore before its due date, so that being prompt has its own reward.
17. As a kid, I want a streak-day completion bonus when I clear all due-today chores, so that finishing the day matters more than just doing the work.
18. As a kid, I want to see how close I am to the next level on a clear, animated bar, so that progress is visible at a glance.
19. As a kid, when I level up, I want a full-screen takeover with confetti and an unlock announcement, so that the milestone is unmistakable from any other moment.
20. As a kid, I want the unlock ladder to be visible ahead of time, so that I know what's coming and have something to look forward to.
21. As a kid, I want my level to climb at a rate that feels earned but reachable — about a week to Lvl 2, a few months to Lvl 10 — so that it's neither trivial nor hopeless.

### Identity — badges and titles

22. As a kid, I want to earn cosmetic category badges (e.g., "Kitchen Champion," "Pet Whisperer") for racking up completions in a category, so that I get a sense of identity within the app.
23. As a kid, I want category badges to be cosmetic and not gate any functionality, so that I'm never punished for ignoring a category I dislike.
24. As a kid, I want to pick one earned badge to display as a title under my name (unlocked at Lvl 5), so that my reputation is visible to my family.
25. As a kid, I want my displayed title and earned badges to be visible to my siblings and parents, so that the family progression has social texture.

### Visibility and family social shape

26. As a kid, I want to see my siblings' streaks and levels, so that the family progression has friendly competition.
27. As a parent, I want to see each kid's streak, level, and earned badges on the family screen, so that I have positive surfaces to praise rather than only compliance metrics.
28. As a parent, I want progression to be derived from real chore completion (and not admin-toggleable), so that the kid trusts the system's integrity.
29. As a parent, I want unlocks to never override my authority (no "skip-without-consequence" tokens), so that the system reinforces my role rather than undermining it.

### Surface — where it lives

30. As a kid, I want a compact streak + level card at the top of my dashboard, so that the daily state is the first thing I see.
31. As a kid, I want my home-screen widget to show my streak alongside chores due, so that I'm reminded what I'm protecting before I open the app.
32. As a kid, I want a full progression view inside my Profile screen — XP bar, badges grid, ladder visualization, freeze count, Mend button when available — so that one place tells me everything about my progress.
33. As a kid, I want the per-chore "+10 XP" feedback to be clearly visible on the completion screen, so that the reward is felt rather than hidden.
34. As a kid, when I'm one chore away from leveling up, I want a small "one more to level up" hint, so that I'm motivated to do the next chore.

### Engineering and integrity

35. As a developer, I want the streak and level/XP logic implemented as pure functions of their inputs, so that timezone, leap day, freeze, and mend edge cases are testable in isolation without a database.
36. As a developer, I want progression to be evaluated lazily on read rather than via a daily cron, so that the system has no scheduler to break and no drift on inactive users.
37. As a developer, I want a single source-of-truth ladder definition (level → XP threshold → unlock), so that adding or tuning a level reward is a single edit.
38. As a developer, I want progression state denormalized onto the User row, so that dashboard reads are O(1) rather than scanning chore history.
39. As a developer, I want chore completion to atomically award XP, evaluate level-up, and update streak in one transaction, so that the kid never sees partial state on a dashboard refresh.

## Implementation Decisions

### Decisions made during grilling

- **Persona scope.** The feature serves the kid/teen persona doing chores. Parent and sibling experiences are derivative (read-only views). This is not a parent dashboard feature.
- **Currency model.** Intrinsic + in-app agency unlocks. No external/redeemable rewards (no allowance ledger, no parent-redeemable points). Kept off-roadmap deliberately to avoid the parent-economy rabbit hole and to ensure the loop works without parent participation.
- **Ladder shape.** Single global level powers the unlock economy. Per-category badges exist as cosmetic flair but do not gate any functionality. This avoids fragmenting the loop and prevents kids from avoiding weak categories to protect strong masteries.
- **Daily spine.** Layered: streak is the daily spine, XP/level is the long arc and the unlock currency. The home widget and FCM push surfaces lead with streak. Level-ups are the periodic larger reward moment.
- **Streak day definition.** A streak day completes when all chores `assignedTo = userId AND dueDate::date = today` have a corresponding `ChoreHistory.action LIKE 'completed%'` entry. Days with zero such chores auto-pass. Overdue chores from previous days are excluded from today's streak calculation. Streak status is binary per day; quality and on-time are separate signals that affect XP, not streak status.
- **End-of-day boundary.** Midnight in the kid's device timezone, passed as `tzOffsetMinutes` on progression endpoints (matching the existing pattern in the insights service).
- **Streak break mechanic.** Streak Freezes (earned at Lvl 3 and Lvl 7, hard cap of 2) silently absorb one missed day each. Once freezes are exhausted, the next missed day produces a one-time Mend opportunity the following day: complete today's chores plus a small XP cost, available at most once per 14 days (halved to 7 days at Lvl 10), unlocked at Lvl 2. After freezes and Mend are exhausted, the streak resets to zero (catastrophic).
- **Visibility split.** Public to family: streak, level, XP, badges, displayed title. Kid-private: freeze count, Mend availability, Mend cooldown timer.

### Unlock ladder

| Level | Unlock |
|-------|--------|
| 2 | Streak Mend mechanic unlocks |
| 3 | Streak Freeze #1 earned (cap 1) |
| 5 | Display Title unlocked — pick one earned badge to show on profile |
| 7 | Streak Freeze #2 earned (cap 2) |
| 10 | Mend cooldown halves from 14 days to 7 days |

Levels 4, 6, 8, and 9 award category badges only (cosmetic).

### XP formula

- **+10 XP** per chore completion.
- **+5 XP** on-time bonus when `completedAt < dueDate`.
- **+10 XP** streak-day bonus, awarded once at end-of-day evaluation if all due-today chores are complete.

### Level curve

`xp_required_to_advance = level * 50`, so cumulative XP to reach level N is `25 * N * (N - 1)`. Tunable via a server-side config constant. Targets: ~1 day to Lvl 2, ~3 weeks to Lvl 5, ~3 months to Lvl 10 at moderate use.

### Schema changes

- Add fields to the `User` model: `xp` (Int, default 0), `level` (Int, default 1), `currentStreak` (Int, default 0), `longestStreak` (Int, default 0), `lastStreakEvalAt` (DateTime, nullable), `freezesAvailable` (Int, default 0), `lastMendAt` (DateTime, nullable), `displayTitle` (String, nullable).
- New table `UserBadge` with `userId`, `badgeKey`, `earnedAt`, indexed by `userId`.

No changes to `Chore`, `ChoreHistory`, `FamilyChallenge`, or any existing model.

### Modules to build

**Server — pure-logic deep modules (no DB, no I/O, no time):**

- **Progression service.** Single source of truth for the level curve, the unlock ladder, and XP awarding rules. Interface: given current XP/level and a chore-completion event, returns the new XP, new level, whether a level-up occurred, and the list of newly available unlocks. Pure function. The level curve and ladder live here as constants. Adding or tuning a level reward is one edit.
- **Streak service.** Pure logic for streak evaluation. Interface: given last-eval timestamp, current streak, freezes available, a sequence of per-day completion booleans within the elapsed window, and a timezone offset, returns the new streak, new freeze count, the timestamp of any break, and whether the user is Mend-eligible. All timezone, freeze-consumption, and zero-due-day logic lives here and is testable without a database.
- **Badge service.** Pure logic for badge thresholds. Interface: given chore-history aggregates and existing badges, returns newly earned badges. Stateless threshold map.

**Server — thin glue:**

- Progression repository — Prisma reads/writes for the new User fields and the UserBadge table.
- Routes: `GET /api/me/progression` (returns level, XP, current streak, freeze count, Mend availability, badges, displayed title), `POST /api/me/progression/mend` (spend XP to restore streak, validates cooldown), `POST /api/me/progression/title` (set displayed title from earned badges).
- Hook in chore completion (`POST /api/chores/:id/complete`): inside the existing transaction, call progression service, streak service, and badge service, then persist via the repository. Atomic with the chore-status update.

**Mobile — Riverpod-shaped, following the existing service-per-domain convention:**

- Progression service (`lib/services/progression_service.dart`) — API client for the three endpoints.
- Progression provider (`lib/providers/progression_provider.dart`) — `NotifierProvider<ProgressionNotifier, ProgressionState>` mirroring the server response. Watches `authProvider` like other providers.
- Streak card widget — compact dashboard header showing streak count, level, and XP-to-next-level progress.
- Progression section widget — embedded in the Profile screen, contains the full XP bar, badges grid, ladder visualization, freeze count, and Mend button when available.
- Level-up modal — full-screen takeover with confetti and the unlock announcement, triggered by a one-shot signal from the progression provider after a successful chore completion that produced a level-up.
- Home widget update — append streak count to the existing chores widget output.

### Storage and evaluation strategy

- Denormalized progression state on the `User` row.
- Lazy evaluation: every call to `GET /api/me/progression` and the chore-completion hook re-evaluates streak based on `lastStreakEvalAt` versus now in the requesting client's timezone, consuming freezes and breaking the streak as appropriate, then persists the updated state.
- No daily cron or background scheduler. Inactive users have stale state until they next interact, which is correct because no kid wants to see "you broke your 30-day streak" notifications when they haven't opened the app in a week.

### API contracts

- `GET /api/me/progression` returns `{ xp, level, xpToNextLevel, currentStreak, longestStreak, freezesAvailable, mendEligible, mendCooldownRemainingSec, badges: BadgeKey[], displayTitle, unlocks: UnlockKey[] }`.
- `POST /api/me/progression/mend` returns 200 on success with the restored progression state, 400 if the kid is not Mend-eligible, 402 if XP balance is insufficient, 429 if the Mend cooldown is active.
- `POST /api/me/progression/title` accepts `{ badgeKey }` and validates that the kid has earned that badge.
- The chore-completion endpoint's response is extended with an optional `progression: { xpAwarded, leveledUp, newLevel?, unlocks?: UnlockKey[], streakIncremented, badgesEarned: BadgeKey[] }` field. The mobile client uses this to decide whether to show the level-up modal.

## Testing Decisions

### What makes a good test

Tests should verify *external behavior* — what a module does given specific inputs — not implementation details like which helper function it calls or how it stores intermediate values. Pure-logic modules are tested by feeding inputs and asserting outputs; nothing else. We do not mock internal collaborators.

### Modules to be unit-tested

- **Progression service.** The XP curve, level boundaries, and unlock-ladder mappings need exhaustive coverage: XP awarded per chore at each bonus combination, level-up boundary cases (exactly hitting threshold, overshooting, multiple levels in one event if XP is large), unlock-list correctness at each level transition.
- **Streak service.** Highest-leverage tests in the project. Coverage: zero-due-day auto-pass; overdue chores not bleeding into today; freeze consumption on a single missed day; freeze consumption on multiple consecutive missed days (cap behavior); streak break when freezes exhausted; timezone boundary cases (UTC-12 to UTC+14, day-boundary edge cases); mend-eligibility flag set correctly the day after a break; same-day double-evaluation idempotency.
- **Badge service.** Coverage: threshold transitions per category; idempotency (already-earned badges are not awarded twice); multiple badges earned in one event.

### Modules not unit-tested

- The progression repository (covered by integration tests on the routes).
- The progression provider and other Riverpod plumbing (state correctness is covered by the API contract tests; widget rendering is manual QA).
- Widgets: streak card, progression section, level-up modal. Manual QA on the level-up moment is more useful than golden-image tests for this kind of celebratory moment.

### Prior art in the codebase

- Pure-function tests against `insightsService` (`server/src/tests/insightsService.test.ts`), particularly the timezone-shift case at line 121, are the model to follow for `streakService` timezone tests.
- The existing `feedback_service_test.dart` on the mobile side (`mobile/test/services/feedback_service_test.dart`) is the pattern for any mobile-side tests that do get written.

## Out of Scope

- **Parent-redeemable rewards.** No allowance ledger, no parent-side approval of redemptions, no real-world reward tracking. The unlock economy is intrinsic only. Parent-redeemable rewards may be added later behind a per-family flag, but the v1 system works with zero parent participation.
- **Sibling competition mechanics.** The family screen will *display* sibling streaks/levels/badges, but no leaderboard rank, no "you beat your sister this week," no head-to-head challenges. Display only.
- **Photo-proof XP bonus.** Considered during grilling, deliberately deferred. Adding a reward for photo evidence pulls in moderation and parent-approval surface area; out of v1.
- **Chore-difficulty-weighted XP.** All chores award the same base 10 XP regardless of priority or category. Weighting introduces gaming risk and configuration burden.
- **Per-category mastery levels.** Categories are cosmetic only (badges). No separate per-category XP bars.
- **A new "Me" tab.** Progression lives inside the existing Profile and Dashboard tabs.
- **Streak / level data in the offline SQLite mirror.** Progression is read-only on the client and lives behind a network call. If a kid is offline, the progression card shows last-known state with a refresh affordance. Adding progression to the offline-sync layer is deferred.
- **Push notifications driven by progression.** No "your streak ends in 4 hours" pushes in v1; existing FCM "due soon" pushes are sufficient. Streak-loss-aversion pushes are a follow-up that can ride on the existing notification preferences pipeline.
- **Configurable per-family overrides.** No per-family streak threshold, no per-family curve tuning. Strong defaults ship; configurability is a follow-up if real families ask for it.

## Further Notes

- **Migration of existing users.** On deploy, all existing users get `xp = 0`, `level = 1`, `currentStreak = 0`, `freezesAvailable = 0`. The first chore completion after deploy seeds progression. We do not retro-award XP from `ChoreHistory` because that produces an immediate level inflation that disconnects level from felt accomplishment. Kids start over; the system feels new.
- **Atomicity at chore completion.** Awarding XP, evaluating level-up, updating streak, and inserting `UserBadge` rows all live inside the same Prisma transaction as the chore status update. A failure in progression must roll back the chore completion to avoid the kid seeing a completed chore with no reward.
- **Idempotency on completion.** Completing the same chore twice (e.g., a network retry) must not double-award XP. The chore-completion endpoint already gates on `chore.status` — progression awarding piggybacks on that gate. Tests assert this.
- **Mend cooldown enforcement.** `lastMendAt` lives on `User`; the Mend endpoint compares it against now minus the cooldown (14 days, or 7 at Lvl 10) and returns 429 if too recent. The kid sees a "Mend available in N days" surface that is computed client-side from `mendCooldownRemainingSec` returned by `GET /api/me/progression`.
- **Composability with future extrinsic rewards.** The intrinsic system is designed so that an extrinsic layer can sit on top later: a parent-flippable "this milestone earned a real reward" toggle on level-ups would be a single boolean on the level-up event. The current PRD ships the foundation; extrinsic is a strict superset.
- **Composability with the existing FamilyChallenge.** No interaction in v1. Family challenges remain a parallel, family-shared mechanic. The kid's personal progression and the family's shared challenge progress are independent.
- **Naming.** "Streak Freeze," "Streak Mend," and "Display Title" are user-facing names. Internal identifiers should be stable keys (`STREAK_FREEZE`, `STREAK_MEND`, `DISPLAY_TITLE`) so renames don't break stored data.
