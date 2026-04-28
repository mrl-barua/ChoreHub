import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/chore_provider.dart';
import '../../providers/family_provider.dart';
import '../../services/feedback_service.dart';
import '../../widgets/chore_form_fields.dart';

const _categoriesForInit = ['cleaning', 'cooking', 'dishwashing', 'laundry', 'gardening', 'shopping', 'other'];

class CreateChoreScreen extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialCategory;
  const CreateChoreScreen({super.key, this.initialTitle, this.initialCategory});

  @override
  ConsumerState<CreateChoreScreen> createState() => _CreateChoreScreenState();
}

class _CreateChoreScreenState extends ConsumerState<CreateChoreScreen> {
  final _formKey = GlobalKey<FormState>();
  late ChoreFormController _formController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _formController = ChoreFormController();
    if (widget.initialTitle != null) {
      _formController.titleController.text = widget.initialTitle!;
    }
    if (widget.initialCategory != null && _categoriesForInit.contains(widget.initialCategory)) {
      _formController.category = widget.initialCategory!;
    }
    Future.microtask(() => ref.read(familyProvider.notifier).refreshWithSync());
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final description = _formController.descriptionController.text.trim();
      await ref.read(choreProvider.notifier).createChore(
            title: _formController.titleController.text.trim(),
            category: _formController.category,
            timeSlot: _formController.timeSlot,
            assignedTo: _formController.assignedTo,
            dueDate: _formController.dueDate?.toIso8601String().substring(0, 10),
            priority: _formController.priority,
            description: description.isEmpty ? null : description,
            recurrence: _formController.recurrence,
          );
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppFeedback.error(context, 'Failed to create chore. Try again.');
      }
    }
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
          child: ChoreFormFields(
            controller: _formController,
            members: family.members,
            onSubmit: _submit,
            isLoading: _isSubmitting,
            submitLabel: 'Add Chore',
          ),
        ),
      ),
    );
  }
}
