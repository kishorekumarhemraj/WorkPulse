import 'package:equatable/equatable.dart';

class Session extends Equatable {
  final String id;
  final String taskId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<String> peopleIds;
  final DateTime createdAt;

  const Session({
    required this.id,
    required this.taskId,
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
    String? taskId,
    DateTime? startTime,
    DateTime? endTime,
    List<String>? peopleIds,
    DateTime? createdAt,
  }) {
    return Session(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      peopleIds: peopleIds ?? this.peopleIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, taskId, startTime, endTime, peopleIds, createdAt];
}
