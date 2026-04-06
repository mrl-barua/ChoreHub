# Project Knowledge — ChoreHub

> Upload this to your Claude Project knowledge base. Update when architecture changes significantly.

## What This Project Is
ChoreHub is a family chore management mobile app where households create, assign, and track chores with real-time chat, analytics dashboards, gamification (challenges and streaks), and offline-first data sync. The app targets families who want to coordinate household responsibilities.

## Tech Stack (Quick Reference)
- **Backend:** Node.js, Express 5.2.1, Prisma 5.22, PostgreSQL, Socket.IO 4.8.3
- **Frontend:** Flutter (Dart ^3.8.1), Riverpod 3.x, GoRouter 17, Dio 5.x, SQLite (sqflite)
- **Auth:** JWT — 15m access tokens, 7d refresh tokens, bcryptjs for password hashing
- **Real-time:** Socket.IO for chat messaging, typing indicators, reactions, read receipts
- **Deployment:** Development-only (no Docker/CI) — Express on localhost:3000, Flutter on device/emulator

## How I Work in This Codebase
When I (Claude) help with this project:

### Backend Tasks
- Route handlers go in `server/src/routes/<resource>.ts` — business logic lives directly in handlers (no controller/service separation)
- Mount new routers in `server/src/index.ts` with `app.use('/api/<path>', authenticate, router)`
- Always verify family membership in route handlers before allowing data access
- Use try/catch per handler with `console.error` + 500 response
- Validate request fields manually (no zod/joi in this project)
- Run `npx prisma generate` after any `schema.prisma` changes
- Use selective `select` in Prisma queries — don't return full model objects with passwords

### Flutter Tasks
- Screens are `ConsumerStatefulWidget`, placed in `lib/screens/<feature>/`
- Follow the Riverpod `NotifierProvider` pattern: state class (with `copyWith`) + notifier class + provider declaration
- API calls go through `ApiClient().dio` inside provider notifier methods
- Register new routes in `lib/app.dart` GoRouter config
- Use `AppTheme.*` static members for colors/typography — not `Theme.of(context)` for custom values
- Store sensitive data in `flutter_secure_storage`, never `SharedPreferences`
- Socket events flow through `SocketService` singleton → consumed in providers via `StreamController` streams

### Critical Rules
- Always run `npm run db:generate` after schema changes (Prisma client must match schema)
- Update `ApiConfig.baseUrl` in `lib/config/api_config.dart` when server IP changes
- Socket.IO URL is the base URL without `/api` suffix
- All models should extend `Equatable` and include `fromJson`/`toJson`/`copyWith`
- Providers must watch `authProvider` and reload data on auth state changes

## Data Model Summary
| Model | What It Represents |
|-------|--------------------|
| **User** | Registered user with username, email, hashed password, optional avatar |
| **Family** | Household group that users belong to |
| **FamilyMember** | User-family membership with role (member or admin) |
| **Invitation** | Pending/accepted/declined request to join a family |
| **Chore** | Task with title, category, priority, status, optional assignment and due date |
| **ChoreHistory** | Audit log entry for chore lifecycle events (created, assigned, completed, etc.) |
| **ChoreComment** | Comment on a chore (schema only — no API routes yet) |
| **Message** | Chat message with optional chore attachment, @mentions, replies, image, reactions |
| **MessageReadReceipt** | Tracks which users have read which messages |
| **FamilyChallenge** | Gamification challenge with target count and progress |
| **ChoreSwapRequest** | Request to swap chore assignment between users (schema only — no routes yet) |
| **Notification** | In-app notification with type, title, body, and read status |

