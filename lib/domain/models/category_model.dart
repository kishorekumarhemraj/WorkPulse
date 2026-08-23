import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String id;
  final String name;
  final String? iconName;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.name,
    this.iconName,
    required this.createdAt,
  });

  Category copyWith({
    String? id,
    String? name,
    String? iconName,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, iconName, createdAt];
}
