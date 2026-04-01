import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/user.dart';
import '../models/family.dart';
import '../models/family_member.dart';
import '../models/chore.dart';
import '../models/chore_history.dart';
import '../models/invitation.dart';
import '../repositories/chore_repository.dart';
import '../repositories/family_repository.dart';
import '../repositories/history_repository.dart';
import '../repositories/invitation_repository.dart';
import '../repositories/user_repository.dart';
import 'api_client.dart';
import 'connectivity_service.dart';

class SyncService {
  final ApiClient _apiClient = ApiClient();
  final DatabaseHelper _db = DatabaseHelper();
  final ChoreRepository _choreRepo = ChoreRepository();
  final FamilyRepository _familyRepo = FamilyRepository();
  final HistoryRepository _historyRepo = HistoryRepository();
  final InvitationRepository _invitationRepo = InvitationRepository();
  final UserRepository _userRepo = UserRepository();
  final ConnectivityService _connectivity = ConnectivityService();

  bool _isSyncing = false;

  Future<void> sync() async {
    if (_isSyncing || !_connectivity.isOnline) return;
    _isSyncing = true;

    try {
      await _push();
      await _pull();
    } catch (e) {
      // Sync failed silently - will retry on next trigger
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _push() async {
    final pendingFamilies = await _familyRepo.getPendingSync();
    final pendingChores = await _choreRepo.getPendingSync();
    final pendingInvitations = await _invitationRepo.getPendingSync();
    final pendingHistory = await _historyRepo.getPendingSync();

    if (pendingFamilies.isEmpty && pendingChores.isEmpty && pendingInvitations.isEmpty && pendingHistory.isEmpty) return;

    await _apiClient.dio.post('/sync/push', data: {
      'families': pendingFamilies.map((f) => {'id': f.id, 'name': f.name}).toList(),
      'chores': pendingChores.map((c) => c.toJson()).toList(),
      'invitations': pendingInvitations
          .where((i) => i.status != 'pending')
          .map((i) => {'id': i.id, 'status': i.status})
          .toList(),
      'choreHistory': pendingHistory.map((h) => h.toJson()).toList(),
    });

    for (final f in pendingFamilies) {
      await _familyRepo.markSynced(f.id);
    }
    for (final c in pendingChores) {
      await _choreRepo.markSynced(c.id);
    }
    for (final i in pendingInvitations) {
      await _invitationRepo.markSynced(i.id);
    }
    for (final h in pendingHistory) {
      await _historyRepo.markSynced(h.id);
    }
  }

  Future<void> _pull() async {
    final db = await _db.database;

    final meta = await db.query('sync_meta', where: 'key = ?', whereArgs: ['last_sync_at']);
    final since = meta.isNotEmpty ? meta.first['value'] as String : '1970-01-01T00:00:00.000Z';

    final response = await _apiClient.dio.get('/sync/pull', queryParameters: {'since': since});
    final data = response.data;

    if (data['users'] != null) {
      for (final u in data['users']) {
        final user = User.fromJson(u);
        await _userRepo.insertUser(user);
      }
    }

    if (data['families'] != null) {
      for (final f in data['families']) {
        final family = Family.fromJson(f);
        await db.insert('families', {...family.toMap(), 'sync_status': 'synced'},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    if (data['familyMembers'] != null) {
      for (final m in data['familyMembers']) {
        final member = FamilyMember.fromJson(m);
        await db.insert('family_members', {...member.toMap(), 'sync_status': 'synced'},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    if (data['chores'] != null) {
      for (final c in data['chores']) {
        final chore = Chore.fromJson(c);
        final existing = await _choreRepo.getChoreById(chore.id);
        if (existing != null && existing.syncStatus == 'pending') {
          final localTime = DateTime.tryParse(existing.updatedAt ?? '') ?? DateTime(1970);
          final serverTime = DateTime.tryParse(chore.updatedAt ?? '') ?? DateTime(1970);
          if (serverTime.isAfter(localTime)) {
            await db.insert('chores', {...chore.toMap(), 'sync_status': 'synced'},
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        } else {
          await db.insert('chores', {...chore.toMap(), 'sync_status': 'synced'},
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    }

    if (data['invitations'] != null) {
      for (final i in data['invitations']) {
        final invitation = Invitation.fromJson(i);
        await db.insert('invitations', {...invitation.toMap(), 'sync_status': 'synced'},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    if (data['choreHistory'] != null) {
      for (final h in data['choreHistory']) {
        final history = ChoreHistory.fromJson(h);
        await db.insert('chore_history', {...history.toMap(), 'sync_status': 'synced'},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    await db.insert(
      'sync_meta',
      {'key': 'last_sync_at', 'value': DateTime.now().toUtc().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
