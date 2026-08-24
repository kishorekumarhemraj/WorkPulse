import 'package:flutter/widgets.dart';

/// Tracks the search field belonging to the screen currently on show, so a
/// single application-level shortcut can focus it.
///
/// The alternative — resolving a `FocusSearchIntent` through `Actions` — only
/// works when focus already sits inside the screen that owns the field. After
/// a nav change focus is on the shell itself, which is exactly when a user
/// reaches for the shortcut. A registry sidesteps that: one screen is mounted
/// at a time, so "the search field" is unambiguous.
class SearchFocusRegistry {
  FocusNode? _node;

  /// The node currently offered for focusing, or null when the visible screen
  /// has no search field.
  @visibleForTesting
  FocusNode? get registered => _node;

  void register(FocusNode node) => _node = node;

  /// Clears [node] if it is still the registered one. Guarded so a screen
  /// being disposed after its replacement has registered cannot unregister
  /// the new screen's field.
  void unregister(FocusNode node) {
    if (identical(_node, node)) _node = null;
  }

  /// Focuses the registered field. Returns false when there is nothing to
  /// focus, which callers use to leave the key event unhandled.
  bool requestFocus() {
    final node = _node;
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }
}

/// Hands a [SearchFocusRegistry] down to the screens beneath it.
///
/// Deliberately an [InheritedWidget] rather than a provider: [SearchField] is a
/// design-system primitive used in widget tests that host it on its own, and it
/// should not drag a `ProviderScope` requirement along with it. A screen with
/// no scope above it simply has no shortcut target.
class SearchFocusScope extends InheritedWidget {
  final SearchFocusRegistry registry;

  const SearchFocusScope({
    super.key,
    required this.registry,
    required super.child,
  });

  /// The enclosing registry, or null when there is no scope — read without
  /// registering a dependency, since the registry instance never changes for
  /// the life of a scope.
  static SearchFocusRegistry? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<SearchFocusScope>()?.registry;
  }

  @override
  bool updateShouldNotify(SearchFocusScope oldWidget) =>
      !identical(registry, oldWidget.registry);
}
