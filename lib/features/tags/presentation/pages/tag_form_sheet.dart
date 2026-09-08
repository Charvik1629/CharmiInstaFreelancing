import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/tag.dart';
import '../cubit/admin_tags_cubit.dart';

/// Create / edit form for a tag, shown in a bottom sheet. Pass [tag] to edit.
class TagFormSheet extends StatefulWidget {
  const TagFormSheet({super.key, required this.cubit, this.tag});

  final AdminTagsCubit cubit;
  final Tag? tag;

  @override
  State<TagFormSheet> createState() => _TagFormSheetState();
}

class _TagFormSheetState extends State<TagFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _sortOrder;
  late bool _isActive;
  bool _saving = false;

  bool get _isEdit => widget.tag != null;

  @override
  void initState() {
    super.initState();
    final t = widget.tag;
    _name = TextEditingController(text: t?.name ?? '');
    _slug = TextEditingController(text: t?.slug ?? '');
    _sortOrder =
        TextEditingController(text: t == null ? '' : t.sortOrder.toString());
    _isActive = t?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final slug = _slug.text.trim();
    final sortOrder = int.tryParse(_sortOrder.text.trim()) ?? 0;

    final ok = _isEdit
        ? await widget.cubit.updateTag(
            id: widget.tag!.id,
            name: name,
            slug: slug.isEmpty ? null : slug,
            isActive: _isActive,
            sortOrder: sortOrder,
          )
        : await widget.cubit.createTag(
            name: name,
            slug: slug.isEmpty ? null : slug,
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEdit ? 'Edit tag' : 'New tag', style: texts.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              FormField<String>(
                initialValue: _name.text,
                validator: (_) =>
                    _name.text.trim().isEmpty ? 'Name is required' : null,
                builder: (field) => AppTextField(
                  controller: _name,
                  label: 'Name',
                  hint: 'Full Truck Load',
                  onChanged: field.didChange,
                  errorText: field.errorText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _slug,
                label: 'Slug (optional)',
                hint: 'full-truck-load — auto from name if blank',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-z0-9-]')),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              FormField<String>(
                initialValue: _sortOrder.text,
                validator: (_) {
                  final v = _sortOrder.text.trim();
                  if (v.isEmpty) return null; // defaults to 0
                  final n = int.tryParse(v);
                  if (n == null || n < 0 || n > 9999) return '0–9999';
                  return null;
                },
                builder: (field) => AppTextField(
                  controller: _sortOrder,
                  label: 'Sort order',
                  hint: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: field.didChange,
                  errorText: field.errorText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: Text('Show in the user tag picker',
                    style: texts.bodySmall
                        ?.copyWith(color: context.nexveero.textSecondary)),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: _isEdit ? 'Save changes' : 'Create tag',
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
