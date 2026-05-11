# Mobile UI/UX Implementation Plan — Kid-First Pass

**Source:** Audit dated 2026-05-09 against `mobile/lib/widgets/streak_card.dart`, `progression_section.dart`, `level_up_modal.dart`, `screens/home/dashboard_screen.dart`, `widgets/shell_screen.dart`, `widgets/dashboard_stats.dart`.
**Persona lens:** Kid/teen first per locked PRD (`PRD-kid-motivation-loop.md`).
**Scope:** Kid progression surfaces + dashboard/shell only. Other screens deferred.

---

## Phase 0 — Pre-flight (½ day)

**Goal:** Don't break anything in flight. Confirm assumptions before touching files.

- [ ] Verify `progressionProvider.currentStreak` and `analytics['currentStreak']` (server `/families/:id/analytics`) compute streaks against the same definition. If they diverge, file a server-side bug before deleting either.
- [ ] Verify light-mode rendering of: `LevelUpModal`, `ProgressionSection` bottom sheet, `StreakCard`. Take screenshots in both modes for diff reference.
- [ ] Update `CLAUDE.md` claim that "lightTheme is aliased to darkTheme" — it's not (audit #26). One-line edit.

**Exit criteria:** Light/dark screenshots of all five files captured; data-source claim confirmed; CLAUDE.md corrected.

---

## Phase 1 — Critical fixes (1 day)

**Goal:** Remove the dashboard's duplicate-streak bug, fix skill-rule violations that block ship, and replace emoji-icons. Low blast radius — small, mechanical changes per file.

### 1.1 Kill duplicate streak chip (audit #1)
- File: `mobile/lib/screens/home/dashboard_screen.dart`
- Remove the inline streak chip in the greeting row (lines 283-299).
- Remove `_streak` state field (line 47), its assignment (line 110, 133), and the `analytics` line in `Future.wait` if `currentStreak` is its only consumer (line 81 — keep the call if other fields used; just stop reading `currentStreak`).
- Sole streak source on the dashboard becomes `StreakCard`.

### 1.2 Replace emoji-as-icon (audit #5)
- `streak_card.dart:118` — replace `Text('\u{1F525}', fontSize: 28)` with `Icon(Icons.local_fire_department_rounded, size: 28, color: AppTheme.accentOrange)`.
- `progression_section.dart:181` — same swap, size 22.
- `progression_section.dart:372` — replace `Text('\u{1F6E1}️')` with `Icon(Icons.shield_rounded, size: 16, color: AppTheme.accentBlue)`.
- `level_up_modal.dart:149` — keep 🎉 (festive moment) but wrap in `Semantics(label: 'Level up celebration', child: ...)`.
- `level_up_modal.dart:245-246` confetti emojis — keep (festive); see Phase 3 for the motion overhaul.

### 1.3 Theme-aware modal & sheet surfaces (audit #9)
- `level_up_modal.dart:136` — replace `color: AppTheme.surface` with `color: Theme.of(context).cardTheme.color ?? AppTheme.surface`.
- `progression_section.dart:105` — same fix on the `showModalBottomSheet(backgroundColor: ...)` call.

### 1.4 Notification badge legibility & a11y (audit #6, #7)
- `shell_screen.dart:84-108` (notification bell):
  - Wrap in `Semantics(label: 'Notifications, $notifCount unread', button: true)`.
  - Bump container from 40×40 to 44×44 (line 87).
- `shell_screen.dart:99-104` (badge dot):
  - Raise badge from 14×14 to 18×18; raise text from `fontSize: 8` to `fontSize: 10`.
- `shell_screen.dart:181-198` (chat tab badge): raise text from 9 → 10; widen `minWidth: 18` → 20 to absorb the larger glyph.

### 1.5 Bar height token (audit #10)
- Add to `mobile/lib/config/theme.dart`:
  ```dart
  static const double barHeightSm = 8;
  static const double barHeightLg = 12;
  ```
- `streak_card.dart:76` `minHeight: 6` → `AppTheme.barHeightSm`.
- `progression_section.dart:239` `minHeight: 12` → `AppTheme.barHeightLg`.

**Exit criteria:** All audit P1 items closed; manual smoke test on iOS + Android; light + dark mode pass; VoiceOver/TalkBack reads notification bell.

---

## Phase 2 — Kid-hero redesign (2-3 days)

