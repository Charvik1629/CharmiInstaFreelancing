import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:charmi_insta_freelancing/core/network/interceptors/auth_interceptor.dart';
import 'package:charmi_insta_freelancing/core/storage/storage_manager.dart';

class _Storage extends Mock implements StorageManager {}

void main() {
  for (final scenario in ['current', 'stale', 'anonymous', 'forbidden']) {
    test('401 from $scenario request only expires matching session', () async {
      final storage = _Storage();
      when(() => storage.readSecure(any())).thenAnswer((_) async => 'new');
      when(() => storage.clearSession()).thenAnswer((_) async {});
      var expired = 0;
      final dio = Dio();
      dio.interceptors.add(
        AuthInterceptor(storage, onUnauthorized: () => expired++),
      );
      dio.httpClientAdapter = _UnauthorizedAdapter(scenario);
      await expectLater(
        dio.get<dynamic>('https://example.test'),
        throwsA(isA<DioException>()),
      );
      expect(expired, scenario == 'current' ? 1 : 0);
      if (scenario == 'current') {
        verify(() => storage.clearSession()).called(1);
      } else {
        verifyNever(() => storage.clearSession());
      }
      dio.close();
    });
  }
}

class _UnauthorizedAdapter implements HttpClientAdapter {
  _UnauthorizedAdapter(this.scenario);
  final String scenario;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (scenario == 'stale') options.headers['Authorization'] = 'Bearer old';
    if (scenario == 'anonymous') options.headers.remove('Authorization');
    return ResponseBody.fromString('{}', scenario == 'forbidden' ? 403 : 401,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}
