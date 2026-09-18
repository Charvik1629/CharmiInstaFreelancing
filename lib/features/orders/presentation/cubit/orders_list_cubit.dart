import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/order.dart';
import '../../domain/orders_repository.dart';

part 'orders_list_state.dart';

/// Drives the Orders inbox (GET /orders — where you're buyer or seller).
class OrdersListCubit extends Cubit<OrdersListState> {
  OrdersListCubit(this._repository) : super(const OrdersListState());

  final OrdersRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: OrdersStatus.loading));
    final result = await _repository.listOrders();
    switch (result) {
      case Success(value: final orders):
        emit(state.copyWith(
          status: orders.isEmpty ? OrdersStatus.empty : OrdersStatus.loaded,
          orders: orders,
        ));
      case Err(failure: final f):
        emit(state.copyWith(status: OrdersStatus.error, errorMessage: f.message));
    }
  }

  Future<void> refresh() => load();
}
