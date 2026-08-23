import 'package:flutter/material.dart';

/// The WorkPulse colour system, exposed as a [ThemeExtension] so widgets
/// resolve colours through the ambient [Theme] rather than a static lookup.
///
/// Design direction: **native macOS restraint**. Surfaces are neutral greys;
/// a single blue carries interactive intent. Colour is reserved for *data* —
/// project and tag hues, run/idle/archive status, chart series — so that when
/// a user's projects are colourful the UI shows it, instead of competing
/// with it.
///
/// Access it with `context.colors` (see [WorkPulseColorsX]).
@immutable
class WorkPulseColors extends ThemeExtension<WorkPulseColors> {
  // --- Surfaces, back to front -------------------------------------------
  /// The window backdrop, behind all content.
  final Color background;

  /// Panels and content sheets sitting on [background] (sidebar, cards).
  final Color surface;

  /// Inset fills on [surface] — input fields, badge backgrounds.
  final Color card;

  /// Surfaces lifted above [surface] — menus, dialogs, floating panels.
  final Color surfaceRaised;

  /// Recessed wells — code blocks, nested list containers.
  final Color surfaceSunken;

  // --- Content ------------------------------------------------------------
  /// Primary reading text and active icons.
  final Color textPrimary;

  /// Supporting text, inactive icons, metadata.
  final Color textSecondary;

  /// De-emphasised text — placeholders, disabled labels.
  final Color textTertiary;

  /// Text and icons placed on a filled accent surface.
  final Color onAccent;

  // --- Lines and interaction states --------------------------------------
  /// Hairline borders and separators.
  final Color divider;

  /// A stronger border, for focused or emphasised containers.
  final Color borderStrong;

  /// Overlay applied on pointer hover.
  final Color hover;

  /// Overlay applied while pressed.
  final Color pressed;

  /// Keyboard focus ring.
  final Color focusRing;

  /// Scrim behind modal surfaces.
  final Color overlay;

  /// Selected row / active nav item fill.
  final Color selected;

  // --- Semantic roles ----------------------------------------------------
  /// Interactive accent — buttons, links, selection.
  final Color accent;

  /// A pressed/hovered variant of [accent].
  final Color accentHover;

  /// Low-opacity [accent] fill for tinted containers.
  final Color accentSubtle;

  /// Running timers, completed work, positive deltas.
  final Color success;
  final Color successSubtle;

  /// Idle time, archived items, cautions.
  final Color warning;
  final Color warningSubtle;

  /// Destructive actions and errors.
  final Color danger;
  final Color dangerSubtle;

  /// Neutral informational highlights.
  final Color info;
  final Color infoSubtle;

