import 'package:flutter/material.dart';

class DashboardStats extends StatelessWidget {
  final Map<String, int> stats;

  const DashboardStats({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats['total'] ?? 0;
    final done = stats['done'] ?? 0;
    final pending = stats['pending'] ?? 0;
    final progress = total > 0 ? done / total : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: 'Total', count: total, color: Theme.of(context).colorScheme.primary),
                _StatItem(label: 'Done', count: done, color: Colors.green),
                _StatItem(label: 'Pending', count: pending, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              total > 0 ? '${(progress * 100).round()}% complete' : 'No chores yet',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatItem({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}
