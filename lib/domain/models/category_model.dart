import 'package:equatable/equatable.dart';

/// Whether work classified under a category is capitalizable or operational.
///
/// This is a finance-facing distinction, not a workflow one: CAPEX time can be
/// capitalised against an asset or project, OPEX time is expensed as it is
/// incurred. It lives on the Category rather than the WorkItem because the
/// *kind* of work is what decides it — "Feature Development" is capitalizable
/// wherever it happens, "Production Support" is not.
enum CategoryType {
  capex('CAPEX', 'CAPEX', 'Capitalizable'),
  opex('OPEX', 'OPEX', 'Operational');

  /// How the value is stored in SQLite.
  final String value;

  /// The short label used in badges, tables and radio buttons.
  final String label;

  /// The longer gloss shown beside the label where there is room for it.
  final String description;

  const CategoryType(this.value, this.label, this.description);

  /// Parses a stored value, falling back to [CategoryType.opex].
  ///
  /// OPEX is the fallback because it is also what the v5 migration backfills
  /// onto categories created before this field existed: an unreadable value
  /// and a historical one should not disagree.
  static CategoryType fromString(String? value) {
    if (value == null) return CategoryType.opex;
    return CategoryType.values.firstWhere(
      (e) => e.value.toUpperCase() == value.toUpperCase(),
      orElse: () => CategoryType.opex,
    );
  }
}

class Category extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final String? description;
  final String? iconName;

  /// Whether time under this category is capitalizable (CAPEX) or
  /// operational (OPEX). Every category has one; see [CategoryType].
  final CategoryType type;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const Category({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.description,
    this.iconName,
    this.type = CategoryType.opex,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  bool get isCapex => type == CategoryType.capex;

  Category copyWith({
    String? id,
    String? workspaceId,
    String? name,
    String? description,
    String? iconName,
    CategoryType? type,
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
      type: type ?? this.type,
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
        type,
        createdAt,
        updatedAt,
        archivedAt
      ];
}
