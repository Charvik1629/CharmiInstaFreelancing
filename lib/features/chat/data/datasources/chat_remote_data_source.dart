import '../../domain/entities/message_reaction.dart';
import '../../domain/entities/disappearing_settings.dart';
import '../../domain/entities/shared_content.dart';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/extensions/json_extensions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/broadcast_quota.dart';
import '../../domain/entities/chat_label.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/unread_counts.dart';

/// A cursor page of messages (the API paginates newest-first with `before_id`).
class MessagePage {
  const MessagePage({
    required this.items,
    this.hasMore = false,
    this.nextBeforeId,
  });
  final List<ChatMessage> items;
  final bool hasMore;
  final int? nextBeforeId;
}

/// Raw chat endpoint calls spanning all three chat kinds. Direct/group live
/// under /chats + /conversations; broadcasts under /broadcasts.
abstract class ChatRemoteDataSource {
  Future<SharedContent> getShared(
    int conversationId, {
    String type = 'media',
    int page = 1,
  });

  /// GET /chats — direct + group conversations (WhatsApp-style inbox).
  Future<List<Conversation>> getChats({
    String? hasMedia,
    bool hasLinks,
    String? q,
    String? kind,
  });

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
    List<String> attachmentPaths = const [],
    int? replyToMessageId,
  });

  /// GET /broadcasts/{id}/messages?per_page=1 — reads only `meta.
  /// broadcast_message_quota` so we know the free-message allowance BEFORE the
  /// first send. Returns null when the meta block is absent.
  Future<BroadcastQuota?> getBroadcastQuota(int id);

  /// PATCH /conversations/{id}/messages/{msgId} — edit a text message (≤1h).
  Future<ChatMessage> editMessage(
    int conversationId,
    int messageId,
    String body,
  );

  /// DELETE /conversations/{id}/messages/{msgId} — delete a message (≤24h).
  Future<void> deleteMessage(
    int conversationId,
    int messageId, {
    MessageDeleteScope scope = MessageDeleteScope.everyone,
  });
  Future<ReactionUpdate> react(
    int conversationId,
    int messageId,
    String? emoji,
  );
  Future<ChatMessage> keepMessage(int conversationId, int messageId);
  Future<void> deleteConversation(int conversationId);
  Future<Conversation> getConversation(int conversationId);
  Future<List<DisappearingDuration>> getDisappearingOptions();
  Future<DisappearingUpdate> setDisappearing(
    int conversationId, {
    required bool enabled,
    int? hours,
  });
  Future<void> starMessage(
    int conversationId,
    int messageId, {
    required bool star,
  });
  Future<void> pinConversation(int conversationId, {required bool pin});
  Future<List<ChatMessage>> getStarredMessages();

  /// POST /conversations/{id}/messages with a location meta payload.
  Future<ChatMessage> sendMeta({
    required int conversationId,
    required String type,
    required Map<String, dynamic> meta,
    int? replyToMessageId,
  });

  /// POST /conversations/{id}/messages with `type: inquiry` — a one-to-one
  /// inquiry ([body] required) with an optional INR [price] in `meta.price`.
  /// Direct chats only.
  Future<ChatMessage> sendInquiry({
    required int conversationId,
    required String body,
    String? price,
    int? replyToMessageId,
  });

  /// POST /users/{id}/block — block a user.
  Future<void> blockUser(int userId);

  /// Marks a direct/group conversation read (no-op concept for broadcasts).
  Future<void> markRead(int conversationId);

  /// GET /conversations/{id} → the peer's read cursor (`peer_last_read_at`) for
  /// 1:1 read ticks. Null for groups/broadcasts or when unset.
  Future<DateTime?> getPeerLastRead(int id);

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
  Future<SharedContent> getShared(
    int conversationId, {
    String type = 'media',
    int page = 1,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.conversationShared(conversationId),
      query: {'type': type, 'page': page, 'per_page': 20},
    );
    return SharedContent.fromResponse(response.data ?? {});
  }

  @override
  Future<List<Conversation>> getChats({
    String? hasMedia,
    bool hasLinks = false,
    String? q,
    String? kind,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.chats,
      query: {
        'type': ?kind,
        'has_media': ?hasMedia,
        if (hasLinks) 'has_links': 1,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    return _list(res.data, Conversation.fromChatJson);
  }

  @override
  Future<List<Conversation>> getBroadcasts() async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.broadcasts,
    );
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
    List<String> attachmentPaths = const [],
    int? replyToMessageId,
  }) async {
    final path = type == ConversationType.broadcast
        ? ApiEndpoints.broadcastMessages(id)
        : ApiEndpoints.conversationMessages(id);

    final Object data;
    if (attachmentPaths.isNotEmpty) {
      // The API accepts up to 5 files as an attachments[] array.
      data = FormData.fromMap({
        if (body.isNotEmpty) 'body': body,
        'reply_to_message_id': ?replyToMessageId,
        'attachments[]': [
          for (final p in attachmentPaths)
            await MultipartFile.fromFile(p, filename: p.split('/').last),
        ],
      });
    } else {
      data = {'body': body, 'reply_to_message_id': ?replyToMessageId};
    }

    final res = await _client.post<Map<String, dynamic>>(path, data: data);
    return ApiEnvelope.object(res.data, ChatMessage.fromJson);
  }

  @override
  Future<BroadcastQuota?> getBroadcastQuota(int id) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.broadcastMessages(id),
      query: {'per_page': 1},
    );
    final quota = res.data?.asMap('meta')?.asMap('broadcast_message_quota');
    return quota == null ? null : BroadcastQuota.fromJson(quota);
  }

  @override
  Future<ChatMessage> editMessage(
    int conversationId,
    int messageId,
    String body,
  ) async {
    final res = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.conversationMessage(conversationId, messageId),
      data: {'body': body},
    );
    return ApiEnvelope.object(res.data, ChatMessage.fromJson);
  }

  @override
  Future<void> deleteMessage(
    int conversationId,
    int messageId, {
    MessageDeleteScope scope = MessageDeleteScope.everyone,
  }) async {
    await _client.delete<dynamic>(
      ApiEndpoints.conversationMessage(conversationId, messageId),
      data: {'for': scope.name},
    );
  }

  @override
  Future<ReactionUpdate> react(
    int conversationId,
    int messageId,
    String? emoji,
  ) async {
    final path = ApiEndpoints.messageReaction(conversationId, messageId);
    final response = emoji == null
        ? await _client.delete<Map<String, dynamic>>(path)
        : await _client.put<Map<String, dynamic>>(path, data: {'emoji': emoji});
    return ApiEnvelope.object(response.data, ReactionUpdate.fromJson);
  }

  @override
  Future<ChatMessage> keepMessage(int conversationId, int messageId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.messageKeep(conversationId, messageId),
    );
    return ApiEnvelope.object(response.data, ChatMessage.fromJson);
  }

  @override
  Future<void> deleteConversation(int conversationId) async {
    await _client.delete<dynamic>(ApiEndpoints.conversation(conversationId));
  }

  @override
  Future<Conversation> getConversation(int conversationId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.conversation(conversationId),
    );
    return ApiEnvelope.object(response.data, Conversation.fromChatJson);
  }

  @override
  Future<List<DisappearingDuration>> getDisappearingOptions() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.disappearingOptions,
    );
    final data = response.data?['data'];
    final items = data is Map ? data['durations'] : null;
    return [
      for (final item in items is List ? items : const [])
        if (item is Map<String, dynamic>) DisappearingDuration.fromJson(item),
    ];
  }

  @override
  Future<DisappearingUpdate> setDisappearing(
    int conversationId, {
    required bool enabled,
    int? hours,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.conversationDisappearing(conversationId),
      data: {
        'enabled': enabled,
        if (enabled && hours != null) 'duration_hours': hours,
      },
    );
    return ApiEnvelope.object(response.data, DisappearingUpdate.fromJson);
  }

  @override
  Future<void> starMessage(
    int conversationId,
    int messageId, {
    required bool star,
  }) async {
    final path = ApiEndpoints.conversationMessageStar(
      conversationId,
      messageId,
    );
    if (star) {
      await _client.post<dynamic>(path);
    } else {
      await _client.delete<dynamic>(path);
    }
  }

  @override
  Future<List<ChatMessage>> getStarredMessages() async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.messagesStarred,
      query: {'per_page': 50},
    );
    return _list(res.data, ChatMessage.fromJson);
  }

  @override
  Future<void> pinConversation(int conversationId, {required bool pin}) async {
    final path = ApiEndpoints.conversationPin(conversationId);
    if (pin) {
      await _client.post<dynamic>(path);
    } else {
      await _client.delete<dynamic>(path);
    }
  }

  @override
  Future<ChatMessage> sendMeta({
    required int conversationId,
    required String type,
    required Map<String, dynamic> meta,
    int? replyToMessageId,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.conversationMessages(conversationId),
      data: {
        'type': type,
        'meta': meta,
        'reply_to_message_id': ?replyToMessageId,
      },
    );
    return ApiEnvelope.object(res.data, ChatMessage.fromJson);
  }

  @override
  Future<ChatMessage> sendInquiry({
    required int conversationId,
    required String body,
    String? price,
    int? replyToMessageId,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.conversationMessages(conversationId),
      data: {
        'type': 'inquiry',
        'body': body,
        'reply_to_message_id': ?replyToMessageId,
        if (price != null && price.isNotEmpty) 'meta': {'price': price},
      },
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
  Future<DateTime?> getPeerLastRead(int id) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.conversation(id),
    );
    final data = res.data?['data'];
    if (data is Map) return DateTime.tryParse('${data['peer_last_read_at']}');
    return null;
  }

  @override
  Future<UnreadCounts> getUnreadCounts() async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.chatsUnreadCount,
    );
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
      data: {'user_id': userId, if (pin != null && pin.isNotEmpty) 'pin': pin},
    );
    return ApiEnvelope.object(res.data, Conversation.fromStartChatJson);
  }

  Map<String, dynamic> _labelBody({
    required String name,
    String? color,
    required int sortOrder,
  }) => {
    'name': name,
    if (color != null && color.isNotEmpty) 'color': color,
    'sort_order': sortOrder,
  };

  @override
  Future<List<ChatLabel>> getLabels() async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.chatLabels,
    );
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
    await _client.post<dynamic>(
      ApiEndpoints.conversationLabel(conversationId, labelId),
    );
  }

  @override
  Future<void> detachLabel(int conversationId, int labelId) async {
    await _client.delete<dynamic>(
      ApiEndpoints.conversationLabel(conversationId, labelId),
    );
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
