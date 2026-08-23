import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/repositories/attribute_repository.dart';
import 'package:workpulse/domain/repositories/category_repository.dart';
import 'package:workpulse/domain/repositories/idle_period_repository.dart';
import 'package:workpulse/domain/repositories/person_repository.dart';
import 'package:workpulse/domain/repositories/project_repository.dart';
import 'package:workpulse/domain/repositories/session_repository.dart';
import 'package:workpulse/domain/repositories/tag_repository.dart';
import 'package:workpulse/domain/repositories/work_item_repository.dart';

class AnalyticsService {
  final SessionRepository _sessionRepository;
  final WorkItemRepository _workItemRepository;
  final ProjectRepository _projectRepository;
  final CategoryRepository _categoryRepository;
  final TagRepository _tagRepository;
  final PersonRepository _personRepository;
  final AttributeRepository _attributeRepository;
  final IdlePeriodRepository _idlePeriodRepository;

  AnalyticsService({
    required SessionRepository sessionRepository,
    required WorkItemRepository workItemRepository,
    required ProjectRepository projectRepository,
    required CategoryRepository categoryRepository,
    required TagRepository tagRepository,
    required PersonRepository personRepository,
    required AttributeRepository attributeRepository,
    required IdlePeriodRepository idlePeriodRepository,
  })  : _sessionRepository = sessionRepository,
        _workItemRepository = workItemRepository,
        _projectRepository = projectRepository,
        _categoryRepository = categoryRepository,
        _tagRepository = tagRepository,
        _personRepository = personRepository,
        _attributeRepository = attributeRepository,
        _idlePeriodRepository = idlePeriodRepository;

