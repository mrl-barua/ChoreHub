# Conventions

## General
- **Backend language:** TypeScript (strict mode enabled in `tsconfig.json`)
- **Frontend language:** Dart (SDK ^3.8.1)
- **Backend formatting:** No Prettier or formatter config found — follow standard TypeScript conventions
- **Frontend linting:** `flutter_lints` 5.0.0 (standard Dart lint rules)
- **Frontend formatting:** `dart format` (default line length)

---

## Backend Conventions

### Naming
| Element | Convention | Example |
|---------|-----------|---------|
| Files | camelCase | `auth.ts`, `notification.ts` |
| Classes/Interfaces | PascalCase | `AuthRequest` |
| Variables/functions | camelCase | `accessToken`, `authenticate` |
| Route paths | kebab-case (plural nouns) | `/api/families`, `/api/chores` |
| Prisma models | PascalCase (singular) | `User`, `FamilyMember`, `ChoreHistory` |
| Prisma fields | camelCase | `familyId`, `assignedTo`, `createdAt` |
| Environment vars | UPPER_SNAKE_CASE | `JWT_SECRET`, `DATABASE_URL` |

### Route Patterns
- RESTful conventions: `GET /resource`, `POST /resource`, `PATCH /resource/:id`, `DELETE /resource/:id`
- All routes mounted under `/api/` prefix — no API versioning
- Auth middleware (`authenticate`) applied per-router at mount time in `index.ts`, not globally
- Auth routes (`/api/auth`) are the only unprotected routes
- Query parameters for filtering: `?familyId=<id>`, `?before=<date>`, `?limit=50`, `?search=<query>`

### Architecture Pattern
- **No controller/service separation** — route handlers contain business logic and Prisma queries directly
- Single exception: `services/notification.ts` is a helper function for creating notification records
- Each route file exports an Express `Router` that is mounted in `index.ts`
- Family membership is verified inline in route handlers before allowing operations

### Error Handling
- **Per-handler try/catch** — each route handler wraps its logic in try/catch
- No global error handling middleware
- No custom error classes
- Pattern:
  ```typescript
  try {
    // Validation → Business logic → Prisma query → Response
    res.status(200).json(result);
  } catch (error) {
    console.error('Descriptive context:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
  ```
- **HTTP status codes used:** 200 (OK), 201 (Created), 400 (Bad Request), 401 (Unauthorized), 403 (Forbidden), 404 (Not Found), 409 (Conflict), 500 (Internal Server Error)
- **Validation:** Manual field checks at the start of route handlers — no validation library (zod, joi, etc.)

### Prisma Usage
- All IDs are UUIDs via `@default(uuid())`
- Timestamps via `@default(now())` and `@updatedAt`
- Cascade deletes on `FamilyMember` and `Chore` when parent `Family` is deleted
- JSON data stored as `String` fields (reactions, mentions, notification data) — parsed/stringified in application code
- No `$transaction` usage observed — multi-step operations are sequential
- Selective field returns using `select` in Prisma queries for API responses

### File Uploads
- **Multer** with disk storage to `uploads/` directory
- Avatars: 5MB limit, stored as `avatar-<userId>-<timestamp>.<ext>`
- Message images: 10MB limit, image MIME types only, stored as `msg-<timestamp>.<ext>`
- Served statically via `express.static('uploads')`

---

## Flutter Conventions

### Naming
| Element | Convention | Example |
|---------|-----------|---------|
| Files | snake_case | `chore_provider.dart`, `chat_screen.dart` |
| Classes/Widgets | PascalCase | `ChoreNotifier`, `DashboardScreen` |
| Variables/methods | camelCase | `loadChores`, `currentFamily` |
| Constants | camelCase (no k prefix) | `accent`, `radiusM` |
| Providers | camelCase with `Provider` suffix | `choreProvider`, `authProvider` |
| Notifiers | PascalCase with `Notifier` suffix | `ChoreNotifier`, `AuthNotifier` |
| State classes | PascalCase with `State` suffix | `ChoreState`, `AuthState` |

