import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/financial_classification.dart';

class Session extends Equatable {
  final String id;
  final String workItemId;
  final String? categoryId;

  /// A session-level override of the parent task's classification.
  ///
  /// Null is the normal case and means "inherit" — resolved against the task
  /// on read, never copied at write, so a task corrected today also corrects
  /// the hours it booked last month. Set it only where one session genuinely
  /// differs from the task around it.
  ///
  /// This is the one place a session deliberately reads through to its
  /// WorkItem (see AGENTS.md rule 7): what an hour was *for* is a property of
  /// the task, unlike the kind of work it took, which is the session's own.
  final FinancialClassification? financialClassification;

  final DateTime startTime;
  final DateTime? endTime;
  final List<String> tagIds;
  final List<String> peopleIds;
  final String? notes;
  final DateTime createdAt;

  const Session({
    required this.id,
    required this.workItemId,
    this.categoryId,
    this.financialClassification,
    required this.startTime,
    this.endTime,
    this.tagIds = const [],
    this.peopleIds = const [],
    this.notes,
    required this.createdAt,
  });

  /// Duration calculated from timestamps (or elapsed if currently running)
  Duration get duration {
    final end = endTime ?? DateTime.now().toUtc();
    return end.difference(startTime);
  }

  bool get isActive => endTime == null;

  /// This session's effective classification, given the task it belongs to.
  ///
  /// The single place inheritance is resolved. Callers must go through it
  /// rather than reading either field directly, or the override and the
  /// fallback drift apart between screens.
  FinancialClassification classificationWithin(
    FinancialClassification taskClassification,
  ) =>
      financialClassification ?? taskClassification;

  /// Whether this session states a classification of its own.
  bool get hasClassificationOverride => financialClassification != null;

  Session copyWith({
    String? id,
    String? workItemId,
    String? categoryId,
    bool clearCategory = false,
    FinancialClassification? financialClassification,
    bool clearFinancialClassification = false,
    DateTime? startTime,
    DateTime? endTime,
    List<String>? tagIds,
    List<String>? peopleIds,
    String? notes,
    bool clearNotes = false,
    DateTime? createdAt,
  }) {
    return Session(
      id: id ?? this.id,
      workItemId: workItemId ?? this.workItemId,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      financialClassification: clearFinancialClassification
          ? null
          : (financialClassification ?? this.financialClassification),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      tagIds: tagIds ?? this.tagIds,
      peopleIds: peopleIds ?? this.peopleIds,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workItemId,
        categoryId,
        financialClassification,
        startTime,
        endTime,
        tagIds,
        peopleIds,
        notes,
        createdAt
      ];
}
