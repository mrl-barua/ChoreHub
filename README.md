# ChoreHub

A family chore management mobile application with real-time messaging, analytics, and gamification. Built with Flutter (mobile) and Node.js/Express/PostgreSQL (server).

## Features

### Chore Management
- Create, edit, and delete chores with categories, priorities, due dates, and recurrence
- Assign chores to family members with accept/decline flow
- Swipe-to-complete with undo support
- Recurring chore auto-generation (daily/weekly/monthly)
- Chore completion with optional notes and photo proof
- Chore comments/discussion thread
- Chore swapping between family members
- Calendar view for chores by date
- Smart suggestions based on history patterns

### Family Management
- Create family groups and invite members
- Role-based permissions (admin/member)
- Family settings (rename, manage roles)
- Family challenges with progress tracking
- Member stats drill-down with charts

### Real-Time Messaging
- Family group chat via Socket.IO
- @mention support with suggestions
- Chore attachments in messages
- Reply/quote messages
- Message reactions (emoji)
- Read receipts
- Voice message playback
- Image sharing
- Message search
- Date separators

### Analytics & Gamification
- Weekly completion chart
- Category breakdown pie chart
- Member contribution leaderboard
- Completion trend (4-week)
- Personal stats and streaks
- Family challenges with goals
- Smart chore suggestions

### Profile & Settings
- Personal stats dashboard
- Edit display name
- Change password
- Notification preferences
- Dark mode (default)
- Avatar upload

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.x, Dart |
| State Management | Riverpod 3.x (Notifier pattern) |
| Navigation | GoRouter |
| Backend | Node.js, Express 5, TypeScript |
| Database | PostgreSQL with Prisma ORM |
| Real-Time | Socket.IO |
| Auth | JWT (access + refresh tokens) |
| Storage | flutter_secure_storage |

---

## Prerequisites

