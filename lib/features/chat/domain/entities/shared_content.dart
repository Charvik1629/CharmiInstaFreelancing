import '../../../../core/network/api_response.dart';
import 'chat_message.dart';

class SharedContent {
  const SharedContent({
    required this.mediaCount,
    required this.linksCount,
    required this.documentsCount,
    required this.items,
    required this.meta,
  });
  final int mediaCount;
  final int linksCount;
  final int documentsCount;
  final List<ChatMessage> items;
  final PaginationMeta meta;

  factory SharedContent.fromResponse(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>;
    int count(String key) => int.tryParse('${data[key]}') ?? 0;
    return SharedContent(
      mediaCount: count('media_count'),
      linksCount: count('links_count'),
      documentsCount: count('documents_count'),
      items: [
        for (final message in data['items'] as List? ?? [])
          if (message is Map<String, dynamic>) ChatMessage.fromJson(message),
      ],
      meta: PaginationMeta.fromJson(
        body['meta'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
