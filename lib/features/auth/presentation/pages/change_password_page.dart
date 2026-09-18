import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/widgets.dart';
import '../widgets/auth_field.dart';
import '../widgets/password_strength.dart';

/// Change-password screen (design "Change password"). Full client-side flow —
/// validation + live strength meter — but the update call is pending a backend
/// endpoint (see MISSING_APIS.md), so submit shows a notice.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Rebuild so the strength meter reflects the new-password field live.
    _next.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final result = await sl<AuthRepository>().changePassword(
      currentPassword: _current.text,
      password: _next.text,
      passwordConfirmation: _confirm.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Success():
        AppOverlays.snack(context, 'Password updated.');
        Navigator.of(context).maybePop();
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthField(
                  controller: _current,
                  label: 'Current password',
                  hint: 'Enter password',
                  icon: Icons.lock_outline,
                  obscure: true,
                  validator: (v) => Validators.required(v, field: 'Current password'),
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthField(
                  controller: _next,
                  label: 'New password',
                  hint: 'Enter password',
                  icon: Icons.lock_open_outlined,
                  obscure: true,
                  validator: Validators.password,
                ),
                PasswordStrengthBar(password: _next.text),
                const SizedBox(height: AppSpacing.lg),
                AuthField(
                  controller: _confirm,
                  label: 'Confirm new password',
                  hint: 'Enter password',
                  icon: Icons.lock_outline,
                  obscure: true,
                  validator: (v) => Validators.confirmPassword(v, _next.text),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Update password', isLoading: _submitting, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
