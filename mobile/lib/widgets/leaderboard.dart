import 'package:flutter/material.dart';
import '../providers/analytics_provider.dart';

class Leaderboard extends StatelessWidget {
  final List<MemberContribution> data;
  const Leaderboard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final medalColors = [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 22),
                SizedBox(width: 8),
                Text('Leaderboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text('This month', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            ...data.take(5).toList().asMap().entries.map((entry) {
              final rank = entry.key;
              final member = entry.value;
              final isTop3 = rank < 3;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: isTop3
                          ? Icon(Icons.emoji_events_rounded, color: medalColors[rank], size: 20)
                          : Text('${rank + 1}', textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isTop3 ? medalColors[rank] : Colors.grey).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          member.displayName[0].toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isTop3 ? medalColors[rank] : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${member.count}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6C63FF)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
