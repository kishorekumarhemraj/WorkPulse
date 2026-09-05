import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:workpulse/core/keyboard/search_focus.dart';
import 'package:workpulse/core/platform/hotkey_service.dart';
import 'package:workpulse/core/platform/window_service.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/domain/services/activity_heartbeat_service.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/attributes/views/attribute_definitions_view.dart';
import 'package:workpulse/features/categories/views/categories_view.dart';
import 'package:workpulse/features/dashboard/views/dashboard_view.dart';
import 'package:workpulse/features/idle/providers/idle_provider.dart';
import 'package:workpulse/features/idle/views/idle_prompt_dialog.dart';
import 'package:workpulse/features/notes/views/time_notes_view.dart';
import 'package:workpulse/features/patterns/views/patterns_view.dart';
import 'package:workpulse/features/people/views/people_view.dart';
import 'package:workpulse/features/planner/views/planner_view.dart';
import 'package:workpulse/features/projects/views/project_form_dialog.dart';
import 'package:workpulse/features/projects/views/projects_view.dart';
import 'package:workpulse/features/quick_capture/views/quick_capture_body.dart';
import 'package:workpulse/features/reminders/providers/reminder_scheduler_provider.dart';
import 'package:workpulse/features/reports/views/export_dialog.dart';
import 'package:workpulse/features/reports/views/session_history_view.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';
import 'package:workpulse/features/shell/models/shell_nav_tab.dart';
import 'package:workpulse/features/shell/views/command_palette.dart';
import 'package:workpulse/features/shell/widgets/app_sidebar.dart';
import 'package:workpulse/features/tags/views/tags_view.dart';
import 'package:workpulse/features/tasks/views/task_form_dialog.dart';
import 'package:workpulse/features/tasks/views/tasks_view.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/timesheet/views/timesheet_view.dart';
import 'package:workpulse/features/timer/views/active_timer_bar.dart';
import 'package:workpulse/features/tray/providers/tray_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

// Re-exported so existing imports of this library keep resolving ShellNavTab
// and activeNavTabProvider after they moved to the shell models library.
export 'package:workpulse/features/shell/models/shell_nav_tab.dart';

// --- Keyboard intents ---------------------------------------------------

class _NavigateIntent extends Intent {
  final ShellNavTab tab;
  const _NavigateIntent(this.tab);
}

class _OpenPaletteIntent extends Intent {
  const _OpenPaletteIntent();
}

class _NewItemIntent extends Intent {
  const _NewItemIntent();
}

class _StopTimerIntent extends Intent {
  const _StopTimerIntent();
}

class _ExportIntent extends Intent {
  const _ExportIntent();
}

