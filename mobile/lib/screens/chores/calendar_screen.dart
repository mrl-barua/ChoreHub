import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../config/theme.dart';
import '../../models/chore.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../utils/category_helpers.dart';
import '../../utils/date_helpers.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// Get the relevant date for a chore: dueDate if set, otherwise createdAt.
  /// Converts to local time so calendar day comparisons work correctly.
  DateTime? _choreDate(Chore chore) {
    if (chore.dueDate != null && chore.dueDate!.isNotEmpty) {
      final parsed = DateHelpers.parseToLocal(chore.dueDate);
      if (parsed != null) return parsed;
    }
    if (chore.createdAt != null && chore.createdAt!.isNotEmpty) {
      final parsed = DateHelpers.parseToLocal(chore.createdAt);
      if (parsed != null) return parsed;
    }
    return null;
  }

  List<Chore> _getChoresForDay(DateTime day, List<Chore> allChores) {
    return allChores.where((chore) {
      final date = _choreDate(chore);
      if (date == null) return false;
      return isSameDay(date, day);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final chores = ref.watch(choreProvider);
    final family = ref.watch(familyProvider);
    final allChores = chores.allChores.isNotEmpty ? chores.allChores : chores.chores;
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

          if (_selectedDay != null && selectedChores.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${selectedChores.length} chore${selectedChores.length > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${selectedChores.where((c) => c.isDone).length} done',
                    style: TextStyle(fontSize: 13, color: AppTheme.accentGreen),
                  ),
                ],
              ),
            ),

          Expanded(
            child: selectedChores.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available_rounded, size: 48, color: Colors.grey.shade700),
                        const SizedBox(height: 8),
                        Text(
                          'No chores on this day',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: selectedChores.length,
                    itemBuilder: (context, index) {
                      final chore = selectedChores[index];
                      final assignee = family.members.where((m) => m.userId == chore.assignedTo).firstOrNull;
                      final categoryColor = AppTheme.categoryColors[chore.category] ?? Colors.grey;
                      final hasDueDate = chore.dueDate != null && chore.dueDate!.isNotEmpty;

                      return GestureDetector(
                        onTap: () => context.push('/chores/${chore.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
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
                                  chore.isDone ? Icons.check_rounded : CategoryHelpers.iconFor(chore.category),
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
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (assignee != null)
                                          Text(assignee.user?.displayName ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                        if (assignee != null && hasDueDate)
                                          Text('  ·  ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        if (hasDueDate)
                                          Text('Due', style: TextStyle(fontSize: 11, color: AppTheme.accentOrange, fontWeight: FontWeight.w600))
                                        else
                                          Text('Created', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: CategoryHelpers.priorityColor(chore.priority),
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
