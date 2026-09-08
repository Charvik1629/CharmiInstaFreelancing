import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_form_state.dart';

/// Handles the login form submission lifecycle. On success it emits the
/// [AuthSession]; the page hands that to [AuthCubit] and navigates.
class LoginCubit extends Cubit<AuthFormState> {
  LoginCubit(this._repository) : super(const AuthFormState());

  final AuthRepository _repository;

  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting) return;
    emit(const AuthFormState(status: FormStatus.submitting));

    final result = await _repository.login(email: email, password: password);
    switch (result) {
      case Success(value: final session):
        emit(AuthFormState(status: FormStatus.success, session: session));
      case Err(failure: final failure):
        emit(AuthFormState(
          status: FormStatus.failure,
          errorMessage: failure.message,
          // 403 = account pending/rejected approval → route to approval screen.
          forbidden: failure is ForbiddenFailure,
          fieldErrors: failure is ValidationFailure
              ? (failure.fieldErrors ?? const {})
              : const {},
        ));
    }
  }
}
