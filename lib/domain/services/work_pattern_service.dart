import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_pattern_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';

/// The tunables every detector reads, in one place.
///
/// They are constructor arguments rather than constants so the tests can pin
/// a detector's boundary without seeding hours of synthetic sessions, and so a
/// later settings screen has something to write to.
class PatternThresholds {
  /// A stretch at or above this counts as a deep block.
  final Duration deepWorkBlock;

  /// At or below this, a session is a dip rather than a sitting.
  final Duration shortSession;

  /// An insight has to account for at least this much time to be worth the
  /// reader's attention.
  final Duration minimumTimeInvolved;

  /// Times a single task must be picked up *within one day* before that day
  /// counts as fragmented.
  final int fragmentedSessionCount;

  /// Sessions started per tracked day, above which switching itself is the
  /// finding.
  final double switchesPerDayCeiling;

  /// Distinct days a subject must recur on to read as routine.
  final int recurrenceDays;

  /// Routine work never runs longer than this in one sitting.
  final Duration routineMedianCeiling;

  /// A category has to hold this share of active time before its shape is
  /// worth naming.
  final double categoryShareFloor;

  /// Days of silence after which a started commitment is called at risk.
  final int quietDaysBeforeAtRisk;

  /// Idle share of captured time above which the timer itself is the problem.
  final double idleShareCeiling;

  /// Share of active time spent with other people, above which the calendar
  /// is the finding.
  final double collaborationShareCeiling;

  /// Share of active time one project can hold before the others are being
  /// starved.
  final double concentrationShare;

  /// Share below which a project counts as starved.
  final double starvedShare;

  /// Local hour the working day is assumed to start.
  final int workdayStartHour;

  /// Local hour the working day is assumed to end.
  final int workdayEndHour;

  /// Cards shown per lane, so the panel stays readable.
  final int maxInsightsPerAction;

  const PatternThresholds({
    this.deepWorkBlock = const Duration(minutes: 45),
    this.shortSession = const Duration(minutes: 15),
    this.minimumTimeInvolved = const Duration(minutes: 30),
    this.fragmentedSessionCount = 4,
    this.switchesPerDayCeiling = 10,
    this.recurrenceDays = 3,
    this.routineMedianCeiling = const Duration(minutes: 30),
    this.categoryShareFloor = 0.15,
    this.quietDaysBeforeAtRisk = 7,
    this.idleShareCeiling = 0.15,
    this.collaborationShareCeiling = 0.35,
    this.concentrationShare = 0.60,
    this.starvedShare = 0.10,
    this.workdayStartHour = 8,
    this.workdayEndHour = 19,
    this.maxInsightsPerAction = 4,
  });
}

/// Turns a window of tracked sessions into things worth doing something about.
///
/// Deliberately rule-based and entirely local: it reads the same SQLite rows
/// the dashboard already renders and reaches no further. Every sentence it
/// produces is derived from a figure the user could add up by hand from their
/// own Time Log, which is the only kind of advice a privacy-first tracker has
/// any business giving.
///
/// Pure: no repositories, no clock of its own, no I/O. [analyse] is a function
/// of its arguments, which is what makes the detectors testable one boundary
/// at a time.
class WorkPatternService {
  final PatternThresholds thresholds;

  const WorkPatternService({this.thresholds = const PatternThresholds()});

