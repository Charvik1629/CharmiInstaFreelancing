import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/subscription_plan.dart';
import '../cubit/admin_sub_plans_cubit.dart';

/// Create / edit form for a subscription plan, shown in a bottom sheet. On save
/// it calls the [cubit] and pops on success. Pass [plan] to edit, omit to create.
class PlanFormSheet extends StatefulWidget {
  const PlanFormSheet({super.key, required this.cubit, this.plan});

  final AdminSubPlansCubit cubit;
  final SubscriptionPlan? plan;

  @override
  State<PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends State<PlanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _duration;
  late final TextEditingController _sortOrder;
  late bool _isActive;
  bool _saving = false;

  bool get _isEdit => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _duration =
        TextEditingController(text: p == null ? '' : p.durationDays.toString());
    _sortOrder =
        TextEditingController(text: p == null ? '' : p.sortOrder.toString());
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _duration.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final description = _description.text.trim();
    final duration = int.tryParse(_duration.text.trim()) ?? 0;
    final sortOrder = int.tryParse(_sortOrder.text.trim()) ?? 0;

    final ok = _isEdit
        ? await widget.cubit.updatePlan(
            id: widget.plan!.id,
            name: name,
            description: description,
            durationDays: duration,
            isActive: _isActive,
            sortOrder: sortOrder,
          )
        : await widget.cubit.createPlan(
            name: name,
            description: description,
            durationDays: duration,
            isActive: _isActive,
            sortOrder: sortOrder,
          );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    // Lift content above the keyboard (sheet is scroll-controlled).
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEdit ? 'Edit plan' : 'New plan',
                  style: texts.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              FormField<String>(
                initialValue: _name.text,
                validator: (_) =>
                    _name.text.trim().isEmpty ? 'Name is required' : null,
                builder: (field) => AppTextField(
                  controller: _name,
                  label: 'Name',
                  hint: 'Monthly',
                  onChanged: field.didChange,
                  errorText: field.errorText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _description,
                label: 'Description',
                hint: 'Access for 30 days.',
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _duration,
                      label: 'Duration (days)',
                      hint: '30',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _NumberField(
                      controller: _sortOrder,
                      label: 'Sort order',
                      hint: '1',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: Text('Users can request this plan',
                    style: texts.bodySmall
                        ?.copyWith(color: context.nexveero.textSecondary)),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: _isEdit ? 'Save changes' : 'Create plan',
                isLoading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

/// A validated whole-number field used inside the plan form.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: controller.text,
      validator: (_) {
        final n = int.tryParse(controller.text.trim());
        if (n == null) return 'Enter a number';
        if (n < 0) return 'Cannot be negative';
        return null;
      },
      builder: (field) => AppTextField(
        controller: controller,
        label: label,
        hint: hint,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: field.didChange,
        errorText: field.errorText,
      ),
    );
  }
}
