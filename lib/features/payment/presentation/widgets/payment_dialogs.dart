import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// The payment result states from the design: success · pending · failed
/// (retry / change method) · refund. These are dialogs, not screens.
enum PaymentResult { success, pending, failed, refund }

class PaymentDialogs {
  PaymentDialogs._();

  /// Plays Processing → Successful as a labelled preview (real charging needs
  /// the Razorpay SDK). Returns nothing.
  static Future<void> runPreview(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProcessingDialog(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss processing
    await showResult(context, PaymentResult.success,
        message: 'This is a preview — no real charge was made.');
  }

  /// Shows one result state. For [PaymentResult.failed] the caller can act on
  /// the returned value: `'retry'` or `'change'` (else null).
  static Future<String?> showResult(
    BuildContext context,
    PaymentResult result, {
    String? message,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _ResultDialog(result: result, message: message),
    );
  }
}

class _ProcessingDialog extends StatelessWidget {
  const _ProcessingDialog();

  @override
  Widget build(BuildContext context) {
    return const Dialog(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 36, height: 36, child: CircularProgressIndicator()),
            SizedBox(height: AppSpacing.lg),
            Text('Processing…'),
          ],
        ),
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.result, this.message});

  final PaymentResult result;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final (icon, color, title, defaultMsg) = switch (result) {
      PaymentResult.success => (
          Icons.check_rounded,
          nex.success,
          'Payment successful',
          'Your order is confirmed.'
        ),
      PaymentResult.pending => (
          Icons.schedule,
          nex.warning,
          'Payment pending',
          'Your bank is confirming this payment. We\'ll update the order shortly.'
        ),
      PaymentResult.failed => (
          Icons.close_rounded,
          Theme.of(context).colorScheme.error,
          'Payment failed',
          'The request timed out. No money was deducted.'
        ),
      PaymentResult.refund => (
          Icons.replay,
          nex.info,
          'Refund initiated',
          'The amount returns to your source in 3–5 business days.'
        ),
    };
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, color: color, size: 34),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(message ?? defaultMsg,
                textAlign: TextAlign.center,
                style: TextStyle(color: nex.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
            if (result == PaymentResult.failed)
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Change method',
                      variant: AppButtonVariant.outline,
                      onPressed: () => Navigator.of(context).pop('change'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Retry',
                      onPressed: () => Navigator.of(context).pop('retry'),
                    ),
                  ),
                ],
              )
            else
              AppButton(
                label: result == PaymentResult.refund ? 'Track refund' : 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}
