import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/chat_label.dart';
import '../../domain/repositories/chat_repository.dart';

part 'chat_labels_state.dart';

/// Manages the user's chat labels (the "Manage labels" screen): list, create,
/// update, delete.
class ChatLabelsCubit extends Cubit<ChatLabelsState> {
  ChatLabelsCubit(this._repository) : super(const ChatLabelsState());

  final ChatRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: LabelsStatus.loading));
    final result = await _repository.getLabels();
    switch (result) {
      case Success(value: final list):
        final sorted = [...list]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        emit(state.copyWith(
          status: sorted.isEmpty ? LabelsStatus.empty : LabelsStatus.loaded,
          labels: sorted,
        ));
      case Err(failure: final f):
        emit(state.copyWith(status: LabelsStatus.error, errorMessage: f.message));
    }
  }

  Future<void> refresh() => load();

  Future<bool> createLabel({
    required String name,
    String? color,
    required int sortOrder,
  }) async {
    final result = await _repository.createLabel(
        name: name, color: color, sortOrder: sortOrder);
    if (result case Success(value: final label)) {
      final list = [...state.labels, label]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      emit(state.copyWith(labels: list, status: LabelsStatus.loaded));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }

  Future<bool> updateLabel({
    required int id,
    required String name,
    String? color,
    required int sortOrder,
  }) async {
    final result = await _repository.updateLabel(
        id: id, name: name, color: color, sortOrder: sortOrder);
    if (result case Success(value: final label)) {
      final list = state.labels.map((l) => l.id == id ? label : l).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      emit(state.copyWith(labels: list));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }

  Future<bool> deleteLabel(int id) async {
    final result = await _repository.deleteLabel(id);
    if (result.isSuccess) {
      final list = state.labels.where((l) => l.id != id).toList();
      emit(state.copyWith(
        labels: list,
        status: list.isEmpty ? LabelsStatus.empty : LabelsStatus.loaded,
      ));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }
}
