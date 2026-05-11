import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/progression_provider.dart';
import 'animated_list_item.dart';
import 'skeleton_loader.dart';

class StreakCard extends ConsumerStatefulWidget {
  const StreakCard({super.key});

  @override
  ConsumerState<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends ConsumerState<StreakCard> {
  static const List<int> _milestones = [7, 14, 30, 60, 100];
  static const List<String> _dayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  double _previousProgress = 0.0;

  String _proximityHint(int currentStreak) {
    if (currentStreak >= 100) {
      return "You're a legend";
    }
    if (currentStreak < 7) {
      final remaining = 7 - currentStreak;
      return '$remaining more days to a week!';
    }
    for (final milestone in _milestones) {
      if (milestone > currentStreak) {
        final remaining = milestone - currentStreak;
        return '$remaining more days to $milestone!';
      }
    }
    return "You're a legend";
  }

  @override
  Widget build(BuildContext context) {
    final (
      isLoading,
      xp,
      level,
      xpForNextLevel,
      xpIntoLevel,
      currentStreak,
      longestStreak,
      weekCompletionRaw,
      error,
    ) = ref.watch(
      progressionProvider.select(
        (s) => (
          s.isLoading,
          s.xp,
          s.level,
          s.xpForNextLevel,
          s.xpIntoLevel,
          s.currentStreak,
          s.longestStreak,
          s.weekCompletion,
          s.error,
        ),
      ),
    );

    if (isLoading && xp == 0 && level == 1) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppTheme.spaceM),
        child: SkeletonCard(height: 180),
      );
    }

    final weekCompletion = weekCompletionRaw.length == 7
        ? weekCompletionRaw
        : List<bool>.filled(7, false);
    final todayIndex = (DateTime.now().weekday - 1) % 7;
    final progress = xpForNextLevel > 0
        ? (xpIntoLevel / xpForNextLevel).clamp(0.0, 1.0)
        : 0.0;
    final hint = _proximityHint(currentStreak);
    final cardColor =
        Theme.of(context).cardTheme.color ?? AppTheme.surface;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final beginProgress = _previousProgress;

    return AnimatedListItem(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spaceM),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            onTap: () => context.go('/profile'),
            child: Container(
              constraints: const BoxConstraints(minHeight: 180),
              padding: const EdgeInsets.all(AppTheme.spaceM),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(color: AppTheme.borderSubtle(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TopRow(
                    streak: currentStreak,
                    longestStreak: longestStreak,
                    hint: hint,
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  _WeekStrip(
                    weekCompletion: weekCompletion,
                    todayIndex: todayIndex,
                    dayInitials: _dayInitials,
                  ),
                  const SizedBox(height: AppTheme.spaceM),
                  _XpBar(
                    progress: progress,
                    beginProgress: beginProgress,
                    disableAnimations: disableAnimations,
                    onAnimationEnd: () {
                      if (mounted) {
                        setState(() {
                          _previousProgress = progress;
                        });
                      }
                    },
                    level: level,
                    xpIntoLevel: xpIntoLevel,
                    xpForNextLevel: xpForNextLevel,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: AppTheme.spaceXS),
                    Text(
                      error,
                      style: const TextStyle(
                        fontSize: AppTheme.fontXS,
                        color: AppTheme.accentRed,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  final int streak;
  final int longestStreak;
  final String hint;

  const _TopRow({
    required this.streak,
    required this.longestStreak,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 40,
                    color: AppTheme.accentOrange,
                  ),
                  const SizedBox(width: AppTheme.spaceXS),
                  Text(
                    '$streak',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentOrange,
                      height: 1.0,
                      letterSpacing: -1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'day streak',
                style: TextStyle(
                  fontSize: AppTheme.fontS,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceXS),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: AppTheme.fontS,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.spaceS),
        _LongestStreakChip(longestStreak: longestStreak),
      ],
    );
  }
}

class _LongestStreakChip extends StatelessWidget {
  final int longestStreak;
  const _LongestStreakChip({required this.longestStreak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceS,
        vertical: AppTheme.spaceXS,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Text(
        'Best $longestStreak',
        style: const TextStyle(
          fontSize: AppTheme.fontXS,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final List<bool> weekCompletion;
  final int todayIndex;
  final List<String> dayInitials;

  const _WeekStrip({
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
        return _DayDot(
          filled: filled,
          isToday: isToday,
          label: dayInitials[i],
        );
      }),
    );
  }
}

class _DayDot extends StatelessWidget {
  final bool filled;
  final bool isToday;
  final String label;

  const _DayDot({
    required this.filled,
    required this.isToday,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
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
          label,
          style: TextStyle(
            fontSize: AppTheme.fontXS,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday ? AppTheme.accentOrange : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _XpBar extends StatelessWidget {
  final double progress;
  final double beginProgress;
  final bool disableAnimations;
  final VoidCallback onAnimationEnd;
  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;

  const _XpBar({
    required this.progress,
    required this.beginProgress,
    required this.disableAnimations,
    required this.onAnimationEnd,
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
  });

  Widget _buildBar(double value) {
    return LinearProgressIndicator(
      value: value,
      minHeight: AppTheme.barHeightSm,
      backgroundColor: AppTheme.surfaceHigh,
      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget bar = (disableAnimations || progress == beginProgress)
        ? _buildBar(progress)
        : TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: beginProgress, end: progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            onEnd: onAnimationEnd,
            builder: (_, value, __) => _buildBar(value),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          child: bar,
        ),
        const SizedBox(height: AppTheme.spaceXS),
        Text(
          'Lvl $level · $xpIntoLevel/$xpForNextLevel XP',
          style: const TextStyle(
            fontSize: AppTheme.fontS,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
