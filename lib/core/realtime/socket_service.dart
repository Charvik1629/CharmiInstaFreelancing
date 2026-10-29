import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../features/chat/domain/entities/chat_message.dart';
import '../../features/chat/domain/entities/unread_counts.dart';
import '../../features/chat/presentation/cubit/unread_cubit.dart';
import '../constants/api_endpoints.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../storage/storage_keys.dart';
import '../config/app_config.dart';
import '../storage/storage_manager.dart';

/// A realtime message pushed over the socket (`message:new`).
class RealtimeMessage {
  const RealtimeMessage({
    required this.conversationId,
    required this.message,
    this.isBroadcast = false,
  });
  final int conversationId;
  final ChatMessage message;
  final bool isBroadcast;
}

/// Peer typing state pushed over the socket (`typing:update`).
class TypingEvent {
  const TypingEvent({
    required this.conversationId,
    this.userId,
    this.name,
    this.isTyping = false,
  });
  final int conversationId;
  final int? userId;
  final String? name;
  final bool isTyping;
}

/// Peer read marker pushed over the socket (`message:read`).
class ReadEvent {
  const ReadEvent({
    required this.conversationId,
    this.userId,
    required this.lastReadAt,
  });
  final int conversationId;
  final int? userId;
  final DateTime lastReadAt;
}

/// A user's online / last-seen status (`presence:update` or a `presence:check`
/// ack).
class PresenceEvent {
  const PresenceEvent({
    required this.userId,
    required this.isOnline,
    this.lastSeenAt,
  });
  final int userId;
  final bool isOnline;
  final DateTime? lastSeenAt;
}

/// A live in-app notification pushed over the socket (`notification:new`), e.g.
/// someone asked a question on your post, sent an offer, etc.
class NotificationEvent {
  const NotificationEvent({this.type, this.title, this.body, this.loadId});
  final String? type;
  final String? title;
  final String? body;
  final int? loadId;

  /// True when this is a "someone asked a question on your post" notification.
  bool get isQuestion => type == 'question' || type == 'question_asked';
}

/// A live `unread:update` (server → client). `conversationUnread` is that one
/// thread's unread after the change (0 once the viewer marks it read), so the
/// inbox can zero the matching row without a refetch.
class UnreadUpdate {
  const UnreadUpdate({
    this.total,
    this.conversationId,
    this.conversationUnread,
  });
  final int? total;
  final int? conversationId;
  final int? conversationUnread;
}

/// Socket.IO client for live chat + unread badges (design: realtime).
/// Connects to the `socket_url` from `GET /realtime/config`, authenticating with
/// the stored Sanctum token, and dispatches `message:new` / `unread:update`.
/// Falls back silently to the existing polling if the socket can't connect.
class SocketService {
  SocketService(this._client, this._storage);

  final ApiClient _client;
  final StorageManager _storage;

  io.Socket? _socket;

  /// Keeps our own presence "online": the server marks us offline after 60s
  /// without a `presence:ping`, so we heartbeat every 25s while foregrounded
  /// (per GET /realtime/config → presence.ping_interval_seconds).
  Timer? _pingTimer;

  final _messages = StreamController<RealtimeMessage>.broadcast();
  final _conversationCreated = StreamController<void>.broadcast();
  final _typingEvents = StreamController<TypingEvent>.broadcast();
  final _readEvents = StreamController<ReadEvent>.broadcast();
  final _presenceEvents = StreamController<PresenceEvent>.broadcast();
  final _notifications = StreamController<NotificationEvent>.broadcast();
  final _unreadUpdates = StreamController<UnreadUpdate>.broadcast();
  final _connected = StreamController<void>.broadcast();
  final _reportPending = StreamController<int?>.broadcast();

  /// Live pending-report count from `report:pending` (admins). The Settings
  /// "Reported posts" badge listens so admins see the count without reloading.
  /// Carries null when the server didn't include a count (just "there's a new
  /// one") — the UI then refetches the exact number.
  Stream<int?> get reportPendingUpdates => _reportPending.stream;

  /// Fires on every (re)connect. Events that arrive while the app is
  /// backgrounded (socket dropped) are NOT replayed on reconnect, so lists and
  /// open threads listen to this and refetch to catch up — this is what makes
  /// new chats/messages appear on resume without a manual pull-to-refresh.
  Stream<void> get connected => _connected.stream;

  /// Broadcast of incoming messages; conversation screens filter by id.
  Stream<RealtimeMessage> get messages => _messages.stream;

