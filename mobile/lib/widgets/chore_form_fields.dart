import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/family_member.dart';
import 'form_section.dart';
import 'loading_button.dart';

const _categories = ['cleaning', 'cooking', 'dishwashing', 'laundry', 'gardening', 'shopping', 'other'];
const _timeSlots = ['morning', 'lunch', 'evening'];
const _priorities = ['low', 'medium', 'high'];
const _recurrences = ['daily', 'weekly', 'monthly'];

/// Holds all mutable state for the chore form.
class ChoreFormController {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String category = 'cleaning';
  String? timeSlot;
  String? assignedTo;
  DateTime? dueDate;
  String priority = 'medium';
  String? recurrence;

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
  }
}

class ChoreFormFields extends StatefulWidget {
  final ChoreFormController controller;
  final List<FamilyMember> members;
  final VoidCallback onSubmit;
  final bool isLoading;
  final String submitLabel;

  const ChoreFormFields({
    super.key,
    required this.controller,
    required this.members,
    required this.onSubmit,
    required this.isLoading,
    this.submitLabel = 'Create Chore',
  });

  @override
  State<ChoreFormFields> createState() => _ChoreFormFieldsState();
}

class _ChoreFormFieldsState extends State<ChoreFormFields> {
  ChoreFormController get _ctrl => widget.controller;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _ctrl.dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _ctrl.dueDate = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _ctrl.titleController,
          decoration: const InputDecoration(
            labelText: 'What needs to be done?',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Enter a title' : null,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ctrl.descriptionController,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 20),

        // Category chips
        FormSection(
          label: 'Category',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final isSelected = _ctrl.category == cat;
              final color = AppTheme.categoryColors[cat] ?? Colors.grey;
              return ChoiceChip(
                label: Text(cat[0].toUpperCase() + cat.substring(1)),
                selected: isSelected,
                onSelected: (_) => setState(() {
                  _ctrl.category = cat;
                  if (cat != 'cooking') _ctrl.timeSlot = null;
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
        ),

        if (_ctrl.category == 'cooking') ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _ctrl.timeSlot,
            decoration: const InputDecoration(
              labelText: 'Time Slot',
              prefixIcon: Icon(Icons.schedule_rounded),
            ),
            items: _timeSlots
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t[0].toUpperCase() + t.substring(1)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _ctrl.timeSlot = v),
          ),
        ],

        const SizedBox(height: 20),

        // Priority selector
        FormSection(
          label: 'Priority',
          child: Row(
            children: _priorities.map((p) {
              final isSelected = _ctrl.priority == p;
              final color = p == 'high'
                  ? AppTheme.priorityHigh
                  : p == 'low'
                      ? AppTheme.priorityLow
                      : AppTheme.priorityMedium;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: p != 'high' ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _ctrl.priority = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(
                          color: isSelected ? color : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            p == 'high'
                                ? Icons.keyboard_double_arrow_up_rounded
                                : p == 'low'
                                    ? Icons.keyboard_double_arrow_down_rounded
                                    : Icons.remove_rounded,
                            color: isSelected ? color : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p[0].toUpperCase() + p.substring(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? color : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _ctrl.assignedTo,
          decoration: const InputDecoration(
            labelText: 'Assign To',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Unassigned')),
            ...widget.members.map((m) => DropdownMenuItem(
                  value: m.userId,
                  child: Text(m.user?.displayName ?? m.userId),
                )),
          ],
          onChanged: (v) => setState(() => _ctrl.assignedTo = v),
        ),

        const SizedBox(height: 16),

        // Due date
        GestureDetector(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Due Date',
              prefixIcon: const Icon(Icons.calendar_today_rounded),
              suffixIcon: _ctrl.dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _ctrl.dueDate = null),
                    )
                  : null,
            ),
            child: Text(
              _ctrl.dueDate != null
                  ? '${_ctrl.dueDate!.year}-${_ctrl.dueDate!.month.toString().padLeft(2, '0')}-${_ctrl.dueDate!.day.toString().padLeft(2, '0')}'
                  : 'No due date',
              style: TextStyle(color: _ctrl.dueDate != null ? null : Colors.grey),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Recurrence
        FormSection(
          label: 'Repeat',
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('None'),
                selected: _ctrl.recurrence == null,
                onSelected: (_) => setState(() => _ctrl.recurrence = null),
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
                    selected: _ctrl.recurrence == r,
                    onSelected: (_) => setState(() => _ctrl.recurrence = r),
                  )),
            ],
          ),
        ),

        const SizedBox(height: 32),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _ctrl.titleController,
          builder: (context, titleValue, _) {
            final isValid = titleValue.text.trim().isNotEmpty;
            return LoadingButton(
              label: widget.submitLabel,
              isLoading: widget.isLoading,
              onPressed: isValid && !widget.isLoading ? widget.onSubmit : null,
            );
          },
        ),
      ],
    );
  }
}
