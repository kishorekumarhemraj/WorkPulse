import 'package:equatable/equatable.dart';

class Session extends Equatable {
  final String id;
  final String workItemId;
  final String? categoryId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<String> tagIds;
  final List<String> peopleIds;
  final String? notes;
  final DateTime createdAt;

  const Session({
    required this.id,
    required this.workItemId,
    this.categoryId,
    required this.startTime,
    this.endTime,
    this.tagIds = const [],
    this.peopleIds = const [],
    this.notes,
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
    String? categoryId,
    bool clearCategory = false,
    DateTime? startTime,
    DateTime? endTime,
    List<String>? tagIds,
    List<String>? peopleIds,
    String? notes,
    bool clearNotes = false,
    DateTime? createdAt,
  }) {
    return Session(
      id: id ?? this.id,
      workItemId: workItemId ?? this.workItemId,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      tagIds: tagIds ?? this.tagIds,
      peopleIds: peopleIds ?? this.peopleIds,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workItemId,
        categoryId,
        startTime,
        endTime,
        tagIds,
        peopleIds,
        notes,
        createdAt
      ];
}
