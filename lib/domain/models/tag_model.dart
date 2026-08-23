import 'package:equatable/equatable.dart';

class Tag extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final String? colorHex;
  final DateTime createdAt;

  const Tag({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.colorHex,
    required this.createdAt,
  });

  Tag copyWith({
    String? id,
    String? workspaceId,
    String? name,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, workspaceId, name, colorHex, createdAt];
}
