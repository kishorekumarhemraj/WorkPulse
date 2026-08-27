import 'package:equatable/equatable.dart';

class Project extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final String? description;
  final String? colorHex;

  /// The code this project is booked against in the organisation's timesheet
  /// system — a cost code, a WBS element, a job number, whatever the finance
  /// team calls it.
  ///
  /// Nullable in the schema, not because it is optional going forward — the
  /// project form requires one — but because projects created before this
  /// field existed have no code to backfill, and inventing one would be
  /// worse than admitting it is missing.
  final String? timesheetCode;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const Project({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.description,
    this.colorHex,
    this.timesheetCode,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  /// Whether this project can be booked to a timesheet as it stands.
  bool get hasTimesheetCode => timesheetCode?.trim().isNotEmpty ?? false;

  Project copyWith({
    String? id,
    String? workspaceId,
    String? name,
    String? description,
    String? colorHex,
    String? timesheetCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    return Project(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      timesheetCode: timesheetCode ?? this.timesheetCode,
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
        colorHex,
        timesheetCode,
        createdAt,
        updatedAt,
        archivedAt
      ];
}
