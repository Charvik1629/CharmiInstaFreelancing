import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/models/load.dart';
import '../../../../core/models/post_type.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/result.dart';
import '../../../post_types/domain/repositories/post_type_repository.dart';
import '../../../tags/domain/entities/tag.dart';
import '../../domain/entities/new_post.dart';
import '../../domain/repositories/feed_repository.dart';

part 'create_post_state.dart';

/// Drives the Create Post (composer) screen: loads the category list, tracks
/// the form fields, and submits. Image *picking* is a UI concern (done in the
/// page via the permission flow); the cubit only holds the chosen path so it
/// stays unit-testable without platform channels.
class CreatePostCubit extends Cubit<CreatePostState> {
  CreatePostCubit(this._feed, this._postTypes) : super(const CreatePostState());

  final FeedRepository _feed;
  final PostTypeRepository _postTypes;

  /// Set when editing an existing post; drives update vs create on submit.
  int? _editLoadId;

  /// Prefills the composer to edit [load] — title, body, category, the already
  /// attached tags, and the existing photos (shown for reference).
  void seedForEdit(Load load) {
    _editLoadId = load.id;
    final existing = [
      for (final m in load.imageMedia) ?MediaUrl.resolve(m.url),
    ];
    emit(state.copyWith(
      title: load.title,
      body: load.body ?? '',
      selectedTypeId: load.postType?.id,
      existingImageUrls: existing,
      selectedTags: load.tags,
      editing: true,
    ));
  }

  /// Fetches the categories for the picker. Failure is non-fatal — the user can
  /// still post without a category, so we just leave the list empty.
  Future<void> loadCategories() async {
    emit(state.copyWith(categoriesStatus: LoadStatus.loading));
    final result = await _postTypes.getPostTypes();
    switch (result) {
      case Success(value: final types):
        final active = types.where((t) => t.isActive).toList();
        emit(state.copyWith(
          categoriesStatus: LoadStatus.loaded,
          categories: active,
          // Default to the first category if none picked yet.
          selectedTypeId: state.selectedTypeId ??
              (active.isNotEmpty ? active.first.id : null),
        ));
      case Err():
        emit(state.copyWith(categoriesStatus: LoadStatus.error));
    }
  }

  void setTitle(String value) =>
      emit(state.copyWith(title: value, clearError: true));

  void setBody(String value) => emit(state.copyWith(body: value));

  void selectType(int id) => emit(state.copyWith(selectedTypeId: id));

  void setTags(List<Tag> tags) => emit(state.copyWith(selectedTags: tags));

  /// Max media per post — matches the `media[]` limit on POST /loads.
  static const maxImages = 10;

  void addImage(String path) {
    if (state.imagePaths.length >= maxImages) return;
    emit(state.copyWith(imagePaths: [...state.imagePaths, path]));
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= state.imagePaths.length) return;
    final next = [...state.imagePaths]..removeAt(index);
    emit(state.copyWith(imagePaths: next));
  }

  /// Reorders the image strip (design: hold & drag). [newIndex] is the final
  /// position (already adjusted for the removed item, per `onReorderItem`).
  void reorderImages(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.imagePaths.length) return;
    final next = [...state.imagePaths];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), moved);
    emit(state.copyWith(imagePaths: next));
  }

  /// Submits the post. No-ops if already submitting or the form is invalid.
  Future<void> submit() async {
    if (state.isSubmitting || !state.canSubmit) return;
    emit(state.copyWith(
      submitStatus: SubmitStatus.submitting,
      clearError: true,
    ));

    final post = NewPost(
      title: state.title.trim(),
      body: state.body.trim().isEmpty ? null : state.body.trim(),
      postTypeId: state.selectedTypeId,
      imagePaths: state.imagePaths,
      tagIds: state.selectedTags.map((t) => t.id).toList(),
    );
    final result = _editLoadId != null
        ? await _feed.updateLoad(_editLoadId!, post)
        : await _feed.createLoad(post);

    switch (result) {
      case Success(value: final load):
        emit(state.copyWith(submitStatus: SubmitStatus.success, created: load));
      case Err(failure: final f):
        emit(state.copyWith(
          submitStatus: SubmitStatus.failure,
          errorMessage: f.message,
          fieldErrors: _flattenFieldErrors(f),
        ));
    }
  }

  /// Collapses the API's field → [messages] map to field → first message, which
  /// is what the form fields display.
  static Map<String, String> _flattenFieldErrors(Failure f) {
    final raw = f is ValidationFailure ? f.fieldErrors : null;
    if (raw == null) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.first,
    };
  }
}
