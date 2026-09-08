import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/theme/app_theme.dart';
import 'package:charmi_insta_freelancing/core/theme/app_colors.dart';

void main() {
  test('light and dark themes expose NexveeroColors extension', () {
    expect(AppTheme.light.extension<NexveeroColors>(), isNotNull);
    expect(AppTheme.dark.extension<NexveeroColors>(), isNotNull);
  });

  test('light theme uses brand primary, dark uses lighter primary', () {
    expect(AppTheme.light.colorScheme.primary, AppColors.primary);
    expect(AppTheme.dark.colorScheme.primary, AppColors.primaryDark);
  });

  test('themes carry correct brightness', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });

  test('NexveeroColors.lerp interpolates and is stable at endpoints', () {
    final a = NexveeroColors.light;
    final b = NexveeroColors.dark;
    expect(a.lerp(b, 0).gradientStart, a.gradientStart);
    expect(a.lerp(b, 1).gradientStart, b.gradientStart);
    // Non-NexveeroColors falls back to self.
    expect(a.lerp(null, 0.5), a);
  });
}
