import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/tag.dart';
import '../../domain/repositories/tag_repository.dart';

part 'admin_tags_state.dart';

/// Admin management of tags: list all (incl. inactive), create, update, delete.
class AdminTagsCubit extends Cubit<AdminTagsState> {
  AdminTagsCubit(this._repository) : super(const AdminTagsState());

  final TagRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: TagsStatus.loading));
    final result = await _repository.getAllTags();
    switch (result) {
      case Success(value: final tags):
        final sorted = [...tags]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        emit(state.copyWith(
          status: sorted.isEmpty ? TagsStatus.empty : TagsStatus.loaded,
          tags: sorted,
        ));
      case Err(failure: final f):
        emit(state.copyWith(status: TagsStatus.error, errorMessage: f.message));
    }
  }

  Future<void> refresh() => load();

  Future<bool> createTag({
    required String name,
    String? slug,
    required bool isActive,
    required int sortOrder,
  }) async {
    final result = await _repository.createTag(
      name: name,
      slug: slug,
      isActive: isActive,
      sortOrder: sortOrder,
    );
    if (result case Success(value: final tag)) {
      final tags = [...state.tags, tag]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      emit(state.copyWith(tags: tags, status: TagsStatus.loaded));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }

  Future<bool> updateTag({
    required int id,
    required String name,
    String? slug,
    required bool isActive,
    required int sortOrder,
  }) async {
    final result = await _repository.updateTag(
      id: id,
      name: name,
      slug: slug,
      isActive: isActive,
      sortOrder: sortOrder,
    );
    if (result case Success(value: final tag)) {
      final tags = state.tags.map((t) => t.id == id ? tag : t).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      emit(state.copyWith(tags: tags));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }

  Future<bool> deleteTag(int id) async {
    final result = await _repository.deleteTag(id);
    if (result.isSuccess) {
      final tags = state.tags.where((t) => t.id != id).toList();
      emit(state.copyWith(
        tags: tags,
        status: tags.isEmpty ? TagsStatus.empty : TagsStatus.loaded,
      ));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }
}
