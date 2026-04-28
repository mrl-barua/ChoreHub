import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/family_provider.dart';
import '../../services/api_client.dart';
import '../../services/family_service.dart';
import '../../services/feedback_service.dart';

class FamilySettingsScreen extends ConsumerStatefulWidget {
  const FamilySettingsScreen({super.key});

  @override
  ConsumerState<FamilySettingsScreen> createState() => _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends ConsumerState<FamilySettingsScreen> {
  final FamilyService _familyService = FamilyService(ApiClient());
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final family = ref.read(familyProvider).currentFamily;
    _nameController.text = family?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null || _nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await _familyService.updateFamilyName(family.id, _nameController.text.trim());
      await ref.read(familyProvider.notifier).loadFamilies();
      if (mounted) AppFeedback.success(context, 'Family name updated');
    } catch (e) {
      debugPrint('Failed to update family name: $e');
      if (mounted) AppFeedback.error(context, 'Failed to update');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _changeRole(String userId, String currentRole) async {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;
    final newRole = currentRole == 'admin' ? 'member' : 'admin';
    try {
      await _familyService.changeMemberRole(family.id, userId, newRole);
      await ref.read(familyProvider.notifier).loadMembers();
      if (mounted) AppFeedback.success(context, 'Role changed to $newRole');
    } catch (e) {
      debugPrint('Failed to change role: $e');
      if (mounted) AppFeedback.error(context, 'Failed to change role');
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final members = family.members;

    return Scaffold(
      appBar: AppBar(title: const Text('Family Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Family Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'Family name'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isSaving ? null : _saveName,
                child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 32),

          const Text('Member Roles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Tap to toggle admin/member role', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 12),
          ...members.map((m) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
                child: Text((m.user?.displayName ?? '?')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              title: Text(m.user?.displayName ?? 'Unknown'),
              subtitle: Text('@${m.user?.username ?? ''}'),
              trailing: GestureDetector(
                onTap: () => _changeRole(m.userId, m.role),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: m.role == 'admin' ? AppTheme.accent.withValues(alpha: 0.15) : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    m.role == 'admin' ? 'Admin' : 'Member',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: m.role == 'admin' ? AppTheme.accent : Colors.grey),
                  ),
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }
}