**Goal:** Make the kid's progression the unmistakable focal point of the dashboard, and right-size the persona content. This is the highest-leverage phase for engagement.

### 2.1 Reorder dashboard (audit #2)
- `dashboard_screen.dart:220-571` — restructure the ListView:
  1. Greeting block (move from line 268 → top)
  2. Hero `StreakCard` (renamed/expanded, see 2.2)
  3. Pending swap banner (current line 224-249)
  4. "My Tasks" / "Due Soon" / "Done Today" — kid-relevant blocks
  5. `DashboardStats` (family stats — push down or make collapsible)
  6. Insights / Suggestions / Recent Activity (admin-leaning) — at bottom

### 2.2 StreakCard → StreakHero (audit #3, #19)
- File: `mobile/lib/widgets/streak_card.dart`
- New layout (~180pt tall):
  - Top row: large streak number (48pt display), "day streak" label, longest streak chip.
  - Middle row: 7-dot week strip (Mon-Sun) — filled dot for completed day, hollow for missed, ring for today. Pull from `progressionProvider` (add a `weekCompletion: List<bool>` field if not present).
  - Bottom row: XP bar (height `barHeightSm`) + "Lvl X · 30/100 XP" inline label.
- Subtitle line under streak number: proximity hint — `"2 more days to a week!"` (compute next milestone: 7, 14, 30, 60, 100).
- Keep tap → `/profile`.
- Wrap in `AnimatedListItem(index: 0, ...)` (audit #15) when used on dashboard.

### 2.3 Quick-Actions kid pivot (audit #4, #24)
- `dashboard_screen.dart:323-336` — replace 4-tile row:
  - Today's Chores → `/chores?filter=today`
  - My Badges → `/profile#badges` (or scroll-to)
  - Family → `/family`
  - New Chore → `/chores/create` (keep — kids create chores too)
- `_QuickAction` widget (line 606-642): bump icon dot 36 → 44, icon 18 → 22, label fontSize 11 → 12.
- "Members" tile with bare digit removed.

**Exit criteria:** Dashboard fold (top viewport on a 6.1″ phone) shows greeting + hero + first task. Streak hero is unambiguously the dominant element. Week-dot strip renders for users with 0-7 days of history.

---

## Phase 3 — Motion & feedback (1-2 days)

**Goal:** Animations express cause-effect, respect accessibility, and reward the kid for progress.

### 3.1 Animate XP bar (audit #11)
- Wrap `LinearProgressIndicator` in both `streak_card.dart` and `progression_section.dart` with `TweenAnimationBuilder<double>`:
  ```dart
  TweenAnimationBuilder<double>(
    tween: Tween(begin: _previousProgress, end: progress),
    duration: const Duration(milliseconds: 600),
    curve: Curves.easeOutCubic,
    builder: (_, value, __) => LinearProgressIndicator(value: value, ...),
  )
  ```
- Track previous progress in widget state (or via a small `usePrevious` hook).
- Respect `MediaQuery.disableAnimations` — fall through to instant snap.

### 3.2 Confetti rework (audit #8, #12)
- File: `mobile/lib/widgets/level_up_modal.dart`
- In `_LevelUpModalState.initState`: read `MediaQuery.of(context).disableAnimations` (defer to `didChangeDependencies` since `MediaQuery` isn't ready in `initState`).
- If reduced motion is on: skip `_controller.repeat()`, render the modal statically with no confetti painter.
- Otherwise: replace continuous repeat with a one-shot 1200ms burst:
  - Emojis spawn from the level number's center, fly outward with gravity-like easing, fade at the end.
  - `_emojiRainPainter` rewrites: per-emoji `(angle, velocity)` instead of falling rain; opacity tween 1→0 across last 30%.
- Drop emoji `_count` from 40 → 24 to reduce paint cost.

### 3.3 Voice + copy (audit #13, #14)
- `level_up_modal.dart:226` — "Continue" → "Let's go".
- `progression_section.dart:55` — Mend dialog body: "Mending your streak costs 50 XP. You can only do this once every 14 days." → "Spend 50 XP to bring your streak back. You can only do this once every 14 days."
- `progression_section.dart:55` — Mend confirm button: "Mend (-50 XP)" → "Spend 50 XP".
- `progression_section.dart:404` — main CTA "Save your streak — 50 XP" stays (already kid-voiced).

### 3.4 Title-edit affordance (audit #16)
- `progression_section.dart:268-274` — replace the size-16 IconButton with a `TextButton.icon`:
  ```dart
  TextButton.icon(
    onPressed: state.level >= 5 ? _showSetTitleSheet : null,
    icon: const Icon(Icons.edit_rounded, size: 18),
    label: const Text('Change'),
  )
  ```

**Exit criteria:** XP bar fills smoothly when a chore is completed; confetti respects reduced motion; level-up modal shows a one-shot burst; all CTAs use kid-voice.

---

## Phase 4 — Progression restructure (2 days)

**Goal:** Break the 550-line single-Column wall in `ProgressionSection` into grouped, scannable cards.

### 4.1 Three-card layout (audit #17)
- File: `mobile/lib/widgets/progression_section.dart`
- Refactor `_ProgressionSectionState.build` into three child widgets:
  - `_ThisWeekCard` — streak header + week dots (extracted from new StreakHero) + XP bar.
  - `_CollectionCard` — display title row + badges grid.
  - `_UnlocksCard` — unlock ladder + freeze chip + Mend CTA + Set Title CTA.
- Each card uses the existing pattern: `Container` with `Theme.of(context).cardTheme.color`, `radiusL`, `borderSubtle(context)`.
- Inter-card spacing: `spaceM` (16pt). Intra-card spacing: `spaceS` (8pt) between rows.
- Each card wrapped in `AnimatedListItem` for staggered entrance.

### 4.2 "Profile" tab → "Me" rename (audit #22)
- `mobile/lib/widgets/shell_screen.dart:25` — change label `'Profile'` → `'Me'`.
- Verify nothing else hard-codes the string `"Profile"` in nav: `grep -rn "Profile" mobile/lib/widgets mobile/lib/app.dart`.
- Route path stays `/profile` (don't break deep links / FCM payloads).

### 4.3 Bottom-nav inactive contrast (audit #21)
- `shell_screen.dart:154` `opacity: isSelected ? 1.0 : 0.4` → bump inactive opacity to 0.55.
- Verify against WCAG 3:1 non-text contrast in both themes using a contrast checker.

**Exit criteria:** Profile screen progression area is three distinct cards; tab labeled "Me"; bottom-nav inactive icons clearly readable in light + dark.

---

## Phase 5 — Polish & cleanup (1 day)

**Goal:** Small wins that are independently low-risk.

- [ ] **Audit #23** — Drop `margin: fromLTRB(16, 8, 16, 0)` on the swap-request banner (`dashboard_screen.dart:228`); rely on parent ListView's `fromLTRB(20, 16, 20, 100)`.
- [ ] **Audit #25** — In dashboard chore-toggle handlers (lines 429-430, 545-546), drop the explicit `await _loadDashboardData()`; rely on `choreProvider`'s reactivity. Keep one path (pull-to-refresh) that does a full reload.
- [ ] **Audit #18** *(optional)* — Make ladder rows tappable: tap a locked row → bottom sheet "How to unlock Lvl X". Defer if scope tight.
- [ ] **Audit #20** — Note `freeze${plural}` for future i18n; no fix yet.
- [ ] Re-run the audit checklist in the skill (Pre-Delivery Checklist § Visual Quality / Interaction / Light-Dark Mode / Layout / Accessibility) against the changed surfaces.

**Exit criteria:** All P3 items closed except #18 (deferred). Dashboard reload no longer fires on every chore toggle.

---

## Phase sequencing & risk

| Phase | Files touched | Risk | Independently shippable? |
|-------|---------------|------|--------------------------|
| 0 | `CLAUDE.md`, screenshots only | none | yes |
| 1 | 4 widgets, 1 screen, 1 theme | low (mechanical) | yes |
| 2 | 1 screen, 1 widget, optional new field on provider | medium (visual change) | yes |
| 3 | 2 widgets, 1 dialog | low | yes |
| 4 | 1 widget refactor, 1 shell rename | medium (refactor) | yes |
| 5 | 1 screen, 1 widget | low | yes |

Phases are independent — any order works, but **1 → 2 → 3** delivers the most visible kid-engagement lift.

## Out of scope

- Other screens (chores list, chat, family, auth, onboarding, analytics).
- Backend changes — except possibly adding `weekCompletion` to the `/me/progression` payload for Phase 2.2's week-dot strip.
- Chart/analytics surfaces.
- A new "Me" tab as a top-level destination (PRD-deferred).
- Per-family configurable thresholds (PRD-deferred).
