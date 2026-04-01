import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/invitation_provider.dart';
import '../../providers/family_provider.dart';

class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitations = ref.watch(invitationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invitations')),
      body: invitations.isLoading
          ? const Center(child: CircularProgressIndicator())
          : invitations.incoming.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mail_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('No pending invitations', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(invitationProvider.notifier).loadInvitations(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: invitations.incoming.length,
                    itemBuilder: (context, index) {
                      final inv = invitations.incoming[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv.familyName ?? 'Family Invitation',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (inv.fromUser != null) ...[
                                const SizedBox(height: 4),
                                Text('From ${inv.fromUser!.displayName} (@${inv.fromUser!.username})',
                                    style: const TextStyle(color: Colors.grey)),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () async {
                                      await ref.read(invitationProvider.notifier).respondToInvitation(inv.id, 'declined');
                                    },
                                    child: const Text('Decline'),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton(
                                    onPressed: () async {
                                      await ref.read(invitationProvider.notifier).respondToInvitation(inv.id, 'accepted');
                                      ref.read(familyProvider.notifier).loadFamilies();
                                    },
                                    child: const Text('Accept'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
