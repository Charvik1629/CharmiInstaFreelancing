import 'package:equatable/equatable.dart';

import '../../../../core/models/user.dart';

/// The result of a successful login/register: the authenticated [User] and the
/// Sanctum bearer token to store and send on subsequent requests.
class AuthSession extends Equatable {
  const AuthSession({required this.user, required this.token});

  final User user;
  final String token;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    // Shape: { "data": { "user": {...}, "token": "..." } } — caller passes the
    // already-unwrapped `data` object.
    final userJson = json['user'];
    return AuthSession(
      user: User.fromJson(userJson is Map<String, dynamic> ? userJson : const {}),
      token: json['token'] is String ? json['token'] as String : '',
    );
  }

  @override
  List<Object?> get props => [user, token];
}
