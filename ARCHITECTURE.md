# Architecture

## System Overview

```
┌─────────────────┐         ┌──────────────────────────┐         ┌────────────────┐
│                 │  REST   │                          │ Prisma  │                │
│  Flutter App    │────────▶│  Express.js Server       │────────▶│  PostgreSQL    │
│  (mobile/)      │  HTTP   │  (server/src/index.ts)   │  ORM    │                │
│                 │         │                          │         └────────────────┘
│  ┌───────────┐  │ Socket  │  ┌──────────────────┐    │
│  │  SQLite   │  │────────▶│  │  Socket.IO       │    │
│  │  (local)  │  │  WS     │  │  (real-time chat)│    │
│  └───────────┘  │         │  └──────────────────┘    │
└─────────────────┘         │                          │
                            │  /uploads/ (static files)│
                            └──────────────────────────┘
```

- **REST API** handles CRUD operations, auth, sync, analytics
- **Socket.IO** handles real-time messaging, typing indicators, reactions, read receipts
- **SQLite** on the client stores local data for offline-first support
- **Sync endpoints** (`/api/sync/pull` and `/api/sync/push`) reconcile local and server state

---

## Backend (Express + Prisma)

### Stack
| Component | Technology | Version |
|-----------|-----------|---------|
| Runtime | Node.js | Not pinned (no `engines` field) |
| Framework | Express.js | 5.2.1 |
| ORM | Prisma | 5.22.0 |
| Database | PostgreSQL | Via `DATABASE_URL` |
| Auth | JWT (jsonwebtoken) | 9.0.3 |
| Password Hashing | bcryptjs | 3.0.3 |
| Real-time | Socket.IO | 4.8.3 |
| File Uploads | Multer | 2.1.1 |
| Security Headers | Helmet | 8.1.0 |
| CORS | cors | 2.8.6 |
| Environment | dotenv | 17.3.1 |
| Language | TypeScript | 6.0.2 |
| Dev Server | ts-node-dev | 2.0.0 |

### Directory Structure
```
server/
├── src/
│   ├── index.ts              # Entry point: Express + Socket.IO setup, route mounting
│   ├── middleware/
│   │   └── auth.ts           # JWT verification middleware (Bearer token)
│   ├── routes/
│   │   ├── auth.ts           # POST /register, /login, /refresh
│   │   ├── users.ts          # GET/PATCH /me, search, stats, avatar upload
│   │   ├── families.ts       # Family CRUD, members, weekly summary, challenges
│   │   ├── chores.ts         # Chore CRUD, assignment, completion, analytics, history
│   │   ├── invitations.ts    # Send/accept/decline family invitations
│   │   ├── messages.ts       # Message history, send (REST backup), image upload, unread count
│   │   ├── notifications.ts  # List, unread count, mark read
│   │   └── sync.ts           # Offline-first pull/push endpoints
│   └── services/
│       └── notification.ts   # Helper to create notification records
├── prisma/
│   └── schema.prisma         # 13 data models, PostgreSQL datasource
├── uploads/                  # Stored avatars and message images (served statically)
├── package.json
├── tsconfig.json
└── .env                      # Environment variables (not committed)
```

### Data Models

