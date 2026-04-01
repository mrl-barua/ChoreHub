import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';

const _categories = ['cleaning', 'cooking', 'dishwashing', 'other'];
const _timeSlots = ['morning', 'lunch', 'evening'];

class CreateChoreScreen extends ConsumerStatefulWidget {
  const CreateChoreScreen({super.key});

  @override
  ConsumerState<CreateChoreScreen> createState() => _CreateChoreScreenState();
}

class _CreateChoreScreenState extends ConsumerState<CreateChoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String _category = 'cleaning';
  String? _timeSlot;
  String? _assignedTo;
  DateTime? _dueDate;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(choreProvider.notifier).createChore(
          title: _titleController.text.trim(),
          category: _category,
          timeSlot: _category == 'cooking' ? _timeSlot : null,
          assignedTo: _assignedTo,
          dueDate: _dueDate?.toIso8601String().substring(0, 10),
        );

    if (mounted) context.pop();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Chore')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Chore Title', prefixIcon: Icon(Icons.task_outlined)),
                validator: (v) => v == null || v.isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c[0].toUpperCase() + c.substring(1)))).toList(),
                onChanged: (v) => setState(() {
                  _category = v!;
                  if (v != 'cooking') _timeSlot = null;
                }),
              ),
              if (_category == 'cooking') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _timeSlot,
                  decoration: const InputDecoration(labelText: 'Time Slot', prefixIcon: Icon(Icons.schedule)),
                  items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1)))).toList(),
                  onChanged: (v) => setState(() => _timeSlot = v),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _assignedTo,
                decoration: const InputDecoration(labelText: 'Assign To', prefixIcon: Icon(Icons.person_outlined)),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(_dueDate != null
                    ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                    : 'No due date'),
                trailing: _dueDate != null
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _dueDate = null))
                    : null,
                onTap: _pickDate,
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
