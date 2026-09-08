/// The user's composed post, before it becomes a server [Load]. Kept minimal:
/// the composer collects these fields and hands them to the repository.
class NewPost {
  const NewPost({
    required this.title,
    this.body,
    this.postTypeId,
    this.imagePath,
    this.tagIds = const [],
  });

  final String title;
  final String? body;

  /// Selected category id (from PostType). Null = server default.
  final int? postTypeId;

  /// Local file path of an attached image, or null for a text-only post.
  final String? imagePath;

  /// Selected tag ids (from GET /tags) sent as `tag_ids` on POST /loads.
  final List<int> tagIds;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
}
