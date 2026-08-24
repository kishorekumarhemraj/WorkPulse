import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';

const _uuid = Uuid();

final currentWorkspaceProvider =
    AsyncNotifierProvider<CurrentWorkspaceNotifier, Workspace>(
  CurrentWorkspaceNotifier.new,
);

class CurrentWorkspaceNotifier extends AsyncNotifier<Workspace> {
  @override
  Future<Workspace> build() async {
    final workspaceRepo = ref.watch(workspaceRepositoryProvider);
    final workspaces = await workspaceRepo.getAll();

    if (workspaces.isNotEmpty) {
      final workspace = workspaces.first;
      final projectRepo = ref.read(projectRepositoryProvider);
      final projects = await projectRepo.getAll(workspaceId: workspace.id);
      if (projects.isEmpty) {
        await _seedDefaults(workspace.id);
      }
      return workspace;
    }

    // Bootstrap default workspace
    final now = DateTime.now().toUtc();
    final defaultWorkspace = Workspace(
      id: _uuid.v4(),
      name: 'Default',
      createdAt: now,
      updatedAt: now,
    );

    final createdWorkspace = await workspaceRepo.create(defaultWorkspace);

    // Bootstrap initial default project and categories
    await _seedDefaults(createdWorkspace.id);

    return createdWorkspace;
  }

  Future<void> _seedDefaults(String workspaceId) async {
    final now = DateTime.now().toUtc();
    final projectRepo = ref.read(projectRepositoryProvider);
    final categoryRepo = ref.read(categoryRepositoryProvider);

    // Seed default project
    await projectRepo.create(
      Project(
        id: _uuid.v4(),
        workspaceId: workspaceId,
        name: 'General',
        description: 'Default project for general work items',
        colorHex: '#0A84FF',
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Seed standard starter categories
    final defaultCategories = [
      (
        'Engineering',
        'Development, coding, bug fixes, and code reviews',
        'code'
      ),
      (
        'Architecture',
        'System design, technical specs, and RFCs',
        'architecture'
      ),
      ('Meetings', 'Syncs, 1:1s, sprint ceremonies, and discussions', 'chat'),
      (
        'Deep Work',
        'Focused, uninterrupted problem solving and research',
        'brain'
      ),
      (
        'Operations',
        'Deployments, monitoring, admin tasks, and triage',
        'gear'
      ),
    ];

    for (final (name, desc, icon) in defaultCategories) {
      await categoryRepo.create(
        Category(
          id: _uuid.v4(),
          workspaceId: workspaceId,
          name: name,
          description: desc,
          iconName: icon,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<void> switchWorkspace(Workspace workspace) async {
    state = AsyncData(workspace);
  }
}
