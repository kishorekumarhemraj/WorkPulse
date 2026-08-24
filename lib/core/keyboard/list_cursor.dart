import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// A keyboard cursor over a list of results.
///
/// Quick Capture and the command palette each grew their own copy of the same
/// four things: an index, arrow keys that clamp it to the current result
/// count, Home/End, and a scroll nudge so the highlighted row stays on screen.
/// Adding a third copy to [SearchableMultiSelect] is what made it worth
/// writing once.
///
/// The cursor deliberately holds an index rather than an item. A search list
/// is rebuilt on every keystroke, so the item under the cursor is only
/// meaningful for the frame it was read in; the index is what survives, and
/// [clampedIn] is how a caller reads it safely against the list it actually
/// has.
class ListCursor extends ChangeNotifier {
  /// The height of one row, used to keep the cursor on screen. Zero disables
  /// the scroll nudge, for lists short enough never to overflow.
  final double rowExtent;

  final ScrollController? scrollController;

  ListCursor({this.rowExtent = 0, this.scrollController});

  int _index = 0;

  /// The raw cursor position. Callers rendering a list want [clampedIn].
  int get index => _index;

  /// [index] clamped into a list of [length] items, or 0 when it is empty.
  ///
  /// Results shrink as the user types; without this a cursor parked on the
  /// ninth match reads off the end of a list that just became two long.
  int clampedIn(int length) =>
      length == 0 ? 0 : _index.clamp(0, length - 1);

  /// Moves the cursor [delta] rows. Returns whether it actually moved.
  bool moveBy(int delta, int length) =>
      moveTo(clampedIn(length) + delta, length);

  /// Moves the cursor to [target], clamped. Returns whether it actually moved.
  bool moveTo(int target, int length) {
    if (length == 0) return false;
    final next = target.clamp(0, length - 1);
    if (next == _index) return false;
    _index = next;
    notifyListeners();
    _reveal();
    return true;
  }

  /// Returns the cursor to the top — what a caller wants after the query
  /// changes and the results underneath are a different list.
  void reset() {
    if (_index == 0) return;
    _index = 0;
    notifyListeners();
    _reveal();
  }

  /// Maps Down/Up/Home/End onto the cursor, and reports whether it consumed
  /// the key. Enter and Escape are deliberately left to the caller: what they
  /// mean differs per list, and only the caller knows what "confirm" is.
  bool handleKey(KeyEvent event, int length) {
    if (event is! KeyDownEvent) return false;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        moveBy(1, length);
        return true;
      case LogicalKeyboardKey.arrowUp:
        moveBy(-1, length);
        return true;
      case LogicalKeyboardKey.home:
        moveTo(0, length);
        return true;
      case LogicalKeyboardKey.end:
        moveTo(length - 1, length);
        return true;
    }
    return false;
  }

  /// Scrolls the cursor's row back into the viewport when it has left it.
  ///
  /// [jumpTo] rather than an animation: this fires once per arrow keypress,
  /// and a held-down arrow key would otherwise queue animations faster than
  /// they complete.
  void _reveal() {
    final controller = scrollController;
    if (controller == null || rowExtent <= 0) return;
    if (!controller.hasClients) return;

    final target = _index * rowExtent;
    final viewport = controller.position.viewportDimension;
    final offset = controller.offset;

    if (target < offset) {
      controller.jumpTo(target);
    } else if (target + rowExtent > offset + viewport) {
      controller.jumpTo(
        (target + rowExtent - viewport)
            .clamp(0.0, controller.position.maxScrollExtent),
      );
    }
  }
}
