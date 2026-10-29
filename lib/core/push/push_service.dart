import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/chat/domain/entities/conversation.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../config/app_config.dart';
import '../constants/api_endpoints.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';
import '../utils/logger.dart';

/// Gated debug log for FCM diagnostics — silent in release builds (respects
/// [AppConfig.enableLogging]) so notification payloads never leak to logcat.
void _fcmLog(String msg) {
  if (AppConfig.current.enableLogging) debugPrint(msg);
}

/// Push notifications via **Firebase Cloud Messaging (FCM)**, direct — no
/// third-party relay. Android delivery uses the bundled `google-services.json`
/// (the google-services Gradle plugin wires it); iOS uses
/// `GoogleService-Info.plist` + APNs. The backend sends via the FCM Admin SDK,
/// targeting the token this device registers through `POST /devices`.
///
/// The static entry point keeps the name [initFirebase] so existing call sites
/// (main.dart) don't change.
class PushService {
  PushService(this._client);

  final ApiClient _client;
  bool _started = false;
  String? _lastToken;

  /// Local-notifications plugin + channel so FCM messages that arrive while the
  /// app is in the FOREGROUND still appear as a system banner (Android/iOS only
  /// auto-display them when the app is backgrounded).
  static final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'nexveero_default',
    'Nexveero',
    description: 'Chats, offers and activity',
    importance: Importance.high,
  );

  /// The conversation the user is currently viewing, if any. A foreground chat
  /// message for this same thread is already shown in-thread, so we suppress its
  /// banner. The chat thread page sets this on open and clears it on close.
  static int? activeConversationId;

  /// Call when a chat thread opens / closes so foreground banners for the thread
  /// the user is already looking at are suppressed.
  static void setActiveConversation(int? id) => activeConversationId = id;

  /// Initializes Firebase and wires notification-tap routing. Called once at
  /// startup (before auth resolves). Foreground messages are left to the app's
  /// in-app socket; here we only handle taps that open the app.
  static Future<void> initFirebase() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    await _initLocalNotifications();
    // Foreground messages: FCM delivers them to onMessage but the OS does NOT
    // show a banner while the app is open, so we display one ourselves.
    FirebaseMessaging.onMessage.listen((m) {
      _logPayload('onMessage', m);
      _showLocalNotification(m);
    });
    // Tap on a notification while the app is backgrounded/foregrounded.
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      _logPayload('onMessageOpenedApp', m);
      _route(m.data);
    });
    // Tap that cold-started the app.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _logPayload('initialMessage', initial);
      _route(initial.data);
    }
  }

  /// Sets up the local-notifications plugin + Android channel, and routes taps
  /// on a locally-shown notification by its stored data payload.
  static Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localNotifs.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          _route(Map<String, dynamic>.from(jsonDecode(payload) as Map));
        } catch (_) {/* ignore malformed payload */}
      },
    );
    final androidPlugin = _localNotifs.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();
    _fcmLog('NEXVEERO-FCM [local-init] done plugin=${androidPlugin != null}');
  }

  /// Shows a system banner for a foreground FCM message (uses its notification
  /// block, falling back to the data payload).
  static Future<void> _showLocalNotification(RemoteMessage m) async {
    final n = m.notification;
    final title = n?.title ?? m.data['title'] as String? ?? 'Nexveero';
    final body = n?.body ?? m.data['body'] as String? ?? '';
    _fcmLog('NEXVEERO-FCM [local-attempt] title=$title body=$body');
    if (body.isEmpty && (n?.title == null)) return;
    // Suppress a banner for the thread the user is already viewing — the message
    // is already appended in-thread by the socket, so a banner would be noise.
    final convId = int.tryParse('${m.data['conversation_id'] ?? ''}');
    if (convId != null && convId == activeConversationId) {
      _fcmLog('NEXVEERO-FCM [local-suppressed] active conv=$convId');
      return;
    }
    try {
      await _localNotifs.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode(m.data),
      );
      _fcmLog('NEXVEERO-FCM [local-shown] title=$title');
    } catch (e) {
      _fcmLog('NEXVEERO-FCM [local-FAILED] $e');
    }
  }

  /// Prints the full FCM payload (notification + data) to logcat.
  static void _logPayload(String where, RemoteMessage m) {
    _fcmLog('NEXVEERO-FCM [$where] '
        'notification=${m.notification == null ? 'null' : '{title:${m.notification!.title}, body:${m.notification!.body}}'} '
        'data=${m.data} messageId=${m.messageId}');
  }

  /// After login: prompts for permission, gets the FCM token and registers this
  /// device with the backend so it can target the user. Also keeps the token
  /// fresh via [FirebaseMessaging.onTokenRefresh].
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(_register);
    } catch (e) {
      AppLogger.w('Push start failed: $e');
    }
  }

  /// On logout: unregisters this device's token so pushes stop for this user.
  Future<void> unregister() async {
    _started = false;
    final token = _lastToken;
    try {
      if (token != null) {
        await _client.delete<dynamic>(ApiEndpoints.devices, data: {'token': token});
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Best-effort — a failed unregister must never block logout.
    }
    _lastToken = null;
  }

  /// Registers (or refreshes) the FCM token with the backend.
  Future<void> _register(String token) async {
    if (token == _lastToken) return;
    _lastToken = token;
    try {
      await _client.post<dynamic>(
        ApiEndpoints.devices,
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'provider': 'fcm',
        },
      );
    } catch (e) {
      AppLogger.w('Device register failed: $e');
    }
  }

  /// Routes a notification tap by its FCM `data.type` to the right screen.
  /// Types match the backend contract: chat_message, load_question, load_offer,
  /// post_report, user_pending, group_join_request, group_join_result.
  static void _route(Map<String, dynamic> data) {
    final router = AppRouter.router;
    switch (data['type']) {
      case 'load_offer':
      case 'offer':
        router.push(AppRoutes.offers);
      case 'post_report':
      case 'report':
        router.push(AppRoutes.adminReports);
      case 'user_pending':
        router.push(AppRoutes.adminUsers);
      case 'group_join_request':
      case 'group_join_result':
        router.push(AppRoutes.groups);
      case 'order_created':
      case 'order':
        router.push(AppRoutes.orders);
      case 'approval':
        router.push(AppRoutes.businessProfile);
      case 'chat_message':
      case 'load_question':
      case 'chat':
        _openChat(data);
      default:
        router.push(AppRoutes.notifications);
    }
  }

  /// Opens the chat thread named by the FCM `conversation_id`. The conversation
  /// isn't in the payload, so we fetch the inbox (chats, or questions for a
  /// `load_question`) and push the matching thread; if it can't be found we fall
  /// back to the chats list.
  static Future<void> _openChat(Map<String, dynamic> data) async {
    final router = AppRouter.router;
    final convId = int.tryParse('${data['conversation_id'] ?? ''}');
    if (convId == null || !sl.isRegistered<ChatRepository>()) {
      router.push(AppRoutes.feed);
      return;
    }
    final repo = sl<ChatRepository>();
    final result = data['type'] == 'load_question'
        ? await repo.getQuestions()
        : await repo.getChats();
    final convs = result.valueOrNull ?? const <Conversation>[];
    Conversation? match;
    for (final c in convs) {
      if (c.id == convId) {
        match = c;
        break;
      }
    }
    if (match != null) {
      router.push(AppRoutes.chatThread, extra: match);
    } else {
      router.push(AppRoutes.feed);
    }
  }
}

/// Background/terminated-state message handler. Must be a top-level function
/// annotated for the Flutter entry point. In-app UI can't run here; the OS
/// already shows the notification, so this is just a hook for future work.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  _fcmLog('NEXVEERO-FCM [background] '
      'notification=${message.notification == null ? 'null' : '{title:${message.notification!.title}, body:${message.notification!.body}}'} '
      'data=${message.data} messageId=${message.messageId}');
}
