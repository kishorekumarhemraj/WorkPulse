import 'package:pdf/pdf.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/time_note_model.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';

/// The entire data payload required to render the 3-act PDF Report.
///
/// Pure data by design: every number, ratio, and slice is computed once in
/// [ReportBuilderService], allowing arithmetic to be thoroughly unit-tested
/// independently of PDF byte rendering.
class WorkReport {
  final ReportIdentity identity;
  final ReportHeadline headline;
  final ClassificationSplit classification;
  final List<ReportSlice> projects;
  final List<ReportSlice> categories;
  final List<ReportSlice> tags;
  final List<ReportSlice> people;
  final List<ReportCodeRow> codes;
  final List<ReportBreakdown> attributes;
  final List<ReportBucket> rhythm;
  final RhythmAxis rhythmAxis;
  final List<ReportTaskLine> topTasks;
  final int topTasksRemainderCount;
  final TimeNotesReport notes;
  final List<ReportSessionLine> sessions;
  final List<ReportInsight> insights;

  const WorkReport({
    required this.identity,
    required this.headline,
    required this.classification,
    required this.projects,
    required this.categories,
    required this.tags,
    required this.people,
    required this.codes,
    required this.attributes,
    required this.rhythm,
    required this.rhythmAxis,
    required this.topTasks,
    this.topTasksRemainderCount = 0,
    required this.notes,
    required this.sessions,
    this.insights = const [],
  });

  bool get isEmpty => headline.sessionCount == 0;
}

class ReportIdentity {
  final String workspaceName;
  final String? authorName;
  final DateRange range;
  final bool isSingleDay;
  final String dateSubtitle;

  const ReportIdentity({
    required this.workspaceName,
    this.authorName,
    required this.range,
    required this.isSingleDay,
    required this.dateSubtitle,
  });
}

class ReportHeadline {
  final Duration totalGross;
  final Duration totalNet;
  final Duration totalIdle;
  final int taskCount;
  final int projectCount;
  final int categoryCount;
  final int sessionCount;
  final int activeDays;
  final String proseLine;

  const ReportHeadline({
    required this.totalGross,
    required this.totalNet,
    required this.totalIdle,
    required this.taskCount,
    required this.projectCount,
    required this.categoryCount,
    required this.sessionCount,
    required this.activeDays,
    required this.proseLine,
  });

  double get focusEfficiency => totalGross.inSeconds > 0
      ? (totalNet.inSeconds / totalGross.inSeconds) * 100
      : 0.0;

  double get idlePercent => totalGross.inSeconds > 0
      ? (totalIdle.inSeconds / totalGross.inSeconds) * 100
      : 0.0;
}

class ReportSlice {
  final String id;
  final String label;
  final Duration duration;
  final double share; // 0.0 to 1.0
  final String? colorHex;
  final PdfColor color;
  final int sessionCount;
  final bool isUncategorized;

  const ReportSlice({
    required this.id,
    required this.label,
    required this.duration,
    required this.share,
    this.colorHex,
    required this.color,
    required this.sessionCount,
    this.isUncategorized = false,
  });
}

class ReportCodeRow {
  final String code;
  final String? source;
  final Duration duration;
  final double share;
  final List<String> contributingProjects;
  final bool needsAttention;

  const ReportCodeRow({
    required this.code,
    this.source,
    required this.duration,
    required this.share,
    this.contributingProjects = const [],
    this.needsAttention = false,
  });
}

class ReportBreakdown {
  final String definitionId;
  final String definitionName;
  final List<ReportSlice> slices;

  const ReportBreakdown({
    required this.definitionId,
    required this.definitionName,
    required this.slices,
  });
}

enum RhythmAxis {
  hour,
  day,
  week,
}

class ReportBucket {
  final String label;
  final DateTime date;
  final Duration totalDuration;
  final Duration capexDuration;
  final Duration opexDuration;
  final Duration unclassifiedDuration;
  final Duration idleDuration;
  final bool isPeak;

  const ReportBucket({
    required this.label,
    required this.date,
    required this.totalDuration,
    required this.capexDuration,
    required this.opexDuration,
    required this.unclassifiedDuration,
    required this.idleDuration,
    this.isPeak = false,
  });
}

class ReportTaskLine {
  final String taskId;
  final String taskName;
  final String projectName;
  final String? projectColorHex;
  final Set<String> categories;
  final FinancialClassification classification;
  final int sessionCount;
  final Duration totalDuration;
  final double share;

  const ReportTaskLine({
    required this.taskId,
    required this.taskName,
    required this.projectName,
    this.projectColorHex,
    required this.categories,
    required this.classification,
    required this.sessionCount,
    required this.totalDuration,
    required this.share,
  });
}

class ReportSessionLine {
  final Session session;
  final WorkItem workItem;
  final Project? project;
  final Category? category;
  final FinancialClassification classification;
  final String? code;
  final List<Tag> tags;
  final List<Person> people;
  final String attributesSummary;
  final Duration grossDuration;
  final Duration idleDuration;
  final Duration netActiveDuration;
  final bool hasNotes;

  const ReportSessionLine({
    required this.session,
    required this.workItem,
    this.project,
    this.category,
    required this.classification,
    this.code,
    this.tags = const [],
    this.people = const [],
    this.attributesSummary = '',
    required this.grossDuration,
    required this.idleDuration,
    required this.netActiveDuration,
    required this.hasNotes,
  });
}

class ReportInsight {
  final String lane; // sustain | reclaim | plan | delegate
  final String finding;
  final String evidence;
  final int severity;

  const ReportInsight({
    required this.lane,
    required this.finding,
    required this.evidence,
    this.severity = 1,
  });
}
