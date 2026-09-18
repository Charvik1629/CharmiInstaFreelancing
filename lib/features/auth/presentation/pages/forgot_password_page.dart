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

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final email = _email.text.trim();
    final result = await sl<AuthRepository>().forgotPassword(email);
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Success():
        AppOverlays.snack(context, 'If that account exists, a reset code was sent.');
        context.push('${AppRoutes.otp}?to=${Uri.encodeComponent(email)}');
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
                Text("Enter your email and we'll send a reset code.",
                    style: texts.bodyLarge?.copyWith(color: context.nexveero.textSecondary)),
                const SizedBox(height: AppSpacing.xl),
                AuthField(
                  controller: _email,
                  label: 'Email',
                  hint: 'Enter email',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Send reset code', isLoading: _submitting, onPressed: _submit),
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
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: context.nexveero.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Icon(icon, color: Colors.white, size: 30),
    );
  }
}