| Model | Purpose | Key Fields | Relations |
|-------|---------|------------|-----------|
| **User** | User identity and auth | id (UUID), username (unique), email (unique), password (bcrypt), displayName, avatarUrl | Referenced by FamilyMember, Chore, Message, etc. |
| **Family** | Household group | id, name, createdBy | Has many FamilyMember, Chore |
| **FamilyMember** | User-family membership | id, familyId, userId, role (`member`/`admin`) | Belongs to Family (cascade delete). Unique: [familyId, userId] |
| **Invitation** | Family join request | id, familyId, fromUserId, toUserId, status (`pending`/`accepted`/`declined`) | — |
| **Chore** | Task with full lifecycle | id, familyId, title, category, status (`pending`/`done`), priority (`low`/`medium`/`high`), assignmentStatus (`unassigned`/`pending_acceptance`/`accepted`/`declined`), assignedTo, dueDate, recurrence, description | Belongs to Family (cascade delete) |
| **ChoreHistory** | Audit trail for chores | id, choreId, familyId, userId, action (`created`/`assigned`/`completed`/`reopened`/`accepted`/`declined`) | — |
| **ChoreComment** | Comments on chores | id, choreId, userId, text | Defined in schema but **not wired to any route** |
| **Message** | Chat message | id, familyId, userId, text, choreId, mentions (JSON string), replyToId, imageUrl, reactions (JSON string), deletedAt (soft delete) | — |
| **MessageReadReceipt** | Read tracking per message | id, messageId, userId, readAt | Unique: [messageId, userId] |
| **FamilyChallenge** | Gamification challenge | id, familyId, title, targetCount, currentCount, startDate, endDate, createdBy | — |
| **ChoreSwapRequest** | Chore swap between users | id, choreId, fromUserId, toUserId, familyId, status, message | Defined in schema but **no routes implemented** |
| **Notification** | In-app notification | id, userId, familyId, type, title, body, data (JSON string), read | — |

### API Structure

All routes are mounted under `/api/` in `server/src/index.ts`:

| Mount Point | File | Auth Required | Key Endpoints |
|------------|------|---------------|---------------|
| `/api/auth` | `routes/auth.ts` | No | `POST /register`, `POST /login`, `POST /refresh` |
| `/api/users` | `routes/users.ts` | Yes | `GET /me`, `PATCH /me`, `GET /search`, `GET /me/stats`, `POST /me/avatar`, `POST /me/change-password` |
| `/api/families` | `routes/families.ts` | Yes | `POST /`, `GET /`, `GET /:id/members`, `GET /:id/weekly-summary`, `DELETE /:id/members/:userId`, `PATCH /:id`, `PATCH /:id/members/:userId/role`, `POST /:id/challenges`, `GET /:id/challenges` |
| `/api/chores` | `routes/chores.ts` | Yes | `POST /`, `GET /`, `PATCH /:id`, `PATCH /:id/assignment`, `POST /:id/complete`, `GET /:id/history`, `GET /stats`, `GET /history`, `GET /analytics`, `DELETE /:id` |
| `/api/invitations` | `routes/invitations.ts` | Yes | `POST /`, `GET /incoming`, `PATCH /:id` |
| `/api/messages` | `routes/messages.ts` | Yes | `GET /`, `POST /send`, `POST /upload`, `GET /unread` |
| `/api/notifications` | `routes/notifications.ts` | Yes | `GET /`, `GET /unread-count`, `PATCH /:id/read`, `POST /read-all` |
| `/api/sync` | `routes/sync.ts` | Yes | `GET /pull?since=<ISO>`, `POST /push` |

Additional endpoints:
- `GET /api/health` — Health check
- `GET /uploads/*` — Static file serving (avatars, images)

### Middleware Chain

```
Request
  → Helmet (security headers)
  → CORS (all origins)
  → express.json() (body parser)
  → Route-specific: authenticate middleware (JWT verification)
  → Route handler (business logic + Prisma queries)
  → try/catch error handling (per-handler, returns 500)
```

Auth middleware is applied per-router at mount time, not globally. Auth routes (`/api/auth`) have no auth middleware.

### Real-Time Layer (Socket.IO)

Socket.IO runs on the same HTTP server. Auth via `socket.handshake.auth.token` (JWT).

**Server Events:**
| Event | Direction | Description |
|-------|-----------|-------------|
| `send_message` | Client → Server → Broadcast | Create message, emit `new_message` to family room |
| `toggle_reaction` | Client → Server → Broadcast | Toggle emoji reaction, emit `reaction_updated` |
| `mark_read` | Client → Server → Broadcast | Create read receipts, emit `messages_read` |
| `delete_message` | Client → Server → Broadcast | Soft-delete, emit `message_deleted` |
| `typing` | Client → Server → Broadcast | Typing indicator (no persistence) |
| `stop_typing` | Client → Server → Broadcast | Stop typing indicator |