  WorkPatternReport analyse({
    required DateRange window,
    required PatternWindow lookback,
    required List<Session> sessions,
    required Map<String, WorkItem> workItems,
    required Map<String, Project> projects,
    required Map<String, Category> categories,
    required Map<String, Person> people,
    required Map<String, Duration> idleBySession,
    required DateTime now,
  }) {
    final tracked = <_Tracked>[];
    for (final session in sessions) {
      // A running session's duration is still moving. Including it would let
      // the panel change its mind every second the timer bar ticks.
      if (session.isActive) continue;

      final gross = session.duration;
      if (gross <= Duration.zero) continue;

      final idle = idleBySession[session.id] ?? Duration.zero;
      final active = gross > idle ? gross - idle : Duration.zero;
      if (active <= Duration.zero) continue;

      tracked.add(_Tracked(session, gross, active));
    }

    final totalActive = tracked.fold<Duration>(
      Duration.zero,
      (sum, t) => sum + t.active,
    );

    if (tracked.isEmpty || totalActive <= Duration.zero) {
      return WorkPatternReport(window: window, lookback: lookback);
    }

    final totalIdle = tracked.fold<Duration>(
      Duration.zero,
      (sum, t) => sum + (t.gross - t.active),
    );

    final byWorkItem = <String, _SubjectStats>{};
    final byProject = <String, _SubjectStats>{};
    final byCategory = <String, _SubjectStats>{};
    final byPerson = <String, _SubjectStats>{};
    final trackedDays = <DateTime>{};

    var collaborative = Duration.zero;

    for (final t in tracked) {
      trackedDays.add(t.day);

      final item = workItems[t.session.workItemId];
      byWorkItem.putIfAbsent(t.session.workItemId, _SubjectStats.new).add(t);

      if (item != null) {
        byProject.putIfAbsent(item.projectId, _SubjectStats.new).add(t);
      }

      final categoryId = t.session.categoryId ?? item?.categoryId;
      if (categoryId != null) {
        byCategory.putIfAbsent(categoryId, _SubjectStats.new).add(t);
      }

      final peopleIds = t.session.peopleIds.isNotEmpty
          ? t.session.peopleIds
          : (item?.peopleIds ?? const <String>[]);
      if (peopleIds.isNotEmpty) {
        collaborative += t.active;
        for (final personId in peopleIds) {
          byPerson.putIfAbsent(personId, _SubjectStats.new).add(t);
        }
      }
    }

    final rhythm = _rhythm(tracked, totalActive, trackedDays.length);

    final insights = <WorkPatternInsight>[
      ..._fragmentedDays(byWorkItem, workItems, projects, totalActive),
      ..._switchingLoad(tracked, trackedDays.length, totalActive),
      ..._idleDrain(tracked, totalActive, totalIdle),
      ..._outOfHours(tracked, totalActive),
      ..._routineWorkItems(
          byWorkItem, workItems, projects, totalActive, trackedDays.length),
      ..._routineCategories(
          byCategory, categories, totalActive, trackedDays.length),
      ..._collaborationLoad(collaborative, totalActive, tracked.length),
      ..._recurringCheckIns(byPerson, people, totalActive, trackedDays.length),
      ..._atRiskCommitments(byWorkItem, workItems, projects, totalActive, now),
      ..._concentration(byProject, projects, totalActive),
      ..._peakFocusWindow(tracked, rhythm, totalActive),
    ];

    return WorkPatternReport(
      window: window,
      lookback: lookback,
      totalActive: totalActive,
      sessionCount: tracked.length,
      rhythm: rhythm,
      insights: _rank(insights),
    );
  }

  // ---------------------------------------------------------------------
  // Detectors
  // ---------------------------------------------------------------------

  /// Days where one task was picked up over and over.
  ///
  /// Scoped to a single day on purpose: a task touched four times across four
  /// weeks is a routine, which [_routineWorkItems] handles. A task touched
  /// four times before lunch is an interruption pattern, and the cost is the
  /// walk back in each time.
  List<WorkPatternInsight> _fragmentedDays(
    Map<String, _SubjectStats> byWorkItem,
    Map<String, WorkItem> workItems,
    Map<String, Project> projects,
    Duration totalActive,
  ) {
    final results = <WorkPatternInsight>[];

    byWorkItem.forEach((workItemId, stats) {
      final perDay = <DateTime, List<_Tracked>>{};
      for (final t in stats.sessions) {
        perDay.putIfAbsent(t.day, () => []).add(t);
      }

      final fragmentedDays = perDay.entries
          .where((e) => e.value.length >= thresholds.fragmentedSessionCount)
          .toList();
      if (fragmentedDays.isEmpty) return;

      final affected = [for (final e in fragmentedDays) ...e.value];
      final involved = affected.fold<Duration>(
        Duration.zero,
        (sum, t) => sum + t.active,
      );
      if (involved < thresholds.minimumTimeInvolved) return;

      final touches = affected.length;
      final median = _median([for (final t in affected) t.active]);
      final longest =
          affected.map((t) => t.active).reduce((a, b) => a > b ? a : b);

      final item = workItems[workItemId];
      final dayWord = fragmentedDays.length == 1 ? 'day' : 'days';

      results.add(WorkPatternInsight(
        id: 'fragmented:$workItemId',
        action: InsightAction.reclaim,
        severity: _severity(involved, totalActive),
        subject: PatternSubject.workItem,
        subjectId: workItemId,
        colorHex: projects[item?.projectId]?.colorHex,
        title: '“${item?.name ?? 'Untitled task'}” arrives in fragments',
        finding: 'On ${fragmentedDays.length} $dayWord you came back to it '
            '$touches times. The median visit was ${_compact(median)} and the '
            'longest unbroken stretch all window was ${_compact(longest)}, '
            'against ${_compact(involved)} spent on those days in total.',
        recommendation: 'Give it one booked block instead of $touches '
            're-entries. Nothing here needed you the moment it arrived.',
        timeInvolved: involved,
        evidence: [
          InsightEvidence('Visits', '$touches'),
          InsightEvidence('Median visit', _compact(median)),
          InsightEvidence('Longest stretch', _compact(longest)),
          InsightEvidence('Fragmented days', '${fragmentedDays.length}'),
        ],
      ));
    });

    return results;
  }

