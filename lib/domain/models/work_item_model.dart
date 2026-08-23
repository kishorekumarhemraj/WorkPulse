import 'package:equatable/equatable.dart';

class WorkItem extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final String projectId;
  final String categoryId;
  final String? notes;
  final List<String> tagIds;
  final List<String> peopleIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastWorkedAt;
  final DateTime? archivedAt;

  const WorkItem({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.projectId,
    required this.categoryId,
    this.notes,
    this.tagIds = const [],
    this.peopleIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.lastWorkedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  WorkItem copyWith({
    String? id,
    String? workspaceId,
    String? name,
    String? projectId,
    String? categoryId,
    String? notes,
    List<String>? tagIds,
    List<String>? peopleIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastWorkedAt,
    DateTime? archivedAt,
  }) {
    return WorkItem(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      projectId: projectId ?? this.projectId,
      categoryId: categoryId ?? this.categoryId,
      notes: notes ?? this.notes,
      tagIds: tagIds ?? this.tagIds,
      peopleIds: peopleIds ?? this.peopleIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastWorkedAt: lastWorkedAt ?? this.lastWorkedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        name,
        projectId,
        categoryId,
        notes,
        tagIds,
        peopleIds,
        createdAt,
        updatedAt,
        lastWorkedAt,
        archivedAt,
      ];
}
