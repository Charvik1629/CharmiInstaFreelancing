import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../tags/domain/entities/tag.dart';
import '../../../tags/domain/repositories/tag_repository.dart';

/// Multi-select tag picker (design "Add tags"). Loads active tags from
/// `GET /tags` and returns the chosen [Tag]s via `Navigator.pop`. Opened from the
/// Create Post composer.
class TagPickerSheet extends StatefulWidget {
  const TagPickerSheet({super.key, this.initial = const []});

  final List<Tag> initial;

  @override
  State<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<TagPickerSheet> {
  late final TagRepository _repo = sl<TagRepository>();
  List<Tag> _all = const [];
  final Set<int> _selected = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initial.map((t) => t.id));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repo.getTags();
    if (!mounted) return;
    switch (result) {
      case Success(value: final tags):
        setState(() {
          _all = tags;
          _loading = false;
        });
      case Err(failure: final f):
        setState(() {
          _error = f.message;
          _loading = false;
        });
    }
  }

  void _done() {
    Navigator.of(context).pop(
      _all.where((t) => _selected.contains(t.id)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add tags', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(_error!,
                style: TextStyle(color: context.nexveero.textSecondary)),
          )
        else if (_all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text('No tags available.',
                style: TextStyle(color: context.nexveero.textSecondary)),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final t in _all)
                    FilterChip(
                      label: Text(t.name),
                      selected: _selected.contains(t.id),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _selected.add(t.id);
                        } else {
                          _selected.remove(t.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Done${_selected.isEmpty ? '' : ' (${_selected.length})'}',
          onPressed: _loading ? null : _done,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
