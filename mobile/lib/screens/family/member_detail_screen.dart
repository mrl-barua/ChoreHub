import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/family_provider.dart';
import '../../services/api_client.dart';
import '../../services/user_service.dart';
import '../../widgets/charts/weekly_chart.dart';
import '../../widgets/charts/category_pie_chart.dart';
import '../../providers/analytics_provider.dart';

class MemberDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  const MemberDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  final UserService _userService = UserService(ApiClient());

  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final family = ref.read(familyProvider).currentFamily;
    if (family == null) return;
    try {
      final stats = await _userService.loadUserStats(widget.userId, family.id);
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load member stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final member = family.members.where((m) => m.userId == widget.userId).firstOrNull;
    final displayName = member?.user?.displayName ?? 'Unknown';
    final username = member?.user?.username ?? '';
    final role = member?.role ?? 'member';

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? const Center(child: Text('Could not load stats'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.surfaceVariant, AppTheme.surfaceLow]),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppTheme.accent.withValues(alpha: 0.3),
                            child: Text(displayName[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                              Text('@$username', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                            ],
                          )),
                          if (role == 'admin')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                              child: const Text('Admin', style: TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(children: [
                      _StatChip(icon: Icons.check_circle_rounded, label: 'Completed', value: '${_stats!['totalCompleted'] ?? 0}', color: AppTheme.accentGreen),
                      const SizedBox(width: 8),
                      _StatChip(icon: Icons.local_fire_department_rounded, label: 'Streak', value: '${_stats!['currentStreak'] ?? 0}d', color: const Color(0xFFFF9100)),
                      const SizedBox(width: 8),
                      _StatChip(icon: Icons.assignment_rounded, label: 'Assigned', value: '${_stats!['totalAssigned'] ?? 0}', color: AppTheme.accentBlue),
                    ]),

                    if (_stats!['topCategory'] != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Icon(Icons.star_rounded, size: 16, color: AppTheme.accentOrange),
                          const SizedBox(width: 6),
                          Text('Top category: ${_stats!['topCategory']} (${_stats!['topCategoryCount']})',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 24),

                    const Text('This Week', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: WeeklyChart(
                        data: (_stats!['weeklyCompletions'] as List?)?.map((w) =>
                          DayCompletion(w['dayName'] as String, w['completed'] as int)
                        ).toList() ?? [],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if ((_stats!['categoryBreakdown'] as Map?)?.isNotEmpty == true) ...[
                      const Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: CategoryPieChart(
                          data: (_stats!['categoryBreakdown'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int)),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }
}
