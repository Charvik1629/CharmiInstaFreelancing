import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/extensions/string_extensions.dart';

void main() {
  group('email validation', () {
    test('accepts valid emails', () {
      for (final e in ['a@b.co', 'jane.doe+x@example.com', 'user@nexveero.app']) {
        expect(e.isValidEmail, isTrue, reason: e);
      }
    });

    test('rejects invalid emails', () {
      for (final e in ['not-an-email', 'a@b', '@b.co', 'a@.co', '']) {
        expect(e.isValidEmail, isFalse, reason: e);
      }
    });
  });

  test('isNullOrBlank handles null, empty, whitespace', () {
    String? a;
    expect(a.isNullOrBlank, isTrue);
    expect(''.isNullOrBlank, isTrue);
    expect('   '.isNullOrBlank, isTrue);
    expect('x'.isNullOrBlank, isFalse);
  });
}
