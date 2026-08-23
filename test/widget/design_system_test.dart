import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/app_typography.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/filter_dropdown.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/search_field.dart';
import 'package:workpulse/core/widgets/segmented_control.dart';
import 'package:workpulse/core/widgets/status_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      home: Scaffold(body: child),
    );
  }

  group('Theme foundation', () {
    testWidgets('exposes WorkPulseColors on both themes', (tester) async {
      for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
        late WorkPulseColors resolved;
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) {
                resolved = context.colors;
                return const SizedBox();
              },
            ),
            theme: theme,
          ),
        );
        // MaterialApp lerps between themes, so let the transition finish
        // before reading the resolved palette.
        await tester.pumpAndSettle();
        expect(theme.extension<WorkPulseColors>(), isNotNull);
        expect(resolved.accent, theme.colorScheme.primary);
      }
    });

    test('numeric styles use tabular figures so tickers do not jitter', () {
      final style = AppTypography.numeric();
      expect(style.fontFamily, AppTypography.monoFontFamily);
      expect(
        style.fontFeatures?.map((f) => f.feature),
        containsAll(<String>['tnum', 'zero']),
      );
      expect(
          AppTypography.ticker(color: Colors.white).fontFeatures, isNotEmpty);
    });

    test('body text never drops below 12pt', () {
      final textTheme = AppTypography.textTheme(
        primary: Colors.white,
        secondary: Colors.grey,
      );
      for (final style in [
        textTheme.bodyLarge,
        textTheme.bodyMedium,
        textTheme.bodySmall,
        textTheme.labelLarge,
        textTheme.labelMedium,
      ]) {
        expect(style!.fontSize, greaterThanOrEqualTo(12));
      }
    });
  });

  group('PageHeader', () {
    testWidgets('renders title, subtitle, actions and toolbar', (tester) async {
      await tester.pumpWidget(
        host(
          const PageHeader(
            title: 'Work Items',
            subtitle: 'Tracked tasks and activities',
            actions: [Text('New Task')],
            toolbar: Text('Toolbar slot'),
          ),
        ),
      );

      expect(find.text('Work Items'), findsOneWidget);
      expect(find.text('Tracked tasks and activities'), findsOneWidget);
      expect(find.text('New Task'), findsOneWidget);
      expect(find.text('Toolbar slot'), findsOneWidget);
    });
  });

  group('AppSegmentedControl', () {
    testWidgets('reports the tapped value and marks selection', (tester) async {
      String? picked;
      await tester.pumpWidget(
        host(
          AppSegmentedControl<String>(
            selected: 'today',
            onChanged: (value) => picked = value,
            options: const [
              SegmentOption(value: 'today', label: 'Today'),
              SegmentOption(value: 'week', label: 'This Week'),
            ],
          ),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      await tester.tap(find.text('This Week'));
      await tester.pumpAndSettle();
      expect(picked, 'week');
    });
  });

  group('AppFilterDropdown', () {
    testWidgets('falls back to the placeholder when the value is stale',
        (tester) async {
      // A filter can outlive the entity it points at (e.g. the project was
      // deleted). The control must not throw on a value with no matching item.
      await tester.pumpWidget(
        host(
          Center(
            child: AppFilterDropdown<String>(
              placeholder: 'All Projects',
              value: 'deleted-project-id',
              options: const [
                FilterOption(value: 'p1', label: 'Alpha', color: Colors.blue),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('All Projects'), findsWidgets);
    });

    testWidgets('emits the selected value', (tester) async {
      String? picked;
      await tester.pumpWidget(
        host(
          Center(
            child: AppFilterDropdown<String>(
              placeholder: 'All Projects',
              value: null,
              options: const [
                FilterOption(value: 'p1', label: 'Alpha'),
                FilterOption(value: 'p2', label: 'Beta'),
              ],
              onChanged: (value) => picked = value,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta').last);
      await tester.pumpAndSettle();
      expect(picked, 'p2');
    });
  });

  group('SearchField', () {
    testWidgets('shows a clear button once text is entered', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(
        host(Center(child: SearchField(onChanged: changes.add))),
      );

      expect(find.byTooltip('Clear search'), findsNothing);

      await tester.enterText(find.byType(TextField), 'timer');
      await tester.pumpAndSettle();
      expect(changes.last, 'timer');
      expect(find.byTooltip('Clear search'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(changes.last, '');
    });
  });

  group('StatusBadge', () {
    testWidgets('always pairs colour with a label', (tester) async {
      await tester.pumpWidget(
        host(
          const Row(
            children: [
              StatusBadge(
                label: 'Tracking',
                icon: Icons.timer,
                tone: BadgeTone.success,
                emphasis: true,
              ),
              StatusBadge(label: 'Archived', tone: BadgeTone.warning),
            ],
          ),
        ),
      );

      // emphasis uppercases the label for hard status states.
      expect(find.text('TRACKING'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
    });
  });

  group('EmptyState and ErrorState', () {
    testWidgets('empty state surfaces its call to action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(
          EmptyState(
            icon: Icons.assignment_outlined,
            title: 'No tasks created yet',
            message: 'Create your first task to start tracking time.',
            action: OutlinedButton(
              onPressed: () => tapped = true,
              child: const Text('Create First Task'),
            ),
          ),
        ),
      );

      expect(find.text('No tasks created yet'), findsOneWidget);
      await tester.tap(find.text('Create First Task'));
      expect(tapped, isTrue);
    });

    testWidgets('error state offers a retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        host(
          ErrorState(
            title: 'Could not load tasks',
            error: 'database locked',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('Could not load tasks'), findsOneWidget);
      expect(find.text('database locked'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });
  });

  group('AppDialog', () {
    testWidgets('submits on Cmd+Enter and closes on the header button',
        (tester) async {
      var submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AppDialog(
                    title: 'Edit Task',
                    icon: Icons.edit_outlined,
                    onSubmit: () => submitted = true,
                    actions: const [Text('Save')],
                    child: const DialogField(
                      label: 'Name',
                      required: true,
                      child: TextField(),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Task'), findsOneWidget);
      // The submit affordance is advertised in the footer.
      expect(find.text('⌘'), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();
      expect(submitted, isTrue);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Task'), findsNothing);
    });
  });
}
