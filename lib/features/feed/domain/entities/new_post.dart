/// The user's composed post, before it becomes a server [Load]. Kept minimal:
/// the composer collects these fields and hands them to the repository.
class NewPost {
  const NewPost({
    required this.title,
    this.body,
    this.postTypeId,
    this.imagePaths = const [],
    this.tagIds = const [],
  });

  final String title;
  final String? body;

  /// Selected category id (from PostType). Null = server default.
  final int? postTypeId;

  /// Local file paths of attached media, in order. Sent as a `media[]` carousel
  /// on POST /loads (max 10). Empty for a text-only post.
  final List<String> imagePaths;

  /// Selected tag ids (from GET /tags) sent as `tag_ids` on POST /loads.
  final List<int> tagIds;

  bool get hasImage => imagePaths.isNotEmpty;
}
