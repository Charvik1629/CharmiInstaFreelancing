import 'package:equatable/equatable.dart';

import '../extensions/json_extensions.dart';
import 'author.dart';
import 'post_type.dart';

/// Media attached to a load. [kind] is `image` or `file` (e.g. a PDF).
enum MediaKind { image, file, none }

MediaKind mediaKindFromString(String? raw) => switch (raw) {
      'image' => MediaKind.image,
      'file' => MediaKind.file,
      _ => MediaKind.none,
    };

/// One item in a load's `media[]` carousel.
class LoadMedia extends Equatable {
  const LoadMedia({
    required this.url,
    this.mime,
    this.kind = MediaKind.image,
    this.sortOrder = 0,
  });

  final String url;
  final String? mime;
  final MediaKind kind;
  final int sortOrder;

  bool get isImage => kind == MediaKind.image;

  factory LoadMedia.fromJson(Map<String, dynamic> json) => LoadMedia(
        url: json.asStringOr('url', ''),
        mime: json.asString('mime'),
        kind: mediaKindFromString(json.asString('kind')),
        sortOrder: json.asIntOr('sort_order', 0),
      );

  @override
  List<Object?> get props => [url, mime, kind, sortOrder];
}

/// A feed post (the API calls this a "load"). Carries Instagram-style display
/// fields plus per-viewer capability flags that drive which actions the card
/// shows (request, ask, offer, report, edit, delete).
class Load extends Equatable {
  const Load({
    required this.id,
    required this.title,
    this.body,
    this.mediaUrl,
    this.mediaMime,
    this.mediaKind = MediaKind.none,
    this.media = const [],
    this.status = 'active',
    this.isBoosted = false,
    this.isBusiness = false,
    this.postType,
    this.author,
    this.isOwn = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canBoost = false,
    this.canAskQuestion = false,
    this.canMessage = false,
    this.canMakeOffer = false,
    this.canReport = false,
    this.viewerHasRequested = false,
    this.conversationId,
    this.createdAt,
  });

  final int id;
  final String title;
  final String? body;
  final String? mediaUrl;
  final String? mediaMime;
  final MediaKind mediaKind;

  /// Full media carousel (`media[]`). Falls back to a single item built from
  /// [mediaUrl] when the server only sends the legacy cover fields.
  final List<LoadMedia> media;

  final String status;
  final bool isBoosted;
  final bool isBusiness;
  final PostType? postType;
  final Author? author;

  // Per-viewer capabilities (server-computed).
  final bool isOwn;
  final bool canEdit;
  final bool canDelete;
  final bool canBoost;
  final bool canAskQuestion;
  final bool canMessage;
  final bool canMakeOffer;
  final bool canReport;
  final bool viewerHasRequested;
  final int? conversationId;
  final DateTime? createdAt;

  bool get hasImage => mediaKind == MediaKind.image && (mediaUrl?.isNotEmpty ?? false);
  bool get hasFile => mediaKind == MediaKind.file && (mediaUrl?.isNotEmpty ?? false);

  /// Just the image items of the carousel, in order (drives the feed pager).
  List<LoadMedia> get imageMedia =>
      media.where((m) => m.isImage && m.url.isNotEmpty).toList();

  factory Load.fromJson(Map<String, dynamic> json) {
    return Load(
      id: json.asIntOr('id', 0),
      title: json.asStringOr('title', ''),
      body: json.asString('body'),
      mediaUrl: json.asString('media_url'),
      mediaMime: json.asString('media_mime'),
      mediaKind: _kind(json.asString('media_kind')),
      media: _parseMedia(json),
      status: json.asStringOr('status', 'active'),
      isBoosted: json.asBool('is_boosted'),
      isBusiness: json.asBool('is_business'),
      postType: json.asMap('post_type') != null
          ? PostType.fromJson(json.asMap('post_type')!)
          : null,
      author: json.asMap('author') != null
          ? Author.fromJson(json.asMap('author')!)
          : null,
      isOwn: json.asBool('is_own'),
      canEdit: json.asBool('can_edit'),
      canDelete: json.asBool('can_delete'),
      canBoost: json.asBool('can_boost'),
      canAskQuestion: json.asBool('can_ask_question'),
      canMessage: json.asBool('can_message'),
      canMakeOffer: json.asBool('can_make_offer'),
      canReport: json.asBool('can_report'),
      viewerHasRequested: json.asBool('viewer_has_requested'),
      conversationId: json.asInt('conversation_id'),
      createdAt: json.asDate('created_at'),
    );
  }

  static MediaKind _kind(String? raw) => mediaKindFromString(raw);

  /// Reads the `media[]` array; falls back to a single item synthesized from the
  /// legacy `media_url`/`media_mime`/`media_kind` cover fields.
  static List<LoadMedia> _parseMedia(Map<String, dynamic> json) {
    final raw = json['media'];
    if (raw is List && raw.isNotEmpty) {
      final items = raw
          .whereType<Map>()
          .map((m) => LoadMedia.fromJson(Map<String, dynamic>.from(m)))
          .where((m) => m.url.isNotEmpty)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (items.isNotEmpty) return items;
    }
    final url = json.asString('media_url');
    if (url != null && url.isNotEmpty) {
      return [
        LoadMedia(
          url: url,
          mime: json.asString('media_mime'),
          kind: mediaKindFromString(json.asString('media_kind')),
        ),
      ];
    }
    return const [];
  }

  Load copyWith({
    bool? viewerHasRequested,
    int? conversationId,
    String? status,
    bool? isBoosted,
    bool? canBoost,
  }) {
    return Load(
      id: id,
      title: title,
      body: body,
      mediaUrl: mediaUrl,
      mediaMime: mediaMime,
      mediaKind: mediaKind,
      media: media,
      status: status ?? this.status,
      isBoosted: isBoosted ?? this.isBoosted,
      isBusiness: isBusiness,
      postType: postType,
      author: author,
      isOwn: isOwn,
      canEdit: canEdit,
      canDelete: canDelete,
      canBoost: canBoost ?? this.canBoost,
      canAskQuestion: canAskQuestion,
      canMessage: canMessage,
      canMakeOffer: canMakeOffer,
      canReport: canReport,
      viewerHasRequested: viewerHasRequested ?? this.viewerHasRequested,
      conversationId: conversationId ?? this.conversationId,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id, title, body, mediaUrl, mediaKind, media, status, isBoosted, isBusiness,
        postType, author, isOwn, canMessage, viewerHasRequested, conversationId,
      ];
}
