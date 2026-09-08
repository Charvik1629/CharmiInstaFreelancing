import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/config/app_config.dart';
import 'package:charmi_insta_freelancing/core/error/app_exception.dart';
import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/network/base_repository.dart';

class _TestRepo with BaseRepository {}

void main() {
  final repo = _TestRepo();
  final original = AppConfig.current;

  setUp(() {
    // Pretend the base URL is configured so guard() runs the request branch.
    AppConfig.current = AppConfig.dev.copyWith(baseUrl: 'https://api.test');
  });

  tearDown(() => AppConfig.current = original);

  test('returns ConfigFailure when base URL is a placeholder', () async {
    AppConfig.current = original; // dev placeholder
    final r = await repo.guard(() async => 1);
    expect(r.failureOrNull, isA<ConfigFailure>());
  });

  test('wraps success', () async {
    final r = await repo.guard(() async => 'ok');
    expect(r.valueOrNull, 'ok');
  });

  test('maps status codes to typed failures', () async {
    final cases = <int, Type>{
      401: AuthFailure,
      402: InsufficientCreditsFailure,
      403: ForbiddenFailure,
      404: NotFoundFailure,
      422: ValidationFailure,
      500: ServerFailure,
      418: UnknownFailure,
    };
    for (final entry in cases.entries) {
      final r = await repo.guard<int>(
        () async => throw AppException('e', statusCode: entry.key),
      );
      expect(r.failureOrNull.runtimeType, entry.value,
          reason: 'status ${entry.key}');
    }
  });

  test('null status (transport error) maps to NetworkFailure', () async {
    final r = await repo.guard<int>(
      () async => throw const AppException('offline'),
    );
    expect(r.failureOrNull, isA<NetworkFailure>());
  });

  test('422 carries field errors', () async {
    final r = await repo.guard<int>(
      () async => throw const AppException(
        'Invalid',
        statusCode: 422,
        fieldErrors: {'email': ['taken']},
      ),
    );
    final f = r.failureOrNull;
    expect(f, isA<ValidationFailure>());
    expect(f!.fieldErrors?['email'], ['taken']);
  });

  test('unexpected (non-AppException) error maps to UnknownFailure', () async {
    final r = await repo.guard<int>(() async => throw StateError('boom'));
    expect(r.failureOrNull, isA<UnknownFailure>());
  });
}
