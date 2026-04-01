import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/family_provider.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/empty_state.dart';

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-sync when family screen opens to get latest members
    Future.microtask(() => ref.read(familyProvider.notifier).refreshWithSync());
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);

    if (family.currentFamily == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family')),
        body: EmptyState(
          icon: Icons.people_outline_rounded,
          title: 'No family yet',
          subtitle: 'Create a family group or accept an invitation.',
          action: Column(
            children: [
              FilledButton.icon(
                onPressed: () => context.push('/family/create'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Family'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/family/invitations'),
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('View Invitations'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(family.currentFamily!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(familyProvider.notifier).refreshWithSync(),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded),
            onPressed: () => context.push('/family/invitations'),
            tooltip: 'Invitations',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(familyProvider.notifier).refreshWithSync(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AnimatedListItem(
              index: 0,
              child: Text('Members (${family.members.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            ...family.members.asMap().entries.map((entry) {
              final member = entry.value;
              final colors = [
                const Color(0xFF6C63FF),
                const Color(0xFF00C853),
                const Color(0xFFFF9100),
                const Color(0xFF448AFF),
                const Color(0xFFAB47BC),
              ];
              final avatarColor = colors[entry.key % colors.length];

              return AnimatedListItem(
                index: entry.key + 1,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: avatarColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (member.user?.displayName ?? '?')[0].toUpperCase(),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: avatarColor),
                        ),
                      ),
                    ),
                    title: Text(member.user?.displayName ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('@${member.user?.username ?? ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    trailing: member.role == 'admin'
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Admin',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6C63FF))),
                          )
                        : null,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/family/invite'),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Invite'),
      ),
    );
  }
}
