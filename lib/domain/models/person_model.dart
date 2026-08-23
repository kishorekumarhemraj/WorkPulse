import 'package:equatable/equatable.dart';

class Person extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final String? email;
  final DateTime createdAt;

  const Person({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.email,
    required this.createdAt,
  });

  Person copyWith({
    String? id,
    String? workspaceId,
    String? name,
    String? email,
    DateTime? createdAt,
  }) {
    return Person(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, workspaceId, name, email, createdAt];
}
