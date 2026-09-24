import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Compose sheet for a one-to-one Inquiry (design "Inquiry compose"): an
/// "Inquiry" title with a close ✕, a multiline question field, an optional
/// ₹ price field, and a gradient "Send inquiry" button.
///
/// Returns the composed `(body, price)` on send, or `null` if dismissed.
/// [price] is `null` when the optional field was left empty.
class SendInquirySheet extends StatefulWidget {
  const SendInquirySheet({super.key});

  /// Opens the sheet and resolves with the inquiry to send, or `null` if the
  /// user dismissed it.
  static Future<({String body, String? price})?> show(BuildContext context) {
    return AppOverlays.sheet<({String body, String? price})>(
      context,
      builder: (_) => const SendInquirySheet(),
    );
  }

  @override
  State<SendInquirySheet> createState() => _SendInquirySheetState();
}

class _SendInquirySheetState extends State<SendInquirySheet> {
  final _body = TextEditingController();
  final _price = TextEditingController();
  String? _bodyError;

  @override
  void dispose() {
    _body.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    final body = _body.text.trim();
    if (body.isEmpty) {
      setState(() => _bodyError = 'Enter your question');
      return;
    }
    final price = _price.text.trim();
    Navigator.of(context).pop((body: body, price: price.isEmpty ? null : price));
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.help_outline, size: 18, color: primary),
            const SizedBox(width: 6),
            Text('Inquiry',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close, size: 20, color: nex.textSecondary),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          controller: _body,
          hint: 'Ask your question…',
          maxLines: 4,
          errorText: _bodyError,
          onChanged: (_) {
            if (_bodyError != null) setState(() => _bodyError = null);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Price (optional)',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600, color: nex.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          controller: _price,
          hint: '0',
          prefixIcon: Icons.currency_rupee,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Send inquiry',
          icon: Icons.send,
          onPressed: _submit,
        ),
      ],
    );
  }
}
