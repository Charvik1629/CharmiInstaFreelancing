import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';

/// Full-screen "Enter PIN to chat" (design HTML 2933): shown when the peer has a
/// chat PIN set. Returns the entered 4-digit PIN via `pop`, or null if cancelled.
class EnterPinPage extends StatefulWidget {
  const EnterPinPage({super.key, required this.peerName, this.peerAvatarUrl});

  final String peerName;
  final String? peerAvatarUrl;

  @override
  State<EnterPinPage> createState() => _EnterPinPageState();
}

class _EnterPinPageState extends State<EnterPinPage> {
  static const _len = 4;
  String _pin = '';

  void _tap(String d) {
    if (_pin.length >= _len) return;
    setState(() => _pin += d);
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Enter PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                      name: widget.peerName,
                      imageUrl: MediaUrl.resolve(widget.peerAvatarUrl),
                      size: 72),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2),
                      ),
                      child: Icon(Icons.lock,
                          size: 16, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(widget.peerName, style: texts.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text('This chat is protected.\nEnter their 4-digit PIN to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: nex.textSecondary, height: 1.5)),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _len; i++)
                    Container(
                      width: 52,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: i < _pin.length
                              ? Theme.of(context).colorScheme.primary
                              : nex.border,
                          width: 1.5,
                        ),
                      ),
                      child: Text(i < _pin.length ? '•' : '',
                          style: texts.titleLarge),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Unlock chat',
                icon: Icons.lock_open,
                onPressed: _pin.length == _len
                    ? () => context.pop<String>(_pin)
                    : null,
              ),
              const Spacer(),
              _Keypad(onDigit: _tap, onBackspace: _backspace),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback? onTap) => Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(height: 52, child: Center(child: child)),
          ),
        );
    Widget digit(String d) => key(
        Text(d, style: Theme.of(context).textTheme.titleLarge), () => onDigit(d));
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.1,
      children: [
        for (var d = 1; d <= 9; d++) digit('$d'),
        const SizedBox.shrink(),
        digit('0'),
        key(const Icon(Icons.backspace_outlined), onBackspace),
      ],
    );
  }
}
