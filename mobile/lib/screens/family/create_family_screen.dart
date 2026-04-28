import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/family_provider.dart';
import '../../widgets/loading_button.dart';
import '../../services/feedback_service.dart';

class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(familyProvider.notifier).createFamily(_nameController.text.trim());
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppFeedback.error(context, 'Could not create family. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Family')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Family Name',
                  prefixIcon: Icon(Icons.family_restroom),
                  hintText: 'e.g., The Smiths',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter a family name' : null,
                autofocus: true,
              ),
              const SizedBox(height: 24),
              LoadingButton(
                label: 'Create Family',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
