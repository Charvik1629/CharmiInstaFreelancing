import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale from "02 · System": Sora for display/headlines, Plus Jakarta Sans
/// for UI text. Line heights are expressed as `height = leading / fontSize`.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Color textColor) {
    TextStyle sora(double size, FontWeight weight, double leading) =>
        GoogleFonts.sora(
          fontSize: size,
          fontWeight: weight,
          height: leading / size,
          color: textColor,
        );
    TextStyle jakarta(double size, FontWeight weight, double leading) =>
        GoogleFonts.plusJakartaSans(
          fontSize: size,
          fontWeight: weight,
          height: leading / size,
          color: textColor,
        );

    return TextTheme(
      // Display — Sora 800 · 34/40
      displayLarge: sora(34, FontWeight.w800, 40),
      // Heading 1 — Sora 700 · 26/32
      headlineMedium: sora(26, FontWeight.w700, 32),
      // Heading 2 — Jakarta 700 · 20/26
      titleLarge: jakarta(20, FontWeight.w700, 26),
      // Title — Jakarta 600 · 16/22
      titleMedium: jakarta(16, FontWeight.w600, 22),
      // Body — Jakarta 400 · 14.5/22
      bodyMedium: jakarta(14.5, FontWeight.w400, 22),
      bodyLarge: jakarta(15.5, FontWeight.w400, 24),
      // Label — Jakarta 600 · 12/16
      labelLarge: jakarta(12, FontWeight.w600, 16),
      labelMedium: jakarta(12, FontWeight.w600, 16),
      // Caption / meta — Jakarta 500 · 11/15
      bodySmall: jakarta(11, FontWeight.w500, 15),
    );
  }
}