  /// Live `unread:update` events — the inbox listens to zero a specific row and
  /// refresh its counts without waiting for a manual pull-to-refresh.
  Stream<UnreadUpdate> get unreadUpdates => _unreadUpdates.stream;

  /// Online/last-seen changes for users (from `presence:update`).
  Stream<PresenceEvent> get presenceEvents => _presenceEvents.stream;

  /// Peer typing state per conversation (from `typing:update`).
  Stream<TypingEvent> get typingEvents => _typingEvents.stream;

  /// Peer read markers per conversation (from `message:read`).
  Stream<ReadEvent> get readEvents => _readEvents.stream;

  /// Fires when a new conversation is created for the user (e.g. someone
  /// requests their post) — the inbox listens and refreshes.
  Stream<void> get conversationCreated => _conversationCreated.stream;

  /// Live in-app notifications (from `notification:new`) — e.g. a new question
  /// on your post. The notifications inbox + a global toast listen to this.
  Stream<NotificationEvent> get notifications => _notifications.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Logcat-visible socket trace (mirrors the HTTP `NEXVEERO-HTTP` tag). Uses
  /// [debugPrint] because `dart:developer` logs don't surface in `adb logcat`.
  static const _tag = 'NEXVEERO-SOCKET';
  void _log(String msg) {
    if (AppConfig.current.enableLogging) debugPrint('$_tag $msg');
  }

  Future<void> connect() async {
    if (_socket != null) return;
    try {
      final res =
          await _client.get<Map<String, dynamic>>(ApiEndpoints.realtimeConfig);
      final data = res.data?['data'];
      final rawUrl = data is Map ? data['socket_url'] as String? : null;
      final token = await _storage.readSecure(StorageKeys.authToken);
      if (rawUrl == null || rawUrl.isEmpty || token == null) {
        _log('✗ no socket_url/token — realtime disabled, falling back to polling');
        return;
      }
      // The backend often reports a loopback socket_url (e.g.
      // http://127.0.0.1:3001) from its own host — unreachable from a phone. In
      // that case point the socket at the app's own API host (same base URL),
      // keeping the port the server advertised.
      final url = _resolveSocketUrl(rawUrl);
      _log('→ connecting to $url (from $rawUrl)');

      final socket = io.io(
        url,
        io.OptionBuilder()
            // Flutter's socket_io_client long-polling (XHR) transport is
            // unreliable and intermittently times out the handshake — on-device
            // testing showed polling+websocket connecting only sometimes. The
            // server supports a direct websocket upgrade (handshake advertises
            // upgrades:["websocket"]) and nginx proxies wss, so use websocket
            // only — the reliable transport for the Dart client. Reconnect with
            // backoff so a dropped socket (background/network blip) recovers.
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .enableReconnection()
            .setReconnectionAttempts(9999)
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(10000)
            .build(),
      );
      _socket = socket;

      socket.onConnect((_) {
        _log('✓ connected ($url)');
        _startHeartbeat();
        if (!_connected.isClosed) _connected.add(null);
      });
      socket.onDisconnect((r) {
        _log('✗ disconnected ($r)');
        _stopHeartbeat();
      });
      socket.onConnectError((e) => _log('✗ connect error: $e'));
      socket.onError((e) => _log('✗ error: $e'));
      socket.on('message:new', _onMessage);
      socket.on('unread:update', _onUnread);
      socket.on('conversation:created', _onConversationCreated);
      socket.on('typing:update', _onTyping);
      socket.on('message:read', _onRead);
      socket.on('presence:update', _onPresence);
      // Added to / changed membership of a group → refresh the inbox live.
      socket.on('group:added', _onGroupChange);
      socket.on('group:membership', _onGroupChange);
      // Admin realtime: new post report / new signup pending approval.
      socket.on('report:pending', _onReportPending);
      socket.on('user:pending', _onUserPending);
      // Group join requests (admin sees pending; requester sees the result).
      socket.on('join_request:pending', _onJoinRequestPending);
      socket.on('join_request:updated', _onGroupChange);
      // Legacy/compat: if the server ever emits a generic notification.
      socket.on('notification:new', _onNotification);
      socket.connect();
    } catch (e) {
      _log('✗ connect failed: $e');
    }
  }

  /// Maps a loopback `socket_url` (what the backend reports from its own host,
  /// e.g. `http://127.0.0.1:3001`) onto the app's own API host so a phone can
  /// actually reach it — keeping the port the server advertised. A non-loopback
  /// URL is used as-is.
  String _resolveSocketUrl(String raw) {
    try {
      final u = Uri.parse(raw);
      final host = u.host.toLowerCase();
      final isLoopback = host.isEmpty ||
          host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '0.0.0.0';
      if (!isLoopback) return raw;
      final base = Uri.parse(AppConfig.current.baseUrl);
      return u.replace(scheme: base.scheme, host: base.host).toString();
    } catch (_) {
      return raw;
    }
  }

