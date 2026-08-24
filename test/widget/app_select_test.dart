import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/widgets/app_select.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const options = [
    SelectOption(value: 'a', label: 'Core Platform', color: Colors.blue),
    SelectOption(value: 'b', label: 'Design System', color: Colors.green),
    SelectOption(value: 'c', label: 'Infrastructure', color: Colors.orange),
  ];

  /// Hosts the select inside a deliberately wide container — the old
  /// DropdownButtonFormField stretched to fill exactly this space.
  Widget host(Widget child) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 600, child: child),
        ),
      ),
    );
  }

  /// The chevron lives only in the trigger — menu rows use a check — so it is
  /// an unambiguous anchor for measuring the pill itself.
  Size triggerSize(WidgetTester tester) {
    return tester.getSize(
      find
          .ancestor(
            of: find.byIcon(Icons.expand_more),
            matching: find.byType(Container),
          )
          .first,
    );
  }

  group('AppSelect trigger', () {
    testWidgets('sizes to its content instead of filling the row',
        (tester) async {
      await tester.pumpWidget(
        host(AppSelect<String>(
          value: 'a',
          options: options,
          placeholder: 'Select project',
          onChanged: (_) {},
        )),
      );

      final size = triggerSize(tester);
      expect(size.width, lessThan(300));
      expect(size.height, 36);
    });

    testWidgets('caps its width so one long name cannot stretch the row',
        (tester) async {
      await tester.pumpWidget(
        host(AppSelect<String>(
          value: 'a',
          placeholder: 'Select project',
          options: const [
            SelectOption(
              value: 'a',
              label: 'A preposterously long project name that would otherwise '
                  'push everything beside it off the dialog',
            ),
          ],
          onChanged: (_) {},
        )),
      );

      expect(triggerSize(tester).width, lessThanOrEqualTo(260));
    });

    testWidgets('shows the placeholder when nothing is selected',
        (tester) async {
      await tester.pumpWidget(
        host(AppSelect<String>(
          value: null,
          options: options,
          placeholder: 'Select project',
          onChanged: (_) {},
        )),
      );

      expect(find.text('Select project'), findsOneWidget);
    });

    testWidgets('renders an optional caption and required marker',
        (tester) async {
      await tester.pumpWidget(
        host(AppSelect<String>(
          value: null,
          options: options,
          label: 'Project',
          isRequired: true,
          placeholder: 'Select project',
          onChanged: (_) {},
        )),
      );

      expect(find.text('Project *'), findsOneWidget);
    });
  });

  group('AppSelect menu', () {
    testWidgets('opens on tap and lists every option', (tester) async {
      await tester.pumpWidget(
        host(AppSelect<String>(
          value: 'a',
          options: options,
          placeholder: 'Select project',
          onChanged: (_) {},
        )),
      );

      await tester.tap(find.text('Core Platform'));
      await tester.pumpAndSettle();

      expect(find.text('Design System'), findsOneWidget);
      expect(find.text('Infrastructure'), findsOneWidget);
      // The selected label now appears in both the trigger and the menu.
      expect(find.text('Core Platform'), findsNWidgets(2));
    });

    testWidgets('keeps rows at 32px rather than the 48px Material default',
        (tester) async {
      await tester.pumpWidget(
        host(AppSelect<String>(
          value: 'a',
          options: options,
          placeholder: 'Select project',
          onChanged: (_) {},
        )),
      );

      await tester.tap(find.text('Core Platform'));
      await tester.pumpAndSettle();

      final row = tester.getSize(find.byType(MenuItemButton).at(1));
      expect(row.height, 32);
    });

    testWidgets('marks the current selection with a check', (tester) async {
      await tester.pumpWidget(
        host(AppSelect<String>(
          value: 'b',
          options: options,
          placeholder: 'Select project',
          onChanged: (_) {},
        )),
      );

      await tester.tap(find.text('Design System'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('reports the chosen value to the caller', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        host(AppSelect<String>(
          value: 'a',
          options: options,
          placeholder: 'Select project',
          onChanged: (v) => chosen = v,
        )),
      );

      await tester.tap(find.text('Core Platform'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Infrastructure'));
      await tester.pumpAndSettle();

      expect(chosen, 'c');
    });

    testWidgets('a disabled select cannot be opened', (tester) async {
      await tester.pumpWidget(
        host(AppSelect<String>(
          value: 'a',
          options: options,
          enabled: false,
          placeholder: 'Select project',
          onChanged: (_) {},
        )),
      );

      await tester.tap(find.text('Core Platform'));
      await tester.pumpAndSettle();

      expect(find.text('Design System'), findsNothing);
    });
  });

  group('AppSelect form integration', () {
    testWidgets('surfaces its validator through the enclosing Form',
        (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        host(Form(
          key: formKey,
          child: AppSelect<String>(
            value: null,
            options: options,
            placeholder: 'Select project',
            validator: (v) => v == null ? 'Please select a project' : null,
            onChanged: (_) {},
          ),
        )),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Please select a project'), findsOneWidget);
    });

    testWidgets('validates once the caller supplies a value', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        host(Form(
          key: formKey,
          child: AppSelect<String>(
            value: 'a',
            options: options,
            placeholder: 'Select project',
            validator: (v) => v == null ? 'Please select a project' : null,
            onChanged: (_) {},
          ),
        )),
      );

      expect(formKey.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Please select a project'), findsNothing);
    });
  });
}
