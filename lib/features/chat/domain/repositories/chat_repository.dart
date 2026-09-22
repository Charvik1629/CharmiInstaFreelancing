import '../../../../core/utils/result.dart';
import '../../data/datasources/chat_remote_data_source.dart';
import '../entities/chat_label.dart';
import '../entities/chat_message.dart';
import '../entities/conversation.dart';
import '../entities/unread_counts.dart';

/// Domain contract for chat. Covers direct, group and broadcast threads.
abstract class ChatRepository {
  Future<Result<List<Conversation>>> getChats({String? hasMedia, bool hasLinks});
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
  });

  /// Edit a text message (server enforces the ≤1h window).
  Future<Result<ChatMessage>> editMessage(
      int conversationId, int messageId, String body);

  /// Delete a message (server enforces the ≤24h window).
  Future<Result<void>> deleteMessage(int conversationId, int messageId);

  /// Stars / unstars a message (POST/DELETE …/star).
  Future<Result<void>> starMessage(int conversationId, int messageId,
      {required bool star});

  /// Pins / unpins a conversation to the top of the inbox (POST/DELETE …/pin).
  Future<Result<void>> pinConversation(int conversationId, {required bool pin});

  /// GET /messages/starred — every message you've starred, newest first.
  Future<Result<List<ChatMessage>>> getStarredMessages();

  /// Send a location or contact message.
  Future<Result<ChatMessage>> sendMeta({
    required int conversationId,
    required String type,
    required Map<String, dynamic> meta,
  });

  /// Block a user.
  Future<Result<void>> blockUser(int userId);

  Future<Result<void>> markRead(int conversationId);
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
