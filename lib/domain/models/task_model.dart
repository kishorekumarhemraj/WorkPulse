import 'package:equatable/equatable.dart';

class Task extends Equatable {
  final String id;
  final String name;
  final String projectId;
  final String categoryId;
  final List<String> tagIds;
  final List<String> peopleIds;
  final String? jiraId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastWorkedAt;

  const Task({
    required this.id,
    required this.name,
    required this.projectId,
    required this.categoryId,
    this.tagIds = const [],
    this.peopleIds = const [],
    this.jiraId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.lastWorkedAt,
  });

  Task copyWith({
    String? id,
    String? name,
    String? projectId,
    String? categoryId,
    List<String>? tagIds,
    List<String>? peopleIds,
    String? jiraId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastWorkedAt,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      projectId: projectId ?? this.projectId,
      categoryId: categoryId ?? this.categoryId,
      tagIds: tagIds ?? this.tagIds,
      peopleIds: peopleIds ?? this.peopleIds,
      jiraId: jiraId ?? this.jiraId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastWorkedAt: lastWorkedAt ?? this.lastWorkedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        projectId,
        categoryId,
        tagIds,
        peopleIds,
        jiraId,
        notes,
        createdAt,
        updatedAt,
        lastWorkedAt,
      ];
}
