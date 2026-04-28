import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/chore.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../widgets/chore_form_fields.dart';

class EditChoreScreen extends ConsumerStatefulWidget {
  final String choreId;
  const EditChoreScreen({super.key, required this.choreId});

  @override
  ConsumerState<EditChoreScreen> createState() => _EditChoreScreenState();
}

class _EditChoreScreenState extends ConsumerState<EditChoreScreen> {
  final _formKey = GlobalKey<FormState>();
  late ChoreFormController _formController;
  Chore? _chore;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _formController = ChoreFormController();
    _loadChore();
  }

  Future<void> _loadChore() async {
    final choreState = ref.read(choreProvider);
    final choreList = choreState.allChores.isNotEmpty ? choreState.allChores : choreState.chores;
    final chore = choreList.where((c) => c.id == widget.choreId).firstOrNull;
    if (chore != null) {
      _formController.titleController.text = chore.title;
      _formController.descriptionController.text = chore.description ?? '';
      _formController.category = chore.category;
      _formController.timeSlot = chore.timeSlot;
      _formController.assignedTo = chore.assignedTo;
      _formController.dueDate = chore.dueDate != null ? DateTime.tryParse(chore.dueDate!) : null;
      _formController.priority = chore.priority;
      _formController.recurrence = chore.recurrence;
    }
    setState(() {
      _chore = chore;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _chore == null) return;

    final description = _formController.descriptionController.text.trim();
    final updated = _chore!.copyWith(
      title: _formController.titleController.text.trim(),
      category: _formController.category,
      timeSlot: _formController.timeSlot,
      assignedTo: _formController.assignedTo,
      dueDate: _formController.dueDate?.toIso8601String().substring(0, 10),
      priority: _formController.priority,
      description: description.isEmpty ? null : description,
      recurrence: _formController.recurrence,
      updatedAt: DateTime.now().toIso8601String(),
      syncStatus: 'pending',
    );

    await ref.read(choreProvider.notifier).updateChore(updated);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Chore')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_chore == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Chore')),
        body: const Center(child: Text('Chore not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Chore')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ChoreFormFields(
            controller: _formController,
            members: family.members,
            onSubmit: _submit,
            isLoading: false,
            submitLabel: 'Save Changes',
          ),
        ),
      ),
    );
  }
}