Users auto-join `family:<familyId>` rooms on connection.

---

## Frontend (Flutter)

### Stack
| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Flutter | SDK |
| Language | Dart | ^3.8.1 |
| State Management | Riverpod (flutter_riverpod) | 3.3.1 |
| Navigation | GoRouter | 17.0.0 |
| HTTP Client | Dio | 5.9.2 |
| Real-time | socket_io_client | 3.1.4 |
| Local Database | sqflite | 2.4.2 |
| Secure Storage | flutter_secure_storage | 10.0.0 |
| Charts | fl_chart | 0.70.2 |
| Calendar | table_calendar | 3.2.0 |
| Image Picker | image_picker | 1.2.1 |
| Connectivity | connectivity_plus | 7.1.0 |
| Loading Skeletons | shimmer | 3.0.0 |
| Audio | audioplayers + record | 6.6.0 / 6.2.0 |
| Value Equality | equatable | 2.0.8 |
| Linting | flutter_lints | 5.0.0 |

### Directory Structure
```
mobile/lib/
├── main.dart                    # Entry: WidgetsBinding, ConnectivityService init, ProviderScope
├── app.dart                     # ChoreHubApp widget, GoRouter config, auth redirect logic
├── config/
│   ├── api_config.dart          # Base URL (http://192.168.1.54:3000/api), timeouts (10s)
│   └── theme.dart               # AppTheme: dark color palette, typography scale, shadows, radii
├── constants/
│   └── chore_templates.dart     # Quick-add chore template list
├── db/
│   ├── database_helper.dart     # SQLite singleton, version 8, migration handlers
│   └── schema.dart              # CREATE TABLE statements, migration scripts (v1–v8)
├── models/                      # Dart data classes with Equatable
│   ├── user.dart                # User (id, username, displayName, email)
│   ├── chore.dart               # Chore (full lifecycle: status, priority, assignment, recurrence)
│   ├── family.dart              # Family (id, name, createdBy, role)
│   ├── family_member.dart       # FamilyMember (userId, role, nested User)
│   ├── message.dart             # Message + ChoreAttachment + ReplyTo (reactions, mentions, images)
│   ├── chore_history.dart       # ChoreHistory (action audit trail)
│   ├── invitation.dart          # Invitation (status, nested fromUser)
│   └── chore_comment.dart       # ChoreComment (lightweight)
├── providers/                   # Riverpod NotifierProviders
│   ├── auth_provider.dart       # AuthNotifier: login, register, logout, token management
│   ├── chore_provider.dart      # ChoreNotifier: CRUD, filter, sort, search, stats
│   ├── family_provider.dart     # FamilyNotifier: families, members, member stats, current family
│   ├── message_provider.dart    # MessageNotifier: socket + REST hybrid, reactions, typing, read receipts
│   ├── invitation_provider.dart # InvitationNotifier: incoming invites, user search, send/respond
│   ├── analytics_provider.dart  # AnalyticsNotifier: weekly completions, category breakdown, trends
│   ├── notification_provider.dart # NotificationNotifier: list, unread count, mark read
│   ├── connectivity_provider.dart # StreamProvider<bool> + isOnlineProvider
│   └── theme_provider.dart      # ThemeNotifier: dark/light toggle (persisted to secure storage)
├── repositories/                # Local SQLite data access
│   ├── user_repository.dart     # getUserById, insertUser(s)
│   └── (others referenced)     # chore, family, history, invitation, message repositories
├── services/
│   ├── api_client.dart          # Dio singleton: token interceptor, auto-refresh on 401, retry
│   ├── auth_service.dart        # register/login/logout, user persistence to SQLite
│   ├── connectivity_service.dart # Connectivity singleton + status stream
│   ├── socket_service.dart      # Socket.IO singleton: connect/disconnect, event streams, emit methods
│   └── logger.dart              # AppLogger: debug logging utility
├── screens/                     # Full-page UI (ConsumerStatefulWidget)
│   ├── auth/                    # login_screen, register_screen
│   ├── home/                    # dashboard_screen (greeting, my chores, activity, suggestions)
│   ├── chores/                  # chore_list, chore_detail, create_chore, edit_chore, calendar
│   ├── chat/                    # chat_screen (messages, @mentions, reactions, images, replies)
│   ├── family/                  # family, create_family, invite, invitations, member_detail, settings, challenges
│   ├── profile/                 # profile_screen (stats, settings, logout)
│   ├── analytics/               # analytics_screen (charts: weekly, category, member, trend)
│   ├── notifications/           # notification_screen
│   └── onboarding/              # welcome_screen
└── widgets/                     # Reusable UI components
    ├── charts/                  # category_pie_chart, completion_trend_chart, member_chart, weekly_chart
    ├── shell_screen.dart        # Bottom navigation shell (5 tabs: dashboard, chores, chat, family, profile)
    ├── chore_card.dart          # Chore summary card
    ├── chore_filter_bar.dart    # Filter/sort controls
    ├── message_bubble.dart      # Chat message bubble (sent/received)
    ├── mention_suggestions.dart # @mention autocomplete dropdown
    ├── reaction_picker.dart     # Emoji reaction picker
    ├── skeleton_loader.dart     # Shimmer loading placeholder
    ├── empty_state.dart         # "No data" placeholder
    └── (20+ more widgets)       # activity_feed, leaderboard, link_preview, typing_indicator, etc.
```

