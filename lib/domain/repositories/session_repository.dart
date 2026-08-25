import 'package:workpulse/domain/models/session_model.dart';

abstract class SessionRepository {
  Future<Session?> getById(String id);
  Future<List<Session>> getByWorkItemId(String workItemId);

  /// How many sessions a work item already has.
  ///
  /// Exists so the "is this the first session?" question on the Quick Capture
  /// hot path costs one indexed COUNT rather than hydrating every session the
  /// work item has ever had.
  Future<int> countByWorkItemId(String workItemId);
  Future<List<Session>> getByDateRange(DateTime start, DateTime end);
  Future<Session?> getActiveSession();
  Future<Session> create(Session session);
  Future<Session> update(Session session);
  Future<void> delete(String id);
}
