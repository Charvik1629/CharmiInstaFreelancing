part of 'business_directory_cubit.dart';

enum BizDirStatus { initial, loading, loaded, empty, gated, error }

class BusinessDirectoryState extends Equatable {
  const BusinessDirectoryState({
    this.status = BizDirStatus.initial,
    this.businesses = const [],
    this.query = '',
    this.errorMessage,
  });

  final BizDirStatus status;
  final List<Business> businesses;
  final String query;
  final String? errorMessage;

  BusinessDirectoryState copyWith({
    BizDirStatus? status,
    List<Business>? businesses,
    String? query,
    String? errorMessage,
  }) {
    return BusinessDirectoryState(
      status: status ?? this.status,
      businesses: businesses ?? this.businesses,
      query: query ?? this.query,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, businesses, query, errorMessage];
}
