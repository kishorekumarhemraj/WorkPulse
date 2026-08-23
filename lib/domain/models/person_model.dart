import 'package:equatable/equatable.dart';

class Person extends Equatable {
  final String id;
  final String name;
  final String? email;
  final DateTime createdAt;

  const Person({
    required this.id,
    required this.name,
    this.email,
    required this.createdAt,
  });

  Person copyWith({
    String? id,
    String? name,
    String? email,
    DateTime? createdAt,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, email, createdAt];
}
