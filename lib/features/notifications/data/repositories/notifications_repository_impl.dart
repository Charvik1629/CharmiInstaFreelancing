import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_data_source.dart';

class NotificationsRepositoryImpl
    with BaseRepository
    implements NotificationsRepository {
  NotificationsRepositoryImpl(this._remote);

  final NotificationsRemoteDataSource _remote;

  @override
  Future<Result<List<AppNotification>>> getNotifications({int page = 1}) =>
      guard(() => _remote.getNotifications(page: page));

  @override
  Future<Result<void>> markRead(int id) => guard(() => _remote.markRead(id));

  @override
  Future<Result<void>> markAllRead() => guard(_remote.markAllRead);
}