class _QuickCaptureIntent extends Intent {
  const _QuickCaptureIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class MainShellView extends ConsumerStatefulWidget {
  const MainShellView({super.key});

  @override
  ConsumerState<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends ConsumerState<MainShellView>
    with WidgetsBindingObserver {
  late final HotKeyService _hotKeyService;
  late final WindowService _windowService;
  late final ActivityHeartbeatService _heartbeat;

  /// Owned here so the shell's "focus search" shortcut and the screen's search
  /// field agree on which node that is.
  final _searchFocus = SearchFocusRegistry();

  @override
  void initState() {
    super.initState();
    _hotKeyService = ref.read(hotKeyServiceProvider);
    _windowService = ref.read(windowServiceProvider);
    _heartbeat = ref.read(activityHeartbeatServiceProvider);
    ref.read(reminderSchedulerProvider);
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_initializeHotKey);

    // Deferred to after the first frame so the idle listener registered in
    // build() exists to catch the prompt this may raise.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_runStartupRecovery());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The heartbeat deliberately outlives this widget: it tracks "the app is
    // alive with a session running", and the shell is torn down and rebuilt
    // every time the Quick Capture window takes over. It is stopped by
    // [_syncActivityMonitors] when tracking actually ends, and by the provider
    // scope when the app exits.
    _hotKeyService.unregisterAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    super.didChangeAppLifecycleState(lifecycleState);

    // Hiding the window, closing it, or quitting is the last chance to mark the
    // app as alive. Without this the gap reported on the next launch would
    // start at the previous 30s tick instead of the moment the user left.
    if (lifecycleState != AppLifecycleState.resumed && _heartbeat.isBeating) {
      unawaited(_heartbeat.beat().catchError((Object _) {}));
    }
  }

  /// Reconciles a session left open by a previous run before anything else
  /// starts writing heartbeats over the evidence.
  Future<void> _runStartupRecovery() async {
    try {
      await ref.read(idleNotifierProvider.notifier).checkForUnaccountedGap();
    } catch (error, stack) {
      // Best-effort: a failure here must not keep the shell from coming up,
      // and it leaves the open session exactly as it was found rather than
      // guessing at how to split it.
      debugPrint('[WorkPulse] Idle gap recovery failed: $error\n$stack');
    }

    if (!mounted) return;
    _syncActivityMonitors();
  }

  /// Idle polling and the persisted heartbeat both mean "a session is running
  /// and WorkPulse is watching it", so they start and stop together.
  ///
  /// While an idle prompt is open the heartbeat is deliberately held back:
  /// beating would move the baseline past the very gap the user has not
  /// answered for yet, and a force-quit at that point would lose it for good.
  ///
  /// This runs on transitions only. It used to be driven by an unfiltered
  /// `ref.listen` on the whole timer state, which emits once a second while a
  /// session runs — restarting the detector's poll timer before it could ever
  /// fire, so live idle detection never triggered.
  void _syncActivityMonitors() {
    final isTracking = ref.read(timerProvider).value?.isRunning ?? false;
    final isPromptVisible = ref.read(idleNotifierProvider).isPromptVisible;

    ref
        .read(idleDetectorServiceProvider)
        .startMonitoring(isTracking: isTracking);

    if (isTracking && !isPromptVisible) {
      _heartbeat.start();
    } else {
      _heartbeat.stop();
    }
  }

  Future<void> _initializeHotKey() async {
    await _windowService.initialize();
    await _hotKeyService.initialize();
    final settings = await ref.read(appSettingsProvider.future);
    await _registerQuickCaptureHotKey(settings.quickCaptureHotKey);
  }

  Future<void> _registerQuickCaptureHotKey(HotKey hotKey) async {
    await _hotKeyService.registerQuickCaptureHotKey(
      _showQuickCapture,
      hotKey: hotKey,
    );
  }

  Future<void> _showQuickCapture() async {
    // Opened at the height its configuration bar will need, so the fields the
    // user asked to see in Quick Capture are on screen rather than folded into
    // a scroll view at the bottom of a fixed-size window.
    await _windowService.openQuickCapture(
      height: QuickCaptureBody.hudHeightFrom(
        ref.read(attributeDefinitionsProvider).value ??
            const <AttributeDefinition>[],
      ),
    );
  }

  void _setTab(ShellNavTab tab) =>
      ref.read(activeNavTabProvider.notifier).setTab(tab);

  /// Creates the entity that makes sense for the current screen, so the "new"
  /// shortcut always does the obvious thing.
  Future<void> _newInContext() async {
    switch (ref.read(activeNavTabProvider)) {
      case ShellNavTab.projects:
        await ProjectFormDialog.show(context);
      case ShellNavTab.dashboard:
      case ShellNavTab.patterns:
      case ShellNavTab.planner:
      case ShellNavTab.history:
      case ShellNavTab.notes:
      case ShellNavTab.timesheet:
      case ShellNavTab.tasks:
      case ShellNavTab.categories:
      case ShellNavTab.tags:
      case ShellNavTab.people:
      case ShellNavTab.attributes:
        await TaskFormDialog.show(context);
    }
  }

  void _cycleThemeMode() {
    final current = ref.read(appSettingsProvider).value?.themeMode;
    if (current == null) return;
    final next = switch (current) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    ref.read(appSettingsProvider.notifier).setThemeMode(next);
  }

  Future<void> _openCommandPalette() {
    return CommandPalette.show(
      context,
      onNavigate: _setTab,
      onOpenQuickCapture: _showQuickCapture,
      onExport: () => ExportDialog.show(context),
      onNewTask: () => TaskFormDialog.show(context),
      onNewProject: () => ProjectFormDialog.show(context),
      onToggleTheme: _cycleThemeMode,
    );
  }

  Future<void> _showShortcutRecorder(HotKey currentHotKey) async {
    HotKey recordedHotKey = currentHotKey;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AppDialog(
          title: 'Quick Capture Shortcut',
          subtitle: 'Press the keys you want to use.',
          icon: Icons.keyboard_outlined,
          width: DialogWidth.small,
          onSubmit: () => Navigator.of(context).pop(true),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save Shortcut'),
            ),
          ],
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: Radii.mdAll,
              border: Border.all(color: colors.divider),
            ),
            child: HotKeyRecorder(
              initalHotKey: currentHotKey,
              onHotKeyRecorded: (hotKey) {
                recordedHotKey = hotKey;
              },
            ),
          ),
        );
      },
    );

    if (accepted == true) {
      await ref
          .read(appSettingsProvider.notifier)
          .setQuickCaptureHotKey(recordedHotKey);
      await _registerQuickCaptureHotKey(recordedHotKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeTab = ref.watch(activeNavTabProvider);
    final workspaceAsync = ref.watch(currentWorkspaceProvider);
    final settings = ref.watch(appSettingsProvider).value;

    ref.listen<AsyncValue<AppSettings>>(appSettingsProvider, (previous, next) {
      final previousHotKey = previous?.value?.quickCaptureHotKey;
      final nextHotKey = next.value?.quickCaptureHotKey;
      if (nextHotKey != null &&
          previousHotKey?.debugName != nextHotKey.debugName) {
        _registerQuickCaptureHotKey(nextHotKey);
      }
    });

    // Prompt user when inactivity is detected
    ref.listen<IdleState>(idleNotifierProvider, (previous, next) {
      if (next.isPromptVisible && previous?.isPromptVisible != true) {
        IdlePromptDialog.show(context);
      }
      if (previous?.isPromptVisible != next.isPromptVisible) {
        _syncActivityMonitors();
      }
    });

    // Start/stop idle monitoring and heartbeats with the active timer.
    // Selected down to the running flag: the timer republishes its state every
    // second, and reacting to each tick restarted the idle poll timer.
    ref.listen<bool>(
      timerProvider.select((s) => s.value?.isRunning ?? false),
      (previous, next) => _syncActivityMonitors(),
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: workspaceAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: Spacing.lg),
              Text(
                'Initializing WorkPulse…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        error: (error, stack) => ErrorState(
          title: 'WorkPulse could not start',
          error: error,
          onRetry: () => ref.invalidate(currentWorkspaceProvider),
        ),
        data: (workspace) {
          final label = hotKeyLabel(
            settings?.quickCaptureHotKey ?? defaultQuickCaptureHotKey(),
          );

          return _ShellShortcuts(
            onNavigate: _setTab,
            onOpenPalette: _openCommandPalette,
            onNewItem: _newInContext,
            onStopTimer: () => ref.read(timerProvider.notifier).stopTimer(),
            onExport: () => ExportDialog.show(context),
            onQuickCapture: _showQuickCapture,
            onFocusSearch: _searchFocus.requestFocus,
            child: Column(
              children: [
                const ActiveTimerBar(),
                Expanded(
                  child: Row(
                    children: [
                      AppSidebar(
                        workspace: workspace,
                        hotKeyLabel: label,
                        themeMode: settings?.themeMode ?? ThemeMode.dark,
                        onThemeModeChanged: (mode) => ref
                            .read(appSettingsProvider.notifier)
                            .setThemeMode(mode),
                        onQuickCapture: _showQuickCapture,
                        onEditShortcut: settings == null
                            ? null
                            : () => _showShortcutRecorder(
                                  settings.quickCaptureHotKey,
                                ),
                        idleThreshold: settings?.idleThreshold,
                        onIdleThresholdChanged: (threshold) => ref
                            .read(appSettingsProvider.notifier)
                            .setIdleThreshold(threshold),
                      ),
                      Expanded(
                        child: SearchFocusScope(
                          registry: _searchFocus,
                          child: _ContentViewport(activeTab: activeTab),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Application-level keyboard shortcuts.
///
/// Every binding here is also advertised somewhere visible — in the command
/// palette, in a tooltip, or on a collapsed nav item — so the keyboard layer
/// is discoverable rather than hidden.
class _ShellShortcuts extends StatelessWidget {
  final void Function(ShellNavTab tab) onNavigate;
  final VoidCallback onOpenPalette;
  final VoidCallback onNewItem;
  final VoidCallback onStopTimer;
  final VoidCallback onExport;
  final VoidCallback onQuickCapture;
  final VoidCallback onFocusSearch;
  final Widget child;

  const _ShellShortcuts({
    required this.onNavigate,
    required this.onOpenPalette,
    required this.onNewItem,
    required this.onStopTimer,
    required this.onExport,
    required this.onQuickCapture,
    required this.onFocusSearch,
    required this.child,
  });

  static const _digitKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  @override
  Widget build(BuildContext context) {
    // Guarded so adding a tenth destination cannot throw a RangeError at
    // runtime; the extra tab simply has no digit shortcut until one is added.
    final digitCount = ShellNavTab.values.length < _digitKeys.length
        ? ShellNavTab.values.length
        : _digitKeys.length;

    final shortcuts = <ShortcutActivator, Intent>{
      for (var i = 0; i < digitCount; i++) ...{
        SingleActivator(_digitKeys[i], meta: true):
            _NavigateIntent(ShellNavTab.values[i]),
        SingleActivator(_digitKeys[i], control: true):
            _NavigateIntent(ShellNavTab.values[i]),
      },
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
          const _OpenPaletteIntent(),
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          const _OpenPaletteIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
          const _NewItemIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          const _NewItemIntent(),
      const SingleActivator(LogicalKeyboardKey.period, meta: true):
          const _StopTimerIntent(),
      const SingleActivator(LogicalKeyboardKey.period, control: true):
          const _StopTimerIntent(),
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
          const _ExportIntent(),
      const SingleActivator(LogicalKeyboardKey.keyE, control: true):
          const _ExportIntent(),
      // A local mirror of the global Quick Capture hotkey, so it also works
      // when the main window already has focus.
      const SingleActivator(LogicalKeyboardKey.space, alt: true):
          const _QuickCaptureIntent(),
      // Jumps to the visible screen's search box. Six screens carry one and
      // none of them could be reached without a mouse.
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
          const _FocusSearchIntent(),
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          const _FocusSearchIntent(),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NavigateIntent: CallbackAction<_NavigateIntent>(
            onInvoke: (intent) {
              onNavigate(intent.tab);
              return null;
            },
          ),
          _OpenPaletteIntent: CallbackAction<_OpenPaletteIntent>(
            onInvoke: (_) {
              onOpenPalette();
              return null;
            },
          ),
          _NewItemIntent: CallbackAction<_NewItemIntent>(
            onInvoke: (_) {
              onNewItem();
              return null;
            },
          ),
          _StopTimerIntent: CallbackAction<_StopTimerIntent>(
            onInvoke: (_) {
              onStopTimer();
              return null;
            },
          ),
          _ExportIntent: CallbackAction<_ExportIntent>(
            onInvoke: (_) {
              onExport();
              return null;
            },
          ),
          _QuickCaptureIntent: CallbackAction<_QuickCaptureIntent>(
            onInvoke: (_) {
              onQuickCapture();
              return null;
            },
          ),
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              onFocusSearch();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

/// The active screen, cross-faded on tab change.
class _ContentViewport extends StatelessWidget {
  final ShellNavTab activeTab;

  const _ContentViewport({required this.activeTab});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.duration(context, Motion.base),
      switchInCurve: Motion.curve,
      switchOutCurve: Motion.exitCurve,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.012),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      // Keying by tab is what makes the switcher treat each screen as a
      // distinct child and animate between them.
      child: KeyedSubtree(
        key: ValueKey(activeTab),
        child: switch (activeTab) {
          ShellNavTab.dashboard => const DashboardView(),
          ShellNavTab.patterns => const PatternsView(),
          ShellNavTab.planner => const PlannerView(),
          ShellNavTab.history => const SessionHistoryView(),
          ShellNavTab.tasks => const TasksView(),
          ShellNavTab.notes => const TimeNotesView(),
          ShellNavTab.timesheet => const TimesheetView(),
          ShellNavTab.projects => const ProjectsView(),
          ShellNavTab.categories => const CategoriesView(),
          ShellNavTab.tags => const TagsView(),
          ShellNavTab.people => const PeopleView(),
          ShellNavTab.attributes => const AttributeDefinitionsView(),
        },
      ),
    );
  }
}
