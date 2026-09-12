import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../firebase_options.dart';
import '../constants/api_endpoints.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';
import '../utils/logger.dart';

/// Handles a background/terminated push. Must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // No heavy work here; the OS displays the notification. Deep-link handling
  // happens when the user taps it (onMessageOpenedApp).
}

/// Firebase Cloud Messaging: registers the device token with the backend
/// (`POST /devices`) and routes notification taps to the right screen.
/// Initialised after login so the token is tied to the authenticated user.
class PushService {
  PushService(this._client);

  final ApiClient _client;
  bool _started = false;

  static Future<void> initFirebase() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  }

  /// Requests permission, registers the token, and wires tap handling. Safe to
  /// call more than once.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) await _register(token);
      messaging.onTokenRefresh.listen(_register);

      // Cold start from a notification tap.
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleTap(initial);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    } catch (e) {
      AppLogger.w('Push init failed: $e');
    }
  }

  Future<void> _register(String token) async {
    try {
      await _client.post<dynamic>(ApiEndpoints.devices, data: {
        'token': token,
        'device_name': Platform.isIOS ? 'ios' : 'android',
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (e) {
      AppLogger.w('Device registration failed: $e');
    }
  }

  /// Unregisters the current device (call on logout).
  Future<void> unregister() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await _client.delete<dynamic>(ApiEndpoints.devices,
          data: token == null ? null : {'token': token});
    } catch (_) {}
  }

  /// Routes a notification tap by its `type` / `deep_link` payload.
  void _handleTap(RemoteMessage message) {
    final data = message.data;
    final router = AppRouter.router;
    switch (data['type']) {
      case 'offer':
        router.push(AppRoutes.offers);
      case 'order_created':
      case 'order':
        router.push(AppRoutes.orders);
      case 'approval':
        router.push(AppRoutes.businessProfile);
      default:
        router.push(AppRoutes.notifications);
    }
  }
}
