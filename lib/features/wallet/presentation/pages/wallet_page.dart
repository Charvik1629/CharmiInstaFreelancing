import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../payment/data/iap_service.dart';
import '../../../payment/data/razorpay_checkout.dart';
import '../../../payment/presentation/widgets/payment_dialogs.dart';
import '../../../payment/presentation/widgets/payment_method_sheet.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../cubit/wallet_cubit.dart';

/// Wallet & credits (design "Wallet"). Balance, what actions cost, buy-credit
/// packages, and a link to Transactions. Purchases use Razorpay — gated until
/// the SDK + live keys are added (see MISSING_APIS "Wallet / Razorpay").
class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<WalletCubit>()..load(),
      child: const _WalletView(),
    );
  }
}

class _WalletView extends StatelessWidget {
  const _WalletView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Transactions',
            onPressed: () => context.push(AppRoutes.transactions),
          ),
        ],
      ),
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, state) {
          switch (state.status) {
            case WalletStatus.loading:
            case WalletStatus.initial:
              return const LoadingView();
            case WalletStatus.error:
              return ErrorView(
                message: state.errorMessage ?? 'Could not load your wallet',
                onRetry: () => context.read<WalletCubit>().load(),
              );
            case WalletStatus.loaded:
              final wallet = state.wallet!;
              return RefreshIndicator(
                onRefresh: () => context.read<WalletCubit>().refresh(),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _BalanceCard(wallet: wallet),
                    if (wallet.demoTopupEnabled) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Add ${wallet.demoTopupCredits} demo credits',
                        icon: Icons.add,
                        variant: AppButtonVariant.tonal,
                        isLoading: state.toppingUp,
                        onPressed: () async {
                          final balance =
                              await context.read<WalletCubit>().demoTopup();
                          if (context.mounted && balance != null) {
                            AppOverlays.snack(
                                context, 'Balance: $balance credits');
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _CostsCard(wallet: wallet),
                    const SizedBox(height: AppSpacing.xl),
                    if (state.packages.isNotEmpty) ...[
                      Text('Buy credits',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      for (final p in state.packages)
                        _PackageCard(package: p, wallet: wallet),
                    ],
                  ],
                ),
              );
          }
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});
  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: context.nexveero.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available credits',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: AppSpacing.xs),
          Text('${wallet.creditBalance}',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CostsCard extends StatelessWidget {
  const _CostsCard({required this.wallet});
  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, int cost) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text('$cost credits',
                  style: TextStyle(color: context.nexveero.textSecondary)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.nexveero.elevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What things cost',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          row('Post a listing', wallet.postCost),
          row('Boost a post', wallet.boostCost),
          row('Broadcast', wallet.broadcastCost),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package, required this.wallet});
  final CreditPackage package;
  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.nexveero.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${package.credits} credits',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(package.name,
                    style: TextStyle(color: context.nexveero.textSecondary)),
              ],
            ),
          ),
          AppButton(
            label: '₹${package.amount.toStringAsFixed(0)}',
            expanded: false,
            variant: AppButtonVariant.tonal,
            onPressed: () => _buy(context),
          ),
        ],
      ),
    );
  }

  /// Lets the buyer pick Razorpay (card/UPI) or store in-app purchase, then
  /// runs the chosen flow.
  Future<void> _buy(BuildContext context) async {
    final method = await PaymentMethodSheet.show(context);
    if (method == null || !context.mounted) return;
    switch (method) {
      case PaymentMethod.razorpay:
        await _buyRazorpay(context);
      case PaymentMethod.inAppPurchase:
        await _buyIap(context);
    }
  }

  /// Full Razorpay flow: checkout → open Razorpay → verify → refresh.
  /// Cancellations/failures are reported to `/wallet/payments/{id}/outcome`.
  Future<void> _buyRazorpay(BuildContext context) async {
    final repo = sl<WalletRepository>();
    final user = sl<AuthCubit>().state.user;

    final checkoutRes = await repo.checkout(package.id);
    if (!context.mounted) return;
    if (checkoutRes case Err(failure: final f)) {
      await PaymentDialogs.showResult(context, PaymentResult.failed,
          message: f.message);
      return;
    }
    final order = (checkoutRes as Success).value;

    final result = await RazorpayCheckout().open(
      keyId: order.razorpayKeyId,
      orderId: order.razorpayOrderId,
      amountPaise: order.amountPaise,
      description: '${order.credits} credits',
      name: user?.name,
      email: user?.email,
      contact: user?.phone,
    );
    if (!context.mounted) return;

    switch (result) {
      case RazorpaySuccess(:final paymentId, :final orderId, :final signature):
        final verifyRes = await repo.verify(
          paymentId: order.paymentId,
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: signature,
        );
        if (!context.mounted) return;
        if (verifyRes.isSuccess) {
          await context.read<WalletCubit>().refresh();
          if (context.mounted) {
            await PaymentDialogs.showResult(context, PaymentResult.success,
                message: '${order.credits} credits added to your wallet.');
          }
        } else {
          await PaymentDialogs.showResult(context, PaymentResult.pending,
              message: verifyRes.failureOrNull?.message ??
                  'We\'ll confirm your payment shortly.');
        }
      case RazorpayFailed(:final cancelled, :final message):
        await repo.reportOutcome(
            paymentId: order.paymentId,
            status: cancelled ? 'cancelled' : 'failed');
        if (!context.mounted) return;
        if (!cancelled) {
          await PaymentDialogs.showResult(context, PaymentResult.failed,
              message: message);
        }
    }
  }

  /// Apple/Google in-app purchase flow: buy the store product → send the receipt
  /// to the backend (`/wallet/iap/verify`) → refresh.
  Future<void> _buyIap(BuildContext context) async {
    final result = await IapService().buy(package.id);
    if (!context.mounted) return;
    switch (result) {
      case IapUnavailable():
        await PaymentDialogs.showResult(context, PaymentResult.failed,
            message: 'In-app purchases aren\'t available on this device.');
      case IapFailed(:final cancelled, :final message):
        if (!cancelled) {
          await PaymentDialogs.showResult(context, PaymentResult.failed,
              message: message);
        }
      case IapSuccess(
          :final verificationData,
          :final source,
          :final productId,
          :final transactionId
        ):
        // The API expects the store name: apple / google.
        final platform = source == 'app_store' ? 'apple' : 'google';
        final res = await sl<WalletRepository>().verifyIap(
          platform: platform,
          productId: productId,
          receiptData: platform == 'apple' ? verificationData : null,
          purchaseToken: platform == 'google' ? verificationData : null,
          transactionId: transactionId,
        );
        if (!context.mounted) return;
        if (res.isSuccess) {
          await context.read<WalletCubit>().refresh();
          if (context.mounted) {
            await PaymentDialogs.showResult(context, PaymentResult.success,
                message: '${package.credits} credits added to your wallet.');
          }
        } else {
          await PaymentDialogs.showResult(context, PaymentResult.pending,
              message: res.failureOrNull?.message ??
                  'We\'ll confirm your purchase shortly.');
        }
    }
  }
}
