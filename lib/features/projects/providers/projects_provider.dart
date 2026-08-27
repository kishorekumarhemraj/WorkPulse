import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

import 'package:workpulse/domain/models/project_timesheet_code.dart';

const _uuid = Uuid();

final projectsProvider = AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final workspace = await ref.watch(currentWorkspaceProvider.future);
    final projectRepo = ref.watch(projectRepositoryProvider);
    return projectRepo.getAll(
        workspaceId: workspace.id, includeArchived: false);
  }

  Future<Project> createProject({
    required String name,
    String? description,
    String? colorHex,
    String? timesheetCode,
    String? codeAttributeDefinitionId,
    List<ProjectTimesheetCode> timesheetCodes = const [],
  }) async {
    final workspace = await ref.read(currentWorkspaceProvider.future);
    final projectRepo = ref.read(projectRepositoryProvider);

    final now = DateTime.now().toUtc();
    final projectId = _uuid.v4();
    final newProject = Project(
      id: projectId,
      workspaceId: workspace.id,
      name: name.trim(),
      description:
          description?.trim().isEmpty == true ? null : description?.trim(),
      colorHex: colorHex ?? '#0A84FF',
      timesheetCode:
          timesheetCode?.trim().isEmpty == true ? null : timesheetCode?.trim(),
      codeAttributeDefinitionId: codeAttributeDefinitionId?.trim().isEmpty == true
          ? null
          : codeAttributeDefinitionId?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final created = await projectRepo.create(newProject);
    if (timesheetCodes.isNotEmpty) {
      final formattedCodes = timesheetCodes.map((c) {
        if (c.projectId.isEmpty) {
          return c.copyWith(projectId: projectId);
        }
        return c;
      }).toList();
      await projectRepo.setTimesheetCodes(projectId, formattedCodes);
    }
    ref.invalidateSelf();
    await future;
    return created;
  }

  Future<Project> updateProject(Project project,
      {List<ProjectTimesheetCode>? timesheetCodes}) async {
    final projectRepo = ref.read(projectRepositoryProvider);
    final updated = await projectRepo.update(project);
    if (timesheetCodes != null) {
      await projectRepo.setTimesheetCodes(project.id, timesheetCodes);
    }
    ref.invalidateSelf();
    await future;
    return updated;
  }

  Future<List<ProjectTimesheetCode>> getTimesheetCodes(String projectId) async {
    final projectRepo = ref.read(projectRepositoryProvider);
    return projectRepo.getTimesheetCodes(projectId);
  }

  Future<void> archiveProject(String id) async {
    final projectRepo = ref.read(projectRepositoryProvider);
    await projectRepo.archive(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> unarchiveProject(String id) async {
    final projectRepo = ref.read(projectRepositoryProvider);
    await projectRepo.unarchive(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteProject(String id) async {
    final projectRepo = ref.read(projectRepositoryProvider);
    await projectRepo.delete(id);
    ref.invalidateSelf();
    await future;
  }
}
