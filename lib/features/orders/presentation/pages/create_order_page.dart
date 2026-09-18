import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/orders_repository.dart';

/// New order (design "Create Order") → `POST /orders`. Settled in credits.
class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key, this.loadId, this.conversationId});

  /// Optional context when opened from a post or a chat.
  final int? loadId;
  final int? conversationId;

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  bool _submitting = false;

  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      (int.tryParse(_amount.text.trim()) ?? 0) > 0;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final result = await sl<OrdersRepository>().createOrder(
      loadId: widget.loadId,
      conversationId: widget.conversationId,
      amountCredits: int.parse(_amount.text.trim()),
      title: _title.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Success():
        AppOverlays.snack(context, 'Order created');
        context.pop();
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New order')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            AppTextField(
              controller: _title,
              label: 'What is this order for?',
              hint: 'Enter order title',
              prefixIcon: Icons.description_outlined,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _amount,
              label: 'Amount (credits)',
              hint: 'Enter amount',
              prefixIcon: Icons.toll,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _notes,
              label: 'Notes',
              hint: 'Add any details (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Create order',
              isLoading: _submitting,
              onPressed: _valid ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
