part of 'business_feed_cubit.dart';

enum BusinessFeedStatus { initial, loading, loaded, empty, gated, error }

class BusinessFeedState extends Equatable {
  const BusinessFeedState({
    this.status = BusinessFeedStatus.initial,
    this.posts = const [],
    this.errorMessage,
  });

  final BusinessFeedStatus status;
  final List<BusinessPost> posts;
  final String? errorMessage;

  BusinessFeedState copyWith({
    BusinessFeedStatus? status,
    List<BusinessPost>? posts,
    String? errorMessage,
  }) {
    return BusinessFeedState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, posts, errorMessage];
}
