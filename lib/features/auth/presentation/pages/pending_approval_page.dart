import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/user.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Shown after a successful registration, and when a `pending`/`rejected`
/// account tries to log in (login returns 403). New accounts are gated behind a
/// super-admin review — until approved, no token is issued and the app is not
/// accessible. [user] (passed via `extra`) tailors the copy; [rejected] switches
/// to the rejected variant.
class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key, this.user, this.rejected = false});

  final User? user;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final nex = context.nexveero;
    final isRejected = rejected || (user?.isRejected ?? false);
    final business = user?.businessName ?? user?.name;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isRejected ? nex.warning : nex.teal)
                        .withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    isRejected
                        ? Icons.cancel_outlined
                        : Icons.hourglass_top_rounded,
                    size: 44,
                    color: isRejected ? nex.warning : nex.teal,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  isRejected ? 'Account not approved' : 'Pending admin approval',
                  style: texts.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  isRejected
                      ? 'Your account was not approved. Please contact support '
                          'if you believe this is a mistake.'
                      : 'Thanks for registering${business != null ? ', $business' : ''}. '
                          'A Nexveero admin is reviewing your details. You can '
                          'log in once your account is approved — this usually '
                          'takes a little while.',
                  style: texts.bodyLarge?.copyWith(color: nex.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (!isRejected)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: nex.elevated,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: nex.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: nex.iconInactive),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'While you wait, you can explore how Nexveero works '
                            'from the app tour.',
                            style: texts.bodyMedium
                                ?.copyWith(color: nex.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Back to login',
                  onPressed: () => context.go(AppRoutes.login),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
