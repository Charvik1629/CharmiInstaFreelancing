import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_form_state.dart';

/// Handles the B2B register form submission. On success the account is created
/// as `pending` (no token) — the page routes to the "Pending approval" screen
/// with [AuthFormState.user].
class RegisterCubit extends Cubit<AuthFormState> {
  RegisterCubit(this._repository) : super(const AuthFormState());

  final AuthRepository _repository;

  Future<void> submit({
    required String name,
    required String username,
    required String businessName,
    required String phone,
    required String email,
    String? gstNumber,
    String? panNumber,
    String? aadhaarNumber,
    String? referralCode,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (state.isSubmitting) return;
    emit(const AuthFormState(status: FormStatus.submitting));

    final result = await _repository.register(
      name: name,
      username: username,
      businessName: businessName,
      phone: phone,
      email: email,
      gstNumber: gstNumber,
      panNumber: panNumber,
      aadhaarNumber: aadhaarNumber,
      referralCode: referralCode,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
    switch (result) {
      case Success(value: final user):
        emit(AuthFormState(status: FormStatus.success, user: user));
      case Err(failure: final failure):
        emit(AuthFormState(
          status: FormStatus.failure,
          errorMessage: failure.message,
          fieldErrors: failure is ValidationFailure
              ? (failure.fieldErrors ?? const {})
              : const {},
        ));
    }
  }
}
