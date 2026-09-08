import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';

void main() {
  test('Success exposes value and folds correctly', () {
    const Result<int> r = Success(42);
    expect(r.isSuccess, isTrue);
    expect(r.valueOrNull, 42);
    expect(r.when(success: (v) => v * 2, failure: (_) => -1), 84);
  });

  test('Err exposes failure and folds correctly', () {
    const Result<int> r = Err(NotFoundFailure());
    expect(r.isFailure, isTrue);
    expect(r.failureOrNull, isA<NotFoundFailure>());
    expect(r.when(success: (_) => 'ok', failure: (f) => f.message), 'Not found.');
  });
}
