import 'package:equatable/equatable.dart';

import '../extensions/json_extensions.dart';
import 'author.dart';
import 'post_type.dart';

/// Media attached to a load. [kind] is `image` or `file` (e.g. a PDF).
enum MediaKind { image, file, none }

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

  factory Load.fromJson(Map<String, dynamic> json) {
    return Load(
      id: json.asIntOr('id', 0),
      title: json.asStringOr('title', ''),
      body: json.asString('body'),
      mediaUrl: json.asString('media_url'),
      mediaMime: json.asString('media_mime'),
      mediaKind: _kind(json.asString('media_kind')),
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

  static MediaKind _kind(String? raw) => switch (raw) {
        'image' => MediaKind.image,
        'file' => MediaKind.file,
        _ => MediaKind.none,
      };

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
        id, title, body, mediaUrl, mediaKind, status, isBoosted, isBusiness,
        postType, author, isOwn, canMessage, viewerHasRequested, conversationId,
      ];
}