  /// Switching as its own finding, when no single task is to blame.
  List<WorkPatternInsight> _switchingLoad(
    List<_Tracked> tracked,
    int trackedDayCount,
    Duration totalActive,
  ) {
    if (trackedDayCount == 0) return const [];

    final perDay = tracked.length / trackedDayCount;
    if (perDay < thresholds.switchesPerDayCeiling) return const [];

    final shortOnes =
        tracked.where((t) => t.active <= thresholds.shortSession).toList();
    final involved = shortOnes.fold<Duration>(
      Duration.zero,
      (sum, t) => sum + t.active,
    );

    return [
      WorkPatternInsight(
        id: 'switching-load',
        action: InsightAction.reclaim,
        severity: _severity(involved, totalActive),
        subject: PatternSubject.schedule,
        title: 'You start ${perDay.toStringAsFixed(1)} sessions a day',
        finding: '${tracked.length} sessions over $trackedDayCount tracked '
            'days. ${shortOnes.length} of them ended inside '
            '${_compact(thresholds.shortSession)}, carrying '
            '${_compact(involved)} between them.',
        recommendation: 'The short ones are the tax, not the work. Batch them '
            'into one or two windows a day and leave the rest of the day '
            'closed.',
        timeInvolved: involved,
        evidence: [
          InsightEvidence('Sessions', '${tracked.length}'),
          InsightEvidence('Per tracked day', perDay.toStringAsFixed(1)),
          InsightEvidence('Under ${_compact(thresholds.shortSession)}',
              '${shortOnes.length}'),
        ],
      ),
    ];
  }

  /// Time the timer captured and the user then wrote off.
  List<WorkPatternInsight> _idleDrain(
    List<_Tracked> tracked,
    Duration totalActive,
    Duration totalIdle,
  ) {
    if (totalIdle < thresholds.minimumTimeInvolved) return const [];

    final captured = totalActive + totalIdle;
    if (captured <= Duration.zero) return const [];

    final share = totalIdle.inSeconds / captured.inSeconds;
    if (share < thresholds.idleShareCeiling) return const [];

    final affectedDays = <DateTime>{
      for (final t in tracked)
        if (t.gross > t.active) t.day,
    };

    return [
      WorkPatternInsight(
        id: 'idle-drain',
        action: InsightAction.reclaim,
        severity: _severity(totalIdle, totalActive),
        subject: PatternSubject.schedule,
        title: '${_compact(totalIdle)} was captured and then written off',
        finding: '${_pct(share)} of everything the timer recorded was resolved '
            'as idle, across ${affectedDays.length} days.',
        recommendation: 'Either the away threshold is too generous or the '
            'timer is running through your breaks. Until that is settled, '
            'every other figure on this page reads high.',
        timeInvolved: totalIdle,
        evidence: [
          InsightEvidence('Idle', _compact(totalIdle)),
          InsightEvidence('Of captured time', _pct(share)),
          InsightEvidence('Days affected', '${affectedDays.length}'),
        ],
      ),
    ];
  }

