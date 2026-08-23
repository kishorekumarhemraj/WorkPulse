import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

const _uuid = Uuid();

final projectsProvider = AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final workspace = await ref.watch(currentWorkspaceProvider.future);
    final projectRepo = ref.watch(projectRepositoryProvider);
    return projectRepo.getAll(workspaceId: workspace.id, includeArchived: false);
  }

  Future<Project> createProject({
    required String name,
    String? description,
    String? colorHex,
  }) async {
    final workspace = await ref.read(currentWorkspaceProvider.future);
    final projectRepo = ref.read(projectRepositoryProvider);

    final now = DateTime.now().toUtc();
    final newProject = Project(
      id: _uuid.v4(),
      workspaceId: workspace.id,
      name: name.trim(),
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      colorHex: colorHex ?? '#0A84FF',
      createdAt: now,
      updatedAt: now,
    );

    final created = await projectRepo.create(newProject);
    ref.invalidateSelf();
    await future;
    return created;
  }

  Future<Project> updateProject(Project project) async {
    final projectRepo = ref.read(projectRepositoryProvider);
    final updated = await projectRepo.update(project);
    ref.invalidateSelf();
    await future;
    return updated;
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
