import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../../../subscription/domain/entities/subscription.dart';
import '../../../subscription/domain/repositories/subscription_repository.dart';
import '../../domain/repositories/profile_repository.dart';

part 'business_profile_state.dart';

/// Loads the viewer's own business profile: the full [User] (verified derives
/// from `approval_status`) plus their [Subscription] (premium derives from an
/// active plan). Products/tags aren't returned by the API yet, so those sections
/// gate to an empty state.
class BusinessProfileCubit extends Cubit<BusinessProfileState> {
  BusinessProfileCubit(this._profile, this._subs)
      : super(const BusinessProfileState());

  final ProfileRepository _profile;
  final SubscriptionRepository _subs;

  Future<void> load() async {
    emit(state.copyWith(status: BpStatus.loading));
    final result = await _profile.getProfile();
    switch (result) {
      case Success(value: final user):
        // Subscription is secondary — a failure just leaves premium off.
        final sub = (await _subs.getSubscription()).valueOrNull;
        emit(state.copyWith(
            status: BpStatus.loaded, user: user, subscription: sub));
      case Err(failure: final f):
        emit(state.copyWith(status: BpStatus.error, errorMessage: f.message));
    }
  }
}
