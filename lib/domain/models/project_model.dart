import 'package:equatable/equatable.dart';

class Project extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? colorHex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const Project({
    required this.id,
    required this.name,
    this.description,
    this.colorHex,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? colorHex,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, description, colorHex, createdAt, updatedAt, archivedAt];
}
