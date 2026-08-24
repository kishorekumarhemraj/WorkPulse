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

  /// Inset tinted fills on [surface] — badge and chip backgrounds.
  ///
  /// Not the fill for text inputs; those use [field]. The two were one token
  /// until the light theme showed why they cannot be: a tint that reads as a
  /// quiet badge on white is the same tint that makes every input look like a
  /// grey slab.
  final Color card;

  /// The fill for text inputs and other editable controls.
  ///
  /// Light inputs are white with a border, following the platform
  /// convention, rather than a grey fill that competes with [card].
  final Color field;

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

  /// The colour drop shadows are drawn in — see [Elevation].
  ///
  /// Dark surfaces separate by luminance alone, so their shadows only need to
  /// deepen the gap. Light surfaces are all within a few percent of white and
  /// have nothing to separate them but a hairline, which is why the light
  /// value is tinted rather than neutral black: a cool grey shadow reads as
  /// depth where flat black reads as dirt.
  final Color shadow;

  // --- Semantic roles ----------------------------------------------------
  /// Interactive accent — buttons, links, selection.
  final Color accent;

  /// A pressed/hovered variant of [accent].
  final Color accentHover;

  /// Low-opacity [accent] fill for tinted containers.
  final Color accentSubtle;

  /// The background of a *filled* accent button.
  ///
  /// Distinct from [accent] because the two have opposing contrast needs:
  /// [accent] is read as text against dark surfaces, so it must be light,
  /// while a filled button carries white text and so must be dark enough for
  /// that text to clear AA. One colour cannot do both.
  final Color accentFill;

  /// Running timers, completed work, positive deltas.
  final Color success;
  final Color successSubtle;

  /// Idle time, archived items, cautions.
  final Color warning;
  final Color warningSubtle;

  /// Destructive actions and errors.
  final Color danger;
  final Color dangerSubtle;

  /// The background of a *filled* destructive button — see [accentFill].
  final Color dangerFill;

  /// Neutral informational highlights.
  final Color info;
  final Color infoSubtle;

  const WorkPulseColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.field,
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
    required this.shadow,
    required this.accent,
    required this.accentHover,
    required this.accentSubtle,
    required this.accentFill,
    required this.success,
    required this.successSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.danger,
    required this.dangerSubtle,
    required this.dangerFill,
    required this.info,
    required this.infoSubtle,
  });

  /// Dark appearance — the app's default.
  ///
  /// Every text and semantic colour here clears WCAG AA (4.5:1) against
  /// [background], [surface], [card] and [field]; design_system_test.dart
  /// enforces it.
  static const WorkPulseColors dark = WorkPulseColors(
    background: Color(0xFF1A1A1C),
    surface: Color(0xFF232326),
    card: Color(0xFF2C2C30),
    field: Color(0xFF2C2C30),
    surfaceRaised: Color(0xFF303034),
    surfaceSunken: Color(0xFF151517),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFA1A1A8),
    textTertiary: Color(0xFF97979F),
    onAccent: Color(0xFFFFFFFF),
    divider: Color(0xFF3A3A3F),
    borderStrong: Color(0xFF4A4A50),
    hover: Color(0x14FFFFFF),
    pressed: Color(0x24FFFFFF),
    focusRing: Color(0xFF1C96FF),
    overlay: Color(0x99000000),
    selected: Color(0x261C96FF),
    shadow: Color(0x66000000),
    accent: Color(0xFF1C96FF),
    accentHover: Color(0xFF52ABFF),
    accentSubtle: Color(0x1F1C96FF),
    accentFill: Color(0xFF0076DF),
    success: Color(0xFF30D158),
    successSubtle: Color(0x2630D158),
    warning: Color(0xFFFF9F0A),
    warningSubtle: Color(0x26FF9F0A),
    danger: Color(0xFFFF5A4F),
    dangerSubtle: Color(0x26FF453A),
    dangerFill: Color(0xFFDC372C),
    info: Color(0xFF64D2FF),
    infoSubtle: Color(0x2664D2FF),
  );

  /// Light appearance.
  ///
  /// Retuned so the surfaces actually separate: the old palette placed
  /// [background], [card] and [surfaceSunken] within 4% luminance of each
  /// other, which left every filled control invisible on the page and grey on
  /// a white sheet at the same time. Depth now comes from a real
  /// [background]/[surface] step, a [divider] heavy enough to read on white,
  /// and [Elevation] shadows — not from stacking near-identical greys.
  static const WorkPulseColors light = WorkPulseColors(
    background: Color(0xFFF1F2F5),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFEDEEF2),
    field: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFE9EAEF),
    textPrimary: Color(0xFF16161A),
    textSecondary: Color(0xFF53535E),
    textTertiary: Color(0xFF63636D),
    onAccent: Color(0xFFFFFFFF),
    divider: Color(0xFFD8D9E0),
    borderStrong: Color(0xFFB6B7C1),
    hover: Color(0x14000000),
    pressed: Color(0x24000000),
    focusRing: Color(0xFF005FD1),
    overlay: Color(0x59000000),
    selected: Color(0x24005FD1),
    shadow: Color(0x1F0B0B14),
    accent: Color(0xFF005FD1),
    accentHover: Color(0xFF0049A3),
    accentSubtle: Color(0x21005FD1),
    accentFill: Color(0xFF005FD1),
    success: Color(0xFF0B7333),
    successSubtle: Color(0x1F30D158),
    warning: Color(0xFF9A5300),
    warningSubtle: Color(0x1FFF9F0A),
    danger: Color(0xFFCE0016),
    dangerSubtle: Color(0x1FFF453A),
    dangerFill: Color(0xFFCE0016),
    info: Color(0xFF0A6E93),
    infoSubtle: Color(0x1F64D2FF),
  );

  @override
  WorkPulseColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? field,
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
    Color? shadow,
    Color? accent,
    Color? accentHover,
    Color? accentSubtle,
    Color? accentFill,
    Color? success,
    Color? successSubtle,
    Color? warning,
    Color? warningSubtle,
    Color? danger,
    Color? dangerSubtle,
    Color? dangerFill,
    Color? info,
    Color? infoSubtle,
  }) {
    return WorkPulseColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      field: field ?? this.field,
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
      shadow: shadow ?? this.shadow,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      accentFill: accentFill ?? this.accentFill,
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      danger: danger ?? this.danger,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      dangerFill: dangerFill ?? this.dangerFill,
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
      field: c(field, other.field),
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
      shadow: c(shadow, other.shadow),
      accent: c(accent, other.accent),
      accentHover: c(accentHover, other.accentHover),
      accentSubtle: c(accentSubtle, other.accentSubtle),
      accentFill: c(accentFill, other.accentFill),
      success: c(success, other.success),
      successSubtle: c(successSubtle, other.successSubtle),
      warning: c(warning, other.warning),
      warningSubtle: c(warningSubtle, other.warningSubtle),
      danger: c(danger, other.danger),
      dangerSubtle: c(dangerSubtle, other.dangerSubtle),
      dangerFill: c(dangerFill, other.dangerFill),
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
