import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../providers/analytics_provider.dart';

class CompletionTrendChart extends StatelessWidget {
  final List<WeeklyRate> data;
  const CompletionTrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxY = data.map((d) => d.rate).reduce((a, b) => a > b ? a : b).clamp(1.0, 1000.0) + 2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Completion Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Last 4 weeks', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < data.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(data[value.toInt()].label,
                                  style: TextStyle(fontSize: 10, color: isDark ? Colors.grey : Colors.grey.shade600)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.rate)).toList(),
                      isCurved: true,
                      color: AppTheme.accent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(radius: 4, color: AppTheme.accent, strokeWidth: 2, strokeColor: Colors.white),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.accent.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
