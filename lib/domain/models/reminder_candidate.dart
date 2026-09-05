import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/reminder_rule.dart';

/// A notification candidate computed by [ReminderService] for delivery.
class ReminderCandidate extends Equatable {
  final String workItemId;
  final String workItemName;
  final ReminderRule rule;
  final String occurrenceKey;
  final DateTime scheduledFor;
  final String title;
  final String body;

  const ReminderCandidate({
    required this.workItemId,
    required this.workItemName,
    required this.rule,
    required this.occurrenceKey,
    required this.scheduledFor,
    required this.title,
    required this.body,
  });

  @override
  List<Object?> get props => [
        workItemId,
        workItemName,
        rule,
        occurrenceKey,
        scheduledFor,
        title,
        body,
      ];
}
