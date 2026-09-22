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

  /// Broadcast of incoming messages; conversation screens filter by id.
  Stream<RealtimeMessage> get messages => _messages.stream;

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
      final url = data is Map ? data['socket_url'] as String? : null;
      final token = await _storage.readSecure(StorageKeys.authToken);
      if (url == null || url.isEmpty || token == null) {
        _log('✗ no socket_url/token — realtime disabled, falling back to polling');
        return;
      }
      _log('→ connecting to $url');

      final socket = io.io(
        url,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .build(),
      );
      _socket = socket;

      socket.onConnect((_) {
        _log('✓ connected ($url)');
        _startHeartbeat();
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
      // Live notifications (new question on a post, offers, …).
      socket.on('notification:new', _onNotification);
      socket.connect();
    } catch (e) {
      _log('✗ connect failed: $e');
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
}
