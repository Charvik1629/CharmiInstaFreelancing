import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../domain/entities/order.dart';

abstract class OrdersRemoteDataSource {
  Future<AppOrder> createOrder({
    int? loadId,
    int? conversationId,
    required int amountCredits,
    String? title,
    String? description,
    String? notes,
  });
}

class OrdersRemoteDataSourceImpl implements OrdersRemoteDataSource {
  OrdersRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<AppOrder> createOrder({
    int? loadId,
    int? conversationId,
    required int amountCredits,
    String? title,
    String? description,
    String? notes,
  }) async {
    final body = <String, dynamic>{'amount_credits': amountCredits};
    if (loadId != null) body['load_id'] = loadId;
    if (conversationId != null) body['conversation_id'] = conversationId;
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (notes != null) body['notes'] = notes;
    final res =
        await _client.post<Map<String, dynamic>>(ApiEndpoints.orders, data: body);
    return ApiEnvelope.object(res.data, AppOrder.fromJson);
  }
}
