import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/auth_form_state.dart';
import '../cubit/register_cubit.dart';
import '../widgets/auth_field.dart';

/// KYC options: the backend accepts a GST number, or both PAN and Aadhaar.
enum _KycMode { gst, panAadhaar }

/// Create-account screen (design "Register"). Collects the B2B fields the
/// `/auth/register` API accepts. The account is created as `pending` — no token
/// is issued — so on success the user is routed to the "Pending approval"
/// screen rather than into the app.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RegisterCubit>(),
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatefulWidget {
  const _RegisterView();

  @override
  State<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<_RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _gst = TextEditingController();
  final _pan = TextEditingController();
  final _aadhaar = TextEditingController();
  final _referral = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _KycMode _kyc = _KycMode.gst;

  @override
  void dispose() {
    _name.dispose();
    _business.dispose();
    _phone.dispose();
    _email.dispose();
    _gst.dispose();
    _pan.dispose();
    _aadhaar.dispose();
    _referral.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      final gstMode = _kyc == _KycMode.gst;
      context.read<RegisterCubit>().submit(
            name: _name.text.trim(),
            businessName: _business.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            gstNumber: gstMode ? _gst.text.trim().toUpperCase() : null,
            panNumber: gstMode ? null : _pan.text.trim().toUpperCase(),
            aadhaarNumber: gstMode ? null : _aadhaar.text.trim(),
            referralCode: _referral.text.trim(),
            password: _password.text,
            passwordConfirmation: _confirm.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(AppRoutes.login)),
      ),
      body: BlocListener<RegisterCubit, AuthFormState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) {
          if (state.status == FormStatus.success && state.user != null) {
            context.go(AppRoutes.pendingApproval, extra: state.user);
          } else if (state.status == FormStatus.failure) {
            AppOverlays.snack(
                context, state.errorMessage ?? 'Could not create account');
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
                  const AuthBrandMark(),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Create account', style: texts.displayLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Register your business on Nexveero. An admin reviews new '
                    'accounts before access is granted.',
                    style: texts.bodyLarge
                        ?.copyWith(color: context.nexveero.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  BlocBuilder<RegisterCubit, AuthFormState>(
                    builder: (context, state) {
                      return Column(
                        children: [
                          AuthField(
                            controller: _name,
                            label: 'Business owner name',
                            hint: 'As on GST / PAN',
                            icon: Icons.person_outline,
                            validator: Validators.name,
                            serverError: state.fieldError('name'),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AuthField(
                            controller: _business,
                            label: 'Business / firm name',
                            hint: 'Doe Transport',
                            icon: Icons.storefront_outlined,
                            validator: (v) =>
                                Validators.required(v, field: 'Business name'),
                            serverError: state.fieldError('business_name'),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AuthField(
                            controller: _phone,
                            label: 'Mobile number',
                            hint: '9876543210',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: Validators.phone,
                            serverError: state.fieldError('phone'),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AuthField(
                            controller: _email,
                            label: 'Email',
                            hint: 'you@business.com',
                            icon: Icons.alternate_email,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.email,
                            serverError: state.fieldError('email'),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _kycSelector(context),
                          const SizedBox(height: AppSpacing.lg),
                          ..._kycFields(state),
                          const SizedBox(height: AppSpacing.lg),
                          AuthField(
                            controller: _referral,
                            label: 'Referral code (optional)',
                            hint: 'ALICE10',
                            icon: Icons.card_giftcard_outlined,
                            validator: (_) => null,
                            serverError: state.fieldError('referral_code'),
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
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AuthField(
                            controller: _confirm,
                            label: 'Confirm password',
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            obscure: true,
                            validator: (v) =>
                                Validators.confirmPassword(v, _password.text),
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AppButton(
                            label: 'Create account',
                            isLoading: state.isSubmitting,
                            onPressed: _submit,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: const Text('Already have an account? Log in'),
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

  Widget _kycSelector(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<_KycMode>(
        segments: const [
          ButtonSegment(value: _KycMode.gst, label: Text('GST')),
          ButtonSegment(
              value: _KycMode.panAadhaar, label: Text('PAN + Aadhaar')),
        ],
        selected: {_kyc},
        onSelectionChanged: (s) => setState(() => _kyc = s.first),
        showSelectedIcon: false,
      ),
    );
  }

  List<Widget> _kycFields(AuthFormState state) {
    if (_kyc == _KycMode.gst) {
      return [
        AuthField(
          controller: _gst,
          label: 'GST number',
          hint: '27AAPFU0939F1ZV',
          icon: Icons.badge_outlined,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9a-zA-Z]')),
            LengthLimitingTextInputFormatter(15),
          ],
          validator: Validators.gst,
          serverError: state.fieldError('gst_number'),
        ),
      ];
    }
    return [
      AuthField(
        controller: _pan,
        label: 'PAN',
        hint: 'AAPFU0939F',
        icon: Icons.badge_outlined,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[0-9a-zA-Z]')),
          LengthLimitingTextInputFormatter(10),
        ],
        validator: Validators.pan,
        serverError: state.fieldError('pan_number'),
      ),
      const SizedBox(height: AppSpacing.lg),
      AuthField(
        controller: _aadhaar,
        label: 'Aadhaar number',
        hint: '234567890123',
        icon: Icons.badge_outlined,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(12),
        ],
        validator: Validators.aadhaar,
        serverError: state.fieldError('aadhaar_number'),
      ),
    ];
  }
}
