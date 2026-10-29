part of 'business_profile_cubit.dart';

enum BpStatus { initial, loading, loaded, error }

/// Load state of the posts grid, tracked separately so the header shows the
/// moment the profile loads.
enum PostsStatus { initial, loading, loaded, error }

class BusinessProfileState extends Equatable {
  const BusinessProfileState({
    this.status = BpStatus.initial,
    this.user,
    this.subscription,
    this.posts = const [],
    this.postsStatus = PostsStatus.initial,
    this.errorMessage,
  });

  final BpStatus status;
  final User? user;
  final Subscription? subscription;

  /// The viewer's own posts, gathered from the feed and filtered by author id.
  final List<Load> posts;
  final PostsStatus postsStatus;
  final String? errorMessage;

  bool get isVerified => user?.isApproved ?? false;
  bool get isPremium => subscription?.isActive ?? false;

  BusinessProfileState copyWith({
    BpStatus? status,
    User? user,
    Subscription? subscription,
    List<Load>? posts,
    PostsStatus? postsStatus,
    String? errorMessage,
  }) {
    return BusinessProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      subscription: subscription ?? this.subscription,
      posts: posts ?? this.posts,
      postsStatus: postsStatus ?? this.postsStatus,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, user, subscription, posts, postsStatus, errorMessage];
}
