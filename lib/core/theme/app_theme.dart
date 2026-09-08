import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the Aurora Bloom light and dark [ThemeData]. Every screen ships both;
/// body text targets contrast >= 4.5:1 per the design brief.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.teal,
          onSecondary: Colors.white,
          tertiary: AppColors.accent,
          onTertiary: Colors.white,
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightTextPrimary,
          error: AppColors.error,
          onError: Colors.white,
          outline: AppColors.lightBorder,
        ),
        background: AppColors.lightBackground,
        textColor: AppColors.lightTextPrimary,
        nexveero: NexveeroColors.light,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme.dark(
          primary: AppColors.primaryDark,
          onPrimary: Color(0xFF14101F),
          secondary: AppColors.tealDark,
          onSecondary: Color(0xFF08201D),
          tertiary: AppColors.accentDark,
          onTertiary: Color(0xFF2A0A1B),
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          error: AppColors.errorDark,
          onError: Color(0xFF2A0A0B),
          outline: AppColors.darkBorder,
        ),
        background: AppColors.darkBackground,
        textColor: AppColors.darkTextPrimary,
        nexveero: NexveeroColors.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color background,
    required Color textColor,
    required NexveeroColors nexveero,
  }) {
    final textTheme = AppTypography.textTheme(textColor);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [nexveero],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        foregroundColor: textColor,
      ),
      dividerTheme: DividerThemeData(color: nexveero.border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: nexveero.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? AppColors.lightBackground
            : AppColors.darkElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: nexveero.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: nexveero.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: nexveero.iconInactive),
        labelStyle: textTheme.labelLarge?.copyWith(color: nexveero.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: nexveero.elevated,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

/// Convenience accessor for [NexveeroColors] with a safe fallback so widgets never
/// crash if the extension is missing (e.g. in a bare test harness).
extension NexveeroThemeX on BuildContext {
  NexveeroColors get nexveero =>
      Theme.of(this).extension<NexveeroColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? NexveeroColors.dark
          : NexveeroColors.light);
}
