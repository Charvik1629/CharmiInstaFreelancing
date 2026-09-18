import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../domain/entities/order.dart';

abstract class OrdersRemoteDataSource {
  Future<List<AppOrder>> listOrders({String? status});
  Future<AppOrder> getOrder(int id);
  Future<AppOrder> payOrder(int id);
  Future<AppOrder> updateOrderStatus(int id, String status, {String? notes});
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
  Future<List<AppOrder>> listOrders({String? status}) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.orders,
      query: {'status': ?status, 'per_page': 50},
    );
    return ApiEnvelope.list(res.data, AppOrder.fromJson).items;
  }

  @override
  Future<AppOrder> getOrder(int id) async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.order(id));
    return ApiEnvelope.object(res.data, AppOrder.fromJson);
  }

  @override
  Future<AppOrder> payOrder(int id) async {
    final res =
        await _client.post<Map<String, dynamic>>(ApiEndpoints.orderPay(id));
    return ApiEnvelope.object(res.data, AppOrder.fromJson);
  }

  @override
  Future<AppOrder> updateOrderStatus(int id, String status,
      {String? notes}) async {
    final res = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.order(id),
      data: {'status': status, 'notes': ?notes},
    );
    return ApiEnvelope.object(res.data, AppOrder.fromJson);
  }

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
