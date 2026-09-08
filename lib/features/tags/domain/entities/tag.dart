import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// An admin-managed tag. Active tags are attachable to posts/business profiles
/// (`tag_ids` on `POST /loads`); inactive ones are hidden from the user picker.
class Tag extends Equatable {
  const Tag({
    required this.id,
    required this.name,
    this.slug = '',
    this.isActive = true,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final String slug;
  final bool isActive;
  final int sortOrder;

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
        id: json.asIntOr('id', 0),
        name: json.asStringOr('name', ''),
        slug: json.asStringOr('slug', ''),
        isActive: json.asBool('is_active', fallback: true),
        sortOrder: json.asIntOr('sort_order', 0),
      );

  @override
  List<Object?> get props => [id, name, slug, isActive, sortOrder];
}
