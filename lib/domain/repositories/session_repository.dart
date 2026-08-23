import 'package:workpulse/domain/models/session_model.dart';

abstract class SessionRepository {
  Future<Session?> getActiveSession();
  Future<Session?> getSessionById(String id);
  Future<List<Session>> getSessionsForTask(String taskId);
  Future<List<Session>> getSessionsInRange(DateTime start, DateTime end);
  Future<List<Session>> getAllSessions();
  Future<void> createSession(Session session);
  Future<void> updateSession(Session session);
  Future<void> endSession(String sessionId, DateTime endTime);
  Future<void> deleteSession(String id);
}
