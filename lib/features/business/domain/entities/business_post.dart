import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// A post in the Business feed (`GET /business-posts`). A social business
/// update — author, optional image, caption — carrying only Share / Report
/// actions (no Buy/Sell, Offer or Ask). Distinct from a marketplace `Load`.
class BusinessPost extends Equatable {
  const BusinessPost({
    required this.id,
    required this.authorName,
    this.avatarUrl,
    this.verified = false,
    this.location,
    this.caption,
    this.imageUrl,
    this.createdAt,
  });

  final int id;
  final String authorName;
  final String? avatarUrl;
  final bool verified;
  final String? location;
  final String? caption;
  final String? imageUrl;
  final DateTime? createdAt;

  factory BusinessPost.fromJson(Map<String, dynamic> json) {
    final author = json.asMap('author') ?? const {};
    return BusinessPost(
      id: json.asIntOr('id', 0),
      authorName:
          author.asStringOr('name', json.asStringOr('author_name', 'Business')),
      avatarUrl: author.asString('avatar_url') ?? json.asString('avatar_url'),
      verified: author.asBool('is_verified') ||
          json.asBool('is_verified') ||
          json.asBool('verified'),
      location: json.asString('location'),
      caption: json.asString('caption') ?? json.asString('body'),
      imageUrl: json.asString('image_url') ?? json.asString('media_url'),
      createdAt: json.asDate('created_at'),
    );
  }

  @override
  List<Object?> get props =>
      [id, authorName, avatarUrl, verified, location, caption, imageUrl, createdAt];
}
