import '../../../core/utils/result.dart';
import 'entities/order.dart';

abstract class OrdersRepository {
  /// POST /orders — create an order (settled in credits).
  Future<Result<AppOrder>> createOrder({
    int? loadId,
    int? conversationId,
    required int amountCredits,
    String? title,
    String? description,
    String? notes,
  });
}
