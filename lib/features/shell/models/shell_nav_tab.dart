import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sections reachable from the sidebar.
///
/// Declaration order is sidebar order — [tabsInGroup] and [shortcutDigit]
/// both read it — so the Track group runs in the order a day does: see where
/// you stand, read what that says about you, pick the work, log it, write it
/// up, then report it.
enum ShellNavTab {
  dashboard,
  patterns,
  planner,
  tasks,
  history,
  notes,
  timesheet,
  projects,
  categories,
  tags,
  people,
  attributes,
}

/// Sidebar groupings.
///
/// The nav was previously a flat list of eight items, which gave equal weight
/// to the screens a user visits many times a day and the ones they configure
/// once. Grouping separates day-to-day tracking from the reference data that
/// supports it.
enum ShellNavGroup {
  /// What the user does all day.
  track('Track'),

  /// The entities that classify tracked work.
  library('Library'),

  /// Setup that is touched rarely.
  configure('Configure');

  const ShellNavGroup(this.label);
  final String label;
}

/// Static presentation data for a nav destination.
extension ShellNavTabInfo on ShellNavTab {
  String get label => switch (this) {
        ShellNavTab.dashboard => 'Dashboard',
        ShellNavTab.patterns => 'Patterns & Signals',
        ShellNavTab.planner => 'Planner',
        ShellNavTab.history => 'Time Log',
        ShellNavTab.notes => 'Time Notes',
        ShellNavTab.timesheet => 'Time Sheet',
        ShellNavTab.tasks => 'Work Items',
        ShellNavTab.projects => 'Projects',
        ShellNavTab.categories => 'Categories',
        ShellNavTab.tags => 'Tags',
        ShellNavTab.people => 'People',
        ShellNavTab.attributes => 'Attributes',
      };

  IconData get icon => switch (this) {
        ShellNavTab.dashboard => Icons.space_dashboard_outlined,
        ShellNavTab.patterns => Icons.insights_outlined,
        ShellNavTab.planner => Icons.event_note_outlined,
        ShellNavTab.history => Icons.history,
        ShellNavTab.notes => Icons.edit_note_outlined,
        ShellNavTab.timesheet => Icons.table_chart_outlined,
        ShellNavTab.tasks => Icons.check_circle_outline,
        ShellNavTab.projects => Icons.folder_outlined,
        ShellNavTab.categories => Icons.category_outlined,
        ShellNavTab.tags => Icons.label_outline,
        ShellNavTab.people => Icons.people_outline,
        ShellNavTab.attributes => Icons.tune,
      };

  ShellNavGroup get group => switch (this) {
        ShellNavTab.dashboard ||
        ShellNavTab.patterns ||
        ShellNavTab.planner ||
        ShellNavTab.history ||
        ShellNavTab.notes ||
        ShellNavTab.timesheet ||
        ShellNavTab.tasks =>
          ShellNavGroup.track,
        ShellNavTab.projects ||
        ShellNavTab.categories ||
        ShellNavTab.tags ||
        ShellNavTab.people =>
          ShellNavGroup.library,
        ShellNavTab.attributes => ShellNavGroup.configure,
      };

  /// The digit paired with the primary modifier to jump straight here.
  int get shortcutDigit => index + 1;

  /// What the command palette should match against, beyond the label.
  List<String> get searchKeywords => switch (this) {
        ShellNavTab.dashboard => ['analytics', 'summary', 'charts'],
        ShellNavTab.patterns => [
            'patterns',
            'signals',
            'insights',
            'reclaim',
            'delegate',
            'focus',
            'rhythm',
          ],
        ShellNavTab.planner => [
            'planner',
            'planning',
            'due',
            'deadlines',
            'schedule',
            'overdue',
            'calendar',
          ],
        ShellNavTab.history => ['sessions', 'log', 'history', 'entries'],
        ShellNavTab.notes => [
            'notes',
            'standup',
            'daily',
            'summary',
            'journal',
            'log'
          ],
        ShellNavTab.timesheet => [
            'timesheet',
            'time sheet',
            'capex',
            'opex',
            'capitalizable',
            'operational',
            'billing',
            'hours',
          ],
        ShellNavTab.tasks => ['tasks', 'items', 'issues', 'work'],
        ShellNavTab.projects => ['clients', 'projects'],
        ShellNavTab.categories => ['categories', 'types'],
        ShellNavTab.tags => ['labels', 'tags'],
        ShellNavTab.people => ['team', 'contacts', 'people'],
        ShellNavTab.attributes => ['custom fields', 'metadata', 'attributes'],
      };
}

/// The tabs belonging to [group], in sidebar order.
List<ShellNavTab> tabsInGroup(ShellNavGroup group) =>
    ShellNavTab.values.where((t) => t.group == group).toList();

/// The currently displayed section.
final activeNavTabProvider =
    NotifierProvider<ActiveNavTabNotifier, ShellNavTab>(
  ActiveNavTabNotifier.new,
);

class ActiveNavTabNotifier extends Notifier<ShellNavTab> {
  @override
  ShellNavTab build() => ShellNavTab.tasks;

  void setTab(ShellNavTab tab) => state = tab;
}

/// Whether the sidebar is collapsed to an icon rail.
final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
  SidebarCollapsedNotifier.new,
);

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
