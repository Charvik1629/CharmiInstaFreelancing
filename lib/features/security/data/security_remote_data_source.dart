import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/pin_settings.dart';

abstract class SecurityRemoteDataSource {
  Future<PinSettings> getPin();
  Future<PinSettings> setPin({required String mode, String? pin});
}

class SecurityRemoteDataSourceImpl implements SecurityRemoteDataSource {
  SecurityRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<PinSettings> getPin() async {
    final res = await _client.get<Map<String, dynamic>>(ApiEndpoints.securityPin);
    return ApiEnvelope.object(res.data, PinSettings.fromJson);
  }

  @override
  Future<PinSettings> setPin({required String mode, String? pin}) async {
    final res = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.securityPin,
      data: {'mode': mode, 'pin': ?pin},
    );
    return ApiEnvelope.object(res.data, PinSettings.fromJson);
  }
}
