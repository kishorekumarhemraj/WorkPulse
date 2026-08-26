import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/features/shell/models/shell_nav_tab.dart';

void main() {
  group('Sidebar navigation order', () {
    test('Track runs Dashboard, Patterns, Work Items, Log, Notes, Sheet', () {
      // Pinned because the order is what a user's muscle memory and the
      // digit shortcuts both key off — it must not drift when a tab is added.
      expect(
        tabsInGroup(ShellNavGroup.track).map((t) => t.label),
        [
          'Dashboard',
          'Patterns & Signals',
          'Work Items',
          'Time Log',
          'Time Notes',
          'Time Sheet',
        ],
      );
    });

    test('Library and Configure keep their reference-data tabs', () {
      expect(
        tabsInGroup(ShellNavGroup.library).map((t) => t.label),
        ['Projects', 'Categories', 'Tags', 'People'],
      );
      expect(
        tabsInGroup(ShellNavGroup.configure).map((t) => t.label),
        ['Attributes'],
      );
    });

    test('every tab belongs to exactly one group', () {
      final grouped = [
        for (final group in ShellNavGroup.values) ...tabsInGroup(group),
      ];
      expect(grouped.toSet(), ShellNavTab.values.toSet());
      expect(grouped, hasLength(ShellNavTab.values.length));
    });

    test('shortcut digits follow the sidebar, starting at 1', () {
      expect(ShellNavTab.dashboard.shortcutDigit, 1);
      expect(ShellNavTab.timesheet.shortcutDigit, 6);
    });

    test('the Time Sheet is findable by what it reports on', () {
      expect(
        ShellNavTab.timesheet.searchKeywords,
        containsAll(<String>['capex', 'opex', 'timesheet']),
      );
      // "timesheet" used to point at the Time Log; now that a Time Sheet
      // exists, the keyword must not match two destinations.
      expect(ShellNavTab.history.searchKeywords, isNot(contains('timesheet')));
    });
  });
}
