import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/chat_label.dart';
import '../cubit/chat_labels_cubit.dart';

/// Create / edit form for a chat label (name + colour). Pass [label] to edit.
class LabelFormSheet extends StatefulWidget {
  const LabelFormSheet({super.key, required this.cubit, this.label});

  final ChatLabelsCubit cubit;
  final ChatLabel? label;

  /// Preset chip colours (WhatsApp-ish palette).
  static const palette = <String>[
    '#25d366',
    '#128c7e',
    '#34b7f1',
    '#6c47ff',
    '#ff4d9d',
    '#f5a623',
    '#eb5757',
    '#8e8e93',
  ];

  @override
  State<LabelFormSheet> createState() => _LabelFormSheetState();
}

class _LabelFormSheetState extends State<LabelFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sortOrder;
  late String _color;
  bool _saving = false;

  bool get _isEdit => widget.label != null;

  @override
  void initState() {
    super.initState();
    final l = widget.label;
    _name = TextEditingController(text: l?.name ?? '');
    _sortOrder = TextEditingController(text: l == null ? '' : '${l.sortOrder}');
    _color = l?.color ?? LabelFormSheet.palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final sortOrder = int.tryParse(_sortOrder.text.trim()) ?? 0;
    final ok = _isEdit
        ? await widget.cubit.updateLabel(
            id: widget.label!.id,
            name: name,
            color: _color,
            sortOrder: sortOrder,
          )
        : await widget.cubit.createLabel(
            name: name,
            color: _color,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEdit ? 'Edit label' : 'New label', style: texts.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            FormField<String>(
              initialValue: _name.text,
              validator: (_) =>
                  _name.text.trim().isEmpty ? 'Name is required' : null,
              builder: (field) => AppTextField(
                controller: _name,
                label: 'Name',
                hint: 'Clients',
                onChanged: field.didChange,
                errorText: field.errorText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('COLOUR',
                style: texts.labelSmall?.copyWith(
                    color: context.nexveero.textSecondary, letterSpacing: 1)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final hex in LabelFormSheet.palette)
                  _Swatch(
                    hex: hex,
                    selected: hex.toLowerCase() == _color.toLowerCase(),
                    onTap: () => setState(() => _color = hex),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FormField<String>(
              initialValue: _sortOrder.text,
              validator: (_) {
                final v = _sortOrder.text.trim();
                if (v.isEmpty) return null;
                final n = int.tryParse(v);
                if (n == null || n < 0) return 'Enter a valid order';
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
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: _isEdit ? 'Save changes' : 'Create label',
              isLoading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(
      {required this.hex, required this.selected, required this.onTap});
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ChatLabel(id: 0, name: '', color: hex)
        .colorValue(Theme.of(context).colorScheme.primary);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface, width: 3)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
