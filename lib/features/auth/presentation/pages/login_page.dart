import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_form_state.dart';
import '../cubit/login_cubit.dart';
import '../widgets/auth_field.dart';

/// Sign-in screen (design "Welcome back"). Validates locally, submits via
/// [LoginCubit], surfaces server field errors, and on success activates the
/// session and routes to the feed.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LoginCubit>(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      context.read<LoginCubit>().submit(
            email: _email.text.trim(),
            password: _password.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final nexveero = context.nexveero;

    return Scaffold(
      body: BlocListener<LoginCubit, AuthFormState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) async {
          if (state.status == FormStatus.success && state.session != null) {
            await context.read<AuthCubit>().onAuthenticated(state.session!);
            if (context.mounted) context.go(AppRoutes.feed);
          } else if (state.status == FormStatus.failure) {
            if (state.forbidden) {
              // Account pending or rejected approval → approval screen.
              final rejected = (state.errorMessage ?? '')
                  .toLowerCase()
                  .contains('reject');
              context.go(AppRoutes.pendingApproval, extra: rejected);
            } else {
              AppOverlays.snack(context, state.errorMessage ?? 'Login failed');
            }
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  const AuthBrandMark(),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Welcome back', style: texts.displayLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Sign in to continue to Nexveero',
                      style: texts.bodyLarge?.copyWith(color: nexveero.textSecondary)),
                  const SizedBox(height: AppSpacing.xxl),
                  BlocBuilder<LoginCubit, AuthFormState>(
                    builder: (context, state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AuthField(
                            controller: _email,
                            label: 'Email',
                            hint: 'you@email.com',
                            icon: Icons.alternate_email,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.email,
                            serverError: state.fieldError('email'),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AuthField(
                            controller: _password,
                            label: 'Password',
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            obscure: true,
                            validator: Validators.password,
                            serverError: state.fieldError('password'),
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _RememberForgotRow(
                            remember: _remember,
                            onRememberChanged: (v) => setState(() => _remember = v),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AppButton(
                            label: 'Log in',
                            isLoading: state.isSubmitting,
                            onPressed: _submit,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go(AppRoutes.register),
                      child: RichText(
                        text: TextSpan(
                          style: texts.bodyMedium?.copyWith(color: nexveero.textSecondary),
                          children: [
                            const TextSpan(text: 'New here? '),
                            TextSpan(
                              text: 'Create account',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RememberForgotRow extends StatelessWidget {
  const _RememberForgotRow({
    required this.remember,
    required this.onRememberChanged,
  });
  final bool remember;
  final ValueChanged<bool> onRememberChanged;

  @override
  Widget build(BuildContext context) {
    final nexveero = context.nexveero;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => onRememberChanged(!remember),
          child: Row(
            children: [
              Icon(
                remember ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: remember
                    ? Theme.of(context).colorScheme.primary
                    : nexveero.iconInactive,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Remember me',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        TextButton(
          onPressed: () => context.push(AppRoutes.forgotPassword),
          child: const Text('Forgot password?'),
        ),
      ],
    );
  }
}
