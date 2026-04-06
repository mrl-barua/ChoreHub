import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/theme.dart';

class SkeletonLoader extends StatelessWidget {
  final int itemCount;
  const SkeletonLoader({super.key, this.itemCount = 5});

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
