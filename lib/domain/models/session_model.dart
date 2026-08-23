import 'package:equatable/equatable.dart';

class Session extends Equatable {
  final String id;
  final String workItemId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<String> peopleIds;
  final DateTime createdAt;

  const Session({
    required this.id,
    required this.workItemId,
    required this.startTime,
    this.endTime,
    this.peopleIds = const [],
    required this.createdAt,
  });

  /// Duration calculated from timestamps (or elapsed if currently running)
  Duration get duration {
    final end = endTime ?? DateTime.now().toUtc();
    return end.difference(startTime);
  }

  bool get isActive => endTime == null;

  Session copyWith({
    String? id,
    String? workItemId,
    DateTime? startTime,
    DateTime? endTime,
    List<String>? peopleIds,
    DateTime? createdAt,
  }) {
    return Session(
      id: id ?? this.id,
      workItemId: workItemId ?? this.workItemId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      peopleIds: peopleIds ?? this.peopleIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, workItemId, startTime, endTime, peopleIds, createdAt];
}