  /// Joins a conversation room so its messages stream in live.
  void joinConversation(int conversationId) {
    _log('emit conversation:join #$conversationId');
    _socket?.emit('conversation:join', {'conversation_id': conversationId});
  }

  /// App came to the foreground — tell the server we're back (online) and
  /// resume the 25s heartbeat.
  void presenceResume() {
    _log('emit presence:resume');
    _socket?.emit('presence:resume');
    _startHeartbeat(); // ping now + every 25s
  }

  /// App backgrounded/inactive — tell the server we're away and stop pinging
  /// (the server stamps last_seen_at and marks us offline).
  void presenceAway() {
    _log('emit presence:away');
    _stopHeartbeat();
    _socket?.emit('presence:away');
  }

  /// Starts the `presence:ping` heartbeat (immediately, then every 25s).
  void _startHeartbeat() {
    _pingTimer?.cancel();
    _ping();
    _pingTimer =
        Timer.periodic(const Duration(seconds: 25), (_) => _ping());
  }

  void _stopHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _ping() {
    _log('emit presence:ping');
    _socket?.emit('presence:ping', {'active': true});
  }

  void typing(int conversationId, {required bool started}) {
    _socket?.emit(started ? 'typing:start' : 'typing:stop',
        {'conversation_id': conversationId});
  }

  void _onMessage(dynamic data) {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    // The message fields may be flat, or nested under `message`/`data` depending
    // on the socket server. Unwrap so `id` is always read from the real message.
    final inner = json['message'] is Map
        ? Map<String, dynamic>.from(json['message'] as Map)
        : (json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : json);
    final convId = ((json['conversation_id'] ?? inner['conversation_id']) as num?)
        ?.toInt();
    if (convId == null) {
      _log('event message:new — dropped (no conversation_id)');
      return;
    }
    final msg = ChatMessage.fromJson(inner);
    _log('event message:new conv#$convId msg#${msg.id} '
        'broadcast=${json['is_broadcast'] == true}');
    _messages.add(RealtimeMessage(
      conversationId: convId,
      message: msg,
      isBroadcast: json['is_broadcast'] == true,
    ));
  }

  void _onConversationCreated(dynamic data) {
    _log('event conversation:created');
    _conversationCreated.add(null);
    // The backend has no `notification:new`; a new question/offer arrives as a
    // freshly-created chat here. Surface a live toast for those.
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final inner = json['conversation'] is Map
        ? Map<String, dynamic>.from(json['conversation'] as Map)
        : json;
    final type = (inner['type'] ?? json['type']) as String?;
    if (type == 'question' || type == 'offer') {
      final who = (inner['subtitle'] ?? inner['title']) as String?;
      _notifications.add(NotificationEvent(
        type: type,
        title: type == 'question'
            ? 'New question${who != null ? ' from $who' : ''}'
            : 'New offer${who != null ? ' from $who' : ''}',
      ));
    }
  }

  void _onGroupChange(dynamic data) {
    _log('event group:membership/added');
    // Reuse the conversation-created signal so the inbox re-fetches.
    _conversationCreated.add(null);
  }

  /// `report:pending` → a new/updated post report (admins only). Surface it as a
  /// live notification so admins see it without reloading the reports screen.
  void _onReportPending(dynamic data) {
    final json = data is Map ? Map<String, dynamic>.from(data) : const {};
    _log('event report:pending pending=${json['pending_count']}');
    _reportPending.add((json['pending_count'] as num?)?.toInt());
    _notifications.add(const NotificationEvent(
      type: 'post_report',
      title: 'New post reported',
      body: 'A post was reported — review it in Reported posts.',
    ));
  }

  /// `user:pending` → a new signup (or approval change) awaiting admin review.
  void _onUserPending(dynamic data) {
    final json = data is Map ? Map<String, dynamic>.from(data) : const {};
    _log('event user:pending pending=${json['pending_count']}');
    _notifications.add(const NotificationEvent(
      type: 'user_pending',
      title: 'New signup pending',
      body: 'A new account is awaiting approval.',
    ));
  }

  /// `join_request:pending` → someone asked to join a group you manage.
  void _onJoinRequestPending(dynamic data) {
    _log('event join_request:pending');
    _notifications.add(const NotificationEvent(
      type: 'group_join_request',
      title: 'New group join request',
    ));
    _conversationCreated.add(null);
  }

