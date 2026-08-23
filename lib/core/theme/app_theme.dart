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

  // Neutral palette (Dark mode)
  static const Color backgroundDark = Color(0xFF1E1E1E);
  static const Color surfaceDark = Color(0xFF2D2D2D);
  static const Color cardDark = Color(0xFF383838);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);
  static const Color dividerDark = Color(0xFF404040);

  // Neutral palette (Light mode)
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1E1E1E);
  static const Color textSecondaryLight = Color(0xFF666666);
  static const Color dividerLight = Color(0xFFE0E0E0);

  // Common Border Radii
  static final BorderRadius controlRadius = BorderRadius.circular(8);
  static final BorderRadius dialogRadius = BorderRadius.circular(12);

  // Get theme colors based on current brightness
  static AppThemeColors getColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _darkColors : _lightColors;
  }

  static const AppThemeColors _darkColors = AppThemeColors(
    background: backgroundDark,
    surface: surfaceDark,
    card: cardDark,
    textPrimary: textPrimaryDark,
    textSecondary: textSecondaryDark,
    divider: dividerDark,
  );

  static const AppThemeColors _lightColors = AppThemeColors(
    background: backgroundLight,
    surface: surfaceLight,
    card: cardLight,
    textPrimary: textPrimaryLight,
    textSecondary: textSecondaryLight,
    divider: dividerLight,
  );

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
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: controlRadius,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: const BorderSide(color: dividerDark),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondaryDark,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryDark,
          side: const BorderSide(color: dividerDark),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: cardDark,
        hintStyle: const TextStyle(fontSize: 13, color: textSecondaryDark),
        labelStyle: const TextStyle(fontSize: 13, color: textSecondaryDark),
        border: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: dividerDark, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: dividerDark, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: accentRed, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: accentRed, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: dividerDark.withValues(alpha: 0.5), width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surfaceDark,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: cardDark,
        headerForegroundColor: textPrimaryDark,
        headerHeadlineStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return null;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          if (states.contains(WidgetState.disabled)) return textSecondaryDark.withValues(alpha: 0.4);
          return textPrimaryDark;
        }),
        todayBorder: const BorderSide(color: primaryColor, width: 1.0),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return primaryColor;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: const BorderSide(color: dividerDark),
        ),
        dividerColor: dividerDark,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentGreen,
        surface: surfaceLight,
        error: accentRed,
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: controlRadius,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: const BorderSide(color: dividerLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryLight,
          side: const BorderSide(color: dividerLight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: cardLight,
        hintStyle: const TextStyle(fontSize: 13, color: textSecondaryLight),
        labelStyle: const TextStyle(fontSize: 13, color: textSecondaryLight),
        border: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: dividerLight, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: dividerLight, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: accentRed, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: accentRed, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: dividerLight.withValues(alpha: 0.5), width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surfaceLight,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: cardLight,
        headerForegroundColor: textPrimaryLight,
        headerHeadlineStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return null;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          if (states.contains(WidgetState.disabled)) return textSecondaryLight.withValues(alpha: 0.4);
          return textPrimaryLight;
        }),
        todayBorder: const BorderSide(color: primaryColor, width: 1.0),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return primaryColor;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: const BorderSide(color: dividerLight),
        ),
        dividerColor: dividerLight,
      ),
    );
  }
}

class AppThemeColors {
  final Color background;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
  });
}
