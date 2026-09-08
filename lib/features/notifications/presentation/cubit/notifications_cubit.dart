import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';

part 'notifications_state.dart';

/// Drives the Notifications inbox. When the endpoint isn't live yet (404) it
/// degrades to a friendly [NotifStatus.gated] state instead of an error, so the
/// screen shows the design's "coming soon" copy until the backend adds it.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._repository) : super(const NotificationsState());

  final NotificationsRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: NotifStatus.loading));
    final result = await _repository.getNotifications(page: 1);
    switch (result) {
      case Success(value: final items):
        emit(state.copyWith(
          status: items.isEmpty ? NotifStatus.empty : NotifStatus.loaded,
          items: items,
        ));
      case Err(failure: final f):
        // No endpoint yet → gated (not an error the user must retry).
        emit(state.copyWith(
          status: f is NotFoundFailure ? NotifStatus.gated : NotifStatus.error,
          errorMessage: f.message,
        ));
    }
  }

  Future<void> refresh() => load();

  Future<void> markAllRead() async {
    if (state.items.every((n) => n.read)) return;
    emit(state.copyWith(
      items: state.items.map((n) => n.copyWith(read: true)).toList(),
    ));
    await _repository.markAllRead(); // best effort
  }

  Future<void> open(AppNotification n) async {
    if (n.read) return;
    emit(state.copyWith(
      items: state.items
          .map((x) => x.id == n.id ? x.copyWith(read: true) : x)
          .toList(),
    ));
    await _repository.markRead(n.id); // best effort
  }
}
