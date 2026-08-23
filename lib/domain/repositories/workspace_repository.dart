import 'package:workpulse/domain/models/workspace_model.dart';

abstract class WorkspaceRepository {
  Future<Workspace?> getById(String id);
  Future<List<Workspace>> getAll();
  Future<Workspace> create(Workspace workspace);
  Future<Workspace> update(Workspace workspace);
  Future<void> delete(String id);
}