## Key Files to Know
| File | Purpose |
|------|---------|
| `server/prisma/schema.prisma` | Single source of truth for all 13 data models |
| `server/src/index.ts` | Server entry — middleware stack, Socket.IO setup, all route mounting |
| `server/src/middleware/auth.ts` | JWT verification middleware (`authenticate` function) |
| `server/src/routes/auth.ts` | Registration, login, token refresh endpoints |
| `server/src/routes/chores.ts` | Chore CRUD, assignment, completion, analytics, history |
| `server/src/routes/families.ts` | Family CRUD, member management, weekly summary, challenges |
| `server/src/routes/messages.ts` | Message history (REST), image upload, unread count |
| `server/src/routes/sync.ts` | Offline-first pull/push sync endpoints |
| `server/src/services/notification.ts` | Helper function to create notification records |
| `mobile/lib/main.dart` | App entry — ConnectivityService init, ProviderScope |
| `mobile/lib/app.dart` | GoRouter config, auth redirect, all route definitions |
| `mobile/lib/config/api_config.dart` | API base URL and timeout configuration |
| `mobile/lib/config/theme.dart` | AppTheme — dark color palette, typography, shadows, radii |
| `mobile/lib/services/api_client.dart` | Dio singleton — token interceptor, auto-refresh on 401 |
| `mobile/lib/services/socket_service.dart` | Socket.IO singleton — event streams for real-time chat |
| `mobile/lib/services/auth_service.dart` | Auth API calls + local user persistence |
| `mobile/lib/providers/auth_provider.dart` | Auth state management — login, register, logout, token lifecycle |
| `mobile/lib/providers/chore_provider.dart` | Chore state — CRUD, filtering, sorting, search, stats |
| `mobile/lib/providers/message_provider.dart` | Message state — socket+REST hybrid, reactions, typing, read receipts |
| `mobile/lib/providers/family_provider.dart` | Family state — families list, current family, members, stats |
| `mobile/lib/db/database_helper.dart` | SQLite singleton — schema creation, migrations v1–v8 |
| `mobile/lib/db/schema.dart` | All CREATE TABLE and ALTER TABLE migration scripts |

## Current Known Issues / Tech Debt
- **ChoreComment routes missing:** Model exists in Prisma schema but no API endpoints are implemented
- **ChoreSwapRequest routes missing:** Model exists in Prisma schema but no API endpoints are implemented
- **No request validation library:** All validation is manual field checking — error-prone for complex inputs
- **No global error middleware:** Each route handler has its own try/catch — inconsistent error responses possible
- **CORS wide open:** Both Express CORS and Socket.IO CORS accept all origins (`*`)
- **CORS_ORIGINS unused:** The env var is defined but never read by the CORS middleware configuration
- **No light theme:** `lightTheme` in `theme.dart` is aliased to `darkTheme` — only dark mode works
- **No .env.example:** New developers must guess or read code to know required environment variables
- **No Docker/CI:** No containerization or continuous integration pipeline
- **No automated tests:** Neither backend nor frontend have any test files
- **JSON as strings:** Reactions, mentions, and notification data are stored as JSON strings in the database — no structured validation
- **No rate limiting:** API endpoints have no rate limiting or abuse protection
- **Hardcoded secrets in .env:** Development secrets committed (should be rotated for production)

## Workflow Reminders
- **Adding a Prisma model:** Edit `schema.prisma` → `npm run db:migrate` → `npm run db:generate` → create route file in `server/src/routes/` → mount in `index.ts` → create Flutter model in `lib/models/` → create provider in `lib/providers/` → create screen in `lib/screens/`
- **Adding a Flutter screen:** Create `lib/screens/<feature>/<name>_screen.dart` (ConsumerStatefulWidget) → add GoRoute in `lib/app.dart` → create/update provider if new state needed → add navigation from existing screens
- **Adding a Socket.IO event:** Add handler in `server/src/index.ts` socket connection block → add emit/listen methods in `mobile/lib/services/socket_service.dart` → consume stream in relevant provider
- **Modifying the database:** Edit `schema.prisma` → `npm run db:migrate` (creates migration) → `npm run db:generate` (updates client) → update Flutter SQLite schema in `lib/db/schema.dart` → bump DB version in `database_helper.dart`
