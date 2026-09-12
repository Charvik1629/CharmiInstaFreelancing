import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/offer.dart';
import '../../domain/repositories/offers_repository.dart';
import '../cubit/make_offer_cubit.dart';

/// "Make an offer" modal (design: Offer price · Remarks · Submit). Returns the
/// created [Offer] (with the opened conversation) on success, or null.
class MakeOfferSheet {
  MakeOfferSheet._();

  static Future<Offer?> show(
    BuildContext context, {
    required int loadId,
    String? loadTitle,
  }) {
    return showModalBottomSheet<Offer>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider(
        create: (_) => MakeOfferCubit(sl<OffersRepository>(), loadId),
        child: _MakeOfferForm(loadTitle: loadTitle),
      ),
    );
  }
}

/// Offer-price input with the ₹ prefix in brand colour (HTML 1639).
class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.onChanged,
    this.errorText,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: '15000',
        errorText: errorText,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 0),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 6),
          child: Text('₹',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary)),
        ),
      ),
    );
  }
}

class _MakeOfferForm extends StatefulWidget {
  const _MakeOfferForm({this.loadTitle});
  final String? loadTitle;

  @override
  State<_MakeOfferForm> createState() => _MakeOfferFormState();
}

class _MakeOfferFormState extends State<_MakeOfferForm> {
  final _price = TextEditingController();
  final _remarks = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: BlocListener<MakeOfferCubit, MakeOfferState>(
          listenWhen: (p, c) => p.status != c.status,
          listener: (context, state) {
            if (state.status == MakeOfferStatus.success) {
              Navigator.of(context).pop(state.created);
            } else if (state.status == MakeOfferStatus.failure &&
                state.fieldErrors.isEmpty) {
              AppOverlays.snack(context, state.errorMessage ?? 'Could not send offer');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: context.nexveero.border,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                Text('Make an offer',
                    style: Theme.of(context).textTheme.titleLarge),
                if ((widget.loadTitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(widget.loadTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: context.nexveero.textSecondary)),
                ],
                const SizedBox(height: AppSpacing.xl),
                // Design order (HTML 1633–1643): Remarks first, then Offer price.
                const SheetFieldLabel('Remarks'),
                BlocBuilder<MakeOfferCubit, MakeOfferState>(
                  buildWhen: (p, c) => p.fieldErrors['body'] != c.fieldErrors['body'],
                  builder: (context, state) => AppTextField(
                    controller: _remarks,
                    hint: 'Add a note with your offer',
                    maxLines: 3,
                    errorText: state.fieldErrors['body'],
                    onChanged: (v) => context.read<MakeOfferCubit>().setRemarks(v),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SheetFieldLabel('Offer price'),
                BlocBuilder<MakeOfferCubit, MakeOfferState>(
                  buildWhen: (p, c) => p.fieldErrors['price'] != c.fieldErrors['price'],
                  builder: (context, state) => _PriceField(
                    controller: _price,
                    errorText: state.fieldErrors['price'],
                    onChanged: (v) => context.read<MakeOfferCubit>().setPrice(v),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                BlocBuilder<MakeOfferCubit, MakeOfferState>(
                  buildWhen: (p, c) =>
                      p.canSubmit != c.canSubmit || p.isSubmitting != c.isSubmitting,
                  builder: (context, state) => Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Cancel',
                          variant: AppButtonVariant.outline,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: 'Submit',
                          isLoading: state.isSubmitting,
                          onPressed: state.canSubmit
                              ? () => context.read<MakeOfferCubit>().submit()
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
