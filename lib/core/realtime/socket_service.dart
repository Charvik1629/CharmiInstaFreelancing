import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../features/chat/domain/entities/chat_message.dart';
import '../../features/chat/domain/entities/unread_counts.dart';
import '../../features/chat/presentation/cubit/unread_cubit.dart';
import '../constants/api_endpoints.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../storage/storage_keys.dart';
import '../storage/storage_manager.dart';
import '../utils/logger.dart';

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

/// Socket.IO client for live chat + unread badges (design: realtime).
/// Connects to the `socket_url` from `GET /realtime/config`, authenticating with
/// the stored Sanctum token, and dispatches `message:new` / `unread:update`.
/// Falls back silently to the existing polling if the socket can't connect.
class SocketService {
  SocketService(this._client, this._storage);

  final ApiClient _client;
  final StorageManager _storage;

  io.Socket? _socket;
  final _messages = StreamController<RealtimeMessage>.broadcast();

  /// Broadcast of incoming messages; conversation screens filter by id.
  Stream<RealtimeMessage> get messages => _messages.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null) return;
    try {
      final res =
          await _client.get<Map<String, dynamic>>(ApiEndpoints.realtimeConfig);
      final data = res.data?['data'];
      final url = data is Map ? data['socket_url'] as String? : null;
      final token = await _storage.readSecure(StorageKeys.authToken);
      if (url == null || url.isEmpty || token == null) return;

      final socket = io.io(
        url,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .build(),
      );
      _socket = socket;

      socket.onConnect((_) => AppLogger.i('Socket connected'));
      socket.onConnectError((e) => AppLogger.w('Socket connect error: $e'));
      socket.on('message:new', _onMessage);
      socket.on('unread:update', _onUnread);
      socket.connect();
    } catch (e) {
      AppLogger.w('Socket connect failed: $e');
    }
  }

  /// Joins a conversation room so its messages stream in live.
  void joinConversation(int conversationId) {
    _socket?.emit('conversation:join', {'conversation_id': conversationId});
  }

  void typing(int conversationId, {required bool started}) {
    _socket?.emit(started ? 'typing:start' : 'typing:stop',
        {'conversation_id': conversationId});
  }

  void _onMessage(dynamic data) {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final convId = (json['conversation_id'] as num?)?.toInt();
    if (convId == null) return;
    _messages.add(RealtimeMessage(
      conversationId: convId,
      message: ChatMessage.fromJson(json),
      isBroadcast: json['is_broadcast'] == true,
    ));
  }

  void _onUnread(dynamic data) {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    if (!sl.isRegistered<UnreadCubit>()) return;
    sl<UnreadCubit>().setCounts(UnreadCounts(
      total: (json['total'] as num?)?.toInt() ?? 0,
      chats: (json['chats'] as num?)?.toInt() ?? 0,
      questions: (json['questions'] as num?)?.toInt() ?? 0,
      offers: (json['offers'] as num?)?.toInt() ?? 0,
    ));
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
  }
}
