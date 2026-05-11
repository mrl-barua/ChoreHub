import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../providers/progression_provider.dart';
import '../services/feedback_service.dart';
import '../utils/category_helpers.dart';
import 'animated_list_item.dart';

class ProgressionSection extends ConsumerStatefulWidget {
  const ProgressionSection({super.key});

  @override
  ConsumerState<ProgressionSection> createState() => _ProgressionSectionState();
}

class _ProgressionSectionState extends ConsumerState<ProgressionSection> {
  bool _isMending = false;

  static const List<_LadderEntry> _ladder = [
    _LadderEntry(level: 2, label: 'Streak Mend'),
    _LadderEntry(level: 3, label: 'Streak Freeze'),
    _LadderEntry(level: 5, label: 'Display Title'),
    _LadderEntry(level: 7, label: 'Streak Freeze'),
    _LadderEntry(level: 10, label: 'Faster mend recovery'),
  ];

  Future<void> _onMendPressed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Save your streak?'),
        content: const Text(
          'Spend 50 XP to bring your streak back. You can only do this once every 14 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Spend 50 XP'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (mounted) {
      setState(() {
        _isMending = true;
      });
    }
    final notifier = ref.read(progressionProvider.notifier);
    await notifier.mend();

    if (!mounted) return;
    setState(() {
      _isMending = false;
    });

    final err = ref.read(progressionProvider).lastMendError;
    if (err != null) {
      String msg;
      switch (err) {
        case MendErrorReason.notEligible:
          msg = 'Streak is fine — no mend needed.';
          break;
        case MendErrorReason.insufficientXp:
          msg = 'You need 50 XP to mend your streak.';
          break;
        case MendErrorReason.cooldownActive:
          msg = 'Try again later — mend is on cooldown.';
          break;
        case MendErrorReason.unknown:
          msg = "Couldn't mend your streak. Try again.";
          break;
      }
      AppFeedback.error(context, msg);
      notifier.clearMendError();
      return;
    }
    AppFeedback.success(context, "Streak restored! Don't break it again.");
  }

