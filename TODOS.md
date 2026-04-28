# TODOS

## Phase 2 — AI Insights (after Phase 1 ships and is used)

### [x] ChoreHistory composite index
Added `@@index([familyId, action, createdAt])` to `ChoreHistory` in `server/prisma/schema.prisma`.
**Action required:** Run `cd server && npm run db:migrate` to apply the migration.

---

### [x] Tap-to-reschedule (timing suggestions)
Implemented:
- `PATCH /api/families/:id/chores/:choreId/reschedule` in `server/src/routes/families.ts` — computes next occurrence of suggested weekday+hour, updates `Chore.dueDate`
- `choreId` field added to `TimingPatternResult` (server) and `TimingSuggestion` (Flutter model)
- `InsightsService.rescheduleChore(familyId, choreId, dayOfWeek, hour)` in `mobile/lib/services/insights_service.dart`
- `InsightsCard` accepts optional `onReschedule` callback; timing rows show a chevron and are tappable when callback is present
- `_DashboardScreenState._onReschedule` calls the service and shows a SnackBar for success/failure

---

### [ ] Drift alert push notification
**What:** When `detectDriftAlerts` returns results, call `notification.ts` to create an in-app notification (and eventually FCM push). At most once per member per week to avoid fatigue.
**Why:** Drift alerts currently only appear when the user opens the app and views the dashboard. A proactive notification would surface the issue before it becomes a household argument.
**Pros:** `notification.ts` service already exists. This is the "Approach C" direction from the design session: smart contextual notifications that know the family's patterns.
**Cons:** Requires the insights detection to run on a schedule (or be triggered on a smart event), not just at GET request time. Notification frequency throttling needed.
**Context:** Validated by the landscape research (MIT Tech Review). Best implemented after Phase 1 confirms users find drift alerts valuable.
**Depends on:** Phase 1 ships; drift alerts validated as useful.
