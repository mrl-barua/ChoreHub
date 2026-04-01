import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';

const _categories = ['cleaning', 'cooking', 'dishwashing', 'laundry', 'gardening', 'shopping', 'other'];
const _timeSlots = ['morning', 'lunch', 'evening'];
const _priorities = ['low', 'medium', 'high'];
const _recurrences = ['daily', 'weekly', 'monthly'];

class CreateChoreScreen extends ConsumerStatefulWidget {
  const CreateChoreScreen({super.key});

  @override
  ConsumerState<CreateChoreScreen> createState() => _CreateChoreScreenState();
}

class _CreateChoreScreenState extends ConsumerState<CreateChoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'cleaning';
  String? _timeSlot;
  String? _assignedTo;
  DateTime? _dueDate;
  String _priority = 'medium';
  String? _recurrence;

  @override
  void initState() {
    super.initState();
    // Sync to get latest family members (e.g. newly joined User B)
    Future.microtask(() => ref.read(familyProvider.notifier).refreshWithSync());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(choreProvider.notifier).createChore(
          title: _titleController.text.trim(),
          category: _category,
          timeSlot: _timeSlot,
          assignedTo: _assignedTo,
          dueDate: _dueDate?.toIso8601String().substring(0, 10),
          priority: _priority,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          recurrence: _recurrence,
        );

    if (mounted) context.pop();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Chore')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'What needs to be done?', prefixIcon: Icon(Icons.edit_rounded)),
                validator: (v) => v == null || v.isEmpty ? 'Enter a title' : null,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.notes_rounded)),
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              // Category chips
              Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _category == cat;
                  final color = AppTheme.categoryColors[cat] ?? Colors.grey;
                  return ChoiceChip(
                    label: Text(cat[0].toUpperCase() + cat.substring(1)),
                    selected: isSelected,
                    onSelected: (_) => setState(() {
                      _category = cat;
                      if (cat != 'cooking') _timeSlot = null;
                    }),
                    selectedColor: color.withValues(alpha: 0.2),
                    avatar: isSelected ? Icon(Icons.check_rounded, size: 16, color: color) : null,
                    labelStyle: TextStyle(
                      color: isSelected ? color : Colors.grey.shade600,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),

              if (_category == 'cooking') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _timeSlot,
                  decoration: const InputDecoration(labelText: 'Time Slot', prefixIcon: Icon(Icons.schedule_rounded)),
                  items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1)))).toList(),
                  onChanged: (v) => setState(() => _timeSlot = v),
                ),
              ],

              const SizedBox(height: 20),

              // Priority selector
              Text('Priority', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Row(
                children: _priorities.map((p) {
                  final isSelected = _priority == p;
                  final color = p == 'high' ? AppTheme.priorityHigh : p == 'low' ? AppTheme.priorityLow : AppTheme.priorityMedium;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: p != 'high' ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.15) : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                p == 'high' ? Icons.keyboard_double_arrow_up_rounded : p == 'low' ? Icons.keyboard_double_arrow_down_rounded : Icons.remove_rounded,
                                color: isSelected ? color : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p[0].toUpperCase() + p.substring(1),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? color : Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _assignedTo,
                decoration: const InputDecoration(labelText: 'Assign To', prefixIcon: Icon(Icons.person_outline_rounded)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Unassigned')),
                  ...family.members.map((m) => DropdownMenuItem(
                        value: m.userId,
                        child: Text(m.user?.displayName ?? m.userId),
                      )),
                ],
                onChanged: (v) => setState(() => _assignedTo = v),
              ),

              const SizedBox(height: 16),

              // Due date
              GestureDetector(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Due Date',
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    suffixIcon: _dueDate != null
                        ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _dueDate = null))
                        : null,
                  ),
                  child: Text(
                    _dueDate != null
                        ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                        : 'No due date',
                    style: TextStyle(color: _dueDate != null ? null : Colors.grey),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Recurrence
              Text('Repeat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('None'),
                    selected: _recurrence == null,
                    onSelected: (_) => setState(() => _recurrence = null),
                  ),
                  ..._recurrences.map((r) => ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.repeat_rounded, size: 14),
                            const SizedBox(width: 4),
                            Text(r[0].toUpperCase() + r.substring(1)),
                          ],
                        ),
                        selected: _recurrence == r,
                        onSelected: (_) => setState(() => _recurrence = r),
                      )),
                ],
              ),

              const SizedBox(height: 32),
              FilledButton(
                onPressed: _submit,
                child: const Text('Create Chore'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