  const WorkPulseColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.onAccent,
    required this.divider,
    required this.borderStrong,
    required this.hover,
    required this.pressed,
    required this.focusRing,
    required this.overlay,
    required this.selected,
    required this.accent,
    required this.accentHover,
    required this.accentSubtle,
    required this.success,
    required this.successSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.danger,
    required this.dangerSubtle,
    required this.info,
    required this.infoSubtle,
  });

  /// Dark appearance — the app's default.
  static const WorkPulseColors dark = WorkPulseColors(
    background: Color(0xFF1A1A1C),
    surface: Color(0xFF232326),
    card: Color(0xFF2C2C30),
    surfaceRaised: Color(0xFF303034),
    surfaceSunken: Color(0xFF151517),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFA1A1A8),
    textTertiary: Color(0xFF6E6E76),
    onAccent: Color(0xFFFFFFFF),
    divider: Color(0xFF3A3A3F),
    borderStrong: Color(0xFF4A4A50),
    hover: Color(0x14FFFFFF),
    pressed: Color(0x24FFFFFF),
    focusRing: Color(0xFF0A84FF),
    overlay: Color(0x99000000),
    selected: Color(0x260A84FF),
    accent: Color(0xFF0A84FF),
    accentHover: Color(0xFF3D9DFF),
    accentSubtle: Color(0x1F0A84FF),
    success: Color(0xFF30D158),
    successSubtle: Color(0x2630D158),
    warning: Color(0xFFFF9F0A),
    warningSubtle: Color(0x26FF9F0A),
    danger: Color(0xFFFF453A),
    dangerSubtle: Color(0x26FF453A),
    info: Color(0xFF64D2FF),
    infoSubtle: Color(0x2664D2FF),
  );

  /// Light appearance.
  static const WorkPulseColors light = WorkPulseColors(
    background: Color(0xFFF7F7F9),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFF2F2F5),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEDEDF0),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF60606A),
    textTertiary: Color(0xFF8E8E96),
    onAccent: Color(0xFFFFFFFF),
    divider: Color(0xFFE2E2E7),
    borderStrong: Color(0xFFC9C9D0),
    hover: Color(0x0A000000),
    pressed: Color(0x14000000),
    focusRing: Color(0xFF0A84FF),
    overlay: Color(0x40000000),
    selected: Color(0x1A007AFF),
    accent: Color(0xFF007AFF),
    accentHover: Color(0xFF0063D1),
    accentSubtle: Color(0x14007AFF),
    // Slightly darkened from the dark-mode values so they stay legible
    // against white surfaces.
    success: Color(0xFF248A3D),
    successSubtle: Color(0x1F30D158),
    warning: Color(0xFFB25000),
    warningSubtle: Color(0x1FFF9F0A),
    danger: Color(0xFFD70015),
    dangerSubtle: Color(0x1FFF453A),
    info: Color(0xFF0071A4),
    infoSubtle: Color(0x1F64D2FF),
  );

  @override
  WorkPulseColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? onAccent,
    Color? divider,
    Color? borderStrong,
    Color? hover,
    Color? pressed,
    Color? focusRing,
    Color? overlay,
    Color? selected,
    Color? accent,
    Color? accentHover,
    Color? accentSubtle,
    Color? success,
    Color? successSubtle,
    Color? warning,
    Color? warningSubtle,
    Color? danger,
    Color? dangerSubtle,
    Color? info,
    Color? infoSubtle,
  }) {
    return WorkPulseColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      onAccent: onAccent ?? this.onAccent,
      divider: divider ?? this.divider,
      borderStrong: borderStrong ?? this.borderStrong,
      hover: hover ?? this.hover,
      pressed: pressed ?? this.pressed,
      focusRing: focusRing ?? this.focusRing,
      overlay: overlay ?? this.overlay,
      selected: selected ?? this.selected,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      danger: danger ?? this.danger,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      info: info ?? this.info,
      infoSubtle: infoSubtle ?? this.infoSubtle,
    );
  }

  @override
  WorkPulseColors lerp(covariant WorkPulseColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return WorkPulseColors(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      card: c(card, other.card),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      onAccent: c(onAccent, other.onAccent),
      divider: c(divider, other.divider),
      borderStrong: c(borderStrong, other.borderStrong),
      hover: c(hover, other.hover),
      pressed: c(pressed, other.pressed),
      focusRing: c(focusRing, other.focusRing),
      overlay: c(overlay, other.overlay),
      selected: c(selected, other.selected),
      accent: c(accent, other.accent),
      accentHover: c(accentHover, other.accentHover),
      accentSubtle: c(accentSubtle, other.accentSubtle),
      success: c(success, other.success),
      successSubtle: c(successSubtle, other.successSubtle),
      warning: c(warning, other.warning),
      warningSubtle: c(warningSubtle, other.warningSubtle),
      danger: c(danger, other.danger),
      dangerSubtle: c(dangerSubtle, other.dangerSubtle),
      info: c(info, other.info),
      infoSubtle: c(infoSubtle, other.infoSubtle),
    );
  }
}

/// `context.colors` — the canonical way to reach the palette.
extension WorkPulseColorsX on BuildContext {
  WorkPulseColors get colors =>
      Theme.of(this).extension<WorkPulseColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? WorkPulseColors.dark
          : WorkPulseColors.light);
}
