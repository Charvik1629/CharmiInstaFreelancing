import '../../../../core/utils/result.dart';
import '../../data/datasources/chat_remote_data_source.dart';
import '../entities/chat_label.dart';
import '../entities/chat_message.dart';
import '../entities/conversation.dart';
import '../entities/unread_counts.dart';

/// Domain contract for chat. Covers direct, group and broadcast threads.
abstract class ChatRepository {
  Future<Result<List<Conversation>>> getChats();
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
    String? imagePath,
  });

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
