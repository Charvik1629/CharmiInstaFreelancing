import '../entities/message_reaction.dart';
import '../entities/disappearing_settings.dart';
import '../entities/shared_content.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/chat_remote_data_source.dart';
import '../entities/broadcast_quota.dart';
import '../entities/chat_label.dart';
import '../entities/chat_message.dart';
import '../entities/conversation.dart';
import '../entities/unread_counts.dart';

/// Domain contract for chat. Covers direct, group and broadcast threads.
abstract class ChatRepository {
  Future<Result<SharedContent>> getShared(
    int conversationId, {
    String type = 'media',
    int page = 1,
  });
  Future<Result<List<Conversation>>> getChats({
    String? hasMedia,
    bool hasLinks,
    String? q,
    String? kind,
  });
  Future<Result<List<Conversation>>> getBroadcasts();
  Future<Result<List<Conversation>>> getQuestions();

  Future<Result<MessagePage>> getMessages({
    required int id,
    required ConversationType type,
    int? beforeId,
  });

  Future<Result<ChatMessage>> sendMessage({
    required int id,
    required ConversationType type,
    String body,
    List<String> attachmentPaths = const [],
    int? replyToMessageId,
  });

  /// Reads the broadcast free-message quota (`meta.broadcast_message_quota`).
  Future<Result<BroadcastQuota?>> getBroadcastQuota(int id);

  /// Edit a text message (server enforces the ≤1h window).
  Future<Result<ChatMessage>> editMessage(
    int conversationId,
    int messageId,
    String body,
  );

  /// Delete a message (server enforces the ≤24h window).
  Future<Result<void>> deleteMessage(
    int conversationId,
    int messageId, {
    MessageDeleteScope scope = MessageDeleteScope.everyone,
  });

  Future<Result<ReactionUpdate>> react(
    int conversationId,
    int messageId,
    String? emoji,
  );
  Future<Result<ChatMessage>> keepMessage(int conversationId, int messageId);
  Future<Result<void>> deleteConversation(int conversationId);
  Future<Result<Conversation>> getConversation(int conversationId);
  Future<Result<List<DisappearingDuration>>> getDisappearingOptions();
  Future<Result<DisappearingUpdate>> setDisappearing(
    int conversationId, {
    required bool enabled,
    int? hours,
  });

  /// Stars / unstars a message (POST/DELETE …/star).
  Future<Result<void>> starMessage(
    int conversationId,
    int messageId, {
    required bool star,
  });

  /// Pins / unpins a conversation to the top of the inbox (POST/DELETE …/pin).
  Future<Result<void>> pinConversation(int conversationId, {required bool pin});

  /// GET /messages/starred — every message you've starred, newest first.
  Future<Result<List<ChatMessage>>> getStarredMessages();

  /// Send a location message (type + meta payload).
  Future<Result<ChatMessage>> sendMeta({
    required int conversationId,
    required String type,
    required Map<String, dynamic> meta,
    int? replyToMessageId,
  });

  /// Send a one-to-one inquiry (question + optional INR price). Direct only.
  Future<Result<ChatMessage>> sendInquiry({
    required int conversationId,
    required String body,
    String? price,
    int? replyToMessageId,
  });

  /// Block a user.
  Future<Result<void>> blockUser(int userId);

  Future<Result<void>> markRead(int conversationId);

  /// The peer's read cursor for 1:1 read ticks (`peer_last_read_at`).
  Future<Result<DateTime?>> getPeerLastRead(int id);
  Future<Result<UnreadCounts>> getUnreadCounts();
  Future<Result<bool>> chatPinRequired(int userId);
  Future<Result<Conversation>> startChat(int userId, {String? pin});

  // Labels.
  Future<Result<List<ChatLabel>>> getLabels();
  Future<Result<ChatLabel>> createLabel({
    required String name,
    String? color,
    required int sortOrder,
  });
  Future<Result<ChatLabel>> updateLabel({
    required int id,
    required String name,
    String? color,
    required int sortOrder,
  });
  Future<Result<void>> deleteLabel(int id);
  Future<Result<void>> attachLabel(int conversationId, int labelId);
  Future<Result<void>> detachLabel(int conversationId, int labelId);
}
