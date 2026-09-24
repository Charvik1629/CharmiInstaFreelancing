import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/widgets/widgets.dart';

/// Which contact the OTP was sent to — drives the copy, icon and step label.
enum OtpChannel { email, mobile }

/// OTP entry (design "Verify your email / mobile"). Six boxes with auto-advance/
/// backspace and a resend countdown — all client-side. Verification runs on
/// Firebase (pending config), so Verify surfaces a notice instead of faking it.
class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({
    super.key,
    this.destination,
    this.channel = OtpChannel.email,
  });
  final String? destination;
  final OtpChannel channel;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  static const _length = 6;
  final _controllers = List.generate(_length, (_) => TextEditingController());
  final _focusNodes = List.generate(_length, (_) => FocusNode());
  Timer? _timer;
  int _secondsLeft = 24;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 24);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();
  bool get _complete => _code.length == _length;

  void _onChanged(int i, String v) {
    if (v.isNotEmpty && i < _length - 1) _focusNodes[i + 1].requestFocus();
    if (v.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
    setState(() {});
  }

  Future<void> _verify() async {
    if (_submitting || !_complete) return;
    setState(() => _submitting = true);
    final result = await sl<AuthRepository>()
        .verifyOtp(identifier: widget.destination ?? '', code: _code);
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Success():
        AppOverlays.snack(context, 'Verified successfully.');
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }

  Future<void> _resend() async {
    _startCountdown();
    final result = await sl<AuthRepository>().sendOtp(widget.destination ?? '');
    if (!mounted) return;
    if (result case Err(failure: final f)) AppOverlays.snack(context, f.message);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final isEmail = widget.channel == OtpChannel.email;
    final to = widget.destination ?? (isEmail ? 'your email' : 'your mobile');
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: context.nexveero.gradientStart.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(
                    isEmail
                        ? Icons.mark_email_read
                        : Icons.smartphone,
                    color: context.nexveero.gradientStart,
                    size: 36),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text("Verify it's you", style: texts.displayLarge),
              const SizedBox(height: AppSpacing.xs),
              Text.rich(
                TextSpan(
                  style: texts.bodyLarge
                      ?.copyWith(color: context.nexveero.textSecondary),
                  children: [
                    const TextSpan(text: 'Enter the 6-digit code sent to\n'),
                    TextSpan(
                      text: to,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < _length; i++) _OtpBox(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    onChanged: (v) => _onChanged(i, v),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: _secondsLeft > 0
                    ? Text('Resend code in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                        style: texts.bodyMedium?.copyWith(color: context.nexveero.textSecondary))
                    : TextButton(onPressed: _resend, child: const Text('Resend code')),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                  label: 'Verify',
                  isLoading: _submitting,
                  onPressed: _complete ? _verify : null),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                  },
                  child: Text(isEmail ? 'Change email' : 'Change mobile'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _StepIndicator(channel: widget.channel),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 3-step onboarding progress (Email · Mobile · Approval).
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.channel});
  final OtpChannel channel;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final step = channel == OtpChannel.email ? 0 : 1;
    Widget dot(int i) {
      final active = i == step;
      final done = i < step;
      return Container(
        width: active ? 26 : 9,
        height: 5,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          gradient: active ? nex.primaryGradient : null,
          color: active ? null : (done ? nex.success : nex.border),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot(0),
          dot(1),
          dot(2),
          const SizedBox(width: 8),
          Text('Step ${step + 1} of 3 · ${channel == OtpChannel.email ? 'Email' : 'Mobile'}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: nex.textSecondary)),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.controller, required this.focusNode, required this.onChanged});
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: Theme.of(context).textTheme.titleLarge,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(counterText: ''),
      ),
    );
  }
}
