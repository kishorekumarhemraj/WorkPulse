import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/keyboard/list_cursor.dart';
import 'package:workpulse/core/keyboard/shortcut_labels.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/keycap.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/reports/pdf_report_export.dart';
import 'package:workpulse/features/shell/models/shell_nav_tab.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/timer/views/task_switch_dialog.dart';

/// What a palette entry does when chosen.
enum CommandKind { navigate, action, workItem }

class PaletteCommand {
  final String id;
  final String label;

  /// Group heading, e.g. "Go to", "Actions", "Start tracking".
  final String section;
  final IconData icon;
  final CommandKind kind;
  final List<String> keywords;
  final String? shortcut;
  final Future<void> Function() invoke;

  const PaletteCommand({
    required this.id,
    required this.label,
    required this.section,
    required this.icon,
    required this.kind,
    required this.invoke,
    this.keywords = const [],
    this.shortcut,
  });
}

/// An in-app launcher for navigation and actions, opened with the primary
/// modifier plus K.
///
/// Deliberately separate from the global Quick Capture HUD: that window is a
/// latency-critical path (AGENTS.md rule 3) that exists to start a timer from
/// inside another app. This palette is for driving the main window, and adds
/// no work to Quick Capture's build path.
class CommandPalette extends ConsumerStatefulWidget {
  final void Function(ShellNavTab tab) onNavigate;
  final VoidCallback onOpenQuickCapture;
  final VoidCallback onExport;
  final VoidCallback onNewTask;
  final VoidCallback onNewProject;
  final VoidCallback onToggleTheme;

  const CommandPalette({
    super.key,
    required this.onNavigate,
    required this.onOpenQuickCapture,
    required this.onExport,
    required this.onNewTask,
    required this.onNewProject,
    required this.onToggleTheme,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(ShellNavTab tab) onNavigate,
    required VoidCallback onOpenQuickCapture,
    required VoidCallback onExport,
    required VoidCallback onNewTask,
    required VoidCallback onNewProject,
    required VoidCallback onToggleTheme,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: context.colors.overlay,
      builder: (_) => CommandPalette(
        onNavigate: onNavigate,
        onOpenQuickCapture: onOpenQuickCapture,
        onExport: onExport,
        onNewTask: onNewTask,
        onNewProject: onNewProject,
        onToggleTheme: onToggleTheme,
      ),
    );
  }

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  String _query = '';

  /// A command row is 44pt, which is all the cursor needs to keep itself on
  /// screen. Rows carrying a section header are taller, so the nudge is an
  /// approximation — as it was before this moved into [ListCursor] — but it
  /// only has to land the row inside the viewport, not at a precise offset.
  late final ListCursor _cursor = ListCursor(
    rowExtent: _rowHeight,
    scrollController: _scrollController,
  );

  static const double _rowHeight = 44;

