import '../../../../core/models/user.dart';
import '../../../../core/utils/result.dart';
import '../entities/profile_update.dart';

/// Domain contract for the current user's profile.
abstract class ProfileRepository {
  Future<Result<User>> getProfile();
  Future<Result<User>> updateProfile(ProfileUpdate update);
  Future<Result<User>> getUser(int id);
}
