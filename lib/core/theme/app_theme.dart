import 'package:flutter/material.dart';

/// WorkPulse macOS-focused theme definitions
class AppTheme {
  // Brand / Accent colors
  static const Color primaryColor = Color(0xFF0A84FF); // macOS accent blue
  static const Color primaryDark = Color(0xFF0066CC);
  static const Color accentGreen = Color(0xFF30D158);
  static const Color accentOrange = Color(0xFFFF9F0A);
  static const Color accentPurple = Color(0xFFBF5AF2);
  static const Color accentRed = Color(0xFFFF453A);

  // Neutral palette (Dark mode first for macOS utility feel)
  static const Color backgroundDark = Color(0xFF1E1E1E);
  static const Color surfaceDark = Color(0xFF2D2D2D);
  static const Color cardDark = Color(0xFF383838);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);
  static const Color dividerDark = Color(0xFF404040);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentGreen,
        surface: surfaceDark,
        error: accentRed,
      ),
      cardTheme: const CardTheme(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentGreen,
        surface: Colors.white,
        error: accentRed,
      ),
    );
  }
}
