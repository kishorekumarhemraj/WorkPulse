import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_item_plan.dart';

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

  /// Writes only the three plan columns and `updated_at`.
  ///
  /// Deliberately not `update(WorkItem)`: that method deletes and re-inserts
  /// the tag and people join tables (see docs, F3), which is right for the form
  /// dialog and wrong for a checkbox in a list row.
  Future<void> updatePlan(String id, WorkItemPlan plan);

  /// Items with a due date inside [from, to], plus (when [includeOverdue])
  /// everything still open and past due. Ordered by due date ascending.
  /// Excludes archived; includes completed only when [includeCompleted].
  Future<List<WorkItem>> getByDueRange({
    required String workspaceId,
    CalendarDate? from,
    CalendarDate? to,
    bool includeOverdue = true,
    bool includeCompleted = false,
  });

  Future<void> updateLastWorkedAt(String id, DateTime timestamp);
  Future<void> archive(String id);
  Future<void> unarchive(String id);
  Future<void> delete(String id);
}
