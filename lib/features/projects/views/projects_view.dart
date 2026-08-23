import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/confirm_dialog.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/entity_grid.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/search_field.dart';
import 'package:workpulse/core/widgets/skeleton_loader.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/projects/views/project_form_dialog.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';

class ProjectsView extends ConsumerStatefulWidget {
  const ProjectsView({super.key});

  @override
  ConsumerState<ProjectsView> createState() => _ProjectsViewState();
}

class _ProjectsViewState extends ConsumerState<ProjectsView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final projectsAsync = ref.watch(projectsProvider);
    final workItemsAsync = ref.watch(workItemsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: PageScaffold(
        title: 'Projects',
        subtitle: 'Manage and organize your client projects and workspaces',
        actions: [
          ElevatedButton.icon(
            onPressed: () => ProjectFormDialog.show(context),
            icon: const Icon(Icons.add, size: IconSizes.lg),
            label: const Text('New Project'),
          ),
        ],
        toolbar: SearchField(
          hintText: 'Search projects…',
          width: 300,
          onChanged: (value) =>
              setState(() => _searchQuery = value.trim().toLowerCase()),
        ),
        child: projectsAsync.when(
          loading: () => const SkeletonGrid(),
          error: (error, _) => ErrorState(
            title: 'Could not load projects',
            error: error,
            onRetry: () => ref.invalidate(projectsProvider),
          ),
          data: (projects) {
            final filtered = projects.where((p) {
              if (_searchQuery.isEmpty) return true;
              return p.name.toLowerCase().contains(_searchQuery) ||
                  (p.description?.toLowerCase().contains(_searchQuery) ??
                      false);
            }).toList();

            if (filtered.isEmpty) {
              return EmptyState(
                icon: Icons.folder_open_outlined,
                title: _searchQuery.isEmpty
                    ? 'No projects yet'
                    : 'No projects match "$_searchQuery"',
                message: _searchQuery.isEmpty
                    ? 'Projects group your work items and give them a colour '
                        'across the app.'
                    : null,
                action: _searchQuery.isEmpty
                    ? ElevatedButton.icon(
                        onPressed: () => ProjectFormDialog.show(context),
                        icon: const Icon(Icons.add, size: IconSizes.md),
                        label: const Text('Create First Project'),
                      )
                    : null,
              );
            }

            return EntityGrid(
              children: [
                for (final project in filtered)
                  EntityCard(
                    name: project.name,
                    description: project.description,
                    color: ColorUtils.parseHex(project.colorHex),
                    count: workItemsAsync.value
                            ?.where((w) => w.projectId == project.id)
                            .length ??
                        0,
                    countLabel: 'work items',
                    onTap: () =>
                        ProjectFormDialog.show(context, project: project),
                    actions: [
                      EntityAction(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        onSelected: () =>
                            ProjectFormDialog.show(context, project: project),
                      ),
                      EntityAction(
                        label: 'Archive',
                        icon: Icons.archive_outlined,
                        onSelected: () => ref
                            .read(projectsProvider.notifier)
                            .archiveProject(project.id),
                      ),
                      EntityAction(
                        label: 'Delete',
                        icon: Icons.delete_outline,
                        isDestructive: true,
                        onSelected: () async {
                          final confirmed = await confirmDestructive(
                            context,
                            title: 'Delete Project',
                            message:
                                'Are you sure you want to delete "${project.name}"? '
                                'This action cannot be undone.',
                          );
                          if (confirmed) {
                            await ref
                                .read(projectsProvider.notifier)
                                .deleteProject(project.id);
                          }
                        },
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
