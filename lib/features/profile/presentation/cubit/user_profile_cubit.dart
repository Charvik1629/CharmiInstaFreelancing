import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/load.dart';
import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../../domain/repositories/profile_repository.dart';

part 'user_profile_state.dart';

/// Loads another user's public profile (GET /users/{id}) plus their posts.
///
/// The backend has no "posts by user" endpoint, so posts are gathered from the
/// shared feed (`GET /loads`) and filtered client-side by `author.id`. Paging is
/// bounded (stops at the user's known `postsCount`, the feed's end, or a hard
/// page cap) so a large feed can't turn this into an unbounded crawl.
class UserProfileCubit extends Cubit<UserProfileState> {
  UserProfileCubit(this._repository, this._feed, this.userId)
      : super(const UserProfileState());

  final ProfileRepository _repository;
  final FeedRepository _feed;
  final int userId;

  /// Safety cap on feed pages scanned when collecting a user's posts.
  static const int _maxPages = 5;

  Future<void> load() async {
    emit(state.copyWith(status: UserProfileStatus.loading));
    final result = await _repository.getUser(userId);
    switch (result) {
      case Success(value: final user):
        emit(state.copyWith(status: UserProfileStatus.loaded, user: user));
        await _loadPosts(user.postsCount);
      case Err(failure: final f):
        emit(state.copyWith(
            status: UserProfileStatus.error, errorMessage: f.message));
    }
  }

  /// Scans the feed page by page, keeping only this user's loads, until we have
  /// [expected] of them, the feed ends, or [_maxPages] is reached.
  Future<void> _loadPosts(int expected) async {
    emit(state.copyWith(postsStatus: PostsStatus.loading));
    final mine = <Load>[];
    var page = 1;
    while (page <= _maxPages) {
      final result = await _feed.getLoads(page: page);
      if (result case Success(value: final pageData)) {
        mine.addAll(pageData.items.where((l) => l.author?.id == userId));
        final enough = expected > 0 && mine.length >= expected;
        if (enough || !pageData.meta.hasMore) break;
        page++;
      } else {
        // A feed error shouldn't blank the profile — just show no previews.
        emit(state.copyWith(postsStatus: PostsStatus.error));
        return;
      }
    }
    emit(state.copyWith(posts: mine, postsStatus: PostsStatus.loaded));
  }
}
