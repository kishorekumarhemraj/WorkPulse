import 'package:flutter/material.dart';

/// WorkPulse typography.
///
/// Two bundled families (no network fetch — see AGENTS.md rule 8):
///  * **Inter** for all UI text.
///  * **JetBrains Mono** for numerics, via [AppTypography.numeric].
///
/// Every number the user reads — durations, clock times, counts — must use a
/// tabular style so digits occupy equal width. Without it a ticking timer
/// visibly jitters as its glyphs change width, which is exactly the bug the
/// old hardcoded `fontFamily: 'Courier'` was working around.
abstract class AppTypography {
  static const String fontFamily = 'Inter';
  static const String monoFontFamily = 'JetBrainsMono';

  /// Proportional digits look uneven in columns; these features fix that.
  static const List<FontFeature> _tabular = [
    FontFeature.tabularFigures(),
    FontFeature.slashedZero(),
  ];

  /// Builds the app [TextTheme] for a given text colour pair.
  ///
  /// Role mapping used across the app:
  ///  * `headlineSmall` — page titles
  ///  * `titleMedium`   — card / section titles
  ///  * `titleSmall`    — list row titles
  ///  * `bodyMedium`    — default body text
  ///  * `bodySmall`     — supporting text and metadata
  ///  * `labelLarge`    — buttons
  ///  * `labelMedium`   — chips and badges
  ///  * `labelSmall`    — overline / uppercase micro-labels
  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    return TextTheme(
      // Page-level titles.
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 21,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      // Supporting text. 12 is the floor for readable UI text — the old design
      // used 10 and 11 in badges, which is below what is comfortable on a
      // Retina display at normal viewing distance.
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: secondary,
      ),
    );
  }

  /// Monospaced, tabular numerics — durations, clock times, counts.
  static TextStyle numeric({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: monoFontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: _tabular,
    );
  }

  /// The large live ticker in the active timer bar and Quick Capture.
  static TextStyle ticker({required Color color, double fontSize = 15}) {
    return numeric(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 0.2,
    );
  }

  /// Applies tabular figures to an existing (Inter) style, for numbers that
  /// should stay in the UI face but still align in columns.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: _tabular);
}
