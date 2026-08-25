import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/keyboard/list_cursor.dart';
import 'package:workpulse/core/keyboard/menu_keyboard.dart';

KeyEvent _down(LogicalKeyboardKey key, {String? character}) => KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: key,
      character: character,
      timeStamp: Duration.zero,
    );

KeyEvent _up(LogicalKeyboardKey key) => KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: key,
      timeStamp: Duration.zero,
    );

void main() {
  group('ListCursor', () {
    test('an empty list has no position to be at', () {
      final cursor = ListCursor();
      addTearDown(cursor.dispose);

      expect(cursor.clampedIn(0), 0);
      expect(cursor.moveBy(1, 0), isFalse);
      expect(cursor.moveTo(3, 0), isFalse);
    });

    test('reads back clamped when the list shrinks underneath it', () {
      // The case that matters: the user arrows down to the ninth match, then
      // types another letter and two matches remain.
      final cursor = ListCursor();
      addTearDown(cursor.dispose);

      cursor.moveTo(8, 10);
      expect(cursor.index, 8);
      expect(cursor.clampedIn(2), 1);
    });

    test('clamps at both ends and reports whether it moved', () {
      final cursor = ListCursor();
      addTearDown(cursor.dispose);

      expect(cursor.moveBy(-1, 3), isFalse, reason: 'already at the top');
      expect(cursor.moveBy(1, 3), isTrue);
      expect(cursor.moveBy(5, 3), isTrue);
      expect(cursor.index, 2);
      expect(cursor.moveBy(1, 3), isFalse, reason: 'already at the bottom');
    });

    test('notifies only when the position actually changes', () {
      final cursor = ListCursor();
      addTearDown(cursor.dispose);
      var notifications = 0;
      cursor.addListener(() => notifications++);

      cursor.moveTo(1, 3);
      cursor.moveTo(1, 3);
      expect(notifications, 1);

      cursor.reset();
      cursor.reset();
      expect(notifications, 2);
    });

    test('maps the navigation keys and leaves the rest alone', () {
      final cursor = ListCursor();
      addTearDown(cursor.dispose);

      expect(cursor.handleKey(_down(LogicalKeyboardKey.arrowDown), 4), isTrue);
      expect(cursor.index, 1);
      expect(cursor.handleKey(_down(LogicalKeyboardKey.end), 4), isTrue);
      expect(cursor.index, 3);
      expect(cursor.handleKey(_down(LogicalKeyboardKey.arrowUp), 4), isTrue);
      expect(cursor.index, 2);
      expect(cursor.handleKey(_down(LogicalKeyboardKey.home), 4), isTrue);
      expect(cursor.index, 0);

      // Enter and Escape belong to the caller: what they mean differs per
      // list.
      expect(cursor.handleKey(_down(LogicalKeyboardKey.enter), 4), isFalse);
      expect(cursor.handleKey(_down(LogicalKeyboardKey.escape), 4), isFalse);
      expect(cursor.handleKey(_up(LogicalKeyboardKey.arrowDown), 4), isFalse);
    });
  });

  group('TypeAhead', () {
    const labels = ['Apollo', 'Deploy', 'Design', 'Deployment notes'];

    test('a second letter narrows the match', () {
      final typeAhead = TypeAhead();
      final start = DateTime(2026);

      typeAhead.match(_down(LogicalKeyboardKey.keyD, character: 'd'), labels,
          now: start);
      final hit = typeAhead.match(
        _down(LogicalKeyboardKey.keyE, character: 'e'),
        labels,
        now: start.add(const Duration(milliseconds: 200)),
      );
      expect(hit, 1, reason: '"de" reaches Deploy');
    });

    test('accumulating is what reaches past a same-letter neighbour', () {
      final typeAhead = TypeAhead();
      final start = DateTime(2026);

      // "d" alone stops at Deploy; "des" is the only way to Design.
      expect(
        typeAhead.match(_down(LogicalKeyboardKey.keyD, character: 'd'), labels,
            now: start),
        1,
      );
      typeAhead.match(
        _down(LogicalKeyboardKey.keyE, character: 'e'),
        labels,
        now: start.add(const Duration(milliseconds: 100)),
      );
      expect(
        typeAhead.match(
          _down(LogicalKeyboardKey.keyS, character: 's'),
          labels,
          now: start.add(const Duration(milliseconds: 200)),
        ),
        2,
        reason: '"des" reaches Design',
      );
    });

    test('a pause starts a fresh search', () {
      final typeAhead = TypeAhead();
      final start = DateTime(2026);

      typeAhead.match(_down(LogicalKeyboardKey.keyD, character: 'd'), labels,
          now: start);
      final hit = typeAhead.match(
        _down(LogicalKeyboardKey.keyA, character: 'a'),
        labels,
        now: start.add(const Duration(seconds: 5)),
      );
      expect(hit, 0, reason: '"a" alone, not "da"');
    });

    test('a dead prefix falls back to the latest keystroke', () {
      // Without this the user is stuck: every further letter extends a buffer
      // that already matches nothing.
      final typeAhead = TypeAhead();
      final start = DateTime(2026);

      typeAhead.match(_down(LogicalKeyboardKey.keyZ, character: 'z'), labels,
          now: start);
      final hit = typeAhead.match(
        _down(LogicalKeyboardKey.keyA, character: 'a'),
        labels,
        now: start.add(const Duration(milliseconds: 100)),
      );
      expect(hit, 0);
    });

    test('ignores keys that are not search input', () {
      final typeAhead = TypeAhead();

      expect(
          typeAhead.match(_down(LogicalKeyboardKey.arrowDown), labels), isNull);
      expect(
        typeAhead.match(
            _down(LogicalKeyboardKey.space, character: ' '), labels),
        isNull,
        reason: 'space activates the row',
      );
      expect(
        typeAhead.match(
            _down(LogicalKeyboardKey.enter, character: '\n'), labels),
        isNull,
      );
      expect(typeAhead.match(_up(LogicalKeyboardKey.keyA), labels), isNull);
    });

    test('no match reports null rather than a wrong row', () {
      final typeAhead = TypeAhead();
      expect(
        typeAhead.match(_down(LogicalKeyboardKey.keyQ, character: 'q'), labels),
        isNull,
      );
    });
  });
}
