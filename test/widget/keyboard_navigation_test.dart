import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/keyboard/search_focus.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/core/widgets/search_field.dart';

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
}
