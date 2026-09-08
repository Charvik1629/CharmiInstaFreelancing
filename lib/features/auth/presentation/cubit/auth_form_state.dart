import 'package:equatable/equatable.dart';

import '../../../../core/models/user.dart';
import '../../domain/entities/auth_session.dart';

enum FormStatus { idle, submitting, success, failure }

/// Transient state for a login/register form submission. [fieldErrors] carries
/// 422 per-field messages so inputs can show inline errors. [session] is set on
/// a successful login; [user] carries the pending account returned by register
/// (or the account whose login was blocked). [forbidden] marks a 403 — a
/// pending/rejected account trying to log in — so the page routes to the
/// approval screen instead of showing a plain error.
class AuthFormState extends Equatable {
  const AuthFormState({
    this.status = FormStatus.idle,
    this.errorMessage,
    this.fieldErrors = const {},
    this.session,
    this.user,
    this.forbidden = false,
  });

  final FormStatus status;
  final String? errorMessage;
  final Map<String, List<String>> fieldErrors;
  final AuthSession? session;
  final User? user;
  final bool forbidden;

  bool get isSubmitting => status == FormStatus.submitting;

  String? fieldError(String key) =>
      fieldErrors[key]?.isNotEmpty == true ? fieldErrors[key]!.first : null;

  AuthFormState copyWith({
    FormStatus? status,
    String? errorMessage,
    Map<String, List<String>>? fieldErrors,
    AuthSession? session,
    User? user,
    bool? forbidden,
  }) {
    return AuthFormState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      session: session ?? this.session,
      user: user ?? this.user,
      forbidden: forbidden ?? this.forbidden,
    );
  }

  @override
  List<Object?> get props =>
      [status, errorMessage, fieldErrors, session, user, forbidden];
}
