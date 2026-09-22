import '../constants/api_endpoints.dart';
import '../network/api_client.dart';

/// WhatsApp-style link metadata (`POST /link-previews`).
class LinkPreview {
  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  bool get hasContent => (title ?? '').isNotEmpty || imageUrl != null;

  factory LinkPreview.fromJson(Map<String, dynamic> json) => LinkPreview(
        url: json['url'] as String? ?? '',
        title: json['title'] as String?,
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        siteName: json['site_name'] as String?,
      );
}

/// Fetches + caches link previews. The backend caches for 6h; this adds an
/// in-memory cache so a message re-render doesn't refetch. Failures cache as
/// `null` so a broken link isn't retried on every rebuild.
class LinkPreviewService {
  LinkPreviewService(this._client);

  final ApiClient _client;
  final Map<String, LinkPreview?> _cache = {};

  /// The first http(s) URL in [text], or null.
  static String? firstUrl(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = _urlRegex.firstMatch(text);
    if (match == null) return null;
    var url = match.group(0)!;
    if (url.startsWith('www.')) url = 'https://$url';
    return url;
  }

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/|www\.)[^\s<>()]+',
    caseSensitive: false,
  );

  Future<LinkPreview?> fetch(String url) async {
    if (_cache.containsKey(url)) return _cache[url];
    try {
      final res = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.linkPreviews,
        data: {'url': url},
      );
      final data = res.data?['data'];
      final preview = data is Map<String, dynamic>
          ? LinkPreview.fromJson(data)
          : null;
      return _cache[url] = (preview?.hasContent ?? false) ? preview : null;
    } catch (_) {
      return _cache[url] = null;
    }
  }
}
