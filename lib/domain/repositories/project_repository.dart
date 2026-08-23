import 'package:workpulse/domain/models/project_model.dart';

abstract class ProjectRepository {
  Future<Project?> getById(String id);
  Future<List<Project>> getAll({String? workspaceId, bool includeArchived = false});
  Future<Project> create(Project project);
  Future<Project> update(Project project);
  Future<void> archive(String id);
  Future<void> unarchive(String id);
  Future<void> delete(String id);
}
