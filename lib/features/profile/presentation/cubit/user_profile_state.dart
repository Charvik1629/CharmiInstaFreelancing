part of 'user_profile_cubit.dart';

enum UserProfileStatus { initial, loading, loaded, error }

/// Load state of the user's posts grid, tracked separately from the profile
/// header so the header shows the moment the user loads.
enum PostsStatus { initial, loading, loaded, error }

class UserProfileState extends Equatable {
  const UserProfileState({
    this.status = UserProfileStatus.initial,
    this.user,
    this.posts = const [],
    this.postsStatus = PostsStatus.initial,
    this.errorMessage,
  });

  final UserProfileStatus status;
  final User? user;

  /// This user's posts, gathered from the feed and filtered by author id.
  final List<Load> posts;
  final PostsStatus postsStatus;
  final String? errorMessage;

  UserProfileState copyWith({
    UserProfileStatus? status,
    User? user,
    List<Load>? posts,
    PostsStatus? postsStatus,
    String? errorMessage,
  }) {
    return UserProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      posts: posts ?? this.posts,
      postsStatus: postsStatus ?? this.postsStatus,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, posts, postsStatus, errorMessage];
}
