import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/family_provider.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProvider);

    if (family.currentFamily == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('No family yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push('/family/create'),
                icon: const Icon(Icons.add),
                label: const Text('Create Family'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/family/invitations'),
                icon: const Icon(Icons.mail_outlined),
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
            icon: const Icon(Icons.mail_outlined),
            onPressed: () => context.push('/family/invitations'),
            tooltip: 'Invitations',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Members (${family.members.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...family.members.map((member) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      (member.user?.displayName ?? '?')[0].toUpperCase(),
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                    ),
                  ),
                  title: Text(member.user?.displayName ?? 'Unknown'),
                  subtitle: Text('@${member.user?.username ?? ''}'),
                  trailing: member.role == 'admin'
                      ? Chip(
                          label: const Text('Admin'),
                          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                          labelStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onTertiaryContainer),
                        )
                      : null,
                ),
              )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/family/invite'),
        icon: const Icon(Icons.person_add),
        label: const Text('Invite'),
      ),
    );
  }
}
