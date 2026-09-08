import '../../../core/network/base_repository.dart';
import '../../../core/utils/result.dart';
import '../data/security_remote_data_source.dart';
import 'pin_settings.dart';

abstract class SecurityRepository {
  Future<Result<PinSettings>> getPin();
  Future<Result<PinSettings>> setPin({required String mode, String? pin});
}

class SecurityRepositoryImpl with BaseRepository implements SecurityRepository {
  SecurityRepositoryImpl(this._remote);

  final SecurityRemoteDataSource _remote;

  @override
  Future<Result<PinSettings>> getPin() => guard(() => _remote.getPin());

  @override
  Future<Result<PinSettings>> setPin({required String mode, String? pin}) =>
      guard(() => _remote.setPin(mode: mode, pin: pin));
}
