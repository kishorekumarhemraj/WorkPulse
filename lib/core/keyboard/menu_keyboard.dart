import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// Resolves "the user typed some letters" into a row to jump to.
///
/// Letters typed close together accumulate, so in a list of projects "de"
/// reaches Design past Deploy, while a pause starts a fresh search — the
/// behaviour every native list has and neither of this app's menus had.
class TypeAhead {
  /// How long a partial match stays live. Long enough to type a second
  /// letter deliberately, short enough that a later unrelated keystroke is
  /// not read as a continuation.
  final Duration resetAfter;

  TypeAhead({this.resetAfter = const Duration(milliseconds: 900)});

  String _buffer = '';
  DateTime? _typedAt;

  /// The row [event] selects among [labels], or null when the key is not a
  /// character or nothing matches.
  int? match(KeyEvent event, List<String> labels, {DateTime? now}) {
    if (event is! KeyDownEvent) return null;
    final character = event.character;
    if (character == null || character.isEmpty) return null;
    // Space belongs to the menu (activate), and control characters are not
    // search input.
    if (character.trim().isEmpty) return null;
    if (character.codeUnitAt(0) < 0x20) return null;

    final at = now ?? DateTime.now();
    final last = _typedAt;
    if (last == null || at.difference(last) > resetAfter) _buffer = '';
    _typedAt = at;
    _buffer += character.toLowerCase();

    final hit = _firstStartingWith(labels, _buffer);
    if (hit != null) return hit;

    // No match for the accumulated buffer: treat this keystroke as the start
    // of a new search rather than leaving the user stuck on a dead prefix.
    _buffer = character.toLowerCase();
    return _firstStartingWith(labels, _buffer);
  }

  int? _firstStartingWith(List<String> labels, String prefix) {
    for (var i = 0; i < labels.length; i++) {
      if (labels[i].toLowerCase().startsWith(prefix)) return i;
    }
    return null;
  }

  void clear() {
    _buffer = '';
    _typedAt = null;
  }
}

/// Keyboard behaviour for the rows of a [MenuAnchor] menu.
///
/// Two things Material's menu does not do on its own: open on the row that is
/// already selected rather than always on the first, and jump by typing. Both
/// need a focus node per row, which is what this owns.
class MenuKeyboard {
  final List<FocusNode> _nodes = [];
  final TypeAhead _typeAhead = TypeAhead();
  List<String> _labels = const [];

  /// Call from build with the labels currently on offer, in row order.
  void setLabels(List<String> labels) => _labels = labels;

  /// The node for row [index], created on first use and reused after.
  FocusNode nodeAt(int index) {
    while (_nodes.length <= index) {
      _nodes.add(
        FocusNode(
          debugLabel: 'MenuKeyboard row ${_nodes.length}',
          onKeyEvent: _handleKey,
        ),
      );
    }
    return _nodes[index];
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.home) {
      return _focus(0) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      return _focus(_labels.length - 1)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    final hit = _typeAhead.match(event, _labels);
    if (hit == null) return KeyEventResult.ignored;
    return _focus(hit) ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  bool _focus(int index) {
    if (index < 0 || index >= _labels.length || index >= _nodes.length) {
      return false;
    }
    final node = _nodes[index];
    if (!node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  /// Focuses row [index] once the menu has had a frame to mount its rows.
  ///
  /// The menu builds its overlay after [MenuController.open] returns, so the
  /// nodes are not attached yet at the moment the caller knows it opened.
  void focusAfterOpen(int index) {
    _typeAhead.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus(index));
  }

  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    _nodes.clear();
  }
}
