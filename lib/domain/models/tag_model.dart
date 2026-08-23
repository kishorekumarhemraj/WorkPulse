import 'package:equatable/equatable.dart';

class Tag extends Equatable {
  final String id;
  final String name;
  final String? colorHex;
  final DateTime createdAt;

  const Tag({
    required this.id,
    required this.name,
    this.colorHex,
    required this.createdAt,
  });

  Tag copyWith({
    String? id,
    String? name,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, colorHex, createdAt];
}
