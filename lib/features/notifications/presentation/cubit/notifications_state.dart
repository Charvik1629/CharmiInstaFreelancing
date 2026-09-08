part of 'notifications_cubit.dart';

enum NotifStatus { initial, loading, loaded, empty, gated, error }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotifStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final NotifStatus status;
  final List<AppNotification> items;
  final String? errorMessage;

  bool get hasUnread => items.any((n) => !n.read);

  NotificationsState copyWith({
    NotifStatus? status,
    List<AppNotification>? items,
    String? errorMessage,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
