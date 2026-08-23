import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/categories/views/categories_view.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/people/views/people_view.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/projects/views/projects_view.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tags/views/tags_view.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/tasks/views/tasks_view.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

enum ShellNavTab {
  tasks,
  projects,
  categories,
  tags,
  people,
}

final activeNavTabProvider = NotifierProvider<ActiveNavTabNotifier, ShellNavTab>(
  ActiveNavTabNotifier.new,
);

class ActiveNavTabNotifier extends Notifier<ShellNavTab> {
  @override
  ShellNavTab build() => ShellNavTab.tasks;

  void setTab(ShellNavTab tab) => state = tab;
}

class MainShellView extends ConsumerWidget {
  const MainShellView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeNavTabProvider);
    final workspaceAsync = ref.watch(currentWorkspaceProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: workspaceAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing WorkPulse...', style: TextStyle(color: AppTheme.textSecondaryDark)),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Text('Initialization error: $error', style: const TextStyle(color: AppTheme.accentRed)),
        ),
        data: (workspace) {
          return Row(
            children: [
              // Sidebar
              Container(
                width: 220,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceDark,
                  border: Border(
                    right: BorderSide(color: AppTheme.dividerDark, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App Brand Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.timer_outlined, color: AppTheme.primaryColor, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  AppConstants.appName,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryDark,
                                    letterSpacing: -0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Workspace Indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.dividerDark),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.workspaces_outlined, size: 12, color: AppTheme.textSecondaryDark),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    workspace.name,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AppTheme.dividerDark, height: 1),
                    const SizedBox(height: 8),

                    // Navigation Items
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          _SidebarNavItem(
                            icon: Icons.check_circle_outline,
                            label: 'Work Items',
                            isSelected: activeTab == ShellNavTab.tasks,
                            countProvider: Provider((r) => r.watch(workItemsProvider).value?.length),
                            onTap: () => ref.read(activeNavTabProvider.notifier).setTab(ShellNavTab.tasks),
                          ),
                          _SidebarNavItem(
                            icon: Icons.folder_outlined,
                            label: 'Projects',
                            isSelected: activeTab == ShellNavTab.projects,
                            countProvider: Provider((r) => r.watch(projectsProvider).value?.length),
                            onTap: () => ref.read(activeNavTabProvider.notifier).setTab(ShellNavTab.projects),
                          ),
                          _SidebarNavItem(
                            icon: Icons.category_outlined,
                            label: 'Categories',
                            isSelected: activeTab == ShellNavTab.categories,
                            countProvider: Provider((r) => r.watch(categoriesProvider).value?.length),
                            onTap: () => ref.read(activeNavTabProvider.notifier).setTab(ShellNavTab.categories),
                          ),
                          _SidebarNavItem(
                            icon: Icons.label_outline,
                            label: 'Tags',
                            isSelected: activeTab == ShellNavTab.tags,
                            countProvider: Provider((r) => r.watch(tagsProvider).value?.length),
                            onTap: () => ref.read(activeNavTabProvider.notifier).setTab(ShellNavTab.tags),
                          ),
                          _SidebarNavItem(
                            icon: Icons.people_outline,
                            label: 'People',
                            isSelected: activeTab == ShellNavTab.people,
                            countProvider: Provider((r) => r.watch(peopleProvider).value?.length),
                            onTap: () => ref.read(activeNavTabProvider.notifier).setTab(ShellNavTab.people),
                          ),
                        ],
                      ),
                    ),

                    // Footer Version
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'v${AppConstants.appVersion} • macOS',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark),
                      ),
                    ),
                  ],
                ),
              ),

              // Content Viewport
              Expanded(
                child: switch (activeTab) {
                  ShellNavTab.tasks => const TasksView(),
                  ShellNavTab.projects => const ProjectsView(),
                  ShellNavTab.categories => const CategoriesView(),
                  ShellNavTab.tags => const TagsView(),
                  ShellNavTab.people => const PeopleView(),
                },
              ),
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
  final Provider<int?> countProvider;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.countProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(countProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : AppTheme.textSecondaryDark,
                  ),
                ),
              ),
              if (count != null && count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.2) : AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryDark,
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
