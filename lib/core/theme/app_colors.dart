import 'package:flutter/material.dart';

/// Raw color values from the design's "00 · Color tokens" (Aurora Bloom).
/// Prefer accessing colors via [Theme.of] / [NexveeroColors] extension rather than
/// these constants directly, except when seeding themes.
class AppColors {
  AppColors._();

  // Brand / gradient
  static const Color primary = Color(0xFF6C47FF);
  static const Color primaryDark = Color(0xFFA78BFF); // primary in dark theme
  static const Color accent = Color(0xFFFF4D9D);
  static const Color accentDark = Color(0xFFFF74B4);
  static const Color gradientStart = Color(0xFF6C47FF);
  static const Color gradientEnd = Color(0xFFFF4D9D);
  static const Color gradientAltEnd = Color(0xFFFF6FB0);
  static const Color primaryTint = Color(0xFFECE7FB);

  // Neutrals · light
  static const Color lightBackground = Color(0xFFF6F5FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFECE9F3);
  static const Color lightTextPrimary = Color(0xFF17141F);
  static const Color lightTextSecondary = Color(0xFF6E6880);
  static const Color lightIconInactive = Color(0xFF9B93AD);

  // Neutrals · dark
  static const Color darkBackground = Color(0xFF0E0B16);
  static const Color darkSurface = Color(0xFF17121F);
  static const Color darkElevated = Color(0xFF221B33);
  static const Color darkBorder = Color(0xFF24202E);
  static const Color darkTextPrimary = Color(0xFFF3F1F8);
  static const Color darkTextSecondary = Color(0xFFA49CB8);
  static const Color darkIconInactive = Color(0xFF6B6480);

  // Semantic (light)
  static const Color success = Color(0xFF1FA971);
  static const Color error = Color(0xFFE5484D);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color teal = Color(0xFF12B5A6);

  // Semantic (dark variants)
  static const Color successDark = Color(0xFF2FBF71);
  static const Color errorDark = Color(0xFFFF6369);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color tealDark = Color(0xFF34D6C6);
}

/// Brand tokens that don't fit Material's [ColorScheme]. Exposed as a
/// [ThemeExtension] so widgets read them via `Theme.of(context).extension`
/// (or the `context.nexveero` helper) and they swap correctly light↔dark.
@immutable
class NexveeroColors extends ThemeExtension<NexveeroColors> {
  const NexveeroColors({
    required this.gradientStart,
    required this.gradientEnd,
    required this.textSecondary,
    required this.iconInactive,
    required this.border,
    required this.elevated,
    required this.success,
    required this.warning,
    required this.info,
    required this.teal,
  });

  final Color gradientStart;
  final Color gradientEnd;
  final Color textSecondary;
  final Color iconInactive;
  final Color border;
  final Color elevated;
  final Color success;
  final Color warning;
  final Color info;
  final Color teal;

  /// The brand primary gradient used for hero CTAs (Request, splash, etc.).
  LinearGradient get primaryGradient => LinearGradient(
        colors: [gradientStart, gradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const NexveeroColors light = NexveeroColors(
    gradientStart: AppColors.gradientStart,
    gradientEnd: AppColors.gradientEnd,
    textSecondary: AppColors.lightTextSecondary,
    iconInactive: AppColors.lightIconInactive,
    border: AppColors.lightBorder,
    elevated: AppColors.lightSurface,
    success: AppColors.success,
    warning: AppColors.warning,
    info: AppColors.info,
    teal: AppColors.teal,
  );

  static const NexveeroColors dark = NexveeroColors(
    gradientStart: AppColors.primaryDark,
    gradientEnd: AppColors.accentDark,
    textSecondary: AppColors.darkTextSecondary,
    iconInactive: AppColors.darkIconInactive,
    border: AppColors.darkBorder,
    elevated: AppColors.darkElevated,
    success: AppColors.successDark,
    warning: AppColors.warningDark,
    info: AppColors.info,
    teal: AppColors.tealDark,
  );

  @override
  NexveeroColors copyWith({
    Color? gradientStart,
    Color? gradientEnd,
    Color? textSecondary,
    Color? iconInactive,
    Color? border,
    Color? elevated,
    Color? success,
    Color? warning,
    Color? info,
    Color? teal,
  }) {
    return NexveeroColors(
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      textSecondary: textSecondary ?? this.textSecondary,
      iconInactive: iconInactive ?? this.iconInactive,
      border: border ?? this.border,
      elevated: elevated ?? this.elevated,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      teal: teal ?? this.teal,
    );
  }

  @override
  NexveeroColors lerp(ThemeExtension<NexveeroColors>? other, double t) {
    if (other is! NexveeroColors) return this;
    return NexveeroColors(
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      iconInactive: Color.lerp(iconInactive, other.iconInactive, t)!,
      border: Color.lerp(border, other.border, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
    );
  }
}
