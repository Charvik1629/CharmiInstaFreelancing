import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/load.dart';
import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../../../subscription/domain/entities/subscription.dart';
import '../../../subscription/domain/repositories/subscription_repository.dart';
import '../../domain/repositories/profile_repository.dart';

part 'business_profile_state.dart';

/// Loads the viewer's own business profile: the full [User] (verified derives
/// from `approval_status`) plus their [Subscription] (premium derives from an
/// active plan) and their posts. Products/tags aren't returned by the API yet,
/// so those sections gate to an empty state.
class BusinessProfileCubit extends Cubit<BusinessProfileState> {
  BusinessProfileCubit(this._profile, this._subs, this._feed)
      : super(const BusinessProfileState());

  final ProfileRepository _profile;
  final SubscriptionRepository _subs;
  final FeedRepository _feed;

  /// Safety cap on feed pages scanned when collecting the viewer's posts.
  static const int _maxPages = 5;

  Future<void> load() async {
    emit(state.copyWith(status: BpStatus.loading));
    final result = await _profile.getProfile();
    switch (result) {
      case Success(value: final user):
        // Subscription is secondary — a failure just leaves premium off.
        final sub = (await _subs.getSubscription()).valueOrNull;
        emit(state.copyWith(
            status: BpStatus.loaded, user: user, subscription: sub));
        await _loadPosts(user.id, user.postsCount);
      case Err(failure: final f):
        emit(state.copyWith(status: BpStatus.error, errorMessage: f.message));
    }
  }

  /// Gathers the viewer's own posts from the feed (no posts-by-user endpoint
  /// exists), filtered by author id, bounded by [expected], the feed's end, or
  /// [_maxPages].
  Future<void> _loadPosts(int userId, int expected) async {
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
        emit(state.copyWith(postsStatus: PostsStatus.error));
        return;
      }
    }
    emit(state.copyWith(posts: mine, postsStatus: PostsStatus.loaded));
  }
}
