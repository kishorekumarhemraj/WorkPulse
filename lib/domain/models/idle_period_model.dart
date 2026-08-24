import 'package:equatable/equatable.dart';

enum IdleResolution {
  keepTracking('keep_tracking'),
  markIdle('mark_idle'),
  stopSession('stop_session');

  final String value;
  const IdleResolution(this.value);

  static IdleResolution fromString(String value) {
    return IdleResolution.values.firstWhere(
      (e) => e.value == value,
      orElse: () => IdleResolution.keepTracking,
    );
  }
}

class IdlePeriod extends Equatable {
  final String id;
  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final IdleResolution resolution;
  final DateTime createdAt;

  const IdlePeriod({
    required this.id,
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.resolution,
    required this.createdAt,
  });

  Duration get duration => endTime.difference(startTime);

  IdlePeriod copyWith({
    String? id,
    String? sessionId,
    DateTime? startTime,
    DateTime? endTime,
    IdleResolution? resolution,
    DateTime? createdAt,
  }) {
    return IdlePeriod(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      resolution: resolution ?? this.resolution,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, sessionId, startTime, endTime, resolution, createdAt];
}