  void _onNotification(dynamic data) {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    // Fields may be flat or nested under `notification`/`data`.
    final inner = json['notification'] is Map
        ? Map<String, dynamic>.from(json['notification'] as Map)
        : (json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : json);
    final event = NotificationEvent(
      type: inner['type'] as String?,
      title: inner['title'] as String?,
      body: (inner['body'] ?? inner['message']) as String?,
      loadId: (inner['load_id'] as num?)?.toInt(),
    );
    _log('event notification:new type=${event.type}');
    _notifications.add(event);
    // Keep the questions badge fresh when the server doesn't also push
    // unread:update for it.
    if (event.isQuestion && sl.isRegistered<UnreadCubit>()) {
      sl<UnreadCubit>().refresh();
    }
  }

  void _onTyping(dynamic data) {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final convId = (json['conversation_id'] as num?)?.toInt();
    if (convId == null) return;
    _typingEvents.add(TypingEvent(
      conversationId: convId,
      userId: (json['user_id'] as num?)?.toInt(),
      name: json['name'] as String?,
      isTyping: json['is_typing'] == true,
    ));
  }

  void _onPresence(dynamic data) {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final userId = (json['user_id'] as num?)?.toInt();
    if (userId == null) return;
    _presenceEvents.add(PresenceEvent(
      userId: userId,
      isOnline: json['status'] == 'online',
      lastSeenAt: DateTime.tryParse('${json['last_seen_at']}'),
    ));
  }

  /// Asks the server for the current online/last-seen status of [userIds].
  /// Returns a map of `userId → PresenceEvent`, or empty if unavailable.
  Future<Map<int, PresenceEvent>> checkPresence(List<int> userIds) async {
    final socket = _socket;
    if (socket == null || !socket.connected || userIds.isEmpty) return {};
    final completer = Completer<Map<int, PresenceEvent>>();
    try {
      socket.emitWithAck('presence:check', {'user_ids': userIds}, ack: (data) {
        final out = <int, PresenceEvent>{};
        if (data is Map) {
          data.forEach((k, v) {
            final id = int.tryParse('$k');
            if (id != null && v is Map) {
              out[id] = PresenceEvent(
                userId: id,
                isOnline: v['status'] == 'online',
                lastSeenAt: DateTime.tryParse('${v['last_seen_at']}'),
              );
            }
          });
        }
        if (!completer.isCompleted) completer.complete(out);
      });
    } catch (_) {
      return {};
    }
    return completer.future.timeout(const Duration(seconds: 4),
        onTimeout: () => {});
  }

  void _onRead(dynamic data) {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final convId = (json['conversation_id'] as num?)?.toInt();
    final lastReadAt = DateTime.tryParse('${json['last_read_at']}');
    if (convId == null || lastReadAt == null) return;
    _readEvents.add(ReadEvent(
      conversationId: convId,
      userId: (json['user_id'] as num?)?.toInt(),
      lastReadAt: lastReadAt,
    ));
  }

  void _onUnread(dynamic data) {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    _log('event unread:update total=${json['total']}');
    // Inbox rows listen to this regardless of the global badge cubit.
    _unreadUpdates.add(UnreadUpdate(
      total: (json['total'] as num?)?.toInt(),
      conversationId: (json['conversation_id'] as num?)?.toInt(),
      conversationUnread: (json['conversation_unread'] as num?)?.toInt(),
    ));
    if (!sl.isRegistered<UnreadCubit>()) return;
    sl<UnreadCubit>().setCounts(UnreadCounts(
      total: (json['total'] as num?)?.toInt() ?? 0,
      chats: (json['chats'] as num?)?.toInt() ?? 0,
      questions: (json['questions'] as num?)?.toInt() ?? 0,
      offers: (json['offers'] as num?)?.toInt() ?? 0,
    ));
  }

  Future<void> disconnect() async {
    _stopHeartbeat();
    _socket?.dispose();
    _socket = null;
  }

  /// Call when the app returns to the foreground. If the socket dropped while
  /// backgrounded it reconnects (onConnect then fires [connected]); if it stayed
  /// connected we still fire [connected] so lists/threads refetch and catch up
  /// anything that changed server-side while we were away.
  void onAppResumed() {
    final socket = _socket;
    if (socket == null) {
      connect();
    } else if (!socket.connected) {
      socket.connect();
    } else if (!_connected.isClosed) {
      _connected.add(null);
    }
  }
}
