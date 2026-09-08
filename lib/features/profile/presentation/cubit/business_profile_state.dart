part of 'business_profile_cubit.dart';

enum BpStatus { initial, loading, loaded, error }

class BusinessProfileState extends Equatable {
  const BusinessProfileState({
    this.status = BpStatus.initial,
    this.user,
    this.subscription,
    this.errorMessage,
  });

  final BpStatus status;
  final User? user;
  final Subscription? subscription;
  final String? errorMessage;

  bool get isVerified => user?.isApproved ?? false;
  bool get isPremium => subscription?.isActive ?? false;

  BusinessProfileState copyWith({
    BpStatus? status,
    User? user,
    Subscription? subscription,
    String? errorMessage,
  }) {
    return BusinessProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      subscription: subscription ?? this.subscription,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, subscription, errorMessage];
}
