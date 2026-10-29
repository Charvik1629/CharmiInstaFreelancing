part of 'broadcast_groups_cubit.dart';

enum BroadcastGroupsStatus { initial, loading, loaded, empty, error }

class BroadcastGroupsState extends Equatable {
  const BroadcastGroupsState({
    this.status = BroadcastGroupsStatus.initial,
    this.groups = const [],
    this.query = '',
    this.errorMessage,
    this.quota,
  });

  final BroadcastGroupsStatus status;
  final List<BroadcastDetail> groups;
  final String query;
  final String? errorMessage;

  /// `meta.broadcast_list_quota` from GET /broadcasts — the caller's broadcast
  /// allowance for this window. Null when the server omits it.
  final BroadcastQuota? quota;

  BroadcastGroupsState copyWith({
    BroadcastGroupsStatus? status,
    List<BroadcastDetail>? groups,
    String? query,
    String? errorMessage,
    BroadcastQuota? quota,
  }) {
    return BroadcastGroupsState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      query: query ?? this.query,
      errorMessage: errorMessage ?? this.errorMessage,
      quota: quota ?? this.quota,
    );
  }

  @override
  List<Object?> get props => [status, groups, query, errorMessage, quota];
}
