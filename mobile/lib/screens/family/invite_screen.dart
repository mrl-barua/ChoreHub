import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/family_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/feedback_service.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final invitations = ref.watch(invitationProvider);
    final family = ref.watch(familyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invite Member')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              enabled: isOnline,
              decoration: InputDecoration(
                labelText: isOnline ? 'Search by username or name' : 'Search requires internet connection',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: isOnline && _searchController.text.length >= 2
                      ? () => ref.read(invitationProvider.notifier).searchUsers(_searchController.text.trim())
                      : null,
                ),
              ),
              onSubmitted: isOnline
                  ? (query) {
                      if (query.length >= 2) {
                        ref.read(invitationProvider.notifier).searchUsers(query);
                      }
                    }
                  : null,
            ),
          ),
          if (!isOnline)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Colors.orange.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(child: Text('You need an internet connection to search for users and send invitations.')),
                    ],
                  ),
                ),
              ),
            ),
          if (invitations.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(invitations.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (invitations.isSearching)
            const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: invitations.searchResults.length,
              itemBuilder: (context, index) {
                final user = invitations.searchResults[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(user.displayName[0].toUpperCase())),
                    title: Text(user.displayName),
                    subtitle: Text('@${user.username}'),
                    trailing: FilledButton(
                      onPressed: () async {
                        if (family.currentFamily == null) return;
                        await ref.read(invitationProvider.notifier).sendInvitation(
                              family.currentFamily!.id,
                              user.id,
                            );
                        if (context.mounted) {
                          AppFeedback.success(context, 'Invitation sent to ${user.displayName}');
                        }
                      },
                      child: const Text('Invite'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
