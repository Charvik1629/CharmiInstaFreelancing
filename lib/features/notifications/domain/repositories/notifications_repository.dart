import '../../../../core/utils/result.dart';
import '../entities/app_notification.dart';

abstract class NotificationsRepository {
  Future<Result<List<AppNotification>>> getNotifications({int page});
  Future<Result<void>> markRead(int id);
  Future<Result<void>> markAllRead();
}
