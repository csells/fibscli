import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The "Modern Editorial" design system: ivory and ink with a single sharp
/// vermillion accent, an elegant display serif over a clean grotesque, hairline
/// rules, and generous negative space. Every screen draws its colors, type, and
/// component styling from here so the whole app reads as one considered object.
abstract final class AppColors {
  /// Primary page/surface background.
  static const ivory = Color(0xFFF5F2EB);

  /// Secondary surface and the lighter of the two board-point fills.
  static const bone = Color(0xFFEFEBE1);

  /// Near-black used for text, hairlines, and the solid checkers.
  static const ink = Color(0xFF16130F);

  /// Softer ink for secondary text and ghost controls.
  static const inkSoft = Color(0xFF4A443B);

  /// Faint ink for captions, point numbers, and disabled states.
  static const inkFaint = Color(0xFF8A8377);

  /// The lone accent: vermillion, reserved for emphasis (the turn indicator,
  /// the primary action, active states). Used sparingly on purpose.
  static const accent = Color(0xFFE1341E);

  /// The muted secondary board-point fill (the darker triangles) and the bar.
  static const stone = Color(0xFFD8D2C4);

  /// A deeper stone for pressed/secondary emphasis.
  static const stoneDeep = Color(0xFFC9C2B0);

  /// Hairline rule color (ink at 16% — the editorial divider).
  static const line = Color(0x2916130F);

  /// A fainter hairline for disabled outlines.
  static const lineFaint = Color(0x1416130F);
}

/// Editorial type scale: [GoogleFonts.instrumentSerif] for large display copy,
/// [GoogleFonts.publicSans] for everything functional. Instrument Serif ships
/// only regular + italic, so it lives at display/headline sizes where its
/// character reads; Public Sans carries titles, body, and labels.
TextTheme _editorialTextTheme(TextTheme base) {
  final serif = GoogleFonts.instrumentSerif(color: AppColors.ink);
  TextStyle display(
    double size, {
    double height = 0.98,
    double spacing = -0.5,
  }) => serif.copyWith(fontSize: size, height: height, letterSpacing: spacing);
  final sans = GoogleFonts.publicSansTextTheme(
    base,
  ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  return sans.copyWith(
    displayLarge: display(72),
    displayMedium: display(56),
    displaySmall: display(44),
    headlineLarge: display(38, height: 1),
    headlineMedium: display(32, height: 1.02),
    headlineSmall: serif.copyWith(fontSize: 26, height: 1.05),
    titleLarge: sans.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: sans.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: sans.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.08 * 13,
    ),
  );
}

/// A small-caps, wide-tracked label — the editorial kicker/caption used for
/// section eyebrows ("HOME BOARD", "THE BAR") and control labels.
TextStyle editorialKicker({Color? color, double size = 11}) =>
    GoogleFonts.publicSans(
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: size * 0.18,
      color: color ?? AppColors.inkFaint,
    );

/// The single [ThemeData] the app runs on. Material 3, light, built around the
/// [AppColors] palette rather than a seed so the ivory/ink/vermillion identity
/// is exact.
ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.ink,
    onPrimary: AppColors.ivory,
    secondary: AppColors.accent,
    onSecondary: AppColors.ivory,
    error: AppColors.accent,
    onError: AppColors.ivory,
    surface: AppColors.ivory,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.bone,
    outline: AppColors.inkFaint,
    outlineVariant: AppColors.stone,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ivory,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  return base.copyWith(
    textTheme: _editorialTextTheme(base.textTheme),
    dividerColor: AppColors.line,
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ivory,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.instrumentSerif(
        color: AppColors.ink,
        fontSize: 26,
        height: 1,
      ),
      shape: const Border(bottom: BorderSide(color: AppColors.ink)),
    ),
    // The primary CTA: vermillion, crisp, tightly tracked small-caps.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.ivory,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        textStyle: GoogleFonts.publicSans(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 1.1,
        ),
      ),
    ),
    // The secondary/ghost action: ink hairline outline on ivory.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.ink, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        textStyle: GoogleFonts.publicSans(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 1.1,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.inkSoft,
        textStyle: GoogleFonts.publicSans(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.ink),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.ivory,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 4,
      highlightElevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.ivory,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: AppColors.ink),
      ),
      titleTextStyle: GoogleFonts.instrumentSerif(
        color: AppColors.ink,
        fontSize: 30,
        height: 1.05,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bone,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.inkSoft),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: GoogleFonts.publicSans(color: AppColors.ivory),
      actionTextColor: AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
  );
}