  /// Work that only fitted after the day was over.
  List<WorkPatternInsight> _outOfHours(
    List<_Tracked> tracked,
    Duration totalActive,
  ) {
    var outside = Duration.zero;
    final days = <DateTime>{};
    var weekendTime = Duration.zero;

    for (final t in tracked) {
      final portion = _activeWhere(t, _isOutOfHours);
      if (portion <= Duration.zero) continue;
      outside += portion;
      days.add(t.day);
      // Measured over the same slices rather than off the start time, so a
      // Friday night that runs past midnight is split correctly.
      weekendTime += _activeWhere(t, _isWeekend);
    }

    if (outside < thresholds.minimumTimeInvolved) return const [];

    final share = outside.inSeconds / totalActive.inSeconds;
    final weekendClause = weekendTime > Duration.zero
        ? ', ${_compact(weekendTime)} of it at weekends'
        : '';

    return [
      WorkPatternInsight(
        id: 'out-of-hours',
        action: InsightAction.plan,
        severity: _severity(outside, totalActive),
        subject: PatternSubject.schedule,
        title: '${_compact(outside)} landed outside working hours',
        finding: '${_pct(share)} of your active time fell before '
            '${_hourLabel(thresholds.workdayStartHour)}, after '
            '${_hourLabel(thresholds.workdayEndHour)}, or at a weekend — '
            'on ${days.length} separate days$weekendClause.',
        recommendation: 'Work that only fits after hours is work the plan did '
            'not have room for. Take it off next week before the week takes '
            'it off you.',
        timeInvolved: outside,
        evidence: [
          InsightEvidence('Out of hours', _compact(outside)),
          InsightEvidence('Of active time', _pct(share)),
          InsightEvidence('Days', '${days.length}'),
          if (weekendTime > Duration.zero)
            InsightEvidence('At weekends', _compact(weekendTime)),
        ],
      ),
    ];
  }

  /// Tasks that keep coming back and never need a deep block.
  ///
  /// That combination — recurring, short, never demanding an unbroken stretch —
  /// is the shape of work that survives being written down and handed over.
  /// Work that needs 90 unbroken minutes usually needs the context that only
  /// the person holding it has.
  List<WorkPatternInsight> _routineWorkItems(
    Map<String, _SubjectStats> byWorkItem,
    Map<String, WorkItem> workItems,
    Map<String, Project> projects,
    Duration totalActive,
    int trackedDayCount,
  ) {
    final results = <WorkPatternInsight>[];

    byWorkItem.forEach((workItemId, stats) {
      if (stats.days.length < thresholds.recurrenceDays) return;
      if (stats.total < thresholds.minimumTimeInvolved) return;
      if (stats.longest >= thresholds.deepWorkBlock) return;

      final median = _median([for (final t in stats.sessions) t.active]);
      if (median > thresholds.routineMedianCeiling) return;

      final item = workItems[workItemId];
      if (item != null && item.isArchived) return;

      final share = stats.total.inSeconds / totalActive.inSeconds;

      results.add(WorkPatternInsight(
        id: 'routine-task:$workItemId',
        action: InsightAction.delegate,
        severity: _severity(stats.total, totalActive),
        subject: PatternSubject.workItem,
        subjectId: workItemId,
        colorHex: projects[item?.projectId]?.colorHex,
        title: '“${item?.name ?? 'Untitled task'}” repeats and never goes deep',
        finding: 'It came up on ${stats.days.length} of your '
            '$trackedDayCount tracked days across '
            '${stats.sessions.length} sessions, median ${_compact(median)}, '
            'and never once ran past ${_compact(thresholds.deepWorkBlock)}. '
            '${_compact(stats.total)} in total — ${_pct(share)} of your active '
            'time.',
        recommendation: 'Recurring, short, and never needing an unbroken hour '
            'is the profile that hands over cleanly. Write the steps down once '
            'and it stops being yours.',
        timeInvolved: stats.total,
        evidence: [
          InsightEvidence('Days it recurred', '${stats.days.length}'),
          InsightEvidence('Sessions', '${stats.sessions.length}'),
          InsightEvidence('Median session', _compact(median)),
          InsightEvidence('Longest ever', _compact(stats.longest)),
        ],
      ));
    });

    return results;
  }

