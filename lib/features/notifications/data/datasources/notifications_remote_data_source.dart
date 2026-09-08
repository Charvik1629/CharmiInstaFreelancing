import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/app_notification.dart';

abstract class NotificationsRemoteDataSource {
  Future<List<AppNotification>> getNotifications({int page = 1});
  Future<void> markRead(int id);
  Future<void> markAllRead();
}

class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  NotificationsRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<AppNotification>> getNotifications({int page = 1}) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.notifications,
      query: {'page': page},
    );
    return ApiEnvelope.list(res.data, AppNotification.fromJson).items;
  }

  @override
  Future<void> markRead(int id) async {
    await _client.post<dynamic>(ApiEndpoints.notificationRead(id));
  }

  @override
  Future<void> markAllRead() async {
    await _client.post<dynamic>(ApiEndpoints.notificationsReadAll);
  }
}
