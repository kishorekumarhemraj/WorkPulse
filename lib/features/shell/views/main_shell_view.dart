import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/platform/hotkey_service.dart';
import 'package:workpulse/core/platform/window_service.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/attributes/views/attribute_definitions_view.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/categories/views/categories_view.dart';
import 'package:workpulse/features/dashboard/views/dashboard_view.dart';
import 'package:workpulse/features/idle/providers/idle_provider.dart';
import 'package:workpulse/features/idle/views/idle_prompt_dialog.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/people/views/people_view.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/projects/views/projects_view.dart';
import 'package:workpulse/features/quick_capture/views/quick_capture_dialog.dart';
import 'package:workpulse/features/reports/providers/reports_provider.dart';
import 'package:workpulse/features/reports/views/session_history_view.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tags/views/tags_view.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/tasks/views/tasks_view.dart';
import 'package:workpulse/features/timer/models/timer_state.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/timer/views/active_timer_bar.dart';
import 'package:workpulse/features/tray/providers/tray_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

enum ShellNavTab {
  dashboard,
  history,
  tasks,
  projects,
  categories,
  tags,
  people,
  attributes,
}

final activeNavTabProvider =
    NotifierProvider<ActiveNavTabNotifier, ShellNavTab>(
  ActiveNavTabNotifier.new,
);

class ActiveNavTabNotifier extends Notifier<ShellNavTab> {
  @override
  ShellNavTab build() => ShellNavTab.tasks;

  void setTab(ShellNavTab tab) => state = tab;
}

class MainShellView extends ConsumerStatefulWidget {
  const MainShellView({super.key});

