import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/utils/validators.dart';

void main() {
  test('email validator', () {
    expect(Validators.email(''), isNotNull);
    expect(Validators.email('bad'), isNotNull);
    expect(Validators.email('a@b.co'), isNull);
  });

  test('password validator enforces min length', () {
    expect(Validators.password(''), isNotNull);
    expect(Validators.password('short'), isNotNull);
    expect(Validators.password('longenough'), isNull);
  });

  test('name validator', () {
    expect(Validators.name('  '), isNotNull);
    expect(Validators.name('Maya'), isNull);
    expect(Validators.name('x' * 256), isNotNull);
  });

  test('confirmPassword must match', () {
    expect(Validators.confirmPassword('', 'abc'), isNotNull);
    expect(Validators.confirmPassword('abc', 'abd'), isNotNull);
    expect(Validators.confirmPassword('abc', 'abc'), isNull);
  });
}
