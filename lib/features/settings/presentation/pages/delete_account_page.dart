import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

/// Delete account (design "Delete Account", HTML 4853): a full screen — warning,
/// what's removed, store-subscription note, and a Type-DELETE + password confirm
/// before calling `DELETE /account`. On success the AuthCubit signs out.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _confirm = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;

  bool get _valid =>
      _confirm.text.trim().toUpperCase() == 'DELETE' &&
      _password.text.trim().isNotEmpty;

  @override
  void dispose() {
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() => _submitting = true);
    final result =
        await context.read<AuthCubit>().deleteAccount(_password.text.trim());
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!result.isSuccess) {
      AppOverlays.snack(context,
          result.failureOrNull?.message ?? 'Could not delete account');
    }
    // On success the AuthCubit flips to unauthenticated and the router redirects.
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final error = Theme.of(context).colorScheme.error;
    final texts = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: error.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(Icons.delete_forever, color: error, size: 34),
          ),
          const SizedBox(height: AppSpacing.md),
          Text("This can't be undone", style: texts.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Deleting your account permanently removes your profile, posts, chats and orders.',
            style: TextStyle(color: nex.textSecondary, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: nex.border),
            ),
            child: Column(
              children: const [
                _RemovedRow(Icons.photo_library_outlined, 'Posts & media'),
                _RemovedRow(Icons.forum_outlined, 'All conversations'),
                _RemovedRow(Icons.receipt_long_outlined, 'Order & payment history'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: nex.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: nex.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Active subscriptions must be cancelled in the App Store / Play Store separately.',
                    style: TextStyle(color: nex.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _confirm,
            label: 'Type DELETE to confirm',
            hint: 'DELETE',
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _password,
            label: 'Password',
            hint: '••••••••',
            obscure: true,
            prefixIcon: Icons.lock_outline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_valid && !_submitting) ? _delete : null,
              style: FilledButton.styleFrom(
                backgroundColor: error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white))
                  : const Text('Delete my account'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemovedRow extends StatelessWidget {
  const _RemovedRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      ),
    );
  }
}
