import 'package:flutter/foundation.dart';

/// How a keyboard shortcut is written for the user.
///
/// Every hint in the app used to be spelled with macOS glyphs — `⌘N`,
/// `⌥ Space`, `⌘E` — including on Windows, where those symbols mean nothing
/// and the binding that actually fires is the Ctrl one. Both bindings have
/// always been registered; only the labels were wrong.
///
/// Resolved from [defaultTargetPlatform] rather than `Platform.isMacOS` so the
/// labels follow the platform Flutter is rendering as, which is also what
/// widget tests can override.
abstract final class ShortcutLabels {
  /// True where Command, not Control, is the primary accelerator.
  static bool get usesCommandKey =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// The primary accelerator: `⌘` on macOS, `Ctrl` elsewhere.
  static String get primaryModifier => usesCommandKey ? '⌘' : 'Ctrl';

  /// The alternate modifier: `⌥` on macOS, `Alt` elsewhere.
  static String get altModifier => usesCommandKey ? '⌥' : 'Alt';

  static String get shiftModifier => usesCommandKey ? '⇧' : 'Shift';

  static String get controlModifier => usesCommandKey ? '⌃' : 'Ctrl';

  /// The Return/Enter key.
  static String get enterKey => usesCommandKey ? '↩' : 'Enter';

  /// Joins modifiers and a key the way the platform writes them: macOS runs
  /// them together (`⌘N`), Windows separates them (`Ctrl+N`).
  static String combine(List<String> parts) =>
      usesCommandKey ? parts.join('') : parts.join('+');

  /// A shortcut on the primary modifier, e.g. `⌘N` or `Ctrl+N`.
  static String primary(String key) => combine([primaryModifier, key]);

  /// A shortcut on the alternate modifier, e.g. `⌥Space` or `Alt+Space`.
  static String alt(String key) => combine([altModifier, key]);

  /// The keycap sequence for a primary-modifier shortcut, for [KeycapGroup].
  static List<String> primaryKeys(String key) => [primaryModifier, key];

  /// "Submit this form": `⌘↩` / `Ctrl+Enter`.
  static List<String> get submitKeys => [primaryModifier, enterKey];

  /// The platform's name for the file manager, used in "reveal" affordances.
  static String get fileManagerName => switch (defaultTargetPlatform) {
        TargetPlatform.macOS => 'Finder',
        TargetPlatform.windows => 'File Explorer',
        _ => 'file manager',
      };

  /// The label on the button that reveals an exported file.
  static String get revealActionLabel => 'Show in $fileManagerName';

  /// The host operating system's display name, for the version footer.
  static String get platformName => switch (defaultTargetPlatform) {
        TargetPlatform.macOS => 'macOS',
        TargetPlatform.windows => 'Windows',
        TargetPlatform.linux => 'Linux',
        _ => defaultTargetPlatform.name,
      };
}
