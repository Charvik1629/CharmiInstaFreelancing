part of 'admin_tags_cubit.dart';

enum TagsStatus { initial, loading, loaded, empty, error }

class AdminTagsState extends Equatable {
  const AdminTagsState({
    this.status = TagsStatus.initial,
    this.tags = const [],
    this.errorMessage,
  });

  final TagsStatus status;
  final List<Tag> tags;
  final String? errorMessage;

  AdminTagsState copyWith({
    TagsStatus? status,
    List<Tag>? tags,
    String? errorMessage,
  }) {
    return AdminTagsState(
      status: status ?? this.status,
      tags: tags ?? this.tags,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, tags, errorMessage];
}
