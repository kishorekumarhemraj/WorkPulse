import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final String? description;
  final String? iconName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const Category({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.description,
    this.iconName,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  Category copyWith({
    String? id,
    String? workspaceId,
    String? name,
    String? description,
    String? iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    return Category(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  List<Object?> get props => [id, workspaceId, name, description, iconName, createdAt, updatedAt, archivedAt];
}
