import 'package:equatable/equatable.dart';

/// A timesheet code mapping for a specific (project, attribute_option) pair.
///
/// Owned by the project: allows a project with multiple releases or streams
/// (captured via a custom attribute) to map each option to its own code.
class ProjectTimesheetCode extends Equatable {
  final String id;
  final String projectId;
  final String attributeOptionId;
  final String code;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectTimesheetCode({
    required this.id,
    required this.projectId,
    required this.attributeOptionId,
    required this.code,
    required this.createdAt,
    required this.updatedAt,
  });

  ProjectTimesheetCode copyWith({
    String? id,
    String? projectId,
    String? attributeOptionId,
    String? code,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectTimesheetCode(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      attributeOptionId: attributeOptionId ?? this.attributeOptionId,
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        projectId,
        attributeOptionId,
        code,
        createdAt,
        updatedAt,
      ];
}
