import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/keyboard/shortcut_labels.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/color_utils.dart';
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

    double relativeLuminance(Color c) {
      double channel(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4) as double;
      return 0.2126 * channel(c.r) +
          0.7152 * channel(c.g) +
          0.0722 * channel(c.b);
    }

    double contrast(Color a, Color b) {
      final la = relativeLuminance(a);
      final lb = relativeLuminance(b);
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    test('every text colour clears WCAG AA on every surface', () {
      // Contrast is easy to lose when a palette is hand-tuned, and the
      // failure is invisible to anyone not looking for it. This pins it.
      for (final entry in {
        'dark': WorkPulseColors.dark,
        'light': WorkPulseColors.light,
      }.entries) {
        final c = entry.value;
        final textTokens = {
          'textPrimary': c.textPrimary,
          'textSecondary': c.textSecondary,
          'textTertiary': c.textTertiary,
        };
        final allSurfaces = {
          'background': c.background,
          'surface': c.surface,
          'card': c.card,
          'field': c.field,
          'surfaceRaised': c.surfaceRaised,
          'surfaceSunken': c.surfaceSunken,
        };

        // Every text token clears WCAG AA against all surfaces in both themes.
        for (final text in textTokens.entries) {
          for (final bg in allSurfaces.entries) {
            expect(
              contrast(text.value, bg.value),
              greaterThanOrEqualTo(4.5),
              reason: '${entry.key}: ${text.key} on ${bg.key} is below WCAG AA',
            );
          }
        }

        // Semantic tokens clear WCAG AA on standard content surfaces.
        final semanticTokens = {
          'accent': c.accent,
          'success': c.success,
          'warning': c.warning,
          'danger': c.danger,
          'info': c.info,
        };
        final standardSurfaces = {
          'background': c.background,
          'surface': c.surface,
          'card': c.card,
          'field': c.field,
        };

        for (final sem in semanticTokens.entries) {
          for (final bg in standardSurfaces.entries) {
            expect(
              contrast(sem.value, bg.value),
              greaterThanOrEqualTo(4.5),
              reason: '${entry.key}: ${sem.key} on ${bg.key} is below WCAG AA',
            );
          }
        }

        // White label on a filled button. accentFill/dangerFill exist
        // precisely because accent/danger are tuned to be read as text
        // against dark surfaces and are too light to sit under white text.
        expect(
          contrast(c.onAccent, c.accentFill),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key}: onAccent on accentFill is below WCAG AA',
        );
        expect(
          contrast(Colors.white, c.dangerFill),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key}: white on dangerFill is below WCAG AA',
        );

        // A badge is a label on its own tinted fill, and the fill is
        // translucent -- so the real question is not whether the label
        // clears the surface, but whether it clears the fill *once
        // composited over* whichever surface the badge landed on.
        final tinted = {
          'accent': (c.accent, c.accentSubtle),
          'success': (c.success, c.successSubtle),
          'warning': (c.warning, c.warningSubtle),
          'danger': (c.danger, c.dangerSubtle),
          'info': (c.info, c.infoSubtle),
        };
        for (final tint in tinted.entries) {
          final (label, fill) = tint.value;
          for (final base in ['background', 'surface']) {
            final composited = Color.alphaBlend(fill, allSurfaces[base]!);
            expect(
              contrast(label, composited),
              greaterThanOrEqualTo(4.5),
              reason: '${entry.key}: ${tint.key} label on its own subtle '
                  'fill over $base is below WCAG AA',
            );
          }
        }
      }
    });

    test(
        'hue lock: all neutral tokens sit on the 240° hue line or have minimal chroma',
        () {
      for (final entry in {
        'dark': WorkPulseColors.dark,
        'light': WorkPulseColors.light,
      }.entries) {
        final c = entry.value;
        final neutrals = {
          'surfaceSunken': c.surfaceSunken,
          'background': c.background,
          'surface': c.surface,
          'card': c.card,
          'field': c.field,
          'surfaceRaised': c.surfaceRaised,
          'divider': c.divider,
          'borderStrong': c.borderStrong,
          'textTertiary': c.textTertiary,
          'textSecondary': c.textSecondary,
          'textPrimary': c.textPrimary,
        };

        for (final neutral in neutrals.entries) {
          final color = neutral.value;
          final r = color.r * 255.0;
          final g = color.g * 255.0;
          final b = color.b * 255.0;
          final maxVal = math.max(r, math.max(g, b));
          final minVal = math.min(r, math.min(g, b));
          final chroma = maxVal - minVal;

          if (chroma > 2.0) {
            double h;
            if (maxVal == r) {
              h = ((g - b) / chroma) % 6;
            } else if (maxVal == g) {
              h = ((b - r) / chroma) + 2;
            } else {
              h = ((r - g) / chroma) + 4;
            }
            h = h * 60;
            if (h < 0) h += 360;
            expect(
              h,
              inInclusiveRange(238.0, 242.0),
              reason:
                  '${entry.key}: ${neutral.key} hue ($h°) must be within 238°-242°',
            );
          }
        }
      }
    });

    test('surface luminance ordering is monotonic in both themes', () {
      const light = WorkPulseColors.light;
      final lightSunken = relativeLuminance(light.surfaceSunken);
      final lightCard = relativeLuminance(light.card);
      final lightBg = relativeLuminance(light.background);
      final lightSurface = relativeLuminance(light.surface);
      final lightRaised = relativeLuminance(light.surfaceRaised);

      expect(lightSunken, lessThan(lightCard));
      expect(lightCard, lessThan(lightBg));
      expect(lightBg, lessThan(lightSurface));
      expect(lightSurface, lessThanOrEqualTo(lightRaised));

      const dark = WorkPulseColors.dark;
      final darkSunken = relativeLuminance(dark.surfaceSunken);
      final darkBg = relativeLuminance(dark.background);
      final darkSurface = relativeLuminance(dark.surface);
      final darkCard = relativeLuminance(dark.card);
      final darkRaised = relativeLuminance(dark.surfaceRaised);

      expect(darkSunken, lessThan(darkBg));
      expect(darkBg, lessThan(darkSurface));
      expect(darkSurface, lessThan(darkCard));
      expect(darkCard, lessThanOrEqualTo(darkRaised));
    });

    test('the fill variants stay the vivid reading of their role', () {
      // success/warning/info are darkened for AA as text, which on light
      // turns them into forest green, brown and slate. The *Fill tokens
      // exist so shapes -- chart bars, dots, stripes -- keep the hue the
      // role actually means. If a fill ever equals its text token on light,
      // that split has silently collapsed.
      const light = WorkPulseColors.light;
      expect(light.successFill, isNot(light.success));
      expect(light.warningFill, isNot(light.warning));
      expect(light.infoFill, isNot(light.info));

      // Dark's text values are already vivid, so there the two are equal on
      // purpose -- pinned so a future edit to one remembers the other.
      const dark = WorkPulseColors.dark;
      expect(dark.successFill, dark.success);
      expect(dark.warningFill, dark.warning);
      expect(dark.infoFill, dark.info);
    });

    test('surfaces separate far enough to be told apart in both themes', () {
      for (final entry in {
        'dark': WorkPulseColors.dark,
        'light': WorkPulseColors.light,
      }.entries) {
        final c = entry.value;
        // A panel is separated from the page by luminance on dark, and by its
        // hairline on light -- the light theme is white-first, so background
        // and surface are deliberately close and the divider below carries
        // the separation instead. Lifting this floor back would push the page
        // grey again, which is the whole thing being fixed.
        expect(
          contrast(c.background, c.surface),
          greaterThanOrEqualTo(entry.key == 'light' ? 1.01 : 1.10),
          reason: '${entry.key}: a panel must be distinguishable from the page',
        );
        expect(
          contrast(c.surface, c.divider),
          greaterThanOrEqualTo(1.35),
          reason: '${entry.key}: a hairline must read on surface',
        );
        expect(
          contrast(c.surface, c.card),
          greaterThanOrEqualTo(1.06),
          reason: '${entry.key}: card must separate from surface',
        );
        expect(
          contrast(c.card, c.surfaceSunken),
          greaterThanOrEqualTo(1.04),
          reason: '${entry.key}: sunken well must separate from card',
        );
        if (entry.key == 'light') {
          expect(
            contrast(c.textSecondary, c.textTertiary),
            greaterThanOrEqualTo(1.15),
            reason: 'light: the text ramp needs distinct steps',
          );
        }

        // Hover and pressed are mixed from accentTint, so they shift *hue*
        // rather than darkness -- a tint that is plainly visible measures only
        // ~1.10 on a luminance ratio. Requiring luminance alone would drag
        // these states back toward the grey overlay they replaced, so a state
        // qualifies on either axis.
        double chromaOf(Color x) {
          final r = x.r * 255.0, g = x.g * 255.0, b = x.b * 255.0;
          return math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
        }

        for (final state in [('hover', c.hover), ('pressed', c.pressed)]) {
          for (final surface in [
            ('background', c.background),
            ('surface', c.surface),
            ('card', c.card),
            ('surfaceSunken', c.surfaceSunken),
            ('surfaceRaised', c.surfaceRaised),
          ]) {
            final composited = Color.alphaBlend(state.$2, surface.$2);
            final byLuminance = contrast(composited, surface.$2);
            final byChroma = chromaOf(composited) - chromaOf(surface.$2);
            expect(
              byLuminance >= 1.06 || byChroma >= 12.0,
              isTrue,
              reason: '${entry.key}: ${state.$1} on ${surface.$1} is invisible '
                  '(luminance $byLuminance, chroma delta $byChroma)',
            );
          }
        }
      }
    });

    test('entities that carry no colour of their own get a stable derived one',
        () {
      // Categories, people and free-text attributes rendered as neutral chips
      // because nothing gave EntityChip a colour, and they are the three most
      // frequent chip types -- a session row read as five grey chips to one
      // coloured. People and attribute fields derive theirs; categories store
      // one (MigrationV9).
      const seeds = ['person-a', 'person-b', 'def-jira', 'def-component'];

      for (final seed in seeds) {
        final first = ColorUtils.deterministicColor(seed);
        // Stable across calls: a colour that moves between rebuilds is worse
        // than no colour at all.
        expect(ColorUtils.deterministicColor(seed), equals(first));
        // Always a real palette entry, never the fallback-by-accident.
        expect(
          ColorUtils.paletteHex.map(ColorUtils.parseHex),
          contains(first),
        );
      }

      // Distinct seeds should mostly land on distinct swatches, or a row of
      // people reads as one colour and the change buys nothing.
      final distinct = seeds.map(ColorUtils.deterministicColor).toSet();
      expect(distinct.length, greaterThan(1));

      // Seeded on ids, not names: renaming a person must not recolour them.
      expect(
        ColorUtils.deterministicColor('person-a'),
        isNot(equals(ColorUtils.deterministicColor('person-a-renamed'))),
      );
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

      await tester.tap(find.byType(AppFilterDropdown<String>));
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
      // The submit affordance is advertised in the footer, spelled the way
      // the host platform writes it.
      expect(find.text(ShortcutLabels.primaryModifier), findsOneWidget);
      expect(find.text(ShortcutLabels.enterKey), findsOneWidget);

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

  group('CI Grep Guard', () {
    final libDir = Directory('lib');
    final dartFiles =
        libDir.listSync(recursive: true).whereType<File>().where((f) {
      final p = f.path.replaceAll(r'\', '/');
      return p.endsWith('.dart') &&
          !p.contains('lib/core/theme/') &&
          !p.contains('lib/domain/services/pdf/') &&
          !p.endsWith('lib/main.dart');
    }).toList();

    test('no raw Colors.white or Colors.black outside theme and pdf', () {
      final violations = <String>[];
      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') ||
              trimmed.startsWith('///') ||
              trimmed.startsWith('*')) {
            continue;
          }
          if (line.contains('Colors.white') || line.contains('Colors.black')) {
            violations.add('${file.path}:${i + 1}: $line');
          }
        }
      }
      expect(violations, isEmpty,
          reason: 'Raw Colors.white/black forbidden in UI code');
    });

    test('barrierColor must use tokenized overlay color', () {
      final violations = <String>[];
      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          if (line.contains('barrierColor:') && !line.contains('overlay')) {
            violations.add('${file.path}:${i + 1}: $line');
          }
        }
      }
      expect(violations, isEmpty,
          reason: 'barrierColor must use context.colors.overlay');
    });

    test('withValues(alpha:) must use Alphas scale constants', () {
      final violations = <String>[];
      final literalAlphaRegex = RegExp(r'withValues\s*\(\s*alpha:\s*0\.\d+');
      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          if (literalAlphaRegex.hasMatch(line)) {
            violations.add('${file.path}:${i + 1}: $line');
          }
        }
      }
      expect(violations, isEmpty,
          reason: 'withValues(alpha: ...) must use Alphas.* scale');
    });

    test('BoxShadow must not hardcode raw Colors.black or Colors.white', () {
      final violations = <String>[];
      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          if (line.contains('BoxShadow') &&
              (line.contains('Colors.black') ||
                  line.contains('Colors.white'))) {
            violations.add('${file.path}:${i + 1}: $line');
          }
        }
      }
      expect(violations, isEmpty,
          reason: 'BoxShadow must use colors.shadow via Elevation.*');
    });
  });
}
