import '../../../core/utils/result.dart';
import 'entities/order.dart';

abstract class OrdersRepository {
  /// GET /orders — orders where you are buyer or seller.
  Future<Result<List<AppOrder>>> listOrders({String? status});

  /// GET /orders/{id} — a single order's detail.
  Future<Result<AppOrder>> getOrder(int id);

  /// POST /orders — create an order (settled in credits).
  Future<Result<AppOrder>> createOrder({
    int? loadId,
    int? conversationId,
    required int amountCredits,
    String? title,
    String? description,
    String? notes,
  });

  /// POST /orders/{id}/pay — buyer pays with wallet credits.
  Future<Result<AppOrder>> payOrder(int id);

  /// PATCH /orders/{id} — non-payment status change (confirm/cancel/complete).
  Future<Result<AppOrder>> updateOrderStatus(int id, String status,
      {String? notes});
}
