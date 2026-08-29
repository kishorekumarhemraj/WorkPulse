import 'dart:math';
import 'package:intl/intl.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/timesheet_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_pattern_model.dart';
import 'package:workpulse/domain/models/work_report_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/pdf/pdf_theme.dart';
import 'package:workpulse/domain/services/time_notes_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';
import 'package:workpulse/domain/services/timesheet_grid_math.dart';

/// Pure service responsible for computing the complete [WorkReport] data model.
///
/// Contains zero PDF or Flutter dependencies. Pure: records in, model out.
/// All sums, shares, classification buckets, rhythm bucketing, and top-task
/// rankings are calculated deterministically and verifiable via unit tests.
class ReportBuilderService {
  final TimeNotesService _notesService;

  const ReportBuilderService({TimeNotesService? notesService})
      : _notesService = notesService ?? const TimeNotesService();

  WorkReport build({
    required String workspaceName,
    required String? authorName,
    required DateRange range,
    required List<SessionExportRecord> records,
    List<AttributeDefinition> definitions = const [],
    TimesheetCodeResolver codes = const TimesheetCodeResolver(),
    WorkPatternReport? patterns,
  }) {
    final localStart = range.start.toLocal();
    final localEnd = range.end.toLocal();
    final isSingleDay = localStart.year == localEnd.year &&
        localStart.month == localEnd.month &&
        localStart.day == localEnd.day;

    final dateSubtitle = isSingleDay
        ? DateFormat('EEEE, MMMM d, yyyy').format(localStart)
        : '${DateFormat('MMM d, yyyy').format(localStart)} – ${DateFormat('MMM d, yyyy').format(localEnd)}';

    final identity = ReportIdentity(
      workspaceName: workspaceName,
      authorName: authorName,
      range: range,
      isSingleDay: isSingleDay,
      dateSubtitle: dateSubtitle,
    );

    if (records.isEmpty) {
      return WorkReport(
        identity: identity,
        headline: const ReportHeadline(
          totalGross: Duration.zero,
          totalNet: Duration.zero,
          totalIdle: Duration.zero,
          taskCount: 0,
          projectCount: 0,
          categoryCount: 0,
          sessionCount: 0,
          activeDays: 0,
          proseLine: 'No activity logged for this period.',
        ),
        classification: ClassificationSplit.zero,
        projects: const [],
        categories: const [],
        tags: const [],
        people: const [],
        codes: const [],
        attributes: const [],
        rhythm: const [],
        rhythmAxis: isSingleDay ? RhythmAxis.hour : RhythmAxis.day,
        topTasks: const [],
        topTasksRemainderCount: 0,
        notes: _notesService.buildReport(
          records: const [],
          codes: codes,
          range: range,
          isSingleDay: isSingleDay,
        ),
        sessions: const [],
        insights: const [],
      );
    }

    // 1. Totals & Classification Split
    var totalGross = Duration.zero;
    var totalIdle = Duration.zero;
    var totalNet = Duration.zero;

    var capex = Duration.zero;
    var opex = Duration.zero;
    var unclass = Duration.zero;

    final uniqueTasks = <String, WorkItem>{};
    final uniqueProjects = <String, Project?>{};
    final uniqueCategories = <String>{};
    final activeDaysSet = <DateTime>{};

    for (final r in records) {
      totalGross += r.grossDuration;
      totalIdle += r.idleDuration;
      totalNet += r.netActiveDuration;

      // Classification is sourced strictly from r.classification (AGENTS.md)
      switch (r.classification) {
        case FinancialClassification.capex:
          capex += r.netActiveDuration;
          break;
        case FinancialClassification.opex:
          opex += r.netActiveDuration;
          break;
        case FinancialClassification.none:
          unclass += r.netActiveDuration;
          break;
      }

      uniqueTasks[r.workItem.id] = r.workItem;
      if (r.project != null) {
        uniqueProjects[r.project!.id] = r.project;
      }
      if (r.category != null) {
        uniqueCategories.add(r.category!.id);
      }

      final sessionLocal = r.session.startTime.toLocal();
      activeDaysSet.add(
          DateTime(sessionLocal.year, sessionLocal.month, sessionLocal.day));
    }

    final classSplit = ClassificationSplit(
      capex: capex,
      opex: opex,
      none: unclass,
    );

    // 2. Project Breakdown
    final projectDurations = <String, Duration>{};
    final projectCounts = <String, int>{};
    final projectMap = <String, Project?>{};

    for (final r in records) {
      final pid = r.project?.id ?? 'no-project';
      projectDurations[pid] =
          (projectDurations[pid] ?? Duration.zero) + r.netActiveDuration;
      projectCounts[pid] = (projectCounts[pid] ?? 0) + 1;
      projectMap[pid] = r.project;
    }

    final projectSlices = projectDurations.entries.map((e) {
      final p = projectMap[e.key];
      final name = p?.name ?? 'No Project';
      final share = totalNet.inSeconds > 0
          ? (e.value.inSeconds / totalNet.inSeconds)
          : 0.0;
      final color = PdfThemeColors.entityColor(p?.colorHex, e.key);

      return ReportSlice(
        id: e.key,
        label: name,
        duration: e.value,
        share: share,
        colorHex: p?.colorHex,
        color: color,
        sessionCount: projectCounts[e.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));

    // 3. Category Breakdown (Uncategorized sorts last)
    final catDurations = <String, Duration>{};
    final catCounts = <String, int>{};
    final catNames = <String, String>{};

    for (final r in records) {
      final cid = r.category?.id ?? 'uncategorized';
      catDurations[cid] =
          (catDurations[cid] ?? Duration.zero) + r.netActiveDuration;
      catCounts[cid] = (catCounts[cid] ?? 0) + 1;
      catNames[cid] = r.category?.name ?? 'Uncategorized';
    }

    final catSlices = catDurations.entries.map((e) {
      final isUncat = e.key == 'uncategorized';
      final name = catNames[e.key] ?? 'Uncategorized';
      final share = totalNet.inSeconds > 0
          ? (e.value.inSeconds / totalNet.inSeconds)
          : 0.0;
      final color = isUncat
          ? PdfThemeColors.slate400
          : PdfThemeColors.entityColor(null, e.key);

      return ReportSlice(
        id: e.key,
        label: name,
        duration: e.value,
        share: share,
        color: color,
        sessionCount: catCounts[e.key] ?? 0,
        isUncategorized: isUncat,
      );
    }).toList()
      ..sort((a, b) {
        if (a.isUncategorized) return 1;
        if (b.isUncategorized) return -1;
        return b.duration.compareTo(a.duration);
      });

    // 4. Tags & People Breakdown
    final tagDurations = <String, Duration>{};
    final tagCounts = <String, int>{};
    final tagObjects = <String, Tag>{};

    final personDurations = <String, Duration>{};
    final personCounts = <String, int>{};
    final personObjects = <String, Person>{};

    for (final r in records) {
      for (final t in r.tags) {
        tagDurations[t.id] =
            (tagDurations[t.id] ?? Duration.zero) + r.netActiveDuration;
        tagCounts[t.id] = (tagCounts[t.id] ?? 0) + 1;
        tagObjects[t.id] = t;
      }
      for (final p in r.people) {
        personDurations[p.id] =
            (personDurations[p.id] ?? Duration.zero) + r.netActiveDuration;
        personCounts[p.id] = (personCounts[p.id] ?? 0) + 1;
        personObjects[p.id] = p;
      }
    }

    final tagSlices = tagDurations.entries.map((e) {
      final t = tagObjects[e.key];
      final share = totalNet.inSeconds > 0
          ? (e.value.inSeconds / totalNet.inSeconds)
          : 0.0;
      return ReportSlice(
        id: e.key,
        label: t?.name ?? 'Tag',
        duration: e.value,
        share: share,
        colorHex: t?.colorHex,
        color: PdfThemeColors.entityColor(t?.colorHex, e.key),
        sessionCount: tagCounts[e.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));

    final peopleSlices = personDurations.entries.map((e) {
      final p = personObjects[e.key];
      final share = totalNet.inSeconds > 0
          ? (e.value.inSeconds / totalNet.inSeconds)
          : 0.0;
      return ReportSlice(
        id: e.key,
        label: p?.name ?? 'Person',
        duration: e.value,
        share: share,
        color: PdfThemeColors.entityColor(null, e.key),
        sessionCount: personCounts[e.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));

    // 5. Timesheet Codes Breakdown
    final codeRows = <ReportCodeRow>[];
    if (codes.codesByProject.isNotEmpty) {
      final codeDurations = <String, Duration>{};
      final codeSources = <String, String?>{};
      final codeProjects = <String, Set<String>>{};
      final codeAttention = <String, bool>{};

      for (final r in records) {
        final resolution = codes.resolveFor(
          project: r.project,
          attributeOptionIds: r.attributeOptionIds,
        );
        final displayCode =
            (resolution.code != null && resolution.code!.isNotEmpty)
                ? resolution.code!
                : 'No code';

        codeDurations[displayCode] =
            (codeDurations[displayCode] ?? Duration.zero) + r.netActiveDuration;
        codeSources[displayCode] = resolution.source.name;
        codeAttention[displayCode] =
            (codeAttention[displayCode] ?? false) || resolution.needsAttention;

        if (r.project != null) {
          codeProjects
              .putIfAbsent(displayCode, () => <String>{})
              .add(r.project!.name);
        }
      }

      for (final e in codeDurations.entries) {
        final share = totalNet.inSeconds > 0
            ? (e.value.inSeconds / totalNet.inSeconds)
            : 0.0;
        codeRows.add(
          ReportCodeRow(
            code: e.key,
            source: codeSources[e.key],
            duration: e.value,
            share: share,
            contributingProjects: (codeProjects[e.key] ?? {}).toList()..sort(),
            needsAttention: codeAttention[e.key] ?? false,
          ),
        );
      }

      codeRows.sort((a, b) {
        if (a.code == 'No code') return 1;
        if (b.code == 'No code') return -1;
        return b.duration.compareTo(a.duration);
      });
    }

    // 6. Configurable Attributes Breakdowns
    final attributeBreakdowns = <ReportBreakdown>[];
    for (final def in definitions) {
      if (def.isArchived || !def.enabled || !def.reportable) continue;

      final valDurations = <String, Duration>{};
      final valCounts = <String, int>{};

      for (final r in records) {
        final val = r.attributeValues[def.id]?.trim();
        final displayVal = (val != null && val.isNotEmpty) ? val : 'Unset';
        valDurations[displayVal] =
            (valDurations[displayVal] ?? Duration.zero) + r.netActiveDuration;
        valCounts[displayVal] = (valCounts[displayVal] ?? 0) + 1;
      }

      if (valDurations.isNotEmpty) {
        final slices = valDurations.entries.map((e) {
          final isUnset = e.key == 'Unset';
          final share = totalNet.inSeconds > 0
              ? (e.value.inSeconds / totalNet.inSeconds)
              : 0.0;
          return ReportSlice(
            id: e.key,
            label: e.key,
            duration: e.value,
            share: share,
            color: isUnset
                ? PdfThemeColors.slate400
                : PdfThemeColors.entityColor(null, e.key),
            sessionCount: valCounts[e.key] ?? 0,
            isUncategorized: isUnset,
          );
        }).toList()
          ..sort((a, b) {
            if (a.isUncategorized) return 1;
            if (b.isUncategorized) return -1;
            return b.duration.compareTo(a.duration);
          });

        attributeBreakdowns.add(
          ReportBreakdown(
            definitionId: def.id,
            definitionName: def.name,
            slices: slices,
          ),
        );
      }
    }

    // 7. Daily Rhythm Bucketing
    final rhythmBuckets = <ReportBucket>[];
    RhythmAxis rhythmAxis;

    final rangeDays = localEnd.difference(localStart).inDays + 1;

    if (isSingleDay) {
      rhythmAxis = RhythmAxis.hour;
      final dayStart =
          DateTime(localStart.year, localStart.month, localStart.day);

      for (var h = 6; h <= 22; h++) {
        final hourStart = dayStart.add(Duration(hours: h));
        final hourEnd = hourStart.add(const Duration(hours: 1));

        var hNet = Duration.zero;
        var hCapex = Duration.zero;
        var hOpex = Duration.zero;
        var hUnclass = Duration.zero;
        var hIdle = Duration.zero;

        for (final r in records) {
          final sStart = r.session.startTime.toLocal();
          final sEnd =
              (r.session.endTime ?? sStart.add(r.grossDuration)).toLocal();

          final overlap = _intervalOverlap(sStart, sEnd, hourStart, hourEnd);
          if (overlap > Duration.zero) {
            // Proportional attribution of active vs idle
            final ratio = r.grossDuration.inSeconds > 0
                ? overlap.inSeconds / r.grossDuration.inSeconds
                : 1.0;
            final netPart = Duration(
                seconds: (r.netActiveDuration.inSeconds * ratio).round());
            final idlePart =
                Duration(seconds: (r.idleDuration.inSeconds * ratio).round());

            hNet += netPart;
            hIdle += idlePart;

            switch (r.classification) {
              case FinancialClassification.capex:
                hCapex += netPart;
                break;
              case FinancialClassification.opex:
                hOpex += netPart;
                break;
              case FinancialClassification.none:
                hUnclass += netPart;
                break;
            }
          }
        }

        rhythmBuckets.add(
          ReportBucket(
            label: '${h.toString().padLeft(2, '0')}:00',
            date: hourStart,
            totalDuration: hNet,
            capexDuration: hCapex,
            opexDuration: hOpex,
            unclassifiedDuration: hUnclass,
            idleDuration: hIdle,
          ),
        );
      }
    } else if (rangeDays <= 62) {
      rhythmAxis = RhythmAxis.day;
      var curDay = DateTime(localStart.year, localStart.month, localStart.day);
      final lastDay = DateTime(localEnd.year, localEnd.month, localEnd.day);

      while (!curDay.isAfter(lastDay)) {
        var dayNet = Duration.zero;
        var dayCapex = Duration.zero;
        var dayOpex = Duration.zero;
        var dayUnclass = Duration.zero;
        var dayIdle = Duration.zero;

        for (final r in records) {
          final sStart = r.session.startTime.toLocal();
          final sEnd =
              (r.session.endTime ?? sStart.add(r.grossDuration)).toLocal();

          // Uses overlapOnDay from timesheet_grid_math.dart (AGENTS.md / Prompt)
          final overlap = overlapOnDay(sStart, sEnd, curDay);
          if (overlap > Duration.zero) {
            final ratio = r.grossDuration.inSeconds > 0
                ? overlap.inSeconds / r.grossDuration.inSeconds
                : 1.0;
            final netPart = Duration(
                seconds: (r.netActiveDuration.inSeconds * ratio).round());
            final idlePart =
                Duration(seconds: (r.idleDuration.inSeconds * ratio).round());

            dayNet += netPart;
            dayIdle += idlePart;

            switch (r.classification) {
              case FinancialClassification.capex:
                dayCapex += netPart;
                break;
              case FinancialClassification.opex:
                dayOpex += netPart;
                break;
              case FinancialClassification.none:
                dayUnclass += netPart;
                break;
            }
          }
        }

        final weekdayShort = DateFormat('E').format(curDay).substring(0, 1);
        rhythmBuckets.add(
          ReportBucket(
            label: '$weekdayShort ${curDay.day}',
            date: curDay,
            totalDuration: dayNet,
            capexDuration: dayCapex,
            opexDuration: dayOpex,
            unclassifiedDuration: dayUnclass,
            idleDuration: dayIdle,
          ),
        );

        // Advance day safely across daylight saving transitions
        curDay = DateTime(curDay.year, curDay.month, curDay.day + 1);
      }
    } else {
      rhythmAxis = RhythmAxis.week;
      var curWeekStart = weekStartFor(localStart, DateTime.sunday);
      final lastDay = DateTime(localEnd.year, localEnd.month, localEnd.day);

      while (!curWeekStart.isAfter(lastDay)) {
        final curWeekEnd = DateTime(
          curWeekStart.year,
          curWeekStart.month,
          curWeekStart.day + 7,
        );

        var wNet = Duration.zero;
        var wCapex = Duration.zero;
        var wOpex = Duration.zero;
        var wUnclass = Duration.zero;
        var wIdle = Duration.zero;

        for (final r in records) {
          final sStart = r.session.startTime.toLocal();
          final sEnd =
              (r.session.endTime ?? sStart.add(r.grossDuration)).toLocal();

          final overlap =
              _intervalOverlap(sStart, sEnd, curWeekStart, curWeekEnd);
          if (overlap > Duration.zero) {
            final ratio = r.grossDuration.inSeconds > 0
                ? overlap.inSeconds / r.grossDuration.inSeconds
                : 1.0;
            final netPart = Duration(
                seconds: (r.netActiveDuration.inSeconds * ratio).round());
            final idlePart =
                Duration(seconds: (r.idleDuration.inSeconds * ratio).round());

            wNet += netPart;
            wIdle += idlePart;

            switch (r.classification) {
              case FinancialClassification.capex:
                wCapex += netPart;
                break;
              case FinancialClassification.opex:
                wOpex += netPart;
                break;
              case FinancialClassification.none:
                wUnclass += netPart;
                break;
            }
          }
        }

        rhythmBuckets.add(
          ReportBucket(
            label: DateFormat('MMM d').format(curWeekStart),
            date: curWeekStart,
            totalDuration: wNet,
            capexDuration: wCapex,
            opexDuration: wOpex,
            unclassifiedDuration: wUnclass,
            idleDuration: wIdle,
          ),
        );

        curWeekStart = DateTime(
          curWeekStart.year,
          curWeekStart.month,
          curWeekStart.day + 7,
        );
      }
    }

    // 8. Top Tasks Ranking
    final taskDurations = <String, Duration>{};
    final taskCounts = <String, int>{};
    final taskCats = <String, Set<String>>{};
    final taskRecords = <String, SessionExportRecord>{};

    for (final r in records) {
      final tid = r.workItem.id;
      taskDurations[tid] =
          (taskDurations[tid] ?? Duration.zero) + r.netActiveDuration;
      taskCounts[tid] = (taskCounts[tid] ?? 0) + 1;
      taskCats
          .putIfAbsent(tid, () => <String>{})
          .add(r.category?.name ?? 'Uncategorized');
      taskRecords[tid] = r;
    }

    final allTasks = taskDurations.entries.map((e) {
      final rep = taskRecords[e.key]!;
      final share = totalNet.inSeconds > 0
          ? (e.value.inSeconds / totalNet.inSeconds)
          : 0.0;
      return ReportTaskLine(
        taskId: e.key,
        taskName: rep.workItem.name,
        projectName: rep.project?.name ?? 'No Project',
        projectColorHex: rep.project?.colorHex,
        categories: taskCats[e.key] ?? {},
        classification: rep.classification,
        sessionCount: taskCounts[e.key] ?? 0,
        totalDuration: e.value,
        share: share,
      );
    }).toList()
      ..sort((a, b) => b.totalDuration.compareTo(a.totalDuration));

    final topTasks = allTasks.take(12).toList();
    final topTasksRemainderCount = max(0, allTasks.length - 12);

    // 9. Headline Narrative Prose
    final busiestBucket = rhythmBuckets.isNotEmpty
        ? rhythmBuckets
            .reduce((a, b) => a.totalDuration >= b.totalDuration ? a : b)
        : null;

    final busiestClause = (busiestBucket != null &&
            busiestBucket.totalDuration > Duration.zero)
        ? ' Busiest ${isSingleDay ? 'hour' : 'day'} ${busiestBucket.label} (${TimerService.formatDuration(busiestBucket.totalDuration, compact: true)}).'
        : '';

    final capClause = classSplit.classifiedTotal > Duration.zero
        ? ' ${(classSplit.capexShare).toStringAsFixed(0)}% capitalizable.'
        : '';

    final proseLine =
        '${TimerService.formatDuration(totalNet, compact: true)} across ${uniqueTasks.length} tasks in ${uniqueProjects.length} projects.$capClause$busiestClause';

    final headline = ReportHeadline(
      totalGross: totalGross,
      totalNet: totalNet,
      totalIdle: totalIdle,
      taskCount: uniqueTasks.length,
      projectCount: uniqueProjects.length,
      categoryCount: uniqueCategories.length,
      sessionCount: records.length,
      activeDays: activeDaysSet.length,
      proseLine: proseLine,
    );

    // 10. Notes (Reused wholesale via TimeNotesService)
    final notesReport = _notesService.buildReport(
      records: records,
      codes: codes,
      range: range,
      isSingleDay: isSingleDay,
    );

    // 11. Full Session Lines for Appendix Table
    final sortedRecords = [...records]
      ..sort((a, b) => a.session.startTime.compareTo(b.session.startTime));

    final sessionLines = sortedRecords.map((r) {
      final codeRes = codes.resolveFor(
        project: r.project,
        attributeOptionIds: r.attributeOptionIds,
      );
      final attrSummaries = <String>[];
      for (final def in definitions) {
        if (def.isArchived || !def.enabled) continue;
        final v = r.attributeValues[def.id];
        if (v != null && v.isNotEmpty) {
          attrSummaries.add('${def.name}: $v');
        }
      }

      return ReportSessionLine(
        session: r.session,
        workItem: r.workItem,
        project: r.project,
        category: r.category,
        classification: r.classification,
        code: codeRes.code,
        tags: r.tags,
        people: r.people,
        attributesSummary: attrSummaries.join(' · '),
        grossDuration: r.grossDuration,
        idleDuration: r.idleDuration,
        netActiveDuration: r.netActiveDuration,
        hasNotes: (r.session.notes?.trim().isNotEmpty == true),
      );
    }).toList();

    // 12. Insights from WorkPatternReport (Capped at 3, one per lane)
    final reportInsights = <ReportInsight>[];
    if (patterns != null && patterns.insights.isNotEmpty) {
      final seenLanes = <String>{};
      final sortedInsights = [...patterns.insights]
        ..sort((a, b) => b.severity.index.compareTo(a.severity.index));

      for (final ins in sortedInsights) {
        final lane = ins.action.name;
        if (!seenLanes.contains(lane)) {
          seenLanes.add(lane);
          final ev = ins.evidence.isNotEmpty
              ? '${ins.evidence.first.label}: ${ins.evidence.first.value}'
              : '';
          reportInsights.add(
            ReportInsight(
              lane: lane,
              finding: ins.finding,
              evidence: ev,
              severity: ins.severity.index,
            ),
          );
          if (reportInsights.length == 3) break;
        }
      }
    }

    return WorkReport(
      identity: identity,
      headline: headline,
      classification: classSplit,
      projects: projectSlices,
      categories: catSlices,
      tags: tagSlices,
      people: peopleSlices,
      codes: codeRows,
      attributes: attributeBreakdowns,
      rhythm: rhythmBuckets,
      rhythmAxis: rhythmAxis,
      topTasks: topTasks,
      topTasksRemainderCount: topTasksRemainderCount,
      notes: notesReport,
      sessions: sessionLines,
      insights: reportInsights,
    );
  }

  static Duration _intervalOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    final start = aStart.isAfter(bStart) ? aStart : bStart;
    final end = aEnd.isBefore(bEnd) ? aEnd : bEnd;
    return end.isAfter(start) ? end.difference(start) : Duration.zero;
  }
}
