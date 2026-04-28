import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/family_provider.dart';
import '../../services/api_client.dart';
import '../../services/family_service.dart';
import '../../services/feedback_service.dart';
import '../../widgets/challenge_progress_card.dart';
import '../../widgets/skeleton_loader.dart';

class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  final FamilyService _familyService = FamilyService(ApiClient());

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
      final challenges = await _familyService.loadChallenges(family.id);
      if (mounted) {
        setState(() {
          _challenges = challenges;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load challenges: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateDialog() {
    final titleController = TextEditingController(text: 'Family Challenge');
    final targetController = TextEditingController(text: '20');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusL))),
      builder: (ctx) {
        String? titleError;
        String? targetError;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
          void validateAndSubmit() async {
            final newTitleError = titleController.text.trim().isEmpty ? 'Title is required' : null;
            final target = int.tryParse(targetController.text);
            final newTargetError = (target == null || target <= 0) ? 'Enter a number greater than 0' : null;

            setSheetState(() {
              titleError = newTitleError;
              targetError = newTargetError;
            });

            if (newTitleError != null || newTargetError != null) return;

            final family = ref.read(familyProvider).currentFamily;
            if (family == null) return;
            Navigator.pop(ctx);
            try {
              await _familyService.createChallenge(
                family.id,
                title: titleController.text.trim(),
                targetCount: target!,
                startDate: DateTime.now().toIso8601String(),
                endDate: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
              );
              _loadChallenges();
            } catch (e) {
              debugPrint('Failed to create challenge: $e');
              if (mounted) {
                AppFeedback.error(context, 'Failed to create challenge');
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New Challenge', style: TextStyle(fontSize: AppTheme.fontXL, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'Challenge title',
                    errorText: titleError,
                  ),
                  onChanged: (_) {
                    if (titleError != null) setSheetState(() => titleError = null);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  decoration: InputDecoration(
                    hintText: 'Target chore count',
                    errorText: targetError,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (targetError != null) setSheetState(() => targetError = null);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: validateAndSubmit,
                    child: const Text('Create Challenge'),
                  ),
                ),
              ],
            ),
          );
        },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Challenges')),
      body: _isLoading
          ? const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  SkeletonChallengeCard(),
                  SkeletonChallengeCard(),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadChallenges,
              child: _challenges.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded, size: 64, color: AppTheme.surfaceHigh),
                          const SizedBox(height: 12),
                          const Text('No challenges yet', style: TextStyle(color: AppTheme.textSecondary)),
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
