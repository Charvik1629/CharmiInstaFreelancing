import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_state.dart';

/// Owns the session for the whole app. On startup [bootstrap] decides whether
/// the user is signed in; login/register pages call [onAuthenticated] after a
/// successful submit; [logout] clears everything.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState());

  final AuthRepository _repository;

  /// Called once at startup. Uses the cached user for an instant decision, then
  /// refreshes from /auth/me in the background (without bouncing the user out on
  /// a transient network error).
  Future<void> bootstrap() async {
    final hasToken = await _repository.hasToken();
    if (!hasToken) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }

    final cached = _repository.cachedUser();
    if (cached != null) {
      emit(AuthState(status: AuthStatus.authenticated, user: cached));
    }

    final result = await _repository.me();
    switch (result) {
      case Success(value: final user):
        emit(AuthState(status: AuthStatus.authenticated, user: user));
      case Err(failure: final failure):
        // Only force logout when the token is actually rejected (401).
        if (failure.statusCode == 401) {
          await logout();
        } else if (cached == null) {
          // Couldn't confirm and nothing cached → treat as signed out.
          emit(const AuthState(status: AuthStatus.unauthenticated));
        }
    }
  }

  /// Persists and activates a session produced by a successful login/register.
  Future<void> onAuthenticated(AuthSession session) async {
    await _repository.persistSession(session);
    emit(AuthState(status: AuthStatus.authenticated, user: session.user));
  }

  /// Replaces the current user after a profile edit and re-caches it. No-op if
  /// not authenticated.
  Future<void> updateUser(User user) async {
    if (state.status != AuthStatus.authenticated) return;
    await _repository.cacheUser(user);
    emit(AuthState(status: AuthStatus.authenticated, user: user));
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