  void _showSetTitleSheet() {
    final state = ref.read(progressionProvider);
    final notifier = ref.read(progressionProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color ?? AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusL)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a Title',
                style: TextStyle(
                  fontSize: AppTheme.fontXL,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppTheme.spaceS),
              const Text(
                'Pick one earned badge to show under your name.',
                style: TextStyle(
                  fontSize: AppTheme.fontS,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceM),
              ...state.badges.map((b) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _BadgeChip(badgeKey: b, compact: true),
                    title: Text(_badgeLabel(b)),
                    trailing: state.displayTitle == b
                        ? const Icon(Icons.check_rounded, color: AppTheme.accentGreen)
                        : null,
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      await notifier.setTitle(b);
                    },
                  )),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                title: const Text('Clear title'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await notifier.setTitle(null);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedListItem(
          index: 0,
          child: _ThisWeekCard(),
        ),
        const SizedBox(height: AppTheme.spaceM),
        AnimatedListItem(
          index: 1,
          child: _CollectionCard(
            onChangeTitle: _showSetTitleSheet,
          ),
        ),
        const SizedBox(height: AppTheme.spaceM),
        AnimatedListItem(
          index: 2,
          child: _UnlocksCard(
            ladder: _ladder,
            isMending: _isMending,
            onMendPressed: _onMendPressed,
            onSetTitlePressed: _showSetTitleSheet,
          ),
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
      color: Theme.of(context).cardTheme.color ?? AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      border: Border.all(color: AppTheme.borderSubtle(context)),
    );

class _ThisWeekCard extends ConsumerStatefulWidget {
  const _ThisWeekCard();

  @override
  ConsumerState<_ThisWeekCard> createState() => _ThisWeekCardState();
}

class _ThisWeekCardState extends ConsumerState<_ThisWeekCard> {
  double _previousProgress = 0.0;

  static const List<String> _dayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  List<bool> _resolveWeekCompletion(List<bool> weekCompletion) {
    if (weekCompletion.length == 7) {
      return weekCompletion;
    }
    return List<bool>.filled(7, false);
  }

  Widget _buildBar(double value) {
    return LinearProgressIndicator(
      value: value,
      minHeight: AppTheme.barHeightLg,
      backgroundColor: AppTheme.surfaceHigh,
      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(progressionProvider.select((s) => (
          currentStreak: s.currentStreak,
          longestStreak: s.longestStreak,
          weekCompletion: s.weekCompletion,
          xpIntoLevel: s.xpIntoLevel,
          xpForNextLevel: s.xpForNextLevel,
          level: s.level,
          error: s.error,
        )));

    final progress = data.xpForNextLevel > 0
        ? (data.xpIntoLevel / data.xpForNextLevel).clamp(0.0, 1.0)
        : 0.0;
    final weekCompletion = _resolveWeekCompletion(data.weekCompletion);
    final todayIndex = (DateTime.now().weekday - 1) % 7;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final skipTween = disableAnimations || progress == _previousProgress;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceM),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, size: 22, color: AppTheme.accentOrange),
              const SizedBox(width: AppTheme.spaceS),
              Text(
                '${data.currentStreak} day streak',
                style: const TextStyle(
                  fontSize: AppTheme.fontL,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppTheme.spaceS),
              Text(
                '· longest ${data.longestStreak}',
                style: const TextStyle(
                  fontSize: AppTheme.fontS,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          if (data.error != null) ...[
            const SizedBox(height: AppTheme.spaceXS),
            Text(
              data.error!,
              style: const TextStyle(
                fontSize: AppTheme.fontS,
                color: AppTheme.accentRed,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spaceS),
          _WeekDotStrip(
            weekCompletion: weekCompletion,
            todayIndex: todayIndex,
            dayInitials: _dayInitials,
          ),
          const SizedBox(height: AppTheme.spaceS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level ${data.level}',
                style: const TextStyle(
                  fontSize: AppTheme.fontL,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accent,
                ),
              ),
              Text(
                '${data.xpIntoLevel} / ${data.xpForNextLevel} to Lvl ${data.level + 1}',
                style: const TextStyle(
                  fontSize: AppTheme.fontS,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceS),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            child: skipTween
                ? _buildBar(progress)
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: _previousProgress, end: progress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    onEnd: () {
                      if (mounted) {
                        setState(() {
                          _previousProgress = progress;
                        });
                      }
                    },
                    builder: (_, value, __) => _buildBar(value),
                  ),
          ),
        ],
      ),
    );
  }
}

class _WeekDotStrip extends StatelessWidget {
  final List<bool> weekCompletion;
  final int todayIndex;
  final List<String> dayInitials;

  const _WeekDotStrip({
    required this.weekCompletion,
    required this.todayIndex,
    required this.dayInitials,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final filled = weekCompletion[i];
        final isToday = i == todayIndex;
        final ringWidth = isToday ? 2.5 : 1.5;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppTheme.accentOrange : Colors.transparent,
                border: Border.all(
                  color: AppTheme.accentOrange,
                  width: ringWidth,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceXS),
            Text(
              dayInitials[i],
              style: TextStyle(
                fontSize: AppTheme.fontXS,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday ? AppTheme.accentOrange : AppTheme.textMuted,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _CollectionCard extends ConsumerWidget {
  final VoidCallback onChangeTitle;

  const _CollectionCard({
    required this.onChangeTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(progressionProvider.select((s) => (
          displayTitle: s.displayTitle,
          level: s.level,
          badges: s.badges,
        )));

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceM),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.displayTitle != null) ...[
            Row(
              children: [
                const Text(
                  'Title:',
                  style: TextStyle(
                    fontSize: AppTheme.fontS,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceS),
                Expanded(
                  child: Text(
                    _badgeLabel(data.displayTitle!),
                    style: const TextStyle(
                      fontSize: AppTheme.fontM,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: data.level >= 5 ? onChangeTitle : null,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceS),
          ],
          const Text(
            'Badges',
            style: TextStyle(
              fontSize: AppTheme.fontS,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceS),
          if (data.badges.isEmpty)
            const Text(
              'No badges yet — finish chores to earn your first.',
              style: TextStyle(
                fontSize: AppTheme.fontS,
                color: AppTheme.textMuted,
              ),
            )
          else
            Wrap(
              spacing: AppTheme.spaceS,
              runSpacing: AppTheme.spaceS,
              children: data.badges
                  .map((b) => _BadgeChip(badgeKey: b))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _UnlocksCard extends ConsumerWidget {
  final List<_LadderEntry> ladder;
  final bool isMending;
  final VoidCallback onMendPressed;
  final VoidCallback onSetTitlePressed;

  const _UnlocksCard({
    required this.ladder,
    required this.isMending,
    required this.onMendPressed,
    required this.onSetTitlePressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(progressionProvider.select((s) => (
          level: s.level,
          freezesAvailable: s.freezesAvailable,
          mendEligible: s.mendEligible,
          badges: s.badges,
          displayTitle: s.displayTitle,
        )));

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceM),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unlock Ladder',
            style: TextStyle(
              fontSize: AppTheme.fontS,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceS),
          ...ladder.map((entry) {
            final earned = data.level >= entry.level;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    earned
                        ? Icons.check_circle_rounded
                        : Icons.lock_outline_rounded,
                    size: AppTheme.iconSizeM,
                    color: earned ? AppTheme.accentGreen : AppTheme.textMuted,
                  ),
                  const SizedBox(width: AppTheme.spaceS),
                  SizedBox(
                    width: 56,
                    child: Text(
                      'Lvl ${entry.level}',
                      style: TextStyle(
                        fontSize: AppTheme.fontS,
                        fontWeight: FontWeight.w700,
                        color: earned
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.label,
                      style: TextStyle(
                        fontSize: AppTheme.fontM,
                        color: earned
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (data.freezesAvailable > 0) ...[
            const SizedBox(height: AppTheme.spaceS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceM,
                vertical: AppTheme.spaceS,
              ),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                border: Border.all(
                  color: AppTheme.accentBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_rounded, size: 16, color: AppTheme.accentBlue),
                  const SizedBox(width: AppTheme.spaceS),
                  Text(
                    '${data.freezesAvailable} streak freeze${data.freezesAvailable == 1 ? '' : 's'} available',
                    style: const TextStyle(
                      fontSize: AppTheme.fontS,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentBlue,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (data.mendEligible) ...[
            const SizedBox(height: AppTheme.spaceS),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isMending ? null : onMendPressed,
                icon: isMending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.healing_rounded),
                label: const Text('Save your streak — 50 XP'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                ),
              ),
            ),
          ],
          if (data.level >= 5 &&
              data.badges.isNotEmpty &&
              data.displayTitle == null) ...[
            const SizedBox(height: AppTheme.spaceS),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSetTitlePressed,
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Set Title'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LadderEntry {
  final int level;
  final String label;
  const _LadderEntry({required this.level, required this.label});
}

String _badgeLabel(String badgeKey) {
  final parts = badgeKey.split('_');
  if (parts.length < 2) return badgeKey;
  final tier = parts.last;
  final categoryRaw = parts.sublist(0, parts.length - 1).join('_');
  final category = categoryRaw
      .toLowerCase()
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
  final tierTitle = tier.isEmpty
      ? ''
      : '${tier[0].toUpperCase()}${tier.substring(1).toLowerCase()}';
  return '$category ($tierTitle)';
}

Color _tierColor(String badgeKey) {
  final tier = badgeKey.split('_').last.toUpperCase();
  switch (tier) {
    case 'BRONZE':
      return const Color(0xFFCD7F32);
    case 'SILVER':
      return const Color(0xFFC0C0C0);
    case 'GOLD':
      return AppTheme.accentGold;
    default:
      return AppTheme.accent;
  }
}

String _categoryFromBadge(String badgeKey) {
  final parts = badgeKey.split('_');
  if (parts.isEmpty) return 'other';
  final raw = parts.first.toLowerCase();
  switch (raw) {
    case 'kitchen':
    case 'cooking':
      return 'cooking';
    case 'cleaning':
      return 'cleaning';
    case 'pet':
    case 'pets':
      return 'other';
    case 'laundry':
      return 'laundry';
    case 'garden':
    case 'gardening':
      return 'gardening';
    case 'shopping':
      return 'shopping';
    case 'dishes':
    case 'dishwashing':
      return 'dishwashing';
    default:
      return 'other';
  }
}

class _BadgeChip extends StatelessWidget {
  final String badgeKey;
  final bool compact;
  const _BadgeChip({required this.badgeKey, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(badgeKey);
    final categoryKey = _categoryFromBadge(badgeKey);
    final iconData = CategoryHelpers.iconFor(categoryKey);
    final size = compact ? 28.0 : 36.0;
    final labelStyle = TextStyle(
      fontSize: compact ? AppTheme.fontXS : AppTheme.fontS,
      fontWeight: FontWeight.w700,
      color: tierColor,
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppTheme.spaceS : AppTheme.spaceM,
        vertical: compact ? 4 : AppTheme.spaceS,
      ),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: tierColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, size: compact ? 14 : 18, color: tierColor),
          ),
          const SizedBox(width: AppTheme.spaceS),
          Text(_badgeLabel(badgeKey), style: labelStyle),
        ],
      ),
    );
  }
}
