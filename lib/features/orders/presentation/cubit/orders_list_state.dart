part of 'orders_list_cubit.dart';

enum OrdersStatus { initial, loading, loaded, empty, error }

class OrdersListState extends Equatable {
  const OrdersListState({
    this.status = OrdersStatus.initial,
    this.orders = const [],
    this.errorMessage,
  });

  final OrdersStatus status;
  final List<AppOrder> orders;
  final String? errorMessage;

  OrdersListState copyWith({
    OrdersStatus? status,
    List<AppOrder>? orders,
    String? errorMessage,
  }) {
    return OrdersListState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, orders, errorMessage];
}
