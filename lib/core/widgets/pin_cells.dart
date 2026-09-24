import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// The app's single 4-digit PIN input (design: four 52×56 rounded cells).
/// Used everywhere a PIN is entered so the UI is identical (Security · Set your
/// own, Enter PIN to chat). Backed by one hidden system-keyboard field — tapping
/// anywhere focuses it. Set [mask] true to show `•` for entered digits, false to
/// show the digits themselves. For a static read-only PIN use [PinCells.display].
class PinCells extends StatefulWidget {
  const PinCells({
    super.key,
    required TextEditingController this.controller,
    this.mask = false,
    this.length = 4,
    this.autofocus = false,
    this.onCompleted,
  }) : displayValue = null;

  /// Non-editable variant that just renders [value] (e.g. the Random PIN).
  const PinCells.display(String this.displayValue, {super.key, this.length = 4})
      : controller = null,
        mask = false,
        autofocus = false,
        onCompleted = null;

  final TextEditingController? controller;
  final String? displayValue;
  final bool mask;
  final int length;
  final bool autofocus;
  final ValueChanged<String>? onCompleted;

  @override
  State<PinCells> createState() => _PinCellsState();
}

class _PinCellsState extends State<PinCells> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onChange);
    _focus.addListener(_onChange);
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    final t = widget.controller?.text ?? '';
    if (t.length == widget.length) widget.onCompleted?.call(t);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final primary = Theme.of(context).colorScheme.primary;
    final editable = widget.controller != null;
    final text = widget.displayValue ?? widget.controller?.text ?? '';

    final cells = Row(
      children: [
        for (var i = 0; i < widget.length; i++)
          Expanded(
            child: Container(
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: nex.elevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (editable && _focus.hasFocus && i == text.length) ||
                          i < text.length
                      ? primary
                      : nex.border,
                  width: 1.5,
                ),
              ),
              child: Text(
                i < text.length
                    ? (widget.mask ? '•' : text[i])
                    : '•',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color:
                          i < text.length ? null : nex.iconInactive,
                    ),
              ),
            ),
          ),
      ],
    );

    if (!editable) return cells;

    return Stack(
      children: [
        cells,
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              showCursor: false,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
