import '../../../core/network/base_repository.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/order.dart';
import '../domain/orders_repository.dart';
import 'orders_remote_data_source.dart';

class OrdersRepositoryImpl with BaseRepository implements OrdersRepository {
  OrdersRepositoryImpl(this._remote);

  final OrdersRemoteDataSource _remote;

  @override
  Future<Result<List<AppOrder>>> listOrders({String? status}) =>
      guard(() => _remote.listOrders(status: status));

  @override
  Future<Result<AppOrder>> getOrder(int id) =>
      guard(() => _remote.getOrder(id));

  @override
  Future<Result<AppOrder>> payOrder(int id) =>
      guard(() => _remote.payOrder(id));

  @override
  Future<Result<AppOrder>> updateOrderStatus(int id, String status,
          {String? notes}) =>
      guard(() => _remote.updateOrderStatus(id, status, notes: notes));

  @override
  Future<Result<AppOrder>> createOrder({
    int? loadId,
    int? conversationId,
    required int amountCredits,
    String? title,
    String? description,
    String? notes,
  }) =>
      guard(() => _remote.createOrder(
            loadId: loadId,
            conversationId: conversationId,
            amountCredits: amountCredits,
            title: title,
            description: description,
            notes: notes,
          ));
}