  @override
  void initState() {
    super.initState();
    _cursor.addListener(_onCursorMoved);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _cursor.removeListener(_onCursorMoved);
    _cursor.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onCursorMoved() => setState(() {});

  /// Subsequence match, so "wkit" finds "Work Items" the way editors do.
  bool _matches(String haystack, String needle) {
    if (needle.isEmpty) return true;
    final h = haystack.toLowerCase();
    final n = needle.toLowerCase();
    if (h.contains(n)) return true;

    var index = 0;
    for (final rune in n.runes) {
      final char = String.fromCharCode(rune);
      if (char == ' ') continue;
      index = h.indexOf(char, index);
      if (index == -1) return false;
      index++;
    }
    return true;
  }

  List<PaletteCommand> _buildCommands(List<WorkItem> workItems) {
    final timerState = ref.read(timerProvider).value;
    final isRunning = timerState?.isRunning ?? false;

    return [
      for (final tab in ShellNavTab.values)
        PaletteCommand(
          id: 'nav-${tab.name}',
          label: tab.label,
          section: 'Go to',
          icon: tab.icon,
          kind: CommandKind.navigate,
          keywords: tab.searchKeywords,
          shortcut: ShortcutLabels.primary('${tab.shortcutDigit}'),
          invoke: () async => widget.onNavigate(tab),
        ),
      PaletteCommand(
        id: 'action-quick-capture',
        label: 'Open Quick Capture',
        section: 'Actions',
        icon: Icons.bolt,
        kind: CommandKind.action,
        keywords: const ['start', 'track', 'capture'],
        invoke: () async => widget.onOpenQuickCapture(),
      ),
      PaletteCommand(
        id: 'action-new-task',
        label: 'New Work Item',
        section: 'Actions',
        icon: Icons.add_task,
        kind: CommandKind.action,
        keywords: const ['create', 'task', 'add'],
        shortcut: ShortcutLabels.primary('N'),
        invoke: () async => widget.onNewTask(),
      ),
      PaletteCommand(
        id: 'action-new-project',
        label: 'New Project',
        section: 'Actions',
        icon: Icons.create_new_folder_outlined,
        kind: CommandKind.action,
        keywords: const ['create', 'project', 'add'],
        invoke: () async => widget.onNewProject(),
      ),
      if (isRunning)
        PaletteCommand(
          id: 'action-stop',
          label: 'Stop Timer',
          section: 'Actions',
          icon: Icons.stop_circle_outlined,
          kind: CommandKind.action,
          keywords: const ['stop', 'pause', 'end'],
          shortcut: ShortcutLabels.primary('.'),
          invoke: () async => ref.read(timerProvider.notifier).stopTimer(),
        ),
      PaletteCommand(
        id: 'action-export-pdf',
        label: "Export Today's PDF Report",
        section: 'Actions',
        icon: Icons.picture_as_pdf_outlined,
        kind: CommandKind.action,
        keywords: const [
          'pdf',
          'report',
          'today',
          'daily',
          'manager',
          'standup',
          'export'
        ],
        invoke: _exportTodayPdf,
      ),
      PaletteCommand(
        id: 'action-export',
        label: 'Export Data',
        section: 'Actions',
        icon: Icons.file_download_outlined,
        kind: CommandKind.action,
        keywords: const ['csv', 'json', 'download', 'backup'],
        shortcut: ShortcutLabels.primary('E'),
        invoke: () async => widget.onExport(),
      ),
      PaletteCommand(
        id: 'action-theme',
        label: 'Switch Appearance',
        section: 'Actions',
        icon: Icons.contrast,
        kind: CommandKind.action,
        keywords: const ['theme', 'dark', 'light', 'appearance'],
        invoke: () async => widget.onToggleTheme(),
      ),
      // Starting a timer is the app's most common action, so work items are
      // directly launchable rather than requiring a trip to the list.
      for (final item in workItems.where((w) => !w.isArchived).take(50))
        PaletteCommand(
          id: 'item-${item.id}',
          label: item.name,
          section: 'Start tracking',
          icon: Icons.play_circle_outline,
          kind: CommandKind.workItem,
          invoke: () => _startTracking(item),
        ),
    ];
  }

  Future<void> _startTracking(WorkItem item) async {
    final timerState = ref.read(timerProvider).value;
    final isTrackingSomethingElse = timerState != null &&
        timerState.isRunning &&
        timerState.activeWorkItem != null &&
        timerState.activeWorkItem!.id != item.id;

    if (isTrackingSomethingElse) {
      // Switching mid-session must go through the same confirmation the rest
      // of the app uses — exactly one session may be active at a time.
      ref.read(timerProvider.notifier).requestSwitch(item);
      if (!mounted) return;
      await TaskSwitchDialog.show(
        context,
        currentItem: timerState.activeWorkItem!,
        currentElapsed: timerState.elapsed,
        targetItem: item,
      );
    } else {
      await ref.read(timerProvider.notifier).startTimer(item);
    }
  }

  Future<void> _exportTodayPdf() async {
    await PdfReportExport.run(
      context,
      ref,
      range: DashboardTimeRange.today.toDateRange(),
      fileNamePrefix: 'WorkPulse_Daily_Report',
    );
  }

  Future<void> _run(PaletteCommand command) async {
    Navigator.of(context).pop();
    await command.invoke();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final workItems = ref.watch(workItemsProvider).value ?? const <WorkItem>[];

    final results = _buildCommands(workItems).where((c) {
      if (_query.isEmpty) return c.kind != CommandKind.workItem;
      return _matches(c.label, _query) ||
          c.keywords.any((k) => _matches(k, _query));
    }).toList();

    final safeIndex = _cursor.clampedIn(results.length);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 100, left: 24, right: 24),
      // A Focus handler rather than Shortcuts/CallbackShortcuts: the query
      // field holds focus, and a TextField consumes Enter itself before an
      // ancestor shortcut ever sees it. This mirrors how Quick Capture
      // handles the same problem.
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;

          if (_cursor.handleKey(event, results.length)) {
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            if (results.isNotEmpty) _run(results[safeIndex]);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          width: 560,
          constraints: const BoxConstraints(maxHeight: 440),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: Radii.xxlAll,
            border: Border.all(color: colors.divider),
            boxShadow: Elevation.high(colors.shadow),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Query input
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.md,
                  Spacing.md,
                  Spacing.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: IconSizes.lg,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: theme.textTheme.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'Search commands, screens and work items…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) {
                          setState(() => _query = value.trim());
                          // The results underneath are a different list now.
                          _cursor.reset();
                        },
                      ),
                    ),
                    const Keycap('esc'),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.divider),

              Flexible(
                child: results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(Spacing.xxl),
                        child: Text(
                          'No matches for "$_query"',
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          vertical: Spacing.sm,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final command = results[index];
                          final showSection = index == 0 ||
                              results[index - 1].section != command.section;
                          return _CommandRow(
                            command: command,
                            isSelected: index == safeIndex,
                            sectionHeader: showSection ? command.section : null,
                            onTap: () => _run(command),
                            onHover: () =>
                                _cursor.moveTo(index, results.length),
                          );
                        },
                      ),
              ),

              Divider(height: 1, color: colors.divider),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg,
                  vertical: Spacing.sm,
                ),
                child: Row(
                  children: [
                    // Wrapped, not a fixed Row: these hints are wider on
                    // Windows ("Ctrl+Enter" against "⌘↩") and overflowed.
                    Expanded(
                      child: Wrap(
                        spacing: Spacing.lg,
                        runSpacing: Spacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const _KeyHint(keys: ['↑', '↓'], label: 'navigate'),
                          const _KeyHint(keys: ['home', 'end'], label: 'jump'),
                          _KeyHint(
                            keys: [ShortcutLabels.enterKey],
                            label: 'run',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Text(
                      '${results.length} result'
                      '${results.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One "these keys do this" hint in the palette footer.
class _KeyHint extends StatelessWidget {
  final List<String> keys;
  final String label;

  const _KeyHint({required this.keys, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KeycapGroup(keys),
        const SizedBox(width: Spacing.sm - 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CommandRow extends StatelessWidget {
  final PaletteCommand command;
  final bool isSelected;
  final String? sectionHeader;
  final VoidCallback onTap;
  final VoidCallback onHover;

  const _CommandRow({
    required this.command,
    required this.isSelected,
    required this.sectionHeader,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionHeader != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              Spacing.xs,
            ),
            child: Text(
              sectionHeader!.toUpperCase(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: colors.textTertiary),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: MouseRegion(
            onEnter: (_) => onHover(),
            cursor: SystemMouseCursors.click,
            child: Material(
              color: isSelected ? colors.selected : Colors.transparent,
              borderRadius: Radii.smAll,
              child: InkWell(
                onTap: onTap,
                borderRadius: Radii.smAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.sm + 1,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        command.icon,
                        size: IconSizes.md,
                        color:
                            isSelected ? colors.accent : colors.textSecondary,
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Text(
                          command.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (command.shortcut != null) ...[
                        const SizedBox(width: Spacing.sm),
                        Keycap(command.shortcut!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
