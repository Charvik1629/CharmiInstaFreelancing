import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../widgets/payment_dialogs.dart';

/// Payment method (design "Payment Method"). UPI-first, matching the design.
/// Real charging needs the Razorpay SDK + keys, so "Pay" runs a clearly-labelled
/// preview of the result states, no charge. Razorpay covers UPI, so once keys are
/// wired this screen works as-is.
class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({super.key, this.amountLabel = '₹18,000', this.reference});

  final String amountLabel;
  final String? reference;

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

enum _Method { upi, card, netbanking, wallet }

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  _Method _selected = _Method.upi;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // amount card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: nex.primaryGradient,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.reference == null
                            ? 'Amount to pay'
                            : 'Paying for ${widget.reference}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.amountLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Sora',
                              fontWeight: FontWeight.w800,
                              fontSize: 32)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('PAY USING',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: nex.textSecondary, letterSpacing: 1)),
                const SizedBox(height: AppSpacing.sm),
                _UpiTile(
                  selected: _selected == _Method.upi,
                  onTap: () => setState(() => _selected = _Method.upi),
                ),
                _MethodTile(
                  icon: Icons.credit_card,
                  label: 'Card',
                  sub: 'Credit / debit card',
                  selected: _selected == _Method.card,
                  onTap: () => setState(() => _selected = _Method.card),
                ),
                _MethodTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Net banking',
                  sub: 'All major banks',
                  selected: _selected == _Method.netbanking,
                  onTap: () => setState(() => _selected = _Method.netbanking),
                ),
                _MethodTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Wallet credits',
                  sub: 'Not enough for this order',
                  selected: _selected == _Method.wallet,
                  enabled: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  AppButton(
                    label: 'Pay ${widget.amountLabel}${_selected == _Method.upi ? ' via UPI' : ''}',
                    onPressed: () => PaymentDialogs.runPreview(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: nex.iconInactive),
                      const SizedBox(width: 6),
                      Text('Preview only — connect Razorpay to take real payments.',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: nex.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpiTile extends StatelessWidget {
  const _UpiTile({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.04) : null,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: selected ? primary : nex.border,
              width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: nex.elevated,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.qr_code_2, color: primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('UPI',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('GPay, PhonePe, Paytm & more',
                          style: TextStyle(color: nex.textSecondary, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? primary : nex.iconInactive),
              ],
            ),
            if (selected) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  for (final app in ['GPay', 'PhonePe', 'Paytm', '+ UPI ID'])
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: nex.border),
                        ),
                        child: Text(app,
                            style: const TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final primary = Theme.of(context).colorScheme.primary;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: selected ? primary : nex.border,
              width: selected ? 1.5 : 1),
        ),
        child: ListTile(
          leading: Icon(icon,
              color: selected ? primary : nex.textSecondary),
          title: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub),
          trailing: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? primary : nex.iconInactive,
          ),
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}
