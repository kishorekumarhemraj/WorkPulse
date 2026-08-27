import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/keyboard/search_focus.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/core/widgets/filter_dropdown.dart';
import 'package:workpulse/core/widgets/search_field.dart';
import 'package:workpulse/core/widgets/searchable_multi_select.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      home: Scaffold(body: child),
    );
  }

  group('Focus visibility', () {
    // The palette has always defined a focusRing token; before this only text
    // inputs drew it, so tabbing through lists moved an invisible cursor.
    testWidgets('a tappable AppCard draws the focus ring when focused',
        (tester) async {
      late WorkPulseColors colors;

      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              colors = context.colors;
              return AppCard(
                onTap: () {},
                child: const Text('Row'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      Border? borderOf() {
        final container = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byType(AppCard),
            matching: find.byType(AnimatedContainer),
          ),
        );
        return (container.decoration as BoxDecoration?)?.border as Border?;
      }

      expect(borderOf()?.top.color, isNot(colors.focusRing));

      // Tab in from nothing focused.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(borderOf()?.top.color, colors.focusRing);
      expect(borderOf()?.top.width, 2);
    });

    testWidgets('a non-tappable AppCard is not a focus stop', (tester) async {
      await tester.pumpWidget(host(const AppCard(child: Text('Panel'))));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final border =
          (container.decoration as BoxDecoration?)?.border as Border?;
      expect(border?.top.width, 1);
    });

    testWidgets('both themes define a visible default focus colour',
        (tester) async {
      for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
        expect(theme.focusColor.a, greaterThan(0.2));
      }
    });
  });

  group('SearchFocusRegistry', () {
    test('unregister only clears the node that is still registered', () {
      final registry = SearchFocusRegistry();
      final first = FocusNode();
      final second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      registry.register(first);
      registry.register(second);
      // The outgoing screen disposes after the incoming one registers.
      registry.unregister(first);

      expect(registry.registered, second);
    });

    test('requestFocus reports when there is nothing to focus', () {
      expect(SearchFocusRegistry().requestFocus(), isFalse);
    });

    testWidgets('a mounted SearchField registers itself for the shortcut',
        (tester) async {
      final registry = SearchFocusRegistry();

      await tester.pumpWidget(
        host(
          SearchFocusScope(
            registry: registry,
            child: SearchField(onChanged: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(registry.registered, isNotNull);
      expect(registry.registered!.hasFocus, isFalse);

      expect(registry.requestFocus(), isTrue);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
        isTrue,
      );
    });

    testWidgets('a disposed SearchField stops offering its node',
        (tester) async {
      final registry = SearchFocusRegistry();

      Widget build({required bool showField}) => host(
            SearchFocusScope(
              registry: registry,
              child:
                  showField ? SearchField(onChanged: (_) {}) : const SizedBox(),
            ),
          );

      await tester.pumpWidget(build(showField: true));
      await tester.pumpAndSettle();
      expect(registry.registered, isNotNull);

      await tester.pumpWidget(build(showField: false));
      await tester.pumpAndSettle();

      expect(registry.registered, isNull);
      expect(registry.requestFocus(), isFalse);
    });
  });

  group('SearchField keyboard behaviour', () {
    // A field with no scope above it must still work; SearchField is a
    // design-system primitive that widget tests host on its own.
    testWidgets('works with no SearchFocusScope above it', (tester) async {
      await tester.pumpWidget(host(SearchField(onChanged: (_) {})));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Escape clears the query', (tester) async {
      final changes = <String>[];

      await tester.pumpWidget(
        host(SearchField(onChanged: changes.add)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'invoice');
      await tester.pumpAndSettle();
      expect(changes.last, 'invoice');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(changes.last, '');
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
          isEmpty);
    });
  });

  group('SearchableMultiSelect keyboard', () {
    const items = [
      SearchableMultiSelectItem(id: 'a', label: 'Alpha'),
      SearchableMultiSelectItem(id: 'b', label: 'Beta'),
      SearchableMultiSelectItem(id: 'c', label: 'Gamma'),
    ];

    /// Hosts the control the way every real caller does: inside a form that
    /// pops itself on Escape.
    Widget hostInDialog({
      required List<String> selectedIds,
      required ValueChanged<List<String>> onChanged,
      required VoidCallback onDialogPopped,
    }) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                onDialogPopped();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: SearchableMultiSelect(
              allItems: items,
              selectedIds: selectedIds,
              onChanged: onChanged,
              hintText: 'Search tags...',
              emptyStateText: 'No tags yet',
            ),
          ),
        ),
      );
    }

    Future<void> openList(WidgetTester tester) async {
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
    }

    testWidgets('Enter takes the row the arrows landed on', (tester) async {
      List<String>? picked;
      await tester.pumpWidget(hostInDialog(
        selectedIds: const [],
        onChanged: (ids) => picked = ids,
        onDialogPopped: () {},
      ));
      await openList(tester);

      // The cursor starts on the first match, so one Down reaches Beta.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(picked, ['b']);
    });

    testWidgets('End jumps to the last row', (tester) async {
      List<String>? picked;
      await tester.pumpWidget(hostInDialog(
        selectedIds: const [],
        onChanged: (ids) => picked = ids,
        onDialogPopped: () {},
      ));
      await openList(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(picked, ['c']);
    });

    testWidgets('Escape closes the list without closing the form',
        (tester) async {
      // The bug this encodes: every form hosting this control pops on
      // Escape, so dismissing an open dropdown used to discard the whole
      // half-filled form.
      var dialogPopped = false;
      await tester.pumpWidget(hostInDialog(
        selectedIds: const [],
        onChanged: (_) {},
        onDialogPopped: () => dialogPopped = true,
      ));
      await openList(tester);
      expect(find.text('Gamma'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Gamma'), findsNothing, reason: 'the list should close');
      expect(dialogPopped, isFalse, reason: 'the form should survive');
    });

    testWidgets('Escape reaches the form once the list is already closed',
        (tester) async {
      var dialogPopped = false;
      await tester.pumpWidget(hostInDialog(
        selectedIds: const [],
        onChanged: (_) {},
        onDialogPopped: () => dialogPopped = true,
      ));
      await openList(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(dialogPopped, isTrue);
    });

    testWidgets('Backspace on an empty query removes the last chip',
        (tester) async {
      List<String>? updated;
      await tester.pumpWidget(hostInDialog(
        selectedIds: const ['a', 'b'],
        onChanged: (ids) => updated = ids,
        onDialogPopped: () {},
      ));
      await openList(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(updated, ['a']);
    });

    testWidgets('Backspace stays a text edit while there is text to edit',
        (tester) async {
      List<String>? updated;
      await tester.pumpWidget(hostInDialog(
        selectedIds: const ['a', 'b'],
        onChanged: (ids) => updated = ids,
        onDialogPopped: () {},
      ));
      await openList(tester);
      await tester.enterText(find.byType(TextField), 'Gam');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(updated, isNull, reason: 'no chip should have been removed');
    });

    testWidgets('a chip remove button is reachable and labelled',
        (tester) async {
      List<String>? updated;
      await tester.pumpWidget(hostInDialog(
        selectedIds: const ['a'],
        onChanged: (ids) => updated = ids,
        onDialogPopped: () {},
      ));
      await tester.pumpAndSettle();

      final remove = find.byTooltip('Remove Alpha');
      expect(remove, findsOneWidget);
      await tester.tap(remove);
      await tester.pumpAndSettle();

      expect(updated, isEmpty);
    });
  });

  group('AppFilterDropdown focus', () {
    testWidgets('draws the focus ring when tabbed onto', (tester) async {
      // The trigger used to be a bare InkWell: tabbing onto it moved the
      // keyboard cursor somewhere with nothing to show for it.
      late WorkPulseColors colors;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                colors = context.colors;
                return AppFilterDropdown<String>(
                  placeholder: 'All Projects',
                  value: null,
                  options: const [
                    FilterOption(value: 'p1', label: 'Apollo'),
                  ],
                  onChanged: (_) {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Border? triggerBorder() {
        final container = tester
            .widgetList<Container>(
          find.descendant(
            of: find.byType(AppFilterDropdown<String>),
            matching: find.byType(Container),
          ),
        )
            .firstWhere((c) {
          final d = c.decoration;
          return d is BoxDecoration && d.border != null;
        });
        return (container.decoration as BoxDecoration).border as Border?;
      }

      expect(triggerBorder()?.top.color, isNot(colors.focusRing));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(triggerBorder()?.top.color, colors.focusRing);
      expect(triggerBorder()?.top.width, 1.5);
    });

    testWidgets(
        'can open with arrow down, navigate options and select with enter',
        (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AppFilterDropdown<String>(
              placeholder: 'All Projects',
              value: null,
              options: const [
                FilterOption(value: 'p1', label: 'Apollo'),
                FilterOption(value: 'p2', label: 'Beacon'),
              ],
              onChanged: (val) => selected = val,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tab to focus trigger
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Arrow down to open menu (starts on 'All Projects' since value is null)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(find.text('Apollo'), findsOneWidget);
      expect(find.text('Beacon'), findsOneWidget);

      // Arrow down to 'Apollo'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Arrow down to 'Beacon'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Select with Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selected, 'p2');
    });
  });
}