  /// The same shape one level up: a whole category that never goes deep.
  List<WorkPatternInsight> _routineCategories(
    Map<String, _SubjectStats> byCategory,
    Map<String, Category> categories,
    Duration totalActive,
    int trackedDayCount,
  ) {
    final results = <WorkPatternInsight>[];

    byCategory.forEach((categoryId, stats) {
      if (stats.days.length < thresholds.recurrenceDays) return;
      if (stats.longest >= thresholds.deepWorkBlock) return;

      final share = stats.total.inSeconds / totalActive.inSeconds;
      if (share < thresholds.categoryShareFloor) return;

      final median = _median([for (final t in stats.sessions) t.active]);
      if (median > thresholds.routineMedianCeiling) return;

      final category = categories[categoryId];

      results.add(WorkPatternInsight(
        id: 'routine-category:$categoryId',
        action: InsightAction.delegate,
        severity: _severity(stats.total, totalActive),
        subject: PatternSubject.category,
        subjectId: categoryId,
        title: '${category?.name ?? 'One category'} is '
            '${_pct(share)} of your time and always shallow',
        finding: '${_compact(stats.total)} across ${stats.sessions.length} '
            'sessions on ${stats.days.length} of $trackedDayCount tracked '
            'days, median ${_compact(median)}, never longer than '
            '${_compact(stats.longest)} at a stretch.',
        recommendation: 'An entire category that never asks for deep focus is '
            'the cheapest thing on this page to give away — and the easiest to '
            'hand over as a whole rather than task by task.',
        timeInvolved: stats.total,
        evidence: [
          InsightEvidence('Share of active time', _pct(share)),
          InsightEvidence('Sessions', '${stats.sessions.length}'),
          InsightEvidence('Median session', _compact(median)),
          InsightEvidence('Longest ever', _compact(stats.longest)),
        ],
      ));
    });

    return results;
  }

  /// How much of the window was spent in someone else's company.
  List<WorkPatternInsight> _collaborationLoad(
    Duration collaborative,
    Duration totalActive,
    int sessionCount,
  ) {
    if (collaborative < thresholds.minimumTimeInvolved) return const [];

    final share = collaborative.inSeconds / totalActive.inSeconds;
    if (share < thresholds.collaborationShareCeiling) return const [];

    return [
      WorkPatternInsight(
        id: 'collaboration-load',
        action: InsightAction.delegate,
        severity: _severity(collaborative, totalActive),
        subject: PatternSubject.schedule,
        title: '${_pct(share)} of your time has someone else in the room',
        finding: '${_compact(collaborative)} of ${_compact(totalActive)} '
            'active time was logged against at least one other person.',
        recommendation: 'Go through the recurring ones and ask which need you '
            'specifically. A standing meeting you attend out of habit is a '
            'seat someone on your team can take — and learn from.',
        timeInvolved: collaborative,
        evidence: [
          InsightEvidence('With others', _compact(collaborative)),
          InsightEvidence('Of active time', _pct(share)),
          InsightEvidence('Sessions in window', '$sessionCount'),
        ],
      ),
    ];
  }

  /// Short sessions with the same person, over and over — a standing check-in.
  List<WorkPatternInsight> _recurringCheckIns(
    Map<String, _SubjectStats> byPerson,
    Map<String, Person> people,
    Duration totalActive,
    int trackedDayCount,
  ) {
    final results = <WorkPatternInsight>[];

    byPerson.forEach((personId, stats) {
      if (stats.days.length < thresholds.recurrenceDays) return;
      if (stats.total < thresholds.minimumTimeInvolved) return;

      final median = _median([for (final t in stats.sessions) t.active]);
      if (median > thresholds.shortSession) return;

      final person = people[personId];

      results.add(WorkPatternInsight(
        id: 'check-in:$personId',
        action: InsightAction.delegate,
        severity: _severity(stats.total, totalActive),
        subject: PatternSubject.person,
        subjectId: personId,
        title: 'Standing short sessions with '
            '${person?.name ?? 'the same person'}',
        finding: '${stats.sessions.length} sessions on ${stats.days.length} of '
            '$trackedDayCount tracked days, median only ${_compact(median)} — '
            '${_compact(stats.total)} in total.',
        recommendation: 'Short, regular and predictable reads as a check-in '
            'rather than a decision. Hand the recurring slot to someone else, '
            'or let it become a written update.',
        timeInvolved: stats.total,
        evidence: [
          InsightEvidence('Days', '${stats.days.length}'),
          InsightEvidence('Sessions', '${stats.sessions.length}'),
          InsightEvidence('Median session', _compact(median)),
        ],
      ));
    });

    return results;
  }