  Future<DashboardData> getDashboardData({
    required String workspaceId,
    required DateRange range,
  }) async {
    // 1. Fetch sessions in date range
    final allSessions = await _sessionRepository.getByDateRange(
      range.start,
      range.end,
    );

    // 2. Fetch context entities
    // includeArchived: true - archiving a task must not erase its
    // historical time data from dashboard metrics.
    final allWorkItems = await _workItemRepository.getAll(
        workspaceId: workspaceId, includeArchived: true);
    final allProjects =
        await _projectRepository.getAll(workspaceId: workspaceId);
    final allCategories =
        await _categoryRepository.getAll(workspaceId: workspaceId);
    final allTags = await _tagRepository.getAll(workspaceId: workspaceId);
    final allPeople = await _personRepository.getAll(workspaceId: workspaceId);
    final allDefinitions =
        await _attributeRepository.getDefinitions(workspaceId: workspaceId);

    final workItemMap = {for (final w in allWorkItems) w.id: w};
    final projectMap = {for (final p in allProjects) p.id: p};
    final categoryMap = {for (final c in allCategories) c.id: c};
    final tagMap = {for (final t in allTags) t.id: t};
    final personMap = {for (final p in allPeople) p.id: p};

    // 3. Collect idle periods for sessions
    final sessionIdleMap = <String, List<IdlePeriod>>{};
    for (final s in allSessions) {
      final idles = await _idlePeriodRepository.getIdlePeriodsForSession(s.id);
      sessionIdleMap[s.id] = idles;
    }

    // 4. Calculate total tracked, active, and idle durations
    Duration totalTracked = Duration.zero;
    Duration totalIdle = Duration.zero;
    Duration totalActive = Duration.zero;

    final sessionActiveDurations = <String, Duration>{};

    for (final s in allSessions) {
      final grossDuration = s.duration;
      totalTracked += grossDuration;

      final idles = sessionIdleMap[s.id] ?? [];
      Duration sessionIdle = Duration.zero;
      for (final idle in idles) {
        if (idle.resolution == IdleResolution.markIdle) {
          sessionIdle += idle.duration;
        }
      }
      totalIdle += sessionIdle;

      final netActive = grossDuration > sessionIdle
          ? grossDuration - sessionIdle
          : Duration.zero;
      sessionActiveDurations[s.id] = netActive;
      totalActive += netActive;
    }

    final uniqueWorkItemIds =
        allSessions.map((Session s) => s.workItemId).toSet();

    final summary = AnalyticsSummary(
      totalTrackedDuration: totalTracked,
      totalActiveDuration: totalActive,
      totalIdleDuration: totalIdle,
      sessionCount: allSessions.length,
      taskCount: uniqueWorkItemIds.length,
    );

    final baseActiveSeconds =
        totalActive.inSeconds > 0 ? totalActive.inSeconds : 1;

    // 5. Project Breakdown
    final projectDurations = <String, Duration>{};
    final projectSessionCounts = <String, int>{};

    for (final s in allSessions) {
      final workItem = workItemMap[s.workItemId];
      if (workItem != null) {
        final projId = workItem.projectId;
        final dur = sessionActiveDurations[s.id] ?? Duration.zero;
        projectDurations[projId] =
            (projectDurations[projId] ?? Duration.zero) + dur;
        projectSessionCounts[projId] = (projectSessionCounts[projId] ?? 0) + 1;
      }
    }

    final projectBreakdown = projectDurations.entries.map((entry) {
      final proj = projectMap[entry.key];
      final dur = entry.value;
      final pct = (dur.inSeconds / baseActiveSeconds) * 100.0;
      return BreakdownItem(
        id: entry.key,
        name: proj?.name ?? 'Unknown Project',
        colorHex: proj?.colorHex ?? '#0A84FF',
        duration: dur,
        percentage: pct.clamp(0.0, 100.0),
        sessionCount: projectSessionCounts[entry.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));

    // 6. Category Breakdown
    final categoryDurations = <String, Duration>{};
    final categorySessionCounts = <String, int>{};

    for (final s in allSessions) {
      final workItem = workItemMap[s.workItemId];
      if (workItem != null) {
        final catId = workItem.categoryId;
        final dur = sessionActiveDurations[s.id] ?? Duration.zero;
        categoryDurations[catId] =
            (categoryDurations[catId] ?? Duration.zero) + dur;
        categorySessionCounts[catId] = (categorySessionCounts[catId] ?? 0) + 1;
      }
    }

    final categoryBreakdown = categoryDurations.entries.map((entry) {
      final cat = categoryMap[entry.key];
      final dur = entry.value;
      final pct = (dur.inSeconds / baseActiveSeconds) * 100.0;
      return BreakdownItem(
        id: entry.key,
        name: cat?.name ?? 'Unknown Category',
        iconName: cat?.iconName ?? 'folder',
        colorHex: '#30D158',
        duration: dur,
        percentage: pct.clamp(0.0, 100.0),
        sessionCount: categorySessionCounts[entry.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));

    // 7. WorkItem / Task Breakdown
    final taskDurations = <String, Duration>{};
    final taskSessionCounts = <String, int>{};

    for (final s in allSessions) {
      final dur = sessionActiveDurations[s.id] ?? Duration.zero;
      taskDurations[s.workItemId] =
          (taskDurations[s.workItemId] ?? Duration.zero) + dur;
      taskSessionCounts[s.workItemId] =
          (taskSessionCounts[s.workItemId] ?? 0) + 1;
    }

    final workItemBreakdown = taskDurations.entries.map((entry) {
      final item = workItemMap[entry.key];
      final proj = item != null ? projectMap[item.projectId] : null;
      final dur = entry.value;
      final pct = (dur.inSeconds / baseActiveSeconds) * 100.0;
      return BreakdownItem(
        id: entry.key,
        name: item?.name ?? 'Unknown Task',
        colorHex: proj?.colorHex ?? '#0A84FF',
        duration: dur,
        percentage: pct.clamp(0.0, 100.0),
        sessionCount: taskSessionCounts[entry.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));

    // 8. Tag Breakdown
    final tagDurations = <String, Duration>{};
    final tagSessionCounts = <String, int>{};

    for (final s in allSessions) {
      final item = workItemMap[s.workItemId];
      if (item != null && item.tagIds.isNotEmpty) {
        final dur = sessionActiveDurations[s.id] ?? Duration.zero;
        for (final tagId in item.tagIds) {
          tagDurations[tagId] = (tagDurations[tagId] ?? Duration.zero) + dur;
          tagSessionCounts[tagId] = (tagSessionCounts[tagId] ?? 0) + 1;
        }
      }
    }

    final tagBreakdown = tagDurations.entries.map((entry) {
      final tag = tagMap[entry.key];
      final dur = entry.value;
      final pct = (dur.inSeconds / baseActiveSeconds) * 100.0;
      return BreakdownItem(
        id: entry.key,
        name: tag?.name ?? 'Tag',
        colorHex: tag?.colorHex ?? '#BF5AF2',
        duration: dur,
        percentage: pct.clamp(0.0, 100.0),
        sessionCount: tagSessionCounts[entry.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));

    // 9. Person Breakdown
    final personDurations = <String, Duration>{};
    final personSessionCounts = <String, int>{};

    for (final s in allSessions) {
      final dur = sessionActiveDurations[s.id] ?? Duration.zero;
      final peopleIds = s.peopleIds.isNotEmpty
          ? s.peopleIds
          : (workItemMap[s.workItemId]?.peopleIds ?? []);
      for (final personId in peopleIds) {
        personDurations[personId] =
            (personDurations[personId] ?? Duration.zero) + dur;
        personSessionCounts[personId] =
            (personSessionCounts[personId] ?? 0) + 1;
      }
    }

    final personBreakdown = personDurations.entries.map((entry) {
      final person = personMap[entry.key];
      final dur = entry.value;
      final pct = (dur.inSeconds / baseActiveSeconds) * 100.0;
      return BreakdownItem(
        id: entry.key,
        name: person?.name ?? 'Person',
        colorHex: '#FF9F0A',
        duration: dur,
        percentage: pct.clamp(0.0, 100.0),
        sessionCount: personSessionCounts[entry.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));

    // 10. Configurable Attributes Breakdown
    final attributeBreakdowns = <AttributeBreakdownGroup>[];
    final reportableDefs = allDefinitions
        .where((d) => d.reportable && d.enabled && !d.isArchived)
        .toList();

    for (final def in reportableDefs) {
      final groupDurations = <String, Duration>{};
      final groupCounts = <String, int>{};
      final groupLabels = <String, String>{};
      final groupColors = <String, String?>{};

      final options = await _attributeRepository.getOptions(def.id);
      final optionMap = {for (final o in options) o.id: o};

      for (final s in allSessions) {
        final dur = sessionActiveDurations[s.id] ?? Duration.zero;
        final itemValues =
            await _attributeRepository.getWorkItemValues(s.workItemId);
        final attrVal = itemValues
            .where(
                (WorkItemAttributeValue v) => v.attributeDefinitionId == def.id)
            .firstOrNull;

        if (attrVal != null) {
          String key;
          String label;
          String? col;

          if (def.type == AttributeType.boolean) {
            final isTrue = attrVal.booleanValue == true;
            key = isTrue ? 'yes' : 'no';
            label = isTrue ? 'Yes' : 'No';
            col = isTrue ? '#30D158' : '#8E8E93';
          } else if (def.type == AttributeType.singleSelect &&
              attrVal.optionId != null) {
            final opt = optionMap[attrVal.optionId];
            key = attrVal.optionId!;
            label = opt?.label ?? 'Option';
            col = opt?.colorHex;
          } else if (attrVal.textValue != null &&
              attrVal.textValue!.isNotEmpty) {
            key = attrVal.textValue!;
            label = attrVal.textValue!;
          } else {
            key = 'unspecified';
            label = 'Unspecified';
            col = '#8E8E93';
          }

          groupDurations[key] = (groupDurations[key] ?? Duration.zero) + dur;
          groupCounts[key] = (groupCounts[key] ?? 0) + 1;
          groupLabels[key] = label;
          groupColors[key] = col;
        }
      }

      if (groupDurations.isNotEmpty) {
        final items = groupDurations.entries.map((entry) {
          final dur = entry.value;
          final pct = (dur.inSeconds / baseActiveSeconds) * 100.0;
          return BreakdownItem(
            id: entry.key,
            name: groupLabels[entry.key] ?? entry.key,
            colorHex: groupColors[entry.key] ?? '#64D2FF',
            duration: dur,
            percentage: pct.clamp(0.0, 100.0),
            sessionCount: groupCounts[entry.key] ?? 0,
          );
        }).toList()
          ..sort((a, b) => b.duration.compareTo(a.duration));

        attributeBreakdowns
            .add(AttributeBreakdownGroup(definition: def, items: items));
      }
    }

    // 11. Daily Activity Trend (with midnight session splitting)
    final dailyMap = <DateTime, DailyActivityItem>{};
    final dayCount = range.end.difference(range.start).inDays + 1;

    for (int i = 0; i < (dayCount > 31 ? 31 : dayCount); i++) {
      final day = DateTime.utc(
          range.start.year, range.start.month, range.start.day + i);
      dailyMap[day] = DailyActivityItem(
        date: day,
        activeDuration: Duration.zero,
        idleDuration: Duration.zero,
        sessionCount: 0,
      );
    }

    for (final s in allSessions) {
      final sessionEnd = s.endTime ?? DateTime.now().toUtc();
      final active = sessionActiveDurations[s.id] ?? Duration.zero;
      final idles = sessionIdleMap[s.id] ?? [];
      Duration totalIdleDur = Duration.zero;
      for (final idl in idles) {
        if (idl.resolution == IdleResolution.markIdle) {
          totalIdleDur += idl.duration;
        }
      }

      final grossDuration = sessionEnd.difference(s.startTime);
      if (grossDuration <= Duration.zero) continue;

      // Split session across midnight boundaries
      final daySlices = _splitAcrossDays(s.startTime, sessionEnd);

      for (final slice in daySlices) {
        final sliceDuration = slice.end.difference(slice.start);
        final fraction =
            sliceDuration.inMicroseconds / grossDuration.inMicroseconds;

        final sliceActive =
            Duration(microseconds: (active.inMicroseconds * fraction).round());
        final sliceIdle = Duration(
            microseconds: (totalIdleDur.inMicroseconds * fraction).round());

        final dayKey =
            DateTime.utc(slice.start.year, slice.start.month, slice.start.day);
        final existing = dailyMap[dayKey] ??
            DailyActivityItem(
              date: dayKey,
              activeDuration: Duration.zero,
              idleDuration: Duration.zero,
              sessionCount: 0,
            );

        dailyMap[dayKey] = DailyActivityItem(
          date: dayKey,
          activeDuration: existing.activeDuration + sliceActive,
          idleDuration: existing.idleDuration + sliceIdle,
          sessionCount:
              existing.sessionCount + (slice.start == s.startTime ? 1 : 0),
        );
      }
    }

    final dailyActivity = dailyMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return DashboardData(
      range: range,
      summary: summary,
      projectBreakdown: projectBreakdown,
      categoryBreakdown: categoryBreakdown,
      workItemBreakdown: workItemBreakdown,
      tagBreakdown: tagBreakdown,
      personBreakdown: personBreakdown,
      attributeBreakdowns: attributeBreakdowns,
      dailyActivity: dailyActivity,
    );
  }

  /// Splits a time range [start, end] into per-day slices at UTC midnight boundaries.
  ///
  /// For example, a session from 2026-01-15 23:00 to 2026-01-16 01:00 UTC
  /// produces two slices:
  ///   [2026-01-15 23:00, 2026-01-16 00:00) and [2026-01-16 00:00, 2026-01-16 01:00)
  static List<DateRange> _splitAcrossDays(DateTime start, DateTime end) {
    final slices = <DateRange>[];
    var cursor = start.toUtc();
    final utcEnd = end.toUtc();

    while (cursor.isBefore(utcEnd)) {
      final nextMidnight =
          DateTime.utc(cursor.year, cursor.month, cursor.day + 1);
      final sliceEnd = nextMidnight.isBefore(utcEnd) ? nextMidnight : utcEnd;
      slices.add(DateRange(start: cursor, end: sliceEnd));
      cursor = sliceEnd;
    }

    return slices;
  }
}
