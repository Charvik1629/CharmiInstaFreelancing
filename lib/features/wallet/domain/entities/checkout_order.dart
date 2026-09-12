import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// Result of `POST /wallet/checkout` — a Razorpay order created for a credit
/// package. Feeds the Razorpay checkout sheet, and [paymentId] is echoed back
/// to `POST /wallet/verify`.
class CheckoutOrder extends Equatable {
  const CheckoutOrder({
    required this.paymentId,
    required this.credits,
    required this.amountPaise,
    required this.razorpayKeyId,
    required this.razorpayOrderId,
  });

  final int paymentId;
  final int credits;
  final int amountPaise;
  final String razorpayKeyId;
  final String razorpayOrderId;

  factory CheckoutOrder.fromJson(Map<String, dynamic> json) => CheckoutOrder(
        paymentId: json.asIntOr('payment_id', 0),
        credits: json.asIntOr('credits', 0),
        amountPaise: json.asIntOr('amount_paise', 0),
        razorpayKeyId: json.asStringOr('razorpay_key_id', ''),
        razorpayOrderId: json.asStringOr('razorpay_order_id', ''),
      );

  @override
  List<Object?> get props =>
      [paymentId, credits, amountPaise, razorpayKeyId, razorpayOrderId];
}
