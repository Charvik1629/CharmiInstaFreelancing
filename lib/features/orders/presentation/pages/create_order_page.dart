import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// New order (design "Create Order"). Gated — no `/orders` API yet
/// (MISSING_APIS #9). The form is ready; submit is disabled with a note.
class CreateOrderPage extends StatelessWidget {
  const CreateOrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New order')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const AppTextField(
              label: 'What is this order for?',
              hint: 'e.g. Lisbon full photo set',
              prefixIcon: Icons.description_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppTextField(
              label: 'Amount',
              hint: '0.00',
              prefixIcon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppTextField(
              label: 'Notes',
              hint: 'Add any details (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Create order',
              onPressed: () => AppOverlays.snack(
                  context, 'Orders need a backend endpoint (see MISSING_APIS #9).'),
            ),
          ],
        ),
      ),
    );
  }
}
