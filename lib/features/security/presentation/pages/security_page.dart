import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/security_cubit.dart';

/// Security · chat PIN (design "Set PIN"). Choose a fixed 4-digit PIN, or let
/// the app issue a random PIN each chat.
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
  bool _own = false;
  final _pin = TextEditingController();
  bool _seeded = false;

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
        listenWhen: (p, c) => p.saved != c.saved || p.errorMessage != c.errorMessage,
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
            _seeded = true;
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Chat PIN', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text('Protect who can open your chats.',
                  style: TextStyle(color: context.nexveero.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              AppSegmented(
                segments: const ['Random', 'Set your own'],
                selectedIndex: _own ? 1 : 0,
                onChanged: (i) => setState(() => _own = i == 1),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_own)
                AppTextField(
                  controller: _pin,
                  label: 'Enter 4-digit PIN',
                  hint: 'Enter PIN',
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscure: true,
                  prefixIcon: Icons.lock_outline,
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: context.nexveero.elevated,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.autorenew, color: context.nexveero.textSecondary),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(
                        child: Text('A fresh PIN is generated for each new chat.'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Save',
                isLoading: state.saving,
                onPressed: () => context.read<SecurityCubit>().save(
                      mode: _own ? 'own' : 'random',
                      pin: _own ? _pin.text.trim() : null,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}
