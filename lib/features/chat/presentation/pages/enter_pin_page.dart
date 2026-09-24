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
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Rebuild so "Unlock chat" enables/disables as the PIN length changes.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final texts = Theme.of(context).textTheme;
    final pin = _controller.text;
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
              // Shared 4-digit PIN cells (masked) + system numeric keyboard —
              // matches the design (no custom keypad).
              PinCells(
                controller: _controller,
                mask: true,
                autofocus: true,
                onCompleted: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Unlock chat',
                icon: Icons.lock_open,
                onPressed: pin.length == _len
                    ? () => context.pop<String>(pin)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
