import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../config/onesignal_config.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';
import '../utils/logger.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';

/// Push notifications via **OneSignal** (which relays to FCM/APNs server-side,
/// so the app avoids the firebase_core Android-Gradle build wall).
///
/// Fill in [OneSignalConfig.appId] to activate; until then every call is a
/// safe no-op. The static method name is kept as [initFirebase] so existing
/// call sites (main.dart) don't change.
class PushService {
  PushService(this._client);

  // ignore: unused_field
  final ApiClient _client;
  bool _started = false;

  /// Initializes the OneSignal SDK and routes notification taps. Called once at
  /// startup (before auth resolves).
  static Future<void> initFirebase() async {
    if (!OneSignalConfig.isConfigured) {
      AppLogger.w('OneSignal appId not set — push disabled.');
      return;
    }
    OneSignal.initialize(OneSignalConfig.appId);
    OneSignal.Notifications.addClickListener(_onClick);
  }

  /// After login: prompts for permission and ties this device to the user so
  /// the backend can target them by external id.
  Future<void> start() async {
    if (_started || !OneSignalConfig.isConfigured) return;
    _started = true;
    try {
      await OneSignal.Notifications.requestPermission(true);
      final userId = sl<AuthCubit>().state.user?.id;
      if (userId != null) await OneSignal.login('$userId');
    } catch (e) {
      AppLogger.w('Push start failed: $e');
    }
  }

  /// On logout: detaches the external id so pushes stop for this user.
  Future<void> unregister() async {
    _started = false;
    if (!OneSignalConfig.isConfigured) return;
    try {
      await OneSignal.logout();
    } catch (_) {}
  }

  /// Routes a notification tap by its `type` / `deep_link` payload.
  static void _onClick(OSNotificationClickEvent event) {
    final data = event.notification.additionalData ?? const {};
    final router = AppRouter.router;
    switch (data['type']) {
      case 'offer':
        router.push(AppRoutes.offers);
      case 'order_created':
      case 'order':
        router.push(AppRoutes.orders);
      case 'approval':
        router.push(AppRoutes.businessProfile);
      case 'chat_message':
      case 'chat':
        router.push(AppRoutes.feed);
      default:
        router.push(AppRoutes.notifications);
    }
  }
}
