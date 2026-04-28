# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
ChoreHub is a family chore management mobile app with real-time chat, analytics dashboards, gamification (challenges and streaks), and offline-first sync. Families create and assign chores, track completion, communicate via in-app messaging, and compete through challenges.

## Repo Structure
Monorepo with two top-level directories:
```
ChoreHub/
├── server/       # Express.js + Prisma backend (REST API + Socket.IO)
├── mobile/       # Flutter mobile app (Android/iOS)
```

## Commands

### Backend (`server/`)
```bash
npm install
npm run dev           # Start dev server with ts-node-dev (port 3000)
npm run build         # Compile TypeScript to dist/
npm run start         # Run compiled server
npm run db:migrate    # Run Prisma migrations
npm run db:generate   # Generate Prisma client (required after schema changes)
```

### Flutter (`mobile/`)
```bash
flutter pub get
flutter run
flutter analyze       # Run Dart linter (flutter_lints)
flutter test          # Run all tests
flutter test test/widget_test.dart  # Run a single test file
```

## Environment Variables (`server/.env`)

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string (e.g., `postgresql://user:pass@localhost:5432/chorehub?schema=public`) | Yes |
| `JWT_SECRET` | Secret key for signing access tokens (15m expiry) | Yes |
| `JWT_REFRESH_SECRET` | Secret key for signing refresh tokens (7d expiry) | Yes |
| `PORT` | Server port (default: `3000`) | No |

## Key Workflows

- **Adding a new API endpoint:** Create route handler in `server/src/routes/<resource>.ts` → import `authenticate` middleware from `../middleware/auth` → add router methods → mount router in `server/src/index.ts` with `app.use('/api/<resource>', authenticate, <resource>Routes)`
- **Adding a new Flutter screen:** Create `mobile/lib/screens/<feature>/<name>_screen.dart` as `ConsumerStatefulWidget` → add `GoRoute` in `mobile/lib/app.dart` → create or update `NotifierProvider` in `mobile/lib/providers/` if new state is needed
- **Running DB migrations:** `cd server && npm run db:migrate`
- **Generating Prisma client:** `cd server && npm run db:generate`

## Architecture

### Backend
Route handlers in `server/src/routes/` contain business logic directly — there is no separate controller layer. Manual field validation is used everywhere (no zod/joi). Family membership is verified inline in each route handler that requires it.

All routes are mounted in `server/src/index.ts` under `/api/` with `authenticate` middleware applied per-router (except `/api/auth` and `/api/health`). Static file uploads are served from `/uploads/`.

Socket.IO runs on the same HTTP server. Auth uses `socket.handshake.auth.token` (JWT). Clients auto-join `family:<familyId>` rooms. Primary real-time events: `send_message`/`new_message`, `toggle_reaction`/`reaction_updated`, `mark_read`/`messages_read`, `typing`/`stop_typing`.

**Unimplemented:** `ChoreComment` and `ChoreSwapRequest` models exist in `server/prisma/schema.prisma` but have no API routes yet.

### Flutter State Management (Riverpod)
All state lives in `NotifierProvider` classes under `mobile/lib/providers/`. The canonical pattern:

```dart
class ChoreState { final List<Chore> chores; final bool isLoading; final String? error; }
class ChoreNotifier extends Notifier<ChoreState> {
  @override ChoreState build() { ... }   // initial state + data fetch
}
final choreProvider = NotifierProvider<ChoreNotifier, ChoreState>(ChoreNotifier.new);
```

All providers watch `authProvider` so data reloads on auth changes. `ref.invalidate()` in logout resets all providers. Cross-provider dependencies use `ref.watch()` inside `build()`.

### Offline-First Sync
SQLite (sqflite, `mobile/lib/db/`) stores a local mirror of chores, messages, families, and invitations. `mobile/lib/repositories/` provides the data access layer for SQLite. `ConnectivityService` exposes an online/offline stream; `connectivity_provider.dart` wraps it as a `StreamProvider<bool>`. The sync endpoints `GET /api/sync/pull` and `POST /api/sync/push` reconcile local and server state.

### Authentication Flow
`ApiClient` (`mobile/lib/services/api_client.dart`) is a Dio singleton with an interceptor that:
1. Attaches the Bearer access token from `FlutterSecureStorage` to every request
2. On 401: attempts token refresh via `POST /api/auth/refresh`
3. On refresh success: retries the original request
4. On refresh failure: clears all tokens and invalidates all providers

