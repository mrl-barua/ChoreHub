# CLAUDE.md
> Auto-generated context file. Keep this updated as the project evolves.

## Project Overview
ChoreHub is a family chore management mobile app with real-time chat, analytics dashboards, gamification (challenges and streaks), and offline-first sync. Families create and assign chores, track completion, communicate via in-app messaging, and compete through challenges.

## Repo Structure
Monorepo with two top-level directories:
```
ChoreHub/
├── server/       # Express.js + Prisma backend (REST API + Socket.IO)
├── mobile/       # Flutter mobile app (Android/iOS)
├── CLAUDE.md
├── ARCHITECTURE.md
├── CONVENTIONS.md
├── PROJECT_KNOWLEDGE.md
└── README.md
```

## Quick Start

### Backend
```bash
cd server
npm install
# Create .env file with required variables (see Environment Variables below)
npm run db:migrate    # Run Prisma migrations
npm run db:generate   # Generate Prisma client
npm run dev           # Start dev server (ts-node-dev, port 3000)
```

### Flutter
```bash
cd mobile
flutter pub get
# Update API base URL in lib/config/api_config.dart to match your server IP
flutter run
```

## Key Workflows

- **Adding a new API endpoint:** Create route handler in `server/src/routes/<resource>.ts` → import `authenticate` middleware from `../middleware/auth` → add router methods → mount router in `server/src/index.ts` with `app.use('/api/<resource>', authenticate, <resource>Routes)`
- **Adding a new Flutter screen:** Create `mobile/lib/screens/<feature>/<name>_screen.dart` as `ConsumerStatefulWidget` → add `GoRoute` in `mobile/lib/app.dart` → create or update `NotifierProvider` in `mobile/lib/providers/` if new state is needed
- **Running DB migrations:** `cd server && npm run db:migrate`
- **Generating Prisma client:** `cd server && npm run db:generate`

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string (e.g., `postgresql://user:pass@localhost:5432/chorehub?schema=public`) | Yes |
| `JWT_SECRET` | Secret key for signing access tokens (15m expiry) | Yes |
| `JWT_REFRESH_SECRET` | Secret key for signing refresh tokens (7d expiry) | Yes |
| `PORT` | Server port (default: `3000`) | No |
| `CORS_ORIGINS` | Allowed CORS origins (currently unused in middleware — CORS defaults to `*`) | No |

## Common Pitfalls

- **Prisma generate required:** Must run `npx prisma generate` after any changes to `server/prisma/schema.prisma`, otherwise the Prisma client will be out of sync.
- **API base URL:** Flutter app's `ApiConfig.baseUrl` defaults to `http://192.168.1.54:3000/api` — update this in `mobile/lib/config/api_config.dart` to match your server's LAN IP.
- **Socket.IO URL:** The Socket.IO client connects to the base URL *without* the `/api` suffix (e.g., `http://192.168.1.54:3000`).
- **No .env.example:** There is no `.env.example` file — you must create `server/.env` manually with the variables above.
- **CORS wide open:** Socket.IO CORS is set to `origin: '*'` — restrict this before deploying to production.
- **Dark mode only:** `lightTheme` is aliased to `darkTheme` in `mobile/lib/config/theme.dart` — only a dark theme is implemented.
- **No validation library:** Backend uses manual field validation in route handlers (no zod/joi) — be thorough when adding new endpoints.

## Reference Files
- Architecture: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Conventions: [`CONVENTIONS.md`](CONVENTIONS.md)
- Claude Project Knowledge: [`PROJECT_KNOWLEDGE.md`](PROJECT_KNOWLEDGE.md)

---

## Flutter Coding Standards

These are non-negotiable patterns enforced across the entire codebase.
All contributors and AI tools must follow these when writing or modifying Flutter code.

---

### API Client
- Never instantiate `ApiClient()` or `Dio()` inline inside a widget or method
- Always use the shared singleton or injected instance
- ✅ `_apiClient.dio.get(...)` via service class
- ❌ `ApiClient().dio.get(...)` inside a widget

