import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/business_post.dart';
import '../../domain/repositories/business_repository.dart';

part 'business_feed_state.dart';

/// Drives the Business feed. When the endpoint isn't live yet (404) it degrades
/// to [BusinessFeedStatus.gated] rather than an error, so the tab stays usable
/// (header + search + sponsored slots) until the backend adds it.
class BusinessFeedCubit extends Cubit<BusinessFeedState> {
  BusinessFeedCubit(this._repository) : super(const BusinessFeedState());

  final BusinessRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: BusinessFeedStatus.loading));
    final result = await _repository.getPosts(page: 1);
    switch (result) {
      case Success(value: final items):
        emit(state.copyWith(
          status: items.isEmpty
              ? BusinessFeedStatus.empty
              : BusinessFeedStatus.loaded,
          posts: items,
        ));
      case Err(failure: final f):
        emit(state.copyWith(
          status: f is NotFoundFailure
              ? BusinessFeedStatus.gated
              : BusinessFeedStatus.error,
          errorMessage: f.message,
        ));
    }
  }

  Future<void> refresh() => load();

  Future<Result<void>> report(int id, String reason) =>
      _repository.reportPost(id, reason);
}