- **Flutter** 3.8+ ([install](https://docs.flutter.dev/get-started/install))
- **Node.js** 20+ ([install](https://nodejs.org))
- **PostgreSQL** 14+ ([install](https://www.postgresql.org/download/))
- **Android Studio** or **VS Code** with Flutter extension

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/mrl-barua/ChoreHub.git
cd ChoreHub
```

### 2. Server Setup

```bash
cd server

# Install dependencies
npm install

# Create environment file
cp .env.example .env
```

Edit `server/.env` with your database credentials and generate secure JWT secrets:

```env
DATABASE_URL="postgresql://postgres:yourpassword@localhost:5432/chorehub?schema=public"
JWT_SECRET="<generate with: node -e \"console.log(require('crypto').randomBytes(32).toString('hex'))\">"
JWT_REFRESH_SECRET="<generate with: node -e \"console.log(require('crypto').randomBytes(32).toString('hex'))\">"
PORT=3000
CORS_ORIGINS="http://localhost:3000"
```

Create the database and push the schema:

```bash
# Create the database first in PostgreSQL:
# psql -U postgres -c "CREATE DATABASE chorehub;"

# Push schema to database
npx prisma db push

# Generate Prisma client
npx prisma generate

# Start the server
npm run dev
```

The server runs at `http://localhost:3000`.

### 3. Mobile Setup

```bash
cd mobile

# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

#### Connecting to the server

The mobile app needs to know your server's IP address.

**Android Emulator:**
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

**Physical Phone (same WiFi):**
```bash
# Find your PC's IP: ipconfig (Windows) or ifconfig (Mac/Linux)
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:3000/api
```

**iOS Simulator:**
```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
```

### 4. Create Your First Account

1. Open the app
2. Tap **Sign Up** and create an account
3. Create a family group
4. Invite other family members
5. Start creating and assigning chores!

---

## Project Structure

```
ChoreHub/
├── server/                    # Node.js backend
│   ├── prisma/
│   │   └── schema.prisma      # Database schema
│   ├── src/
│   │   ├── index.ts           # Express + Socket.IO entry
│   │   ├── middleware/
│   │   │   └── auth.ts        # JWT authentication
│   │   ├── routes/
│   │   │   ├── auth.ts        # Login, register, refresh
│   │   │   ├── users.ts       # Profile, stats, avatar
│   │   │   ├── families.ts    # Family CRUD, challenges
│   │   │   ├── chores.ts      # Chores, analytics, swaps
│   │   │   ├── invitations.ts # Invitation flow
│   │   │   ├── messages.ts    # Chat messages, upload
│   │   │   ├── notifications.ts # Notification center
│   │   │   └── sync.ts        # Data sync (legacy)
│   │   └── services/
│   │       └── notification.ts # Notification helper
│   └── .env.example
│
├── mobile/                    # Flutter app
│   └── lib/
│       ├── main.dart
│       ├── app.dart           # GoRouter navigation
│       ├── config/
│       │   ├── api_config.dart
│       │   └── theme.dart     # Dark theme, design tokens
│       ├── constants/
│       │   └── chore_templates.dart
│       ├── models/            # Data models with Equatable
│       ├── providers/         # Riverpod state management
│       │   ├── auth_provider.dart
│       │   ├── chore_provider.dart
│       │   ├── family_provider.dart
│       │   ├── message_provider.dart
│       │   ├── analytics_provider.dart
│       │   ├── invitation_provider.dart
│       │   ├── notification_provider.dart
│       │   └── theme_provider.dart
│       ├── screens/           # App screens
│       │   ├── auth/          # Login, register
│       │   ├── home/          # Dashboard
│       │   ├── chores/        # List, detail, create, edit, calendar
│       │   ├── chat/          # Family messaging
│       │   ├── family/        # Members, settings, challenges
│       │   ├── profile/       # Profile, stats
│       │   ├── analytics/     # Charts and reports
│       │   ├── notifications/ # Notification center
│       │   └── onboarding/    # Welcome flow
│       ├── services/          # API client, socket, auth
│       └── widgets/           # Reusable UI components
│
└── README.md
```

---

## API Endpoints

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Login |
| POST | `/api/auth/refresh` | Refresh JWT token |

### Users
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/users/me` | Get current user |
| PATCH | `/api/users/me` | Update profile |
| GET | `/api/users/me/stats` | Personal stats |
| POST | `/api/users/me/avatar` | Upload avatar |
| POST | `/api/users/me/change-password` | Change password |
| GET | `/api/users/search?q=` | Search users |
| GET | `/api/users/:userId/stats` | Member stats |

### Families
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/families` | List user's families |
| POST | `/api/families` | Create family |
| PATCH | `/api/families/:id` | Update family name |
| GET | `/api/families/:id/members` | List members |
| DELETE | `/api/families/:id/members/:userId` | Remove member |
| PATCH | `/api/families/:id/members/:userId/role` | Change role |
| GET | `/api/families/:id/weekly-summary` | Weekly summary |
| POST | `/api/families/:id/challenges` | Create challenge |
| GET | `/api/families/:id/challenges` | List challenges |

### Chores
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/chores?familyId=` | List chores |
| POST | `/api/chores` | Create chore |
| PATCH | `/api/chores/:id` | Update chore |
| DELETE | `/api/chores/:id` | Delete chore |
| POST | `/api/chores/:id/complete` | Complete with note |
| GET | `/api/chores/:id/history` | Chore history |
| GET | `/api/chores/:id/comments` | List comments |
| POST | `/api/chores/:id/comments` | Add comment |
| PATCH | `/api/chores/:id/assignment` | Accept/decline |
| GET | `/api/chores/stats` | Family stats |
| GET | `/api/chores/analytics` | Full analytics |
| GET | `/api/chores/suggestions` | Smart suggestions |
| GET | `/api/chores/swaps` | Pending swaps |
| PATCH | `/api/chores/swaps/:id` | Accept/decline swap |

### Messages
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/messages?familyId=` | Message history |
| POST | `/api/messages/send` | Send message (REST) |
| POST | `/api/messages/upload` | Upload image/audio |

### Notifications
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/notifications` | List notifications |
| GET | `/api/notifications/unread-count` | Unread count |
| PATCH | `/api/notifications/:id/read` | Mark as read |
| POST | `/api/notifications/read-all` | Mark all read |

---

## License

This project is for educational and personal use.
