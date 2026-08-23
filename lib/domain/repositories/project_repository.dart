import 'package:workpulse/domain/models/project_model.dart';

abstract class ProjectRepository {
  Future<List<Project>> getAllProjects({bool includeArchived = false});
  Future<Project?> getProjectById(String id);
  Future<Project?> getProjectByName(String name);
  Future<void> createProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String id);
}
