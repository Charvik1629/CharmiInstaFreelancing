import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/config/app_config.dart';

void main() {
  test('shipped base URLs are configured (no REPLACE_ME placeholder)', () {
    expect(AppConfig.dev.isBaseUrlConfigured, isTrue);
    expect(AppConfig.prod.isBaseUrlConfigured, isTrue);
  });

  test('a REPLACE_ME base URL is detected as not configured', () {
    final placeholder =
        AppConfig.prod.copyWith(baseUrl: 'https://REPLACE_ME.example');
    expect(placeholder.isBaseUrlConfigured, isFalse);
  });

  test('apiBaseUrl combines base + prefix', () {
    expect(AppConfig.dev.apiBaseUrl.endsWith('/api/v1'), isTrue);
  });

  test('prod disables logging, dev enables it', () {
    expect(AppConfig.prod.enableLogging, isFalse);
    expect(AppConfig.dev.enableLogging, isTrue);
  });
}
