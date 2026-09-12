import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/extensions/json_extensions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/chat_label.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/unread_counts.dart';

/// A cursor page of messages (the API paginates newest-first with `before_id`).
class MessagePage {
  const MessagePage({required this.items, this.hasMore = false, this.nextBeforeId});
  final List<ChatMessage> items;
  final bool hasMore;
  final int? nextBeforeId;
}

/// Raw chat endpoint calls spanning all three chat kinds. Direct/group live
/// under /chats + /conversations; broadcasts under /broadcasts.
abstract class ChatRemoteDataSource {
  /// GET /chats — direct + group conversations (WhatsApp-style inbox).
  Future<List<Conversation>> getChats();

  /// GET /broadcasts — the user's broadcast lists.
  Future<List<Conversation>> getBroadcasts();

  /// GET /questions — the Q&A inbox (buyers' questions on your posts). Same row
  /// shape as GET /chats, so it decodes through [Conversation.fromChatJson].
  Future<List<Conversation>> getQuestions();

  /// Messages for a thread. Routes to /conversations or /broadcasts based on
  /// [type]. [beforeId] pages older messages.
  Future<MessagePage> getMessages({
    required int id,
    required ConversationType type,
    int? beforeId,
    int limit = 30,
  });

  /// Sends a message (text and/or an image attachment) to a direct/group
  /// conversation or a broadcast list. Multipart when [imagePath] is set.
  Future<ChatMessage> sendMessage({
    required int id,
    required ConversationType type,
    String body = '',
    String? imagePath,
  });

  /// PATCH /conversations/{id}/messages/{msgId} — edit a text message (≤1h).
  Future<ChatMessage> editMessage(int conversationId, int messageId, String body);

  /// DELETE /conversations/{id}/messages/{msgId} — delete a message (≤24h).
  Future<void> deleteMessage(int conversationId, int messageId);

  /// POST /conversations/{id}/messages with a location/contact meta payload.
  Future<ChatMessage> sendMeta({
    required int conversationId,
    required String type,
    required Map<String, dynamic> meta,
  });

  /// POST /users/{id}/block — block a user.
  Future<void> blockUser(int userId);

  /// Marks a direct/group conversation read (no-op concept for broadcasts).
  Future<void> markRead(int conversationId);

  /// GET /chats/unread-count — badge totals (chats + questions + offers).
  Future<UnreadCounts> getUnreadCounts();

  /// GET /chats/pin-requirement — whether starting a 1:1 with [userId] needs
  /// that user's chat PIN (first-time only).
  Future<bool> chatPinRequired(int userId);

  /// POST /chats — start or reopen a 1:1 chat. [pin] is the peer's 4-digit PIN,
  /// required first-time when they have Set-PIN on.
  Future<Conversation> startChat(int userId, {String? pin});

