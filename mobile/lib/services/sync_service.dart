import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/user.dart';
import '../models/family.dart';
import '../models/family_member.dart';
import '../models/chore.dart';
import '../models/chore_history.dart';
import '../models/invitation.dart';
import '../models/message.dart';
import '../repositories/chore_repository.dart';
import '../repositories/family_repository.dart';
import '../repositories/history_repository.dart';
import '../repositories/invitation_repository.dart';
import '../repositories/message_repository.dart';
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
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _push() async {
    final pendingFamilies = await _familyRepo.getPendingSync();
    final pendingChores = await _choreRepo.getPendingSync();
    final pendingInvitations = await _invitationRepo.getPendingSync();
    final pendingHistory = await _historyRepo.getPendingSync();

    if (pendingFamilies.isNotEmpty || pendingChores.isNotEmpty || pendingInvitations.isNotEmpty || pendingHistory.isNotEmpty) {
      try {
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
      } catch (e) {
        debugPrint('Push sync failed: $e');
      }
    }

    // Push unsent messages via REST (socket may have been disconnected)
    await _pushPendingMessages();
  }

  Future<void> _pushPendingMessages() async {
    final messageRepo = MessageRepository();
    final db = await _db.database;

    // Get all family IDs the user belongs to
    final familyMaps = await db.query('families');
    for (final fm in familyMaps) {
      final familyId = fm['id'] as String;
      final pending = await messageRepo.getUnsentMessages(familyId);
      for (final msg in pending) {
        try {
          await _apiClient.dio.post('/messages/send', data: {
            'id': msg.id,
            'familyId': msg.familyId,
            'text': msg.text,
            'choreId': msg.choreId,
            'mentions': msg.mentions,
            'replyToId': msg.replyToId,
            'imageUrl': msg.imageUrl,
            'createdAt': msg.createdAt,
          });
          await messageRepo.markSynced(msg.id);
        } catch (e) {
          debugPrint('Push message ${msg.id} failed: $e');
        }
      }
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

    if (data['messages'] != null) {
      final messageRepo = MessageRepository();
      for (final m in data['messages']) {
        final message = Message.fromJson(m);
        await messageRepo.insertMessage(message);
      }
    }

    await db.insert(
      'sync_meta',
      {'key': 'last_sync_at', 'value': DateTime.now().toUtc().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
