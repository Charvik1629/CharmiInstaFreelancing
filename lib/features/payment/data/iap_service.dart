import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// Outcome of an Apple/Google in-app purchase attempt.
sealed class IapResult {
  const IapResult();
}

class IapSuccess extends IapResult {
  const IapSuccess({
    required this.productId,
    required this.verificationData,
    required this.source,
    this.transactionId,
  });

  /// Store product identifier that was purchased.
  final String productId;

  /// Store-signed receipt/token to send to the backend for verification
  /// (Apple: base64 receipt; Google: purchase token).
  final String verificationData;

  /// `app_store` or `play_store`.
  final String source;
  final String? transactionId;
}

class IapFailed extends IapResult {
  const IapFailed({required this.message, this.cancelled = false});
  final String message;
  final bool cancelled;
}

class IapUnavailable extends IapResult {
  const IapUnavailable();
}

/// Thin wrapper around `in_app_purchase` for buying a single consumable credit
/// package. Products must be configured in App Store Connect / Play Console with
/// ids matching [productIdForPackage]; the store receipt is then verified by the
/// backend (a `/wallet/iap/verify` endpoint — pending).
class IapService {
  final _iap = InAppPurchase.instance;

  /// Convention for the store product id of a credit package.
  static String productIdForPackage(int packageId) =>
      'nexveero_credits_$packageId';

  Future<IapResult> buy(int packageId) async {
    if (!await _iap.isAvailable()) return const IapUnavailable();

    final productId = productIdForPackage(packageId);
    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      return IapFailed(
          message: 'Product $productId is not available in the store.');
    }
    final product = response.productDetails.first;

    final completer = Completer<IapResult>();
    late final StreamSubscription<List<PurchaseDetails>> sub;
    sub = _iap.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.productID != productId) continue;
        switch (p.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            if (p.pendingCompletePurchase) await _iap.completePurchase(p);
            if (!completer.isCompleted) {
              completer.complete(IapSuccess(
                productId: productId,
                verificationData: p.verificationData.serverVerificationData,
                source: p.verificationData.source,
                transactionId: p.purchaseID,
              ));
            }
          case PurchaseStatus.error:
            if (!completer.isCompleted) {
              completer.complete(
                  IapFailed(message: p.error?.message ?? 'Purchase failed'));
            }
          case PurchaseStatus.canceled:
            if (!completer.isCompleted) {
              completer.complete(
                  const IapFailed(message: 'Cancelled', cancelled: true));
            }
          case PurchaseStatus.pending:
            break;
        }
      }
    });

    await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product));

    final result = await completer.future;
    await sub.cancel();
    return result;
  }
}