Access tokens expire in 15 minutes; refresh tokens expire in 7 days.

### Navigation
GoRouter with a shell route (`mobile/lib/widgets/shell_screen.dart`) providing 5-tab bottom navigation: Dashboard, Chores, Chat, Family, Profile. Auth guard in `mobile/lib/app.dart` redirects unauthenticated users to `/login` and authenticated users on auth routes to `/dashboard`.

### Theming
Dark theme only — `lightTheme` is aliased to `darkTheme` in `mobile/lib/config/theme.dart`. Use `AppTheme.*` static members for custom colors, **not** `Theme.of(context).colorScheme` for app-specific design tokens.

## Common Pitfalls

- **Prisma generate required:** Run `npx prisma generate` after any `schema.prisma` change.
- **API base URL:** `ApiConfig.baseUrl` defaults to `http://192.168.1.54:3000/api` — update in `mobile/lib/config/api_config.dart` per environment.
- **Socket.IO URL:** Client connects to the base URL *without* the `/api` suffix.
- **No .env.example:** Create `server/.env` manually using the table above.
- **CORS wide open:** Socket.IO CORS is `origin: '*'` — restrict before production.
- **No validation library:** Add manual field checks in every new route handler.

## Reference Files
- Architecture: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Conventions: [`CONVENTIONS.md`](CONVENTIONS.md)
- Claude Project Knowledge: [`PROJECT_KNOWLEDGE.md`](PROJECT_KNOWLEDGE.md)

---

## Flutter Coding Standards

These are non-negotiable patterns enforced across the entire codebase.

### API Client
- Never instantiate `ApiClient()` or `Dio()` inline inside a widget or method
- Always use the shared singleton or injected instance
- ✅ `_apiClient.dio.get(...)` via service class
- ❌ `ApiClient().dio.get(...)` inside a widget

### Service Layer
- All API calls must live in a service class under `lib/services/`
- Widgets and providers must never call `dio` directly
- Service methods must return typed models or throw meaningful exceptions
- One service per domain: `ChoreService`, `FamilyService`, `UserService`, `MessageService`, `NotificationService`
- ✅ `await _choreService.toggleStatus(choreId, chore.isDone)`
- ❌ `await _apiClient.dio.patch('/chores/$choreId', data: {...})`

### Error Handling
- Every `async` operation wrapped in try/catch must set a visible error state
- Never catch and only `debugPrint` — the UI must be able to react to failures
- Always `return` early after setting error state — never fall through to success handling
- ❌ `catch (e) { debugPrint(e.toString()); }`
- ❌ `catch (_) {}`

### setState
- Always use `if (mounted)` guard before any `setState` call in async methods
- Always expand multi-field `setState` — never inline multiple assignments on one line
- ❌ `setState(() { _x = x; _y = y; });` on one line

### Business Logic in API Calls
- Never place ternaries, conditionals, or `.map()` transforms inside `data: {}` or `queryParameters: {}` passed to dio
- Always resolve to a named variable first
- ✅ `final newStatus = isDone ? 'pending' : 'done'; dio.patch(...)`
- ❌ `dio.patch(..., data: {'status': chore.isDone ? 'pending' : 'done'})`

### DRY
- Status strings, priority strings → `lib/constants/chore_constants.dart`
- Category icons, priority colors, history colors → `lib/utils/category_helpers.dart`
- Date formatting, time ago, date parsing → `lib/utils/date_helpers.dart`

### SOLID Principles

**Single Responsibility:** Widgets handle UI only — no formatting logic, no direct API calls.

**Open/Closed:** Use enums or constant classes instead of growing if/switch chains.
- ✅ `ChoreStatus.done` from constants
- ❌ `'done'` string literal scattered across multiple files

**Dependency Inversion:** Services are class-level fields, never instantiated inside callbacks.
- ✅ `final ChoreService _choreService = ChoreService(ApiClient());` as a class field
- ❌ `final service = ChoreService(ApiClient());` inside a button callback

### Adding New Features Checklist
- [ ] API call goes in the appropriate service class in `lib/services/`
- [ ] Widget only calls the service method, not dio directly
- [ ] Both success and error states are handled and visible in the UI
- [ ] `setState` is guarded with `if (mounted)` and expanded multi-line
- [ ] No business logic lives inside `data: {}` parameters
- [ ] No string literals duplicated — use constants from `lib/constants/`
- [ ] Shared helpers used: `CategoryHelpers`, `DateHelpers` from `lib/utils/`

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
