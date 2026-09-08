part of 'admin_sub_requests_cubit.dart';

enum ReqStatus { initial, loading, loaded, empty, error }

class AdminSubRequestsState extends Equatable {
  const AdminSubRequestsState({
    this.status = ReqStatus.initial,
    this.filter = SubRequestStatus.pending,
    this.requests = const [],
    this.actingOnId,
    this.errorMessage,
  });

  final ReqStatus status;
  final SubRequestStatus filter;
  final List<SubscriptionRequest> requests;
  final int? actingOnId;
  final String? errorMessage;

  AdminSubRequestsState copyWith({
    ReqStatus? status,
    SubRequestStatus? filter,
    List<SubscriptionRequest>? requests,
    int? actingOnId,
    bool clearActingOn = false,
    String? errorMessage,
  }) {
    return AdminSubRequestsState(
      status: status ?? this.status,
      filter: filter ?? this.filter,
      requests: requests ?? this.requests,
      actingOnId: clearActingOn ? null : (actingOnId ?? this.actingOnId),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, filter, requests, actingOnId, errorMessage];
}