### Auth Flow

```
1. User registers or logs in
   └─▶ POST /api/auth/register or /login
   └─▶ Server returns { user, accessToken, refreshToken }

2. Tokens stored securely
   └─▶ flutter_secure_storage: 'access_token', 'refresh_token'
   └─▶ User object saved to local SQLite

3. Every API request
   └─▶ Dio interceptor reads access_token from secure storage
   └─▶ Attaches Authorization: Bearer <token> header

4. On 401 response
   └─▶ Dio interceptor catches error
   └─▶ POST /api/auth/refresh with refresh_token
   └─▶ New access_token stored, original request retried

5. On refresh failure
   └─▶ All tokens cleared from secure storage
   └─▶ SQLite user data wiped
   └─▶ AuthState.isAuthenticated → false
   └─▶ GoRouter redirect sends user to /login

6. On logout
   └─▶ Socket.IO disconnected
   └─▶ Tokens cleared, SQLite wiped
   └─▶ All dependent providers invalidated
```

### API Service Layer

- **`ApiClient`** (`services/api_client.dart`): Dio singleton created once, shared across all providers
- **Base URL**: Configured in `config/api_config.dart` (default: `http://192.168.1.54:3000/api`)
- **Timeouts**: 10s connect, 10s receive
- **Interceptors**:
  1. `onRequest` — Attach Bearer token from secure storage
  2. `onError` (401) — Attempt token refresh, retry original request, or redirect to login
- **Usage in providers**: `ApiClient().dio.get('/chores?familyId=$id')` — providers call Dio directly, parse JSON into model objects

### Navigation (GoRouter)

- **Shell route** with bottom navigation (5 tabs): Dashboard, Chores, Chat, Family, Profile
- **Modal routes** (slide-up transition): create/edit chore, family create/invite/settings, analytics, notifications, calendar
- **Auth routes** (fade-scale transition): login, register
- **Auth guard**: GoRouter `redirect` checks `authProvider.isAuthenticated` — unauthenticated users redirected to `/login`, authenticated users on auth routes redirected to `/dashboard`

---

## Deployment

- **Backend**: No Docker or CI/CD configuration found. Server runs locally via `npm run dev` (ts-node-dev). Listens on `0.0.0.0:3000`. PostgreSQL must be running externally. [ASSUMED: development-only setup currently]
- **Frontend**: Standard Flutter build (`flutter build apk` / `flutter build ios`). No flavor or environment configuration beyond `api_config.dart`.
