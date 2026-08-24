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

  /// The background of a *filled* accent button.
  ///
  /// Distinct from [accent] because the two have opposing contrast needs:
  /// [accent] is read as text against dark surfaces, so it must be light,
  /// while a filled button carries white text and so must be dark enough for
  /// that text to clear AA. One colour cannot do both.
  final Color accentFill;

  /// Low-opacity [accent] fill for tinted containers.
  final Color accentSubtle;

  /// Running timers, completed work, positive deltas — as *text*.
  ///
  /// Text on a light surface must be dark to clear AA, which is why the light
  /// value is a deep green and not the vivid one below. Anything that is a
  /// shape rather than a glyph wants [successFill].
  final Color success;

  /// The same role as a *fill*: chart bars, status dots, stripes.
  ///
  /// A shape carries no text, so it is free to be the hue the role actually
  /// means. Making one token serve both is what turned the light theme's
  /// activity chart forest-green and its idle bars brown. Dark mode needs no
  /// split — its text values are already vivid — so the two are equal there.
  final Color successFill;
  final Color successSubtle;

  /// Idle time, archived items, cautions — as *text*. See [success].
  final Color warning;

  /// The same role as a *fill*. See [successFill].
  final Color warningFill;
  final Color warningSubtle;

  /// Destructive actions and errors — as *text*.
  final Color danger;

  /// The background of a *filled* destructive button, and the fill
  /// hue for danger shapes. See [accentFill] and [successFill].
  final Color dangerFill;
  final Color dangerSubtle;

  /// Neutral informational highlights — as *text*. See [success].
  final Color info;

  /// The same role as a *fill*. See [successFill].
  final Color infoFill;
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
    required this.accentFill,
    required this.accentSubtle,
    required this.success,
    required this.successFill,
    required this.successSubtle,
    required this.warning,
    required this.warningFill,
    required this.warningSubtle,
    required this.danger,
    required this.dangerFill,
    required this.dangerSubtle,
    required this.info,
    required this.infoFill,
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
    accentFill: Color(0xFF0076DF),
    accentSubtle: Color(0x1F1C96FF),
    success: Color(0xFF30D158),
    successFill: Color(0xFF30D158),
    successSubtle: Color(0x2630D158),
    warning: Color(0xFFFF9F0A),
    warningFill: Color(0xFFFF9F0A),
    warningSubtle: Color(0x26FF9F0A),
    danger: Color(0xFFFF5A4F),
    dangerFill: Color(0xFFDC372C),
    dangerSubtle: Color(0x26FF453A),
    info: Color(0xFF64D2FF),
    infoFill: Color(0xFF64D2FF),
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
    accentFill: Color(0xFF005FD1),
    accentSubtle: Color(0x1C005FD1),
    success: Color(0xFF0B7333),
    successFill: Color(0xFF16A34A),
    successSubtle: Color(0x2916A34A),
    warning: Color(0xFF9A5300),
    warningFill: Color(0xFFEA8C00),
    warningSubtle: Color(0x2BEA8C00),
    danger: Color(0xFFCE0016),
    dangerFill: Color(0xFFCE0016),
    dangerSubtle: Color(0x13CE0016),
    info: Color(0xFF0A6E93),
    infoFill: Color(0xFF0EA5C6),
    infoSubtle: Color(0x220EA5C6),
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
    Color? accentFill,
    Color? accentSubtle,
    Color? success,
    Color? successFill,
    Color? successSubtle,
    Color? warning,
    Color? warningFill,
    Color? warningSubtle,
    Color? danger,
    Color? dangerFill,
    Color? dangerSubtle,
    Color? info,
    Color? infoFill,
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
      accentFill: accentFill ?? this.accentFill,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      success: success ?? this.success,
      successFill: successFill ?? this.successFill,
      successSubtle: successSubtle ?? this.successSubtle,
      warning: warning ?? this.warning,
      warningFill: warningFill ?? this.warningFill,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      danger: danger ?? this.danger,
      dangerFill: dangerFill ?? this.dangerFill,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      info: info ?? this.info,
      infoFill: infoFill ?? this.infoFill,
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
      accentFill: c(accentFill, other.accentFill),
      accentSubtle: c(accentSubtle, other.accentSubtle),
      success: c(success, other.success),
      successFill: c(successFill, other.successFill),
      successSubtle: c(successSubtle, other.successSubtle),
      warning: c(warning, other.warning),
      warningFill: c(warningFill, other.warningFill),
      warningSubtle: c(warningSubtle, other.warningSubtle),
      danger: c(danger, other.danger),
      dangerFill: c(dangerFill, other.dangerFill),
      dangerSubtle: c(dangerSubtle, other.dangerSubtle),
      info: c(info, other.info),
      infoFill: c(infoFill, other.infoFill),
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
