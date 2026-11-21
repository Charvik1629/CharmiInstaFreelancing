import '../../domain/entities/message_reaction.dart';
import '../../domain/entities/disappearing_settings.dart';
import '../../domain/entities/shared_content.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/broadcast_quota.dart';
import '../../domain/entities/chat_label.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/unread_counts.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';

class ChatRepositoryImpl with BaseRepository implements ChatRepository {
  ChatRepositoryImpl(this._remote);

  final ChatRemoteDataSource _remote;

  @override
  Future<Result<SharedContent>> getShared(
    int conversationId, {
    String type = 'media',
    int page = 1,
  }) => guard(() => _remote.getShared(conversationId, type: type, page: page));

  @override
  Future<Result<List<Conversation>>> getChats({
    String? hasMedia,
    bool hasLinks = false,
    String? q,
    String? kind,
  }) => guard(
    () => _remote.getChats(
      hasMedia: hasMedia,
      hasLinks: hasLinks,
      q: q,
      kind: kind,
    ),
  );

  @override
  Future<Result<List<Conversation>>> getBroadcasts() =>
      guard(() => _remote.getBroadcasts());

  @override
  Future<Result<List<Conversation>>> getQuestions() =>
      guard(() => _remote.getQuestions());

  @override
  Future<Result<MessagePage>> getMessages({
    required int id,
    required ConversationType type,
    int? beforeId,
  }) =>
      guard(() => _remote.getMessages(id: id, type: type, beforeId: beforeId));

  @override
  Future<Result<ChatMessage>> sendMessage({
    required int id,
    required ConversationType type,
    String body = '',
    List<String> attachmentPaths = const [],
    int? replyToMessageId,
  }) => guard(
    () => _remote.sendMessage(
      id: id,
      type: type,
      body: body,
      attachmentPaths: attachmentPaths,
      replyToMessageId: replyToMessageId,
    ),
  );

  @override
  Future<Result<BroadcastQuota?>> getBroadcastQuota(int id) =>
      guard(() => _remote.getBroadcastQuota(id));

  @override
  Future<Result<ChatMessage>> editMessage(
    int conversationId,
    int messageId,
    String body,
  ) => guard(() => _remote.editMessage(conversationId, messageId, body));

  @override
  Future<Result<void>> deleteMessage(
    int conversationId,
    int messageId, {
    MessageDeleteScope scope = MessageDeleteScope.everyone,
  }) => guard(
    () => _remote.deleteMessage(conversationId, messageId, scope: scope),
  );

  @override
  Future<Result<ReactionUpdate>> react(
    int conversationId,
    int messageId,
    String? emoji,
  ) => guard(() => _remote.react(conversationId, messageId, emoji));
  @override
  Future<Result<ChatMessage>> keepMessage(int conversationId, int messageId) =>
      guard(() => _remote.keepMessage(conversationId, messageId));
  @override
  Future<Result<void>> deleteConversation(int conversationId) =>
      guard(() => _remote.deleteConversation(conversationId));
  @override
  Future<Result<Conversation>> getConversation(int conversationId) =>
      guard(() => _remote.getConversation(conversationId));
  @override
  Future<Result<List<DisappearingDuration>>> getDisappearingOptions() =>
      guard(_remote.getDisappearingOptions);
  @override
  Future<Result<DisappearingUpdate>> setDisappearing(
    int conversationId, {
    required bool enabled,
    int? hours,
  }) => guard(
    () =>
        _remote.setDisappearing(conversationId, enabled: enabled, hours: hours),
  );

  @override
  Future<Result<void>> starMessage(
    int conversationId,
    int messageId, {
    required bool star,
  }) => guard(() => _remote.starMessage(conversationId, messageId, star: star));

  @override
  Future<Result<void>> pinConversation(
    int conversationId, {
    required bool pin,
  }) => guard(() => _remote.pinConversation(conversationId, pin: pin));

  @override
  Future<Result<List<ChatMessage>>> getStarredMessages() =>
      guard(() => _remote.getStarredMessages());

  @override
  Future<Result<ChatMessage>> sendMeta({
    required int conversationId,
    required String type,
    required Map<String, dynamic> meta,
    int? replyToMessageId,
  }) => guard(
    () => _remote.sendMeta(
      conversationId: conversationId,
      type: type,
      meta: meta,
      replyToMessageId: replyToMessageId,
    ),
  );

  @override
  Future<Result<ChatMessage>> sendInquiry({
    required int conversationId,
    required String body,
    String? price,
    int? replyToMessageId,
  }) => guard(
    () => _remote.sendInquiry(
      conversationId: conversationId,
      body: body,
      price: price,
      replyToMessageId: replyToMessageId,
    ),
  );

  @override
  Future<Result<void>> blockUser(int userId) =>
      guard(() => _remote.blockUser(userId));

  @override
  Future<Result<void>> markRead(int conversationId) =>
      guard(() => _remote.markRead(conversationId));

  @override
  Future<Result<DateTime?>> getPeerLastRead(int id) =>
      guard(() => _remote.getPeerLastRead(id));

  @override
  Future<Result<UnreadCounts>> getUnreadCounts() =>
      guard(_remote.getUnreadCounts);

  @override
  Future<Result<bool>> chatPinRequired(int userId) =>
      guard(() => _remote.chatPinRequired(userId));

  @override
  Future<Result<Conversation>> startChat(int userId, {String? pin}) =>
      guard(() => _remote.startChat(userId, pin: pin));

  @override
  Future<Result<List<ChatLabel>>> getLabels() => guard(_remote.getLabels);

  @override
  Future<Result<ChatLabel>> createLabel({
    required String name,
    String? color,
    required int sortOrder,
  }) => guard(
    () => _remote.createLabel(name: name, color: color, sortOrder: sortOrder),
  );

  @override
  Future<Result<ChatLabel>> updateLabel({
    required int id,
    required String name,
    String? color,
    required int sortOrder,
  }) => guard(
    () => _remote.updateLabel(
      id: id,
      name: name,
      color: color,
      sortOrder: sortOrder,
    ),
  );

  @override
  Future<Result<void>> deleteLabel(int id) =>
      guard(() => _remote.deleteLabel(id));

  @override
  Future<Result<void>> attachLabel(int conversationId, int labelId) =>
      guard(() => _remote.attachLabel(conversationId, labelId));

  @override
  Future<Result<void>> detachLabel(int conversationId, int labelId) =>
      guard(() => _remote.detachLabel(conversationId, labelId));
}