### Widget Structure
- **Screens** use `ConsumerStatefulWidget` (for `ref` access and lifecycle methods like `initState`)
- **Reusable widgets** use `ConsumerWidget` (when they need `ref`) or `StatelessWidget` (when they don't)
- `StatefulWidget` without Consumer is not used — all stateful widgets that need provider access extend `ConsumerStatefulWidget`

### State Management Pattern (Riverpod)
```
Provider Declaration:
  final choreProvider = NotifierProvider<ChoreNotifier, ChoreState>(() => ChoreNotifier());

State Class (immutable):
  class ChoreState {
    final List<Chore> chores;
    final String filter;
    final bool isLoading;
    final String? error;
    ChoreState copyWith({...});  // Immutable updates
  }

Notifier Class (business logic):
  class ChoreNotifier extends Notifier<ChoreState> {
    @override
    ChoreState build() { ... }  // Initial state + data loading
    Future<void> loadChores() { ... }
    Future<void> createChore(...) { ... }
  }

Widget Usage:
  final state = ref.watch(choreProvider);           // Subscribe to state
  ref.read(choreProvider.notifier).loadChores();    // Call methods
  ref.listen(authProvider, (prev, next) { ... });   // React to changes
```

- Providers watch `authProvider` — data reloads on auth state changes
- Cross-provider deps via `ref.watch()` inside `build()` method
- `ref.invalidate()` used on logout to reset all providers

### API Call Pattern
- Providers call `ApiClient().dio` methods directly (no separate repository layer for API calls)
- Response JSON parsed into model objects using `Model.fromJson()`
- State updated via `state = state.copyWith(isLoading: false, data: result)`
- Errors caught in providers, stored in state as `error` string, surfaced to UI via snackbars
- Loading states managed with `isLoading` flag in state classes

### Model Pattern
- All models extend `Equatable` for value equality (except `ChoreComment`)
- Models have `fromJson()`, `toJson()`, `fromMap()`, `toMap()` factory methods
- `copyWith()` for immutable updates
- `syncStatus` field on models that support offline storage (`'pending'` / `'synced'`)

### Folder Placement
| What | Where |
|------|-------|
| New screen | `lib/screens/<feature>/<name>_screen.dart` |
| New reusable widget | `lib/widgets/<name>.dart` or `lib/widgets/<category>/<name>.dart` |
| New model | `lib/models/<name>.dart` |
| New provider | `lib/providers/<name>_provider.dart` |
| New service | `lib/services/<name>_service.dart` or `lib/services/<name>.dart` |
| New repository | `lib/repositories/<name>_repository.dart` |
| New config/constant | `lib/config/<name>.dart` or `lib/constants/<name>.dart` |

### Navigation Pattern
- Routes defined in `lib/app.dart` using GoRouter
- Shell routes (with bottom nav): `/dashboard`, `/chores`, `/chat`, `/family`, `/profile`
- Modal routes (slide-up, no bottom nav): `/chores/create`, `/chores/:id`, `/family/invite`, etc.
- Navigation via `context.go('/path')` or `context.push('/path')`
- Path parameters for IDs: `/chores/:id`, `/family/member/:userId`
- Query parameters for pre-fill: `/chores/create?title=X&category=Y`

### Theming
- Single dark theme defined in `lib/config/theme.dart` via `AppTheme` class
- Colors accessed as static members: `AppTheme.accent`, `AppTheme.surface`, `AppTheme.textPrimary`
- No `Theme.of(context)` for custom colors — use `AppTheme.*` directly
- Category-specific colors via `AppTheme.categoryColors` map

---

## Git Conventions
- **Branch:** `main` (single branch observed)
- **Commit style:** Conventional Commits — `feat:`, `fix:`, `refactor:`, `docs:` prefixes
- **Examples from history:**
  - `feat: add family challenges and notifications features`
  - `fix: stop animation in empty state when widget is deactivated`
  - `refactor: simplify chore card animation handling`
  - `docs: comprehensive README with setup guide and API reference`
- **No CI/CD** pipeline or pre-commit hooks configured
