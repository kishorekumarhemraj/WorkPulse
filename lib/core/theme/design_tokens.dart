import 'package:flutter/material.dart';

/// Design tokens for WorkPulse.
///
/// The only sanctioned sources for spacing, radii, motion, icon sizes,
/// control heights and layout breakpoints. Widgets should never hardcode a
/// raw double for these properties — reach for the nearest token instead, so
/// the whole app rescales and re-skins from one place.

/// Spacing scale (4pt grid).
abstract class Spacing {
  /// 2 — hairline separation inside dense badges.
  static const double xxs = 2;

  /// 4 — icon-to-label gap.
  static const double xs = 4;

  /// 8 — tight internal padding, chip gutters.
  static const double sm = 8;

  /// 12 — control padding, list item gutters.
  static const double md = 12;

  /// 16 — card padding, form field separation.
  static const double lg = 16;

  /// 20 — section separation inside a card.
  static const double xl = 20;

  /// 24 — page padding, major section separation.
  static const double xxl = 24;
}

/// Corner radius scale.
abstract class Radii {
  /// 4 — dense badges and keycaps.
  static const double xs = 4;

  /// 6 — chips, small controls, nav items.
  static const double sm = 6;

  /// 8 — buttons, inputs, dropdowns.
  static const double md = 8;

  /// 10 — list rows.
  static const double lg = 10;

  /// 12 — cards and dialogs.
  static const double xl = 12;

  /// 16 — large surfaces, floating panels.
  static const double xxl = 16;

  /// Fully rounded (stadium).
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Drop-shadow scale.
///
/// Dark surfaces separate from one another by luminance, so shadow there is
/// only reinforcement. Light surfaces are all within a few percent of white —
/// a menu, a dialog and the page behind it are very nearly the same colour —
/// so shadow is the only thing that says which one is in front. Every level
/// takes the palette's [WorkPulseColors.shadow] rather than a hardcoded black,
/// which is what let the old tooltip look correct in dark and like grime in
/// light.
abstract class Elevation {
  /// Resting cards and inset panels. Barely there by design.
  static List<BoxShadow> low(Color shadow) => [
        BoxShadow(
          color: shadow,
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// Menus, popovers, tooltips — anything anchored to a control.
  static List<BoxShadow> medium(Color shadow) => [
        BoxShadow(
          color: shadow,
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: shadow,
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];

  /// Modal dialogs and floating panels, which must clear the whole page.
  static List<BoxShadow> high(Color shadow) => [
        BoxShadow(
          color: shadow,
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: shadow,
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
      ];
}

/// Animation durations and curves.
///
/// Desktop utilities should feel instant. Nothing here is longer than a
/// quarter second, and every animated widget must honour
/// [Motion.enabled] so the macOS "Reduce motion" setting is respected.
abstract class Motion {
  /// 120ms — hover and press feedback.
  static const Duration fast = Duration(milliseconds: 120);

  /// 150ms — the default for view and state transitions.
  static const Duration base = Duration(milliseconds: 150);

  /// 240ms — panel reveals, chart entry.
  static const Duration slow = Duration(milliseconds: 240);

  /// Standard easing for entrances and movement.
  static const Curve curve = Curves.easeOutCubic;

  /// Easing for elements leaving the screen.
  static const Curve exitCurve = Curves.easeInCubic;

  /// Whether animations should play, honouring the platform's
  /// "Reduce motion" accessibility setting.
  static bool enabled(BuildContext context) =>
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// [value], collapsed to zero when the user has asked for reduced motion.
  static Duration duration(BuildContext context, Duration value) =>
      enabled(context) ? value : Duration.zero;
}

/// Icon sizing scale, so icon/text pairings stay optically balanced.
abstract class IconSizes {
  /// 12 — inside dense badges.
  static const double xs = 12;

  /// 14 — chip and inline metadata icons.
  static const double sm = 14;

  /// 16 — button and menu icons.
  static const double md = 16;

  /// 18 — nav items, toolbar actions.
  static const double lg = 18;

  /// 22 — card headers.
  static const double xl = 22;

  /// 28 — empty-state and error-state glyphs.
  static const double xxl = 28;
}

/// Standard control heights, so toolbars line up across screens.
abstract class ControlSizes {
  /// 32 — toolbar controls (search, dropdowns, filter chips).
  static const double toolbar = 32;

  /// 36 — default buttons and inputs.
  static const double standard = 36;

  /// 56 — the active timer bar.
  static const double timerBar = 56;

  /// 220 — expanded sidebar width.
  static const double sidebarExpanded = 220;

  /// 56 — collapsed sidebar icon rail width.
  static const double sidebarCollapsed = 56;
}

/// Layout breakpoints for the main window.
///
/// The app enforces no minimum window size, so every screen has to stay
/// usable well below its default 1200x800 — see responsive_layout_test.dart.
abstract class Breakpoints {
  /// Below this, drop to single-column layouts.
  static const double compact = 760;

  /// Below this, drop the Work Items inspector and 4-up metric grids.
  static const double medium = 1000;
}
