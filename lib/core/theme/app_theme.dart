import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// WorkPulse macOS-focused theme definitions.
///
/// The palette itself lives in [WorkPulseColors] and is attached to each
/// [ThemeData] as a extension, so widgets resolve colours via
/// `context.colors`. This class assembles the Material component themes on top
/// of it.
class AppTheme {
  // The fatal-error screen in main.dart renders before any Theme exists, so
  // it cannot reach the palette through context. These few constants mirror
  // WorkPulseColors.dark for that one pre-theme case.
  static const Color backgroundDark = Color(0xFF1A1A1C);
  static const Color textSecondaryDark = Color(0xFFA1A1A8);
  static const Color accentRed = Color(0xFFFF453A);

  static ThemeData get darkTheme =>
      _build(WorkPulseColors.dark, Brightness.dark);

  static ThemeData get lightTheme =>
      _build(WorkPulseColors.light, Brightness.light);

  static ThemeData _build(WorkPulseColors c, Brightness brightness) {
    final textTheme = AppTypography.textTheme(
      primary: c.textPrimary,
      secondary: c.textSecondary,
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1.0]) =>
        OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: color, width: width),
        );

    // Material 3 derives a button's hover from colorScheme.primary, so half the
    // app's controls hovered blue while rows and icon buttons hovered neutral.
    // One resolver, shared by every button style.
    WidgetStateProperty<Color?> buttonOverlay(WorkPulseColors c) =>
        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return c.pressed;
          if (states.contains(WidgetState.hovered)) return c.hover;
          if (states.contains(WidgetState.focused)) return c.hover;
          return null;
        });

    // Filled accent buttons carry onAccent text on accentFill. A white 8%
    // overlay on that is nearly invisible, so they use onAccent tints instead.
    WidgetStateProperty<Color?> accentButtonOverlay(WorkPulseColors c) =>
        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return c.onAccent.withValues(alpha: 0.20);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return c.onAccent.withValues(alpha: 0.12);
          }
          return null;
        });

    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      brightness: brightness,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.surface,
      dividerColor: c.divider,
      hoverColor: c.hover,
      highlightColor: c.pressed,
      splashColor: c.pressed,
      // Material's default (12% black/white) is barely visible on these
      // surfaces. Controls that draw their own ring — AppCard, SidebarNavItem,
      // AppSelect — opt out locally; everything else inherits this.
      focusColor: c.focusRing.withValues(alpha: 0.28),
      extensions: <ThemeExtension<dynamic>>[c],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.accent,
        onPrimary: c.onAccent,
        secondary: c.success,
        onSecondary: c.onAccent,
        error: c.danger,
        onError: c.onAccent,
        surface: c.surface,
        onSurface: c.textPrimary,
        surfaceContainerHighest: c.card,
        onSurfaceVariant: c.textSecondary,
        outline: c.divider,
        outlineVariant: c.divider,
      ),

      // --- Surfaces -----------------------------------------------------
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.xlAll,
          side: BorderSide(color: c.divider),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        // Painted by AppDialog via Elevation.high; Material's own elevation
        // would tint the surface as well as shadow it.
        elevation: 0,
        shadowColor: c.shadow,
        barrierColor: c.overlay,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.xlAll,
          side: BorderSide(color: c.divider),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: c.shadow,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: c.divider),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          // A light menu is white on white; without a shadow the only thing
          // separating it from the page is a hairline.
          elevation: const WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(c.shadow),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: Radii.mdAll,
              side: BorderSide(color: c.divider),
            ),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(c.textPrimary),
          overlayColor: buttonOverlay(c),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return c.hover;
            }
            return Colors.transparent;
          }),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.divider,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: Radii.smAll,
          border: Border.all(color: c.divider),
          boxShadow: Elevation.medium(c.shadow),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: c.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceRaised,
        contentTextStyle: textTheme.bodyMedium,
        actionTextColor: c.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        showCloseIcon: true,
        closeIconColor: c.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: c.divider),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return c.textSecondary.withValues(alpha: Alphas.heavy);
          }
          if (states.contains(WidgetState.hovered)) {
            return c.textSecondary.withValues(alpha: Alphas.strong);
          }
          return c.textSecondary.withValues(alpha: Alphas.muted);
        }),
        thickness: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ? 9 : 7,
        ),
        radius: const Radius.circular(Radii.xs),
        crossAxisMargin: 2,
        interactive: true,
      ),

      // --- Controls -----------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // accentFill, not accent: this carries white text.
          backgroundColor: c.accentFill,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.card,
          disabledForegroundColor: c.textTertiary,
          elevation: 0,
          minimumSize: const Size(0, ControlSizes.standard),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle: textTheme.labelLarge,
        ).copyWith(
          overlayColor: accentButtonOverlay(c),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accentFill,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.card,
          disabledForegroundColor: c.textTertiary,
          elevation: 0,
          minimumSize: const Size(0, ControlSizes.standard),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle: textTheme.labelLarge,
        ).copyWith(
          overlayColor: accentButtonOverlay(c),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textSecondary,
          minimumSize: const Size(0, ControlSizes.standard),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ).copyWith(
          overlayColor: buttonOverlay(c),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.divider),
          minimumSize: const Size(0, ControlSizes.standard),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ).copyWith(
          overlayColor: buttonOverlay(c),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textSecondary,
          hoverColor: c.hover,
          highlightColor: c.pressed,
          shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        ).copyWith(
          overlayColor: buttonOverlay(c),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        selectedColor: c.accentSubtle,
        disabledColor: c.card,
        side: BorderSide(color: c.divider),
        labelStyle: textTheme.labelMedium!,
        secondaryLabelStyle: textTheme.labelMedium!,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        showCheckmark: false,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(c.onAccent),
        side: BorderSide(color: c.divider),
        shape: const RoundedRectangleBorder(borderRadius: Radii.xsAll),
        overlayColor: buttonOverlay(c),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent;
          return c.textSecondary;
        }),
        overlayColor: buttonOverlay(c),
      ),
      switchTheme: SwitchThemeData(
        // Switch thumb is white on macOS in both light and dark themes by platform convention.
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.textTertiary;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return c.card;
          }
          if (states.contains(WidgetState.selected)) return c.accent;
          return c.borderStrong;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.smAll),
          ),
          overlayColor: buttonOverlay(c),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.card,
        circularTrackColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        selectedTileColor: c.selected,
        selectedColor: c.accent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
      ),

      // --- Inputs -------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: c.field,
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.textTertiary),
        labelStyle: textTheme.bodySmall,
        floatingLabelStyle: textTheme.bodySmall?.copyWith(color: c.accent),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: c.danger),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
        border: inputBorder(c.divider),
        enabledBorder: inputBorder(c.divider),
        focusedBorder: inputBorder(c.focusRing, 1.5),
        errorBorder: inputBorder(c.danger),
        focusedErrorBorder: inputBorder(c.danger, 1.5),
        disabledBorder: inputBorder(c.divider),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm + 2,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(c.shadow),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: Radii.mdAll,
              side: BorderSide(color: c.divider),
            ),
          ),
        ),
      ),

      // --- Pickers ------------------------------------------------------
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.card,
        headerForegroundColor: c.textPrimary,
        headerHeadlineStyle: textTheme.headlineSmall,
        dayStyle: textTheme.bodyMedium,
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.accent;
          return null;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.onAccent;
          if (states.contains(WidgetState.disabled)) return c.textTertiary;
          return c.textPrimary;
        }),
        rangeSelectionBackgroundColor: c.accentSubtle,
        todayBorder: BorderSide(color: c.accent),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.onAccent;
          return c.accent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: Radii.xlAll,
          side: BorderSide(color: c.divider),
        ),
        dividerColor: c.divider,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.surfaceRaised,
        dialBackgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.xlAll,
          side: BorderSide(color: c.divider),
        ),
      ),
    );
  }
}
