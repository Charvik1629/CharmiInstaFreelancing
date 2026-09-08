import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../entities/auth_session.dart';

/// Auth domain contract. The repository also owns token/user persistence so the
/// rest of the app only deals with [AuthSession]/[User], never storage keys.
abstract class AuthRepository {
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  });

  /// Registers a B2B account. Returns the created [User] (`approval_status:
  /// pending`); no session is issued until an admin approves.
  Future<Result<User>> register({
    required String name,
    required String businessName,
    required String phone,
    required String email,
    String? gstNumber,
    String? panNumber,
    String? aadhaarNumber,
    String? referralCode,
    required String password,
    required String passwordConfirmation,
  });

  /// Fetches the current user using the stored token.
  Future<Result<User>> me();

  /// Revokes the token server-side (best effort) and clears local session.
  Future<void> logout();

  /// Persists token + user after a successful auth.
  Future<void> persistSession(AuthSession session);

  /// The cached user from a previous session, if any (offline bootstrap).
  User? cachedUser();

  /// Overwrites the cached user (e.g. after a profile edit) so it survives a
  /// restart and offline bootstrap.
  Future<void> cacheUser(User user);

  /// Whether a token is stored (used to decide the initial route).
  Future<bool> hasToken();

  // Pending backend endpoints (see MISSING_APIS.md). Wired so the screens work
  // the moment those endpoints exist; until then they return a Failure.
  Future<Result<void>> sendOtp(String identifier);
  Future<Result<void>> verifyOtp({required String identifier, required String code});
  Future<Result<void>> forgotPassword(String email);
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  });
}
