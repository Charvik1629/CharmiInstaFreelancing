import 'package:flutter/material.dart';

import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/disappearing_settings.dart';
import '../../domain/repositories/chat_repository.dart';

class DisappearingMessagesPage extends StatefulWidget {
  const DisappearingMessagesPage({
    super.key,
    required this.repository,
    required this.initial,
    required this.onApply,
  });
  final ChatRepository repository;
  final DisappearingSettings initial;
  final Future<Result<DisappearingUpdate>> Function({
    required bool enabled,
    int? hours,
  })
  onApply;
  @override
  State<DisappearingMessagesPage> createState() =>
      _DisappearingMessagesPageState();
}

class _DisappearingMessagesPageState extends State<DisappearingMessagesPage> {
  List<DisappearingDuration> _options = [];
  late int _selected = widget.initial.enabled ? widget.initial.hours ?? 0 : 0;
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.repository.getDisappearingOptions();
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case Success(value: final items):
          _options = items.where((i) => i.hours > 0).toList();
        case Err(failure: final failure):
          _error = failure.message;
      }
    });
  }

  String get _label => _selected == 0
      ? 'Off'
      : _options.where((o) => o.hours == _selected).firstOrNull?.label ??
            widget.initial.label ??
            '$_selected hours';
  bool get _changed =>
      _selected != (widget.initial.enabled ? widget.initial.hours ?? 0 : 0);
  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await widget.onApply(
      enabled: _selected != 0,
      hours: _selected == 0 ? null : _selected,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      Navigator.pop(context, true);
    } else {
      AppOverlays.snack(
        context,
        result.failureOrNull?.message ?? 'Could not update timer',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Disappearing messages')),
        body: SafeArea(
          child: _loading
              ? const LoadingView()
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: nex.primaryGradient,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.timer_outlined,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selected == 0
                                ? 'Messages that vanish'
                                : 'On · $_label',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selected == 0
                                ? 'New messages disappear after the timer you pick. Anyone in this chat can change it. Tap Keep on a message to save it.'
                                : 'New messages will disappear from this chat $_label after they are sent, except when kept.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: nex.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                children: [
                                  Text(_error!),
                                  TextButton(
                                    onPressed: _load,
                                    child: const Text('Retry timer options'),
                                  ),
                                ],
                              ),
                            ),
                          Material(
                            color: colors.surface,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: nex.border),
                            ),
                            child: RadioGroup<int>(
                              groupValue: _selected,
                              onChanged: (value) {
                                if (!_saving && value != null) {
                                  setState(() => _selected = value);
                                }
                              },
                              child: Column(
                                children: [
                                  RadioListTile<int>(
                                    value: 0,
                                    selected: _selected == 0,
                                    selectedTileColor: colors.primary
                                        .withValues(alpha: .04),
                                    title: Text(
                                      'Off',
                                      style: TextStyle(color: colors.onSurface),
                                    ),
                                    subtitle: Text(
                                      'Messages stay until deleted',
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                    enabled: !_saving,
                                  ),
                                  if (widget.initial.enabled &&
                                      widget.initial.hours != null &&
                                      !_options.any(
                                        (o) => o.hours == widget.initial.hours,
                                      ))
                                    RadioListTile<int>(
                                      value: widget.initial.hours!,
                                      title: Text(widget.initial.displayLabel),
                                      subtitle: const Text('Current timer'),
                                      enabled: false,
                                    ),
                                  for (final option in _options)
                                    RadioListTile<int>(
                                      value: option.hours,
                                      selected: _selected == option.hours,
                                      selectedTileColor: colors.primary
                                          .withValues(alpha: .04),
                                      title: Text(
                                        option.label,
                                        style: TextStyle(
                                          color: colors.onSurface,
                                        ),
                                      ),
                                      enabled: !_saving,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(
                                alpha: .4,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Shared for everyone in this chat. Changing the timer posts a system notice.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: AppButton(
                        label: _saving ? 'Updating…' : 'Update timer',
                        onPressed: _saving || !_changed ? null : _save,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
