import 'package:workpulse/domain/models/session_model.dart';

abstract class SessionRepository {
  Future<Session?> getById(String id);
  Future<List<Session>> getByWorkItemId(String workItemId);

  /// The most recently started session for a work item, or null when it has
  /// none.
  ///
  /// Exists so "what was I last doing on this task?" costs one indexed row
  /// rather than hydrating the task's whole history. Ordered by start_time,
  /// not created_at: a session backdated in the editor is genuinely the later
  /// one, and the classification should follow the clock the user sees.
  Future<Session?> getLatestByWorkItemId(String workItemId);

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
