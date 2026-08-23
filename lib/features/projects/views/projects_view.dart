import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/domain/models/project_model.dart';
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
    final projectsAsync = ref.watch(projectsProvider);
    final workItemsAsync = ref.watch(workItemsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projects',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.getColors(context).textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage and organize your client projects and workspaces',
                        style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textSecondary),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => ProjectFormDialog.show(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Project'),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Search bar
            SizedBox(
              width: 320,
              height: 38,
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search projects...',
                  prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.getColors(context).textSecondary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Project Grid / List
            Expanded(
              child: projectsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Error loading projects: $error', style: TextStyle(color: AppTheme.accentRed)),
                ),
                data: (projects) {
                  final filtered = projects.where((p) {
                    if (_searchQuery.isEmpty) return true;
                    return p.name.toLowerCase().contains(_searchQuery) ||
                        (p.description?.toLowerCase().contains(_searchQuery) ?? false);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_outlined, size: 48, color: AppTheme.getColors(context).textSecondary.withValues(alpha: 0.5)),
                          SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? 'No projects found' : 'No matching projects',
                            style: TextStyle(fontSize: 16, color: AppTheme.getColors(context).textSecondary),
                          ),
                          if (_searchQuery.isEmpty) ...[
                            SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => ProjectFormDialog.show(context),
                              icon: Icon(Icons.add, size: 16),
                              label: Text('Create First Project'),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      mainAxisExtent: 160,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final project = filtered[index];
                      final taskCount = workItemsAsync.value?.where((w) => w.projectId == project.id).length ?? 0;
                      return _ProjectCard(project: project, taskCount: taskCount);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  final Project project;
  final int taskCount;

  const _ProjectCard({required this.project, required this.taskCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ColorUtils.parseHex(project.colorHex);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getColors(context).surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.getColors(context).divider, width: 1),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  project.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.getColors(context).textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: AppTheme.getColors(context).textSecondary),
                color: AppTheme.getColors(context).surface,
                onSelected: (value) async {
                  if (value == 'edit') {
                    await ProjectFormDialog.show(context, project: project);
                  } else if (value == 'archive') {
                    await ref.read(projectsProvider.notifier).archiveProject(project.id);
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.getColors(context).surface,
                        title: Text('Delete Project', style: TextStyle(color: AppTheme.getColors(context).textPrimary)),
                        content: Text('Are you sure you want to delete "${project.name}"? This action cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: Colors.white),
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(projectsProvider.notifier).deleteProject(project.id);
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: AppTheme.getColors(context).textPrimary),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 16, color: AppTheme.getColors(context).textPrimary),
                        SizedBox(width: 8),
                        Text('Archive'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: AppTheme.accentRed),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppTheme.accentRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 6),
          Expanded(
            child: Text(
              project.description ?? 'No description provided.',
              style: TextStyle(
                fontSize: 12,
                color: project.description != null ? AppTheme.getColors(context).textSecondary : AppTheme.getColors(context).textSecondary.withValues(alpha: 0.5),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Divider(color: AppTheme.getColors(context).divider, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.getColors(context).card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$taskCount tasks',
                  style: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary, fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Updated ${_formatDate(project.updatedAt)}',
                  style: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
