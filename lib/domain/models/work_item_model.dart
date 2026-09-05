import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/work_item_plan.dart';

class WorkItem extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final String projectId;
  final String categoryId;

  /// Whether time on this task is capitalizable, operational, or unclassified.
  ///
  /// Sessions inherit this at read time rather than copying it, so correcting
  /// a misclassified task corrects its whole history in one edit. A session
  /// that needs to differ overrides it explicitly — see
  /// [Session.financialClassification].
  final FinancialClassification financialClassification;

  /// What the user intends for this item, as opposed to what has happened to
  /// it. Never inherited by sessions: a session records what happened, and a
  /// plan is a statement about what has not happened yet (AGENTS.md rule 7).
  final WorkItemPlan plan;

  final String? notes;
  final List<String> tagIds;
  final List<String> peopleIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastWorkedAt;
  final DateTime? archivedAt;

  const WorkItem({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.projectId,
    required this.categoryId,
    this.financialClassification = FinancialClassification.none,
    this.plan = const WorkItemPlan.unplanned(),
    this.notes,
    this.tagIds = const [],
    this.peopleIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.lastWorkedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  WorkItem copyWith({
    String? id,
    String? workspaceId,
    String? name,
    String? projectId,
    String? categoryId,
    FinancialClassification? financialClassification,
    WorkItemPlan? plan,
    String? notes,
    List<String>? tagIds,
    List<String>? peopleIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastWorkedAt,
    DateTime? archivedAt,
  }) {
    return WorkItem(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      projectId: projectId ?? this.projectId,
      categoryId: categoryId ?? this.categoryId,
      financialClassification:
          financialClassification ?? this.financialClassification,
      plan: plan ?? this.plan,
      notes: notes ?? this.notes,
      tagIds: tagIds ?? this.tagIds,
      peopleIds: peopleIds ?? this.peopleIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastWorkedAt: lastWorkedAt ?? this.lastWorkedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        name,
        projectId,
        categoryId,
        financialClassification,
        plan,
        notes,
        tagIds,
        peopleIds,
        createdAt,
        updatedAt,
        lastWorkedAt,
        archivedAt,
      ];
}
