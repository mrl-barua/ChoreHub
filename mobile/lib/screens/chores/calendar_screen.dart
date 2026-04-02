import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../config/theme.dart';
import '../../models/chore.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<Chore> _getChoresForDay(DateTime day, List<Chore> allChores) {
    return allChores.where((chore) {
      if (chore.dueDate == null) return false;
      try {
        final due = DateTime.parse(chore.dueDate!);
        return isSameDay(due, day);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chores = ref.watch(choreProvider);
    final family = ref.watch(familyProvider);
    final allChores = chores.chores;
    final selectedChores = _selectedDay != null ? _getChoresForDay(_selectedDay!, allChores) : <Chore>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          TableCalendar<Chore>(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2027, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            eventLoader: (day) => _getChoresForDay(day, allChores),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppTheme.accentOrange,
                shape: BoxShape.circle,
              ),
              markerSize: 6,
              markersMaxCount: 3,
              defaultTextStyle: const TextStyle(color: Colors.white),
              weekendTextStyle: const TextStyle(color: Colors.white70),
              todayTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              leftChevronIcon: Icon(Icons.chevron_left_rounded, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right_rounded, color: Colors.white),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
              weekendStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: selectedChores.isEmpty
                ? Center(
                    child: Text(
                      _selectedDay == null ? 'Tap a day to see chores' : 'No chores on this day',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: selectedChores.length,
                    itemBuilder: (context, index) {
                      final chore = selectedChores[index];
                      final assignee = family.members.where((m) => m.userId == chore.assignedTo).firstOrNull;
                      final categoryColor = AppTheme.categoryColors[chore.category] ?? Colors.grey;

                      return GestureDetector(
                        onTap: () => context.push('/chores/${chore.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C24),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  chore.isDone ? Icons.check_rounded : Icons.task_rounded,
                                  size: 18,
                                  color: chore.isDone ? AppTheme.accentGreen : categoryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      chore.title,
                                      style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w600,
                                        decoration: chore.isDone ? TextDecoration.lineThrough : null,
                                        color: chore.isDone ? Colors.grey : Colors.white,
                                      ),
                                    ),
                                    if (assignee != null)
                                      Text(assignee.user?.displayName ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: chore.priority == 'high' ? AppTheme.priorityHigh
                                      : chore.priority == 'low' ? AppTheme.priorityLow
                                      : AppTheme.priorityMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
