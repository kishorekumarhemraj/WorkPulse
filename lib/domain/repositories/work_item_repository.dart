import 'package:workpulse/domain/models/work_item_model.dart';

abstract class WorkItemRepository {
  Future<WorkItem?> getById(String id);
  Future<List<WorkItem>> getAll(
      {String? workspaceId, bool includeArchived = false});
  Future<List<WorkItem>> getByProjectId(String projectId,
      {bool includeArchived = false});
  Future<List<WorkItem>> getByCategoryId(String categoryId,
      {bool includeArchived = false});
  Future<List<WorkItem>> search(String query,
      {String? workspaceId, int limit = 20});
  Future<List<WorkItem>> getRecent({String? workspaceId, int limit = 10});
  Future<WorkItem> create(WorkItem workItem);
  Future<WorkItem> update(WorkItem workItem);
  Future<void> updateLastWorkedAt(String id, DateTime timestamp);
  Future<void> archive(String id);
  Future<void> unarchive(String id);
  Future<void> delete(String id);
}
