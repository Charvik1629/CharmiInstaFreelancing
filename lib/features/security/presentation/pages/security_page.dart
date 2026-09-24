import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/security_cubit.dart';

/// Security · chat PIN (design "Set PIN"). A master toggle, then choose a fixed
/// 4-digit PIN ("Set your own") or a per-chat random PIN ("Random").
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SecurityCubit>()..load(),
      child: const _SecurityView(),
    );
  }
}

class _SecurityView extends StatefulWidget {
  const _SecurityView();

  @override
  State<_SecurityView> createState() => _SecurityViewState();
}

class _SecurityViewState extends State<_SecurityView> {
  bool _own = true; // design: "Set your own" is the first (left) segment
  bool _enabled = false;
  final _pin = TextEditingController();
  bool _seeded = false;
  // Illustrative random PIN shown in Random mode (the real one is issued
  // per-chat by the server, so this "refreshes on each chat").
  late String _sample = _randomPin();

  static String _randomPin() => (Random().nextInt(9000) + 1000).toString();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: BlocConsumer<SecurityCubit, SecurityState>(
        listenWhen: (p, c) =>
            p.saved != c.saved || p.errorMessage != c.errorMessage,
        listener: (context, state) {
          if (state.saved) {
            AppOverlays.snack(context, 'Chat PIN saved');
          } else if (state.errorMessage != null) {
            AppOverlays.snack(context, state.errorMessage!);
          }
        },
        builder: (context, state) {
          if (state.status == SecurityStatus.loading ||
              state.status == SecurityStatus.initial) {
            return const LoadingView();
          }
          if (state.status == SecurityStatus.error) {
            return ErrorView(
              message: state.errorMessage ?? 'Could not load security settings',
              onRetry: () => context.read<SecurityCubit>().load(),
            );
          }
          if (!_seeded) {
            _own = state.settings.isOwn;
            _enabled = state.settings.enabled;
            _seeded = true;
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _card(context, child: _toggleRow(context, state)),
              const SizedBox(height: AppSpacing.lg),
              if (!_enabled)
                _infoBox(context,
                    'Turn on Set PIN to choose Set your own or Random.')
              else
                _card(context, child: _pinOptions(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.nexveero.border),
        ),
        child: child,
      );

  Widget _toggleRow(BuildContext context, SecurityState state) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set PIN',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('Choose how your chat PIN is created',
                    style: TextStyle(color: context.nexveero.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: state.saving
                ? null
                : (v) {
                    setState(() => _enabled = v);
                    context.read<SecurityCubit>().setEnabled(v);
                  },
          ),
        ],
      );

  Widget _infoBox(BuildContext context, String text) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.nexveero.elevated,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(children: [
          Icon(Icons.info_outline,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text)),
        ]),
      );

  Widget _pinOptions(BuildContext context, SecurityState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSegmented(
          // Design order: "Set your own" first, "Random" second.
          segments: const ['Set your own', 'Random'],
          selectedIndex: _own ? 0 : 1,
          onChanged: (i) {
            setState(() {
              _own = i == 0;
              if (!_own) _sample = _randomPin();
            });
            // Random needs no PIN input, so it saves immediately (design has no
            // Submit on the Random screen).
            if (!_own) context.read<SecurityCubit>().save(mode: 'random');
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_own) ...[
          Text('Enter 4-digit PIN',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.md),
          // Password-style: digits mask to dots as you type (numeric keyboard).
          PinCells(controller: _pin, mask: true),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Submit',
            isLoading: state.saving,
            onPressed: () => context
                .read<SecurityCubit>()
                .save(mode: 'own', pin: _pin.text.trim()),
          ),
        ] else ...[
          Text('Your PIN', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.md),
          PinCells.display(_sample),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.autorenew,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text('Refreshes on each chat',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ],
    );
  }
}