  /// Commitments that were real and then went quiet.
  ///
  /// This is the deliverable you do not want to rediscover the day before it
  /// is due. It needs more than one session behind it, so a single exploratory
  /// half hour is not mistaken for a promise.
  List<WorkPatternInsight> _atRiskCommitments(
    Map<String, _SubjectStats> byWorkItem,
    Map<String, WorkItem> workItems,
    Map<String, Project> projects,
    Duration totalActive,
    DateTime now,
  ) {
    final results = <WorkPatternInsight>[];
    final localNow = now.toLocal();

    byWorkItem.forEach((workItemId, stats) {
      final item = workItems[workItemId];
      if (item == null || item.isArchived) return;
      if (stats.sessions.length < 2) return;
      if (stats.total < thresholds.minimumTimeInvolved) return;

      final last = stats.lastActivity;
      if (last == null) return;

      final quietDays = _wholeDaysBetween(last, localNow);
      if (quietDays < thresholds.quietDaysBeforeAtRisk) return;

      results.add(WorkPatternInsight(
        id: 'at-risk:$workItemId',
        action: InsightAction.plan,
        severity: _severity(stats.total, totalActive),
        subject: PatternSubject.workItem,
        subjectId: workItemId,
        colorHex: projects[item.projectId]?.colorHex,
        title: '“${item.name}” has been quiet for $quietDays days',
        finding: '${_compact(stats.total)} went into it across '
            '${stats.sessions.length} sessions, and then nothing since '
            '${_dayLabel(last)}.',
        recommendation: 'Give it a slot this week or close it out. A '
            'half-finished commitment nobody has cancelled is the one that '
            'surprises you.',
        timeInvolved: stats.total,
        evidence: [
          InsightEvidence('Invested', _compact(stats.total)),
          InsightEvidence('Sessions', '${stats.sessions.length}'),
          InsightEvidence('Last touched', _dayLabel(last)),
          InsightEvidence('Quiet for', '$quietDays days'),
        ],
      ));
    });

    return results;
  }

  /// One project eating the window while others starve.
  List<WorkPatternInsight> _concentration(
    Map<String, _SubjectStats> byProject,
    Map<String, Project> projects,
    Duration totalActive,
  ) {
    if (byProject.length < 3) return const [];

    final ranked = byProject.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    final top = ranked.first;
    final topShare = top.value.total.inSeconds / totalActive.inSeconds;
    if (topShare < thresholds.concentrationShare) return const [];

    final starved = ranked
        .skip(1)
        .where((e) =>
            e.value.total.inSeconds / totalActive.inSeconds <
            thresholds.starvedShare)
        .toList();
    if (starved.length < 2) return const [];

    final named = starved
        .take(2)
        .map((e) => '${projects[e.key]?.name ?? 'another project'} '
            '(${_compact(e.value.total)})')
        .join(' and ');

    return [
      WorkPatternInsight(
        id: 'concentration:${top.key}',
        action: InsightAction.plan,
        severity: _severity(top.value.total, totalActive),
        subject: PatternSubject.project,
        subjectId: top.key,
        colorHex: projects[top.key]?.colorHex,
        title: '${projects[top.key]?.name ?? 'One project'} took '
            '${_pct(topShare)} of the window',
        finding: '${_compact(top.value.total)} against $named. '
            '${starved.length} of your ${byProject.length} projects got under '
            '${_pct(thresholds.starvedShare)} each.',
        recommendation: 'If those quieter ones are also yours to deliver, they '
            'are running on borrowed time. Decide now which one gives.',
        timeInvolved: top.value.total,
        evidence: [
          InsightEvidence('Top project share', _pct(topShare)),
          InsightEvidence('Projects touched', '${byProject.length}'),
          InsightEvidence(
              'Under ${_pct(thresholds.starvedShare)}', '${starved.length}'),
        ],
      ),
    ];
  }

