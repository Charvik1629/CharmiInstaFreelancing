import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/wallet_package.dart';
import '../cubit/admin_packages_cubit.dart';

/// Create / edit form for a credit package. Price is entered in rupees and
/// converted to paise for the API (min ₹1). Pass [package] to edit.
class PackageFormSheet extends StatefulWidget {
  const PackageFormSheet({super.key, required this.cubit, this.package});

  final AdminPackagesCubit cubit;
  final WalletPackage? package;

  @override
  State<PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends State<PackageFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _credits;
  late final TextEditingController _rupees;
  late final TextEditingController _sortOrder;
  late bool _isActive;
  bool _saving = false;

  bool get _isEdit => widget.package != null;

  @override
  void initState() {
    super.initState();
    final p = widget.package;
    _name = TextEditingController(text: p?.name ?? '');
    _credits = TextEditingController(text: p == null ? '' : '${p.credits}');
    _rupees = TextEditingController(
        text: p == null ? '' : p.amount.toStringAsFixed(0));
    _sortOrder = TextEditingController(text: p == null ? '' : '${p.sortOrder}');
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _credits.dispose();
    _rupees.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final credits = int.tryParse(_credits.text.trim()) ?? 0;
    final amountPaise = ((double.tryParse(_rupees.text.trim()) ?? 0) * 100).round();
    final sortOrder = int.tryParse(_sortOrder.text.trim()) ?? 0;

    final ok = _isEdit
        ? await widget.cubit.updatePackage(
            id: widget.package!.id,
            name: name,
            credits: credits,
            amountPaise: amountPaise,
            isActive: _isActive,
            sortOrder: sortOrder,
          )
        : await widget.cubit.createPackage(
            name: name,
            credits: credits,
            amountPaise: amountPaise,
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
              Text(_isEdit ? 'Edit package' : 'New package',
                  style: texts.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              FormField<String>(
                initialValue: _name.text,
                validator: (_) =>
                    _name.text.trim().isEmpty ? 'Name is required' : null,
                builder: (field) => AppTextField(
                  controller: _name,
                  label: 'Name',
                  hint: 'Enter package name',
                  onChanged: field.didChange,
                  errorText: field.errorText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _intField(
                      _credits,
                      'Credits',
                      hint: 'Enter credits',
                      min: 1,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _intField(
                      _rupees,
                      'Price (₹)',
                      hint: 'Enter amount',
                      min: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _intField(_sortOrder, 'Sort order', hint: 'Enter sort order', min: 0),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: Text('Buyers can purchase this package',
                    style: texts.bodySmall
                        ?.copyWith(color: context.nexveero.textSecondary)),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: _isEdit ? 'Save changes' : 'Create package',
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

  Widget _intField(TextEditingController c, String label,
      {required String hint, required int min}) {
    return FormField<String>(
      initialValue: c.text,
      validator: (_) {
        final n = int.tryParse(c.text.trim());
        if (n == null) return 'Enter a number';
        if (n < min) return 'Min $min';
        return null;
      },
      builder: (field) => AppTextField(
        controller: c,
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