---

### Service Layer
- All API calls (`dio.get`, `dio.post`, `dio.patch`, etc.) must live in a service class under `lib/services/`
- Widgets and providers must never call `dio` directly
- Service methods must return typed models or throw meaningful exceptions
- One service per domain: `ChoreService`, `FamilyService`, `UserService`, `MessageService`, `NotificationService`
- ✅ `await _choreService.toggleStatus(choreId, chore.isDone)`
- ❌ `await _apiClient.dio.patch('/chores/$choreId', data: {...})`

---

### Error Handling
- Every `async` operation wrapped in try/catch must set a visible error state
- Never catch and only `debugPrint` — the UI must be able to react to failures
- Always `return` early after setting error state — never fall through to success handling
- ✅ Set `_error`, call `setState`, then `return`
- ❌ `catch (e) { debugPrint(e.toString()); }`
- ❌ `catch (_) {}`

---

### setState
- Always use `if (mounted)` guard before any `setState` call in async methods
- Always expand multi-field `setState` — never inline multiple assignments on one line
- ✅ Multi-line expanded `setState` block
- ❌ `setState(() { _x = x; _y = y; });` on one line

---

### Business Logic in API Calls
- Never place ternaries, conditionals, or `.map()` transforms inside `data: {}` or `queryParameters: {}` passed to dio
- Always resolve to a named variable first
- ✅ `final newStatus = isDone ? 'pending' : 'done'; dio.patch(...)`
- ❌ `dio.patch(..., data: {'status': chore.isDone ? 'pending' : 'done'})`

---

### Comments
- Do not write comments that restate what the code already clearly says
- Do not leave commented-out dead code in the codebase
- Do not leave TODO comments without an owner, ticket reference, or deadline
- If you feel the need to comment what a method does, rename the method instead
- ✅ Comments that explain WHY — non-obvious decisions, workarounds, business rules
- ❌ `// Set loading to true` above `setState(() { _isLoading = true; })`
- ❌ Section markers like `// Header`, `// Stats`, `// Members section`

---

### DRY — Don't Repeat Yourself
- If the same logic appears in more than one place, extract it
- Status strings, priority strings → `lib/constants/chore_constants.dart`
- Category icons, priority colors, history colors → `lib/utils/category_helpers.dart`
- Date formatting, time ago, date parsing → `lib/utils/date_helpers.dart`
- ✅ `CategoryHelpers.iconFor(category)` from shared utility
- ❌ Same `switch (category)` block copied in 4 files

---

### SOLID Principles

**Single Responsibility**
- Each class has one reason to change
- Widgets handle UI only — no formatting logic, no direct API calls
- Formatting, date transforms, and string mapping go in extensions or utils

**Open/Closed**
- Use enums or constant classes instead of growing if/switch chains
- New statuses, types, or categories should not require editing existing methods
- ✅ `ChoreStatus.done` from constants
- ❌ `'done'` string literal scattered across multiple files

**Dependency Inversion**
- Services are injected into consumers — never instantiated inline inside widget callbacks
- ✅ `final ChoreService _choreService = ChoreService(ApiClient());` as a class field
- ❌ `final service = ChoreService(ApiClient());` inside a button callback

---

### Adding New Features Checklist
When adding any new feature that involves an API call:
- [ ] API call goes in the appropriate service class in `lib/services/`
- [ ] Widget only calls the service method, not dio directly
- [ ] Both success and error states are handled and visible in the UI
- [ ] `setState` is guarded with `if (mounted)` and expanded multi-line
- [ ] No business logic lives inside `data: {}` parameters
- [ ] No unnecessary comments — code is self-explanatory or explains WHY
- [ ] No string literals duplicated — use constants from `lib/constants/`
- [ ] No logic duplicated from an existing utility or service
- [ ] Shared helpers used: `CategoryHelpers`, `DateHelpers` from `lib/utils/`
