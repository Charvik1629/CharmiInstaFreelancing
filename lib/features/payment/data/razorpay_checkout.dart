import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Outcome of a Razorpay checkout attempt.
sealed class RazorpayResult {
  const RazorpayResult();
}

class RazorpaySuccess extends RazorpayResult {
  const RazorpaySuccess({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });
  final String paymentId;
  final String orderId;
  final String signature;
}

class RazorpayFailed extends RazorpayResult {
  const RazorpayFailed({required this.code, required this.message});
  final int? code;
  final String message;
  bool get cancelled => code == Razorpay.PAYMENT_CANCELLED;
}

/// Thin wrapper around the Razorpay SDK that turns its event callbacks into a
/// single awaitable [RazorpayResult]. One instance per checkout attempt.
class RazorpayCheckout {
  final _razorpay = Razorpay();
  final _completer = Completer<RazorpayResult>();

  Future<RazorpayResult> open({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String description,
    String? name,
    String? email,
    String? contact,
  }) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    final prefill = <String, dynamic>{};
    if (email != null) prefill['email'] = email;
    if (contact != null) prefill['contact'] = contact;
    _razorpay.open({
      'key': keyId,
      'order_id': orderId,
      'amount': amountPaise,
      'currency': 'INR',
      'name': name ?? 'Nexveero',
      'description': description,
      if (prefill.isNotEmpty) 'prefill': prefill,
    });
    return _completer.future;
  }

  void _onSuccess(PaymentSuccessResponse r) {
    _finish(RazorpaySuccess(
      paymentId: r.paymentId ?? '',
      orderId: r.orderId ?? '',
      signature: r.signature ?? '',
    ));
  }

  void _onError(PaymentFailureResponse r) {
    _finish(RazorpayFailed(
        code: r.code, message: r.message ?? 'Payment failed'));
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    // The external wallet flow completes out of band; treat as pending-cancel.
    _finish(const RazorpayFailed(
        code: null, message: 'Continue in the selected wallet app.'));
  }

  void _finish(RazorpayResult result) {
    if (!_completer.isCompleted) _completer.complete(result);
    _razorpay.clear();
  }
}