  /// When the deep work actually happens — and what is eating into it.
  List<WorkPatternInsight> _peakFocusWindow(
    List<_Tracked> tracked,
    FocusRhythm rhythm,
    Duration totalActive,
  ) {
    if (rhythm.peakFocusHours.isEmpty) return const [];
    if (rhythm.deepWorkTotal < thresholds.minimumTimeInvolved) return const [];

    final band = rhythm.peakFocusHours;
    final deepHistogram = _hourHistogram(
      tracked.where((t) => t.active >= thresholds.deepWorkBlock),
    );
    final shortHistogram = _hourHistogram(
      tracked.where((t) => t.active <= thresholds.shortSession),
    );

    final deepInBand = band.fold<Duration>(
      Duration.zero,
      (sum, h) => sum + (deepHistogram[h] ?? Duration.zero),
    );
    final shortInBand = band.fold<Duration>(
      Duration.zero,
      (sum, h) => sum + (shortHistogram[h] ?? Duration.zero),
    );

    final bandLabel = '${_hourLabel(band.first)}–${_hourLabel(band.last + 1)}';

    final competition = shortInBand > Duration.zero
        ? '${_compact(shortInBand)} of the same band went to sessions under '
            '${_compact(thresholds.shortSession)}.'
        : 'Nothing short is competing for it yet.';

    return [
      WorkPatternInsight(
        id: 'peak-focus',
        action: InsightAction.plan,
        severity: InsightSeverity.informational,
        subject: PatternSubject.schedule,
        title: 'Your deep work happens $bandLabel',
        finding: '${_compact(deepInBand)} of your blocks over '
            '${_compact(thresholds.deepWorkBlock)} fall in those two hours. '
            '$competition',
        recommendation: 'Book that band out before anything else claims it, '
            'and put the fragmented work somewhere it costs you less.',
        evidence: [
          InsightEvidence('Deep work in band', _compact(deepInBand)),
          InsightEvidence('Deep work overall', _compact(rhythm.deepWorkTotal)),
          if (shortInBand > Duration.zero)
            InsightEvidence('Short sessions in band', _compact(shortInBand)),
        ],
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // Shape of the working day
  // ---------------------------------------------------------------------

  FocusRhythm _rhythm(
    List<_Tracked> tracked,
    Duration totalActive,
    int trackedDayCount,
  ) {
    final deep = tracked
        .where((t) => t.active >= thresholds.deepWorkBlock)
        .toList(growable: false);

    final deepTotal = deep.fold<Duration>(
      Duration.zero,
      (sum, t) => sum + t.active,
    );

    final longest =
        tracked.map((t) => t.active).reduce((a, b) => a > b ? a : b);

    return FocusRhythm(
      peakFocusHours: _peakBand(_hourHistogram(deep)),
      longestUnbrokenBlock: longest,
      medianSessionLength: _median([for (final t in tracked) t.active]),
      deepWorkTotal: deepTotal,
      deepWorkShare: totalActive.inSeconds == 0
          ? 0
          : deepTotal.inSeconds / totalActive.inSeconds,
      switchesPerTrackedDay:
          trackedDayCount == 0 ? 0 : tracked.length / trackedDayCount,
      trackedDayCount: trackedDayCount,
    );
  }

  /// The best contiguous two-hour band in an hour histogram.
  ///
  /// Two hours because that is a bookable thing: an answer of "10am" is not
  /// something the user can defend in a calendar, and a whole morning is not
  /// something they can win.
  static List<int> _peakBand(Map<int, Duration> histogram) {
    if (histogram.isEmpty) return const [];

    var bestHour = -1;
    var best = Duration.zero;

    for (var h = 0; h < 23; h++) {
      final total =
          (histogram[h] ?? Duration.zero) + (histogram[h + 1] ?? Duration.zero);
      if (total > best) {
        best = total;
        bestHour = h;
      }
    }

    if (bestHour < 0 || best <= Duration.zero) return const [];
    return [bestHour, bestHour + 1];
  }

  /// Active time spread across the local hours a session actually occupied.
  static Map<int, Duration> _hourHistogram(Iterable<_Tracked> tracked) {
    final histogram = <int, Duration>{};

    for (final t in tracked) {
      _forEachHourSlice(t, (sliceStart, sliceDuration) {
        histogram[sliceStart.hour] =
            (histogram[sliceStart.hour] ?? Duration.zero) +
                _activeFor(t, sliceDuration);
      });
    }

    return histogram;
  }

  /// The part of a session's active time that fell in hours matching
  /// [predicate] — outside working hours, at a weekend, and so on.
  ///
  /// Scaled by the active fraction, so an evening that was mostly idle is not
  /// reported back as an evening of work.
  static Duration _activeWhere(
    _Tracked t,
    bool Function(DateTime local) predicate,
  ) {
    var matched = Duration.zero;

    _forEachHourSlice(t, (sliceStart, sliceDuration) {
      if (predicate(sliceStart)) matched += sliceDuration;
    });

    return _activeFor(t, matched);
  }

  /// [portion] of a session's gross duration, expressed in its active time.
  static Duration _activeFor(_Tracked t, Duration portion) {
    if (t.gross <= Duration.zero || portion <= Duration.zero) {
      return Duration.zero;
    }
    final fraction = portion.inMicroseconds / t.gross.inMicroseconds;
    return Duration(microseconds: (t.active.inMicroseconds * fraction).round());
  }

  /// Walks a session across local hour boundaries.
  ///
  /// Attributing a session to its start hour would put a 09:50–12:10 block
  /// entirely in the 9 o'clock bucket and hide the two hours that followed.
  static void _forEachHourSlice(
    _Tracked t,
    void Function(DateTime sliceStart, Duration sliceDuration) visit,
  ) {
    if (t.gross <= Duration.zero) return;

    var cursor = t.localStart;
    while (cursor.isBefore(t.localEnd)) {
      final nextHour =
          DateTime(cursor.year, cursor.month, cursor.day, cursor.hour + 1);
      final sliceEnd = nextHour.isBefore(t.localEnd) ? nextHour : t.localEnd;

      // A clock that does not move forward — a backwards DST shift is the only
      // way to get here — would otherwise spin this loop forever.
      if (!sliceEnd.isAfter(cursor)) return;

      visit(cursor, sliceEnd.difference(cursor));
      cursor = sliceEnd;
    }
  }

  bool _isOutOfHours(DateTime local) =>
      _isWeekend(local) ||
      local.hour < thresholds.workdayStartHour ||
      local.hour >= thresholds.workdayEndHour;

  static bool _isWeekend(DateTime local) =>
      local.weekday == DateTime.saturday || local.weekday == DateTime.sunday;

  // ---------------------------------------------------------------------
  // Presentation helpers
  // ---------------------------------------------------------------------

  /// Highest severity first, then the biggest time at stake, capped per lane.
  List<WorkPatternInsight> _rank(List<WorkPatternInsight> insights) {
    final sorted = [...insights]..sort((a, b) {
        final bySeverity = b.severity.index.compareTo(a.severity.index);
        if (bySeverity != 0) return bySeverity;
        final byTime = b.timeInvolved.compareTo(a.timeInvolved);
        if (byTime != 0) return byTime;
        return a.id.compareTo(b.id);
      });

    final perAction = <InsightAction, int>{};
    final kept = <WorkPatternInsight>[];

    for (final insight in sorted) {
      final taken = perAction[insight.action] ?? 0;
      if (taken >= thresholds.maxInsightsPerAction) continue;
      perAction[insight.action] = taken + 1;
      kept.add(insight);
    }

    return List.unmodifiable(kept);
  }

  static InsightSeverity _severity(Duration involved, Duration totalActive) {
    if (totalActive.inSeconds <= 0) return InsightSeverity.informational;
    final share = involved.inSeconds / totalActive.inSeconds;
    if (share >= 0.25) return InsightSeverity.high;
    if (share >= 0.10) return InsightSeverity.notable;
    return InsightSeverity.informational;
  }

  static Duration _median(List<Duration> values) {
    if (values.isEmpty) return Duration.zero;
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return Duration(
      microseconds:
          (sorted[middle - 1].inMicroseconds + sorted[middle].inMicroseconds) ~/
              2,
    );
  }

  /// Whole days between two local instants, floor.
  static int _wholeDaysBetween(DateTime from, DateTime to) {
    final fromDay = DateTime(from.year, from.month, from.day);
    final toDay = DateTime(to.year, to.month, to.day);
    return toDay.difference(fromDay).inDays;
  }

  static String _compact(Duration duration) =>
      TimerService.formatDuration(duration,
          compact: true, includeSeconds: false);

  static String _pct(double fraction) => '${(fraction * 100).round()}%';

  static String _hourLabel(int hour) {
    final normalised = hour % 24;
    if (normalised == 0) return '12am';
    if (normalised == 12) return '12pm';
    if (normalised < 12) return '${normalised}am';
    return '${normalised - 12}pm';
  }

  static String _dayLabel(DateTime local) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]}';
  }
}

/// A completed session with its idle time already deducted and its local
/// wall-clock bounds resolved once, rather than in every detector.
class _Tracked {
  final Session session;
  final Duration gross;
  final Duration active;
  final DateTime localStart;
  final DateTime localEnd;

  _Tracked(this.session, this.gross, this.active)
      : localStart = session.startTime.toLocal(),
        localEnd = (session.endTime ?? session.startTime).toLocal();

  /// Local midnight of the day the session started on.
  DateTime get day =>
      DateTime(localStart.year, localStart.month, localStart.day);
}

/// Running totals for one project, task, category or person.
class _SubjectStats {
  final List<_Tracked> sessions = [];
  final Set<DateTime> days = {};

  Duration total = Duration.zero;
  Duration longest = Duration.zero;
  DateTime? lastActivity;

  void add(_Tracked t) {
    sessions.add(t);
    days.add(t.day);
    total += t.active;
    if (t.active > longest) longest = t.active;
    if (lastActivity == null || t.localEnd.isAfter(lastActivity!)) {
      lastActivity = t.localEnd;
    }
  }
}
