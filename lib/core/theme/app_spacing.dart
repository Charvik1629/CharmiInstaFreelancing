/// 4pt spacing grid and corner-radius tokens from "02 · System".
/// Use these instead of magic numbers so layouts stay on the grid.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii: 8 / 12 / 18 / 24 / full.
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
  static const double xl = 24;
  static const double full = 999;
}
