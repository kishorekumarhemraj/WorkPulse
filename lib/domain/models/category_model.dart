import 'package:equatable/equatable.dart';

/// The *kind* of work — coding, meetings, triage, review.
///
/// Categories carry no financial meaning. That moved to
/// [FinancialClassification] on the WorkItem, because whether an hour is
/// capitalizable depends on what the work is for, not on what shape it takes;
/// the same meeting can be either. What a category is still for is the
/// "coding versus meetings" breakdown *within* a classification, which is the
/// question it was always good at answering.
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
  List<Object?> get props => [
        id,
        workspaceId,
        name,
        description,
        iconName,
        createdAt,
        updatedAt,
        archivedAt
      ];
}
