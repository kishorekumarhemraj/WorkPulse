import 'package:equatable/equatable.dart';

class Project extends Equatable {
  final String id;
  final String name;
  final String? colorHex;
  final DateTime createdAt;

  const Project({
    required this.id,
    required this.name,
    this.colorHex,
    required this.createdAt,
  });

  Project copyWith({
    String? id,
    String? name,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, colorHex, createdAt];
}
