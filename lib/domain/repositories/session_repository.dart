import 'package:workpulse/domain/models/session_model.dart';

abstract class SessionRepository {
  Future<Session?> getById(String id);
  Future<List<Session>> getByWorkItemId(String workItemId);
  Future<List<Session>> getByDateRange(DateTime start, DateTime end);
  Future<Session?> getActiveSession();
  Future<Session> create(Session session);
  Future<Session> update(Session session);
  Future<void> delete(String id);
}
