const String createUsersTable = '''
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    email TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    sync_status TEXT NOT NULL DEFAULT 'synced'
  )
''';

const String createFamiliesTable = '''
  CREATE TABLE IF NOT EXISTS families (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_by TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    sync_status TEXT NOT NULL DEFAULT 'pending'
  )
''';

const String createFamilyMembersTable = '''
  CREATE TABLE IF NOT EXISTS family_members (
    id TEXT PRIMARY KEY,
    family_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member',
    joined_at TEXT NOT NULL DEFAULT (datetime('now')),
    sync_status TEXT NOT NULL DEFAULT 'pending',
    UNIQUE(family_id, user_id)
  )
''';

const String createInvitationsTable = '''
  CREATE TABLE IF NOT EXISTS invitations (
    id TEXT PRIMARY KEY,
    family_id TEXT NOT NULL,
    from_user_id TEXT NOT NULL,
    to_user_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    sync_status TEXT NOT NULL DEFAULT 'pending'
  )
''';

const String createChoresTable = '''
  CREATE TABLE IF NOT EXISTS chores (
    id TEXT PRIMARY KEY,
    family_id TEXT NOT NULL,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    time_slot TEXT,
    assigned_to TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    due_date TEXT,
    created_by TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    sync_status TEXT NOT NULL DEFAULT 'pending',
    priority TEXT NOT NULL DEFAULT 'medium',
    description TEXT,
    recurrence TEXT,
    assignment_status TEXT NOT NULL DEFAULT 'unassigned'
  )
''';

// Migration from v1 to v2: add new chore columns
const List<String> migrationV2 = [
  "ALTER TABLE chores ADD COLUMN priority TEXT NOT NULL DEFAULT 'medium'",
  "ALTER TABLE chores ADD COLUMN description TEXT",
  "ALTER TABLE chores ADD COLUMN recurrence TEXT",
];

// Migration from v2 to v3: add assignment_status
const List<String> migrationV3 = [
  "ALTER TABLE chores ADD COLUMN assignment_status TEXT NOT NULL DEFAULT 'unassigned'",
];

const String createChoreHistoryTable = '''
  CREATE TABLE IF NOT EXISTS chore_history (
    id TEXT PRIMARY KEY,
    chore_id TEXT NOT NULL,
    family_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    action TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    sync_status TEXT NOT NULL DEFAULT 'pending'
  )
''';

// Migration from v3 to v4: add chore_history table
const List<String> migrationV4 = [
  createChoreHistoryTable,
];

const String createMessagesTable = '''
  CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    family_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    text TEXT NOT NULL,
    chore_id TEXT,
    mentions TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    sync_status TEXT NOT NULL DEFAULT 'synced'
  )
''';

// Migration from v4 to v5: add messages table
const List<String> migrationV5 = [
  createMessagesTable,
];

// Migration from v5 to v6: add chore_id and mentions to messages
const List<String> migrationV6 = [
  "ALTER TABLE messages ADD COLUMN chore_id TEXT",
  "ALTER TABLE messages ADD COLUMN mentions TEXT",
];

const String createSyncMetaTable = '''
  CREATE TABLE IF NOT EXISTS sync_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
''';

const List<String> allCreateStatements = [
  createUsersTable,
  createFamiliesTable,
  createFamilyMembersTable,
  createInvitationsTable,
  createChoresTable,
  createChoreHistoryTable,
  createMessagesTable,
  createSyncMetaTable,
];
