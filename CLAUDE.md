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
