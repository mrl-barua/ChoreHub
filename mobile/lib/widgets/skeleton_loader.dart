import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/theme.dart';

Widget _shimmerBox(Color color, {double? width, double height = 16, double radius = 8}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
  );
}

class SkeletonLoader extends StatelessWidget {
  final int itemCount;
  const SkeletonLoader({super.key, this.itemCount = 5});

  /// Single card-sized shimmer placeholder.
  static Widget card({double height = 120.0}) => SkeletonCard(height: height);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.shimmerBase(context),
      highlightColor: AppTheme.shimmerHighlight(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(itemCount, (i) => _SkeletonCard(index: i)),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final int index;
  const _SkeletonCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final overlayColor = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.shimmerBase(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: overlayColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: overlayColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Container(height: 10, width: 120, decoration: BoxDecoration(color: overlayColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single card-sized skeleton placeholder
class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, this.height = 120.0});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.shimmerBase(context),
      highlightColor: AppTheme.shimmerHighlight(context),
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.shimmerBase(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
      ),
    );
  }
}

/// A compact skeleton for stats/header areas
class SkeletonStats extends StatelessWidget {
  const SkeletonStats({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.shimmerBase(context),
      highlightColor: AppTheme.shimmerHighlight(context),
      child: Container(
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.shimmerBase(context),
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }
}

/// Skeleton for the dashboard hero area: ring + 2 stat cards + 3 chore rows
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.shimmerBase(context);
    final hi = AppTheme.shimmerHighlight(context);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hero ring placeholder
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: base, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(height: 16),
            // 2 stat cards
            Row(
              children: [
                Expanded(child: _shimmerBox(base, height: 80, radius: AppTheme.radiusL)),
                const SizedBox(width: 12),
                Expanded(child: _shimmerBox(base, height: 80, radius: AppTheme.radiusL)),
              ],
            ),
            const SizedBox(height: 16),
            // 3 chore rows
            ...List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _shimmerBox(base, height: 72, radius: AppTheme.radiusM),
            )),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a single chart card: title line + chart body
class SkeletonChartCard extends StatelessWidget {
  final double height;
  const SkeletonChartCard({super.key, this.height = 220});

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.shimmerBase(context);
    final hi = AppTheme.shimmerHighlight(context);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBox(base, height: 14, width: 120, radius: 6),
            const SizedBox(height: 12),
            _shimmerBox(base, height: height - 60, radius: AppTheme.radiusM),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a member list: avatar circle + text lines per row
class SkeletonMemberList extends StatelessWidget {
  final int count;
  const SkeletonMemberList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.shimmerBase(context);
    final hi = AppTheme.shimmerHighlight(context);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Column(
        children: List.generate(count, (_) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: base, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(base, height: 14, radius: 6),
                    const SizedBox(height: 6),
                    _shimmerBox(base, height: 10, width: 90, radius: 6),
                  ],
                ),
              ),
            ],
          ),
        )),
      ),
    );
  }
}

/// Skeleton for chat message list: alternating left/right bubbles
class SkeletonMessageList extends StatelessWidget {
  const SkeletonMessageList({super.key});

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.shimmerBase(context);
    final hi = AppTheme.shimmerHighlight(context);
    final widths = [180.0, 220.0, 150.0, 200.0, 160.0, 210.0];
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: List.generate(6, (i) {
            final isRight = i.isOdd;
            return Align(
              alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                width: widths[i],
                height: 44,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isRight ? const Radius.circular(16) : const Radius.circular(4),
                    bottomRight: isRight ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Skeleton for a challenge card: title + progress bar + 2 stat chips
class SkeletonChallengeCard extends StatelessWidget {
  const SkeletonChallengeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.shimmerBase(context);
    final hi = AppTheme.shimmerHighlight(context);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBox(base, height: 16, width: 160, radius: 6),
            const SizedBox(height: 12),
            _shimmerBox(base, height: 8, radius: 4),
            const SizedBox(height: 12),
            Row(
              children: [
                _shimmerBox(base, height: 28, width: 70, radius: AppTheme.radiusXL),
                const SizedBox(width: 8),
                _shimmerBox(base, height: 28, width: 70, radius: AppTheme.radiusXL),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
