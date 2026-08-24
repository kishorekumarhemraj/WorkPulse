import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';

/// Represents a discrete note entry pinned to a time-tracking session.
class TimeNoteEntry extends Equatable {
  final Session session;
  final WorkItem workItem;
  final Project? project;
  final Category? category;
  final List<Person> people;
  final List<Tag> tags;
  final String note;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration duration;

  const TimeNoteEntry({
    required this.session,
    required this.workItem,
    this.project,
    this.category,
    this.people = const [],
    this.tags = const [],
    required this.note,
    required this.startTime,
    this.endTime,
    required this.duration,
  });

  @override
  List<Object?> get props => [
        session,
        workItem,
        project,
        category,
        people,
        tags,
        note,
        startTime,
        endTime,
        duration,
      ];
}