  @override
  ConsumerState<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends ConsumerState<MainShellView> {
  late final HotKeyService _hotKeyService;
  late final WindowService _windowService;

  @override
  void initState() {
    super.initState();
    _hotKeyService = DesktopHotKeyService();
    _windowService = DesktopWindowService();
    Future.microtask(_initializeHotKey);

    // Initialize macOS Tray Coordinator
    final trayCoordinator = ref.read(trayCoordinatorProvider);
    trayCoordinator.onQuickCaptureRequested = () {
      _showQuickCapture();
    };
    trayCoordinator.initialize();
  }

  @override
  void dispose() {
    _hotKeyService.unregisterAll();
    super.dispose();
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
    await _windowService.openQuickCapture();
  }

  Future<void> _showShortcutRecorder(HotKey currentHotKey) async {
    HotKey recordedHotKey = currentHotKey;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.getColors(context).surface,
          title: Text(
            'Quick Capture Shortcut',
            style: TextStyle(color: AppTheme.getColors(context).textPrimary),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Press the keys you want to use.',
                  style: TextStyle(color: AppTheme.getColors(context).textSecondary),
                ),
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.getColors(context).card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.getColors(context).divider),
                  ),
                  child: HotKeyRecorder(
                    initalHotKey: currentHotKey,
                    onHotKeyRecorded: (hotKey) {
                      recordedHotKey = hotKey;
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Save Shortcut'),
            ),
          ],
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
    });

    // Start/stop idle monitoring based on active timer status
    ref.listen<AsyncValue<TimerState>>(timerProvider, (previous, next) {
      final isRunning = next.value?.isRunning ?? false;
      ref
          .read(idleDetectorServiceProvider)
          .startMonitoring(isTracking: isRunning);
    });

    return Scaffold(
      backgroundColor: AppTheme.getColors(context).background,
      body: workspaceAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing WorkPulse...',
                  style: TextStyle(color: AppTheme.getColors(context).textSecondary)),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Text('Initialization error: $error',
              style: TextStyle(color: AppTheme.accentRed)),
        ),
        data: (workspace) {
          return Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Sidebar
                    Container(
                      width: 220,
                      decoration: BoxDecoration(
                        color: AppTheme.getColors(context).surface,
                        border: Border(
                          right:
                              BorderSide(color: AppTheme.getColors(context).divider, width: 1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // App Brand Header
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.timer_outlined,
                                          color: AppTheme.primaryColor,
                                          size: 20),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        AppConstants.appName,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.getColors(context).textPrimary,
                                          letterSpacing: -0.3,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                // Workspace Indicator
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.getColors(context).card,
                                    borderRadius: BorderRadius.circular(6),
                                    border:
                                        Border.all(color: AppTheme.getColors(context).divider),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.workspaces_outlined,
                                          size: 12,
                                          color: AppTheme.getColors(context).textSecondary),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          workspace.name,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  AppTheme.getColors(context).textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 12),
                                // Quick Capture Shortcut Button
                                InkWell(
                                  onTap: _showQuickCapture,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.flash_on,
                                            size: 15,
                                            color: AppTheme.primaryColor),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Quick Capture',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    AppTheme.getColors(context).textPrimary),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.getColors(context).surface,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            settings == null
                                                ? '⌥ Space'
                                                : hotKeyLabel(settings
                                                    .quickCaptureHotKey),
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    AppTheme.getColors(context).textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(color: AppTheme.getColors(context).divider, height: 1),
                          SizedBox(height: 8),

                          // Navigation Items
                          Expanded(
                            child: ListView(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 8),
                              children: [
                                _SidebarNavItem(
                                  icon: Icons.space_dashboard_outlined,
                                  label: 'Dashboard',
                                  isSelected:
                                      activeTab == ShellNavTab.dashboard,
                                  onTap: () => ref
                                      .read(activeNavTabProvider.notifier)
                                      .setTab(ShellNavTab.dashboard),
                                ),
                                _SidebarNavItem(
                                  icon: Icons.history,
                                  label: 'Time Log',
                                  isSelected: activeTab == ShellNavTab.history,
                                  countProvider: Provider((r) => r
                                      .watch(sessionHistoryProvider)
                                      .value
                                      ?.length),
                                  onTap: () => ref
                                      .read(activeNavTabProvider.notifier)
                                      .setTab(ShellNavTab.history),
                                ),
                                _SidebarNavItem(
                                  icon: Icons.check_circle_outline,
                                  label: 'Work Items',
                                  isSelected: activeTab == ShellNavTab.tasks,
                                  countProvider: Provider((r) =>
                                      r.watch(workItemsProvider).value?.length),
                                  onTap: () => ref
                                      .read(activeNavTabProvider.notifier)
                                      .setTab(ShellNavTab.tasks),
                                ),
                                _SidebarNavItem(
                                  icon: Icons.folder_outlined,
                                  label: 'Projects',
                                  isSelected: activeTab == ShellNavTab.projects,
                                  countProvider: Provider((r) =>
                                      r.watch(projectsProvider).value?.length),
                                  onTap: () => ref
                                      .read(activeNavTabProvider.notifier)
                                      .setTab(ShellNavTab.projects),
                                ),
                                _SidebarNavItem(
                                  icon: Icons.category_outlined,
                                  label: 'Categories',
                                  isSelected:
                                      activeTab == ShellNavTab.categories,
                                  countProvider: Provider((r) => r
                                      .watch(categoriesProvider)
                                      .value
                                      ?.length),
                                  onTap: () => ref
                                      .read(activeNavTabProvider.notifier)
                                      .setTab(ShellNavTab.categories),
                                ),
                                _SidebarNavItem(
                                  icon: Icons.label_outline,
                                  label: 'Tags',
                                  isSelected: activeTab == ShellNavTab.tags,
                                  countProvider: Provider((r) =>
                                      r.watch(tagsProvider).value?.length),
                                  onTap: () => ref
                                      .read(activeNavTabProvider.notifier)
                                      .setTab(ShellNavTab.tags),
                                ),
                                _SidebarNavItem(
                                  icon: Icons.people_outline,
                                  label: 'People',
                                  isSelected: activeTab == ShellNavTab.people,
                                  countProvider: Provider((r) =>
                                      r.watch(peopleProvider).value?.length),
                                  onTap: () => ref
                                      .read(activeNavTabProvider.notifier)
                                      .setTab(ShellNavTab.people),
                                ),
                                _SidebarNavItem(
                                  icon: Icons.tune,
                                  label: 'Attributes',
                                  isSelected:
                                      activeTab == ShellNavTab.attributes,
                                  countProvider: Provider((r) => r
                                      .watch(attributeDefinitionsProvider)
                                      .value
                                      ?.length),
                                  onTap: () => ref
                                      .read(activeNavTabProvider.notifier)
                                      .setTab(ShellNavTab.attributes),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.light_mode_outlined,
                                        size: 15,
                                        color: AppTheme.getColors(context).textSecondary),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Light Mode',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.getColors(context).textSecondary),
                                      ),
                                    ),
                                    Switch(
                                      value: settings?.themeMode ==
                                          ThemeMode.light,
                                      onChanged: settings == null
                                          ? null
                                          : (enabled) {
                                              ref
                                                  .read(appSettingsProvider
                                                      .notifier)
                                                  .setThemeMode(enabled
                                                      ? ThemeMode.light
                                                      : ThemeMode.dark);
                                            },
                                      activeTrackColor: AppTheme.primaryColor,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                OutlinedButton.icon(
                                  onPressed: settings == null
                                      ? null
                                      : () => _showShortcutRecorder(
                                          settings.quickCaptureHotKey),
                                  icon: Icon(Icons.keyboard_outlined,
                                      size: 15),
                                  label: Text(
                                    settings == null
                                        ? 'Shortcut'
                                        : hotKeyLabel(
                                            settings.quickCaptureHotKey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.getColors(context).textSecondary,
                                    side: BorderSide(
                                        color: AppTheme.getColors(context).divider),
                                    textStyle: TextStyle(fontSize: 12),
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'v${AppConstants.appVersion} • macOS',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.getColors(context).textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content Viewport
                    Expanded(
                      child: switch (activeTab) {
                        ShellNavTab.dashboard => const DashboardView(),
                        ShellNavTab.history => const SessionHistoryView(),
                        ShellNavTab.tasks => const TasksView(),
                        ShellNavTab.projects => const ProjectsView(),
                        ShellNavTab.categories => const CategoriesView(),
                        ShellNavTab.tags => const TagsView(),
                        ShellNavTab.people => const PeopleView(),
                        ShellNavTab.attributes =>
                          const AttributeDefinitionsView(),
                      },
                    ),
                  ],
                ),
              ),
              const ActiveTimerBar(),
            ],
          );
        },
      ),
    );
  }
}

class _SidebarNavItem extends ConsumerWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Provider<int?>? countProvider;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.countProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = countProvider != null ? ref.watch(countProvider!) : null;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.getColors(context).textSecondary,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.getColors(context).textSecondary,
                  ),
                ),
              ),
              if (count != null && count > 0)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                        : AppTheme.getColors(context).card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.getColors(context).textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
