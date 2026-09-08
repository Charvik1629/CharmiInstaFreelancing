import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/config/app_config.dart';

void main() {
  test('placeholder base URL is detected as not configured', () {
    expect(AppConfig.dev.isBaseUrlConfigured, isFalse);
    expect(AppConfig.prod.isBaseUrlConfigured, isFalse);
  });

  test('apiBaseUrl combines base + prefix', () {
    expect(AppConfig.dev.apiBaseUrl.endsWith('/api/v1'), isTrue);
  });

  test('prod disables logging, dev enables it', () {
    expect(AppConfig.prod.enableLogging, isFalse);
    expect(AppConfig.dev.enableLogging, isTrue);
  });
}
