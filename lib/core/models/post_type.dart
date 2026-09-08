import 'package:equatable/equatable.dart';

import '../extensions/json_extensions.dart';

/// A feed post category (Buy / Sell / Business). Used by the composer and as a
/// feed filter. Shared across features, so it lives in core/models.
class PostType extends Equatable {
  const PostType({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.isActive = true,
    this.sortOrder,
  });

  final int id;
  final String slug;
  final String name;
  final String? description;
  final bool isActive;
  final int? sortOrder;

  factory PostType.fromJson(Map<String, dynamic> json) => PostType(
        id: json.asIntOr('id', 0),
        slug: json.asStringOr('slug', ''),
        name: json.asStringOr('name', ''),
        description: json.asString('description'),
        isActive: json.asBool('is_active', fallback: true),
        sortOrder: json.asInt('sort_order'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        if (description != null) 'description': description,
        'is_active': isActive,
        if (sortOrder != null) 'sort_order': sortOrder,
      };

  @override
  List<Object?> get props => [id, slug, name, description, isActive, sortOrder];
}
