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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Tooltip(
                  message: 'Previous week',
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_double_arrow_left_rounded, size: 20),
                    onPressed: () => setState(() => _focusedDay = _focusedDay.subtract(const Duration(days: 7))),
                  ),
                ),
                Tooltip(
                  message: 'Next week',
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_double_arrow_right_rounded, size: 20),
                    onPressed: () => setState(() => _focusedDay = _focusedDay.add(const Duration(days: 7))),
                  ),
                ),
              ],
            ),
          ),
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
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              weekendStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                final displayCount = events.length > 3 ? 3 : events.length;
                final overflow = events.length - displayCount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...List.generate(displayCount, (_) => Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 1),
                        decoration: const BoxDecoration(
                          color: AppTheme.accentOrange,
                          shape: BoxShape.circle,
                        ),
                      )),
                      if (overflow > 0) ...[
                        const SizedBox(width: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentOrange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          ),
                          child: Text(
                            '+$overflow',
                            style: const TextStyle(
                              fontSize: 7,
                              color: AppTheme.accentOrange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
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
                        const Icon(Icons.event_available_rounded, size: 48, color: AppTheme.surfaceHigh),
                        const SizedBox(height: 8),
                        const Text(
                          'No chores on this day',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(choreProvider.notifier).refresh(),
                    child: ListView.builder(
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
                                          Text(assignee.user?.displayName ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                        if (assignee != null && hasDueDate)
                                          const Text('  ·  ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                        if (hasDueDate)
                                          const Text('Due', style: TextStyle(fontSize: 11, color: AppTheme.accentOrange, fontWeight: FontWeight.w600))
                                        else
                                          const Text('Created', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
          ),
        ],
      ),
    );
  }
}
