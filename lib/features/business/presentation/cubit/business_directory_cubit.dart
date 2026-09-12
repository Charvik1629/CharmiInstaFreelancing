import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/business.dart';
import '../../domain/repositories/business_directory_repository.dart';

part 'business_directory_state.dart';

/// Drives the business directory search (`GET /businesses`). Debounces queries
/// and degrades to [BizDirStatus.gated] on 404 so the tab stays usable until the
/// endpoint is live.
class BusinessDirectoryCubit extends Cubit<BusinessDirectoryState> {
  BusinessDirectoryCubit(this._repository) : super(const BusinessDirectoryState());

  final BusinessDirectoryRepository _repository;
  Timer? _debounce;

  Future<void> load([String? query]) async {
    emit(state.copyWith(status: BizDirStatus.loading, query: query ?? state.query));
    final result = await _repository.search(query: query ?? state.query);
    switch (result) {
      case Success(value: final items):
        emit(state.copyWith(
          status: items.isEmpty ? BizDirStatus.empty : BizDirStatus.loaded,
          businesses: items,
        ));
      case Err(failure: final f):
        emit(state.copyWith(
          status: f is NotFoundFailure ? BizDirStatus.gated : BizDirStatus.error,
          errorMessage: f.message,
        ));
    }
  }

  void onQueryChanged(String q) {
    emit(state.copyWith(query: q));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => load(q));
  }

  Future<Result<void>> boost(Business b) async {
    final result = await _repository.boost(b.id);
    if (result.isSuccess) {
      emit(state.copyWith(
        businesses: [
          for (final x in state.businesses)
            if (x.id == b.id) x.copyWith(isBoosted: true, canBoost: false) else x,
        ],
      ));
    }
    return result;
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
