import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/widgets.dart';
import '../widgets/auth_field.dart';

/// Forgot-password screen (design "Forgot password?"). UI + validation are
/// complete; the actual "send reset code" call is pending a backend endpoint
/// (none in the API yet), so submit routes to the OTP screen for the demo flow
/// and shows a clear notice rather than claiming a code was sent.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final email = _email.text.trim();
    final result = _sent
        ? await sl<AuthRepository>().resetPassword(
            login: email,
            token: _token.text.trim(),
            password: _password.text,
            passwordConfirmation: _confirmation.text,
          )
        : await sl<AuthRepository>().forgotPassword(email);
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Success():
        if (_sent) {
          AppOverlays.snack(context, 'Password updated. Please sign in again.');
          context.go(AppRoutes.login);
        } else {
          setState(() => _sent = true);
          AppOverlays.snack(
            context,
            'If that account exists, reset instructions were sent.',
          );
        }
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconBadge(icon: Icons.lock_reset),
                const SizedBox(height: AppSpacing.lg),
                Text('Forgot password?', style: texts.displayLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Enter your email or username to request a password reset.",
                  style: texts.bodyLarge?.copyWith(
                    color: context.nexveero.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AuthField(
                  controller: _email,
                  label: 'Email or username',
                  hint: 'Enter email or username',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter email or username'
                      : null,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_sent) ...[
                  AuthField(
                    controller: _token,
                    label: 'Reset token',
                    hint: 'Enter the token from your reset instructions',
                    icon: Icons.key_outlined,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter reset token'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AuthField(
                    controller: _password,
                    label: 'New password',
                    hint: 'Enter new password',
                    icon: Icons.lock_outline,
                    obscure: true,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AuthField(
                    controller: _confirmation,
                    label: 'Confirm password',
                    hint: 'Re-enter new password',
                    icon: Icons.lock_outline,
                    obscure: true,
                    validator: (value) => value != _password.text
                        ? 'Passwords do not match'
                        : Validators.password(value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AppButton(
                  label: _sent ? 'Reset password' : 'Send reset instructions',
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Back to Log in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: context.nexveero.gradientEnd.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Icon(icon, color: context.nexveero.gradientEnd, size: 36),
    );
  }
}
