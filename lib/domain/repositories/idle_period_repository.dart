import 'package:workpulse/domain/models/idle_period_model.dart';

abstract class IdlePeriodRepository {
  Future<List<IdlePeriod>> getIdlePeriodsForSession(String sessionId);
  Future<IdlePeriod?> getIdlePeriodById(String id);
  Future<void> createIdlePeriod(IdlePeriod idlePeriod);
  Future<void> updateIdlePeriod(IdlePeriod idlePeriod);
  Future<void> deleteIdlePeriod(String id);
}
