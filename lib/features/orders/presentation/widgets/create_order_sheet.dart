import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/order.dart';
import '../../domain/orders_repository.dart';

/// "New order" sheet (design "Create Order", HTML 4556): title, description,
/// amount (credits), notes → `POST /orders`. Returns the created [AppOrder] so
/// the chat can drop an order card into the thread. Opened from a chat thread,
/// so it carries the [conversationId].
class CreateOrderSheet {
  CreateOrderSheet._();

  static Future<AppOrder?> show(
    BuildContext context, {
    int? conversationId,
    int? loadId,
  }) {
    return showModalBottomSheet<AppOrder>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateOrderForm(
        conversationId: conversationId,
        loadId: loadId,
      ),
    );
  }
}

class _CreateOrderForm extends StatefulWidget {
  const _CreateOrderForm({this.conversationId, this.loadId});
  final int? conversationId;
  final int? loadId;

  @override
  State<_CreateOrderForm> createState() => _CreateOrderFormState();
}

class _CreateOrderFormState extends State<_CreateOrderForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  bool _submitting = false;

  bool get _valid =>
      _title.text.trim().isNotEmpty && (int.tryParse(_amount.text.trim()) ?? 0) > 0;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
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
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Success(value: final order):
        Navigator.of(context).pop(order);
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text('New order',
                          style: Theme.of(context).textTheme.titleLarge)),
                  InkResponse(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, color: context.nexveero.iconInactive),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _title,
                label: 'Order title',
                hint: 'Enter order title',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _desc,
                label: 'Description',
                hint: 'Enter description',
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _amount,
                label: 'Amount (credits)',
                hint: 'Enter amount',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                prefixIcon: Icons.toll,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _notes,
                label: 'Notes (optional)',
                hint: 'Add a note…',
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Send order',
                icon: Icons.send,
                isLoading: _submitting,
                onPressed: _valid ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
