import 'package:workpulse/domain/models/idle_period_model.dart';

abstract class IdlePeriodRepository {
  Future<List<IdlePeriod>> getIdlePeriodsForSession(String sessionId);

  /// The idle periods of many sessions at once, grouped by session id.
  ///
  /// Analytics walks every session in a range; asking per session issued one
  /// query per session, which a ninety-day pattern scan feels.
  Future<Map<String, List<IdlePeriod>>> getIdlePeriodsForSessions(
    List<String> sessionIds,
  );
  Future<IdlePeriod?> getIdlePeriodById(String id);
  Future<void> createIdlePeriod(IdlePeriod idlePeriod);
  Future<void> updateIdlePeriod(IdlePeriod idlePeriod);
  Future<void> deleteIdlePeriod(String id);
}