  // Labels.
  Future<List<ChatLabel>> getLabels();
  Future<ChatLabel> createLabel({
    required String name,
    String? color,
    required int sortOrder,
  });
  Future<ChatLabel> updateLabel({
    required int id,
    required String name,
    String? color,
    required int sortOrder,
  });
  Future<void> deleteLabel(int id);
  Future<void> attachLabel(int conversationId, int labelId);
  Future<void> detachLabel(int conversationId, int labelId);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  ChatRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<Conversation>> getChats() async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.chats);
    return _list(res.data, Conversation.fromChatJson);
  }

  @override
  Future<List<Conversation>> getBroadcasts() async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.broadcasts);
    return _list(res.data, Conversation.fromBroadcastJson);
  }

  @override
  Future<List<Conversation>> getQuestions() async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.questions);
    return _list(res.data, Conversation.fromChatJson);
  }

  @override
  Future<MessagePage> getMessages({
    required int id,
    required ConversationType type,
    int? beforeId,
    int limit = 30,
  }) async {
    final path = type == ConversationType.broadcast
        ? ApiEndpoints.broadcastMessages(id)
        : ApiEndpoints.conversationMessages(id);
    final res = await _client.get<Map<String, dynamic>>(
      path,
      query: {'limit': limit, 'before_id': ?beforeId},
    );
    final items = _list(res.data, ChatMessage.fromJson);
    final meta = res.data?.asMap('meta');
    return MessagePage(
      items: items,
      hasMore: meta?.asBool('has_more') ?? false,
      nextBeforeId: meta?.asInt('next_before_id'),
    );
  }

  @override
  Future<ChatMessage> sendMessage({
    required int id,
    required ConversationType type,
    String body = '',
    String? imagePath,
  }) async {
    final path = type == ConversationType.broadcast
        ? ApiEndpoints.broadcastMessages(id)
        : ApiEndpoints.conversationMessages(id);

    final Object data;
    if (imagePath != null && imagePath.isNotEmpty) {
      data = FormData.fromMap({
        if (body.isNotEmpty) 'body': body,
        // The API expects an attachments[] file array.
        'attachments[]': await MultipartFile.fromFile(
          imagePath,
          filename: imagePath.split('/').last,
        ),
      });
    } else {
      data = {'body': body};
    }

    final res = await _client.post<Map<String, dynamic>>(path, data: data);
    return ApiEnvelope.object(res.data, ChatMessage.fromJson);
  }

  @override
  Future<ChatMessage> editMessage(
      int conversationId, int messageId, String body) async {
    final res = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.conversationMessage(conversationId, messageId),
      data: {'body': body},
    );
    return ApiEnvelope.object(res.data, ChatMessage.fromJson);
  }

  @override
  Future<void> deleteMessage(int conversationId, int messageId) async {
    await _client.delete<dynamic>(
        ApiEndpoints.conversationMessage(conversationId, messageId));
  }

  @override
  Future<ChatMessage> sendMeta({
    required int conversationId,
    required String type,
    required Map<String, dynamic> meta,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.conversationMessages(conversationId),
      data: {'type': type, 'meta': meta},
    );
    return ApiEnvelope.object(res.data, ChatMessage.fromJson);
  }

  @override
  Future<void> blockUser(int userId) async {
    await _client.post<dynamic>(ApiEndpoints.userBlock(userId));
  }

  @override
  Future<void> markRead(int conversationId) async {
    await _client.post<dynamic>(ApiEndpoints.conversationRead(conversationId));
  }

  @override
  Future<UnreadCounts> getUnreadCounts() async {
    final res =
        await _client.get<Map<String, dynamic>>(ApiEndpoints.chatsUnreadCount);
    return ApiEnvelope.object(res.data, UnreadCounts.fromJson);
  }

  @override
  Future<bool> chatPinRequired(int userId) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.chatsPinRequirement,
      query: {'user_id': userId},
    );
    final data = res.data?.asMap('data');
    return data?.asBool('pin_required') ?? false;
  }

  @override
  Future<Conversation> startChat(int userId, {String? pin}) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.chats,
      data: {
        'user_id': userId,
        if (pin != null && pin.isNotEmpty) 'pin': pin,
      },
    );
    return ApiEnvelope.object(res.data, Conversation.fromStartChatJson);
  }

  Map<String, dynamic> _labelBody({
    required String name,
    String? color,
    required int sortOrder,
  }) =>
      {
        'name': name,
        if (color != null && color.isNotEmpty) 'color': color,
        'sort_order': sortOrder,
      };

  @override
  Future<List<ChatLabel>> getLabels() async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.chatLabels);
    return _list(res.data, ChatLabel.fromJson);
  }

  @override
  Future<ChatLabel> createLabel({
    required String name,
    String? color,
    required int sortOrder,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.chatLabels,
      data: _labelBody(name: name, color: color, sortOrder: sortOrder),
    );
    return ApiEnvelope.object(res.data, ChatLabel.fromJson);
  }

  @override
  Future<ChatLabel> updateLabel({
    required int id,
    required String name,
    String? color,
    required int sortOrder,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.chatLabel(id),
      data: _labelBody(name: name, color: color, sortOrder: sortOrder),
    );
    return ApiEnvelope.object(res.data, ChatLabel.fromJson);
  }

  @override
  Future<void> deleteLabel(int id) async {
    await _client.delete<dynamic>(ApiEndpoints.chatLabel(id));
  }

  @override
  Future<void> attachLabel(int conversationId, int labelId) async {
    await _client
        .post<dynamic>(ApiEndpoints.conversationLabel(conversationId, labelId));
  }

  @override
  Future<void> detachLabel(int conversationId, int labelId) async {
    await _client
        .delete<dynamic>(ApiEndpoints.conversationLabel(conversationId, labelId));
  }

  /// The messages/chats endpoints return `{ "data": [ ... ] }`; decode the
  /// array defensively (skip non-object entries).
  static List<T> _list<T>(
    Map<String, dynamic>? body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = body?['data'];
    final out = <T>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) out.add(fromJson(e));
      }
    }
    return out;
  }
}
