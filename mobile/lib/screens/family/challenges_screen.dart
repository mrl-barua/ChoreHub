import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/family_provider.dart';
import '../../services/api_client.dart';
import '../../widgets/challenge_progress_card.dart';

class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  List<Map<String, dynamic>> _challenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;
    try {
      final response = await ApiClient().dio.get('/families/${family.id}/challenges');
      if (mounted) setState(() { _challenges = List<Map<String, dynamic>>.from(response.data); _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateDialog() {
    final titleController = TextEditingController(text: 'Family Challenge');
    final targetController = TextEditingController(text: '20');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Challenge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: titleController, decoration: const InputDecoration(hintText: 'Challenge title')),
            const SizedBox(height: 12),
            TextField(controller: targetController, decoration: const InputDecoration(hintText: 'Target chore count'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final family = ref.read(familyProvider).currentFamily;
                  if (family == null) return;
                  Navigator.pop(ctx);
                  try {
                    await ApiClient().dio.post('/families/${family.id}/challenges', data: {
                      'title': titleController.text.trim(),
                      'targetCount': int.tryParse(targetController.text) ?? 20,
                    });
                    _loadChallenges();
                  } catch (_) {}
                },
                child: const Text('Create Challenge'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Challenges')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadChallenges,
              child: _challenges.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events_rounded, size: 64, color: Colors.grey.shade700),
                          const SizedBox(height: 12),
                          Text('No challenges yet', style: TextStyle(color: Colors.grey.shade500)),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _showCreateDialog,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create Challenge'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _challenges.length,
                      itemBuilder: (context, index) {
                        final c = _challenges[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ChallengeProgressCard(
                            title: c['title'] as String? ?? 'Challenge',
                            currentCount: c['currentCount'] as int? ?? 0,
                            targetCount: c['targetCount'] as int? ?? 20,
                            endDate: c['endDate'] as String? ?? '',
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: _challenges.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}
