import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_pattern_model.dart';
import 'package:workpulse/domain/services/work_pattern_service.dart';

/// Every fixture is built from *local* wall-clock times and converted to UTC on
/// the way in, exactly as the app stores them. The detectors reason in local
/// time — "before 8am", "on the same day" — so a test written in raw UTC would
/// pass or fail depending on the machine's zone.
void main() {
  const service = WorkPatternService();

  const workspaceId = 'ws-1';
  final epoch = DateTime.utc(2026, 1, 1);

  Project project(String id, {String name = 'Project'}) => Project(
        id: id,
        workspaceId: workspaceId,
        name: name,
        colorHex: '#0A84FF',
        createdAt: epoch,
        updatedAt: epoch,
      );

  Category category(String id, {String name = 'Category'}) => Category(
        id: id,
        workspaceId: workspaceId,
        name: name,
        createdAt: epoch,
        updatedAt: epoch,
      );

  Person person(String id, {String name = 'Person'}) => Person(
        id: id,
        workspaceId: workspaceId,
        name: name,
        createdAt: epoch,
      );

  WorkItem workItem(
    String id, {
    String name = 'Task',
    String projectId = 'proj-1',
    String categoryId = 'cat-1',
    DateTime? archivedAt,
  }) =>
      WorkItem(
        id: id,
        workspaceId: workspaceId,
        name: name,
        projectId: projectId,
        categoryId: categoryId,
        createdAt: epoch,
        updatedAt: epoch,
        archivedAt: archivedAt,
      );

  var sessionSeq = 0;
  Session session({
    required String workItemId,
    required DateTime localStart,
    required Duration duration,
    String? categoryId,
    List<String> peopleIds = const [],
    bool running = false,
  }) {
    sessionSeq++;
    return Session(
      id: 'sess-$sessionSeq',
      workItemId: workItemId,
      categoryId: categoryId,
      peopleIds: peopleIds,
      startTime: localStart.toUtc(),
      endTime: running ? null : localStart.add(duration).toUtc(),
      createdAt: localStart.toUtc(),
    );
  }

  setUp(() => sessionSeq = 0);

  WorkPatternReport analyse(
    List<Session> sessions, {
    Map<String, WorkItem>? workItems,
    Map<String, Project>? projects,
    Map<String, Category>? categories,
    Map<String, Person>? people,
    Map<String, Duration> idleBySession = const {},
    List<Session> previousSessions = const [],
    DateTime? now,
    DateRange? window,
    WorkPatternService? using,
  }) {
    final reference = now ?? DateTime(2026, 8, 25, 18);
    return (using ?? service).analyse(
      window: window ??
          DateRange(
            start: DateTime(2026, 7, 27).toUtc(),
            end: DateTime(2026, 8, 25, 23, 59, 59).toUtc(),
          ),
      lookback: PatternWindow.oneMonth,
      sessions: sessions,
      workItems: workItems ?? {'task-a': workItem('task-a')},
      projects: projects ?? {'proj-1': project('proj-1')},
      categories: categories ?? {'cat-1': category('cat-1')},
      people: people ?? const {},
      idleBySession: idleBySession,
      previousSessions: previousSessions,
      now: reference,
    );
  }

  WorkPatternInsight? findInsight(WorkPatternReport report, String id) {
    for (final insight in report.insights) {
      if (insight.id == id) return insight;
    }
    return null;
  }

  group('windowing and hygiene', () {
    test('reports no data when nothing was tracked', () {
      final report = analyse(const []);

      expect(report.hasData, isFalse);
      expect(report.hasInsights, isFalse);
      expect(report.totalActive, Duration.zero);
      expect(report.rhythm.hasData, isFalse);
    });

    test('ignores the running session, whose duration is still moving', () {
      final report = analyse([
        session(
          workItemId: 'task-a',
          localStart: DateTime(2026, 8, 24, 9),
          duration: const Duration(hours: 1),
        ),
        session(
          workItemId: 'task-a',
          localStart: DateTime(2026, 8, 25, 9),
          duration: Duration.zero,
          running: true,
        ),
      ]);

      expect(report.sessionCount, 1);
      expect(report.totalActive, const Duration(hours: 1));
    });

    test('deducts resolved idle time from every figure', () {
      final tracked = session(
        workItemId: 'task-a',
        localStart: DateTime(2026, 8, 24, 9),
        duration: const Duration(hours: 2),
      );

      final report = analyse(
        [tracked],
        idleBySession: {tracked.id: const Duration(minutes: 30)},
      );

      expect(report.totalActive, const Duration(minutes: 90));
      expect(report.rhythm.longestUnbrokenBlock, const Duration(minutes: 90));
    });

    test('drops a session that was entirely idle', () {
      final tracked = session(
        workItemId: 'task-a',
        localStart: DateTime(2026, 8, 24, 9),
        duration: const Duration(hours: 1),
      );

      final report = analyse(
        [tracked],
        idleBySession: {tracked.id: const Duration(hours: 1)},
      );

      expect(report.hasData, isFalse);
    });
  });

  group('reclaim — fragmentation', () {
    test('flags a task picked up repeatedly within one day', () {
      final report = analyse([
        for (var i = 0; i < 5; i++)
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, 24, 9 + i),
            duration: const Duration(minutes: 12),
          ),
      ]);

      final insight = findInsight(report, 'fragmented:task-a');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.reclaim);
      expect(insight.subject, PatternSubject.workItem);
      expect(insight.subjectId, 'task-a');
      expect(insight.timeInvolved, const Duration(minutes: 60));
      expect(insight.finding, contains('5 times'));
    });

    test('does not flag the same visit count spread across days', () {
      final report = analyse([
        for (var day = 24; day >= 21; day--)
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, day, 9),
            duration: const Duration(minutes: 12),
          ),
      ]);

      expect(findInsight(report, 'fragmented:task-a'), isNull);
    });

    test('stays quiet when the fragmented day is trivially small', () {
      final report = analyse([
        for (var i = 0; i < 4; i++)
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, 24, 9, i * 10),
            duration: const Duration(minutes: 5),
          ),
      ]);

      expect(findInsight(report, 'fragmented:task-a'), isNull);
    });
  });

  group('reclaim — switching load and idle drain', () {
    test('names switching itself when no single task is to blame', () {
      final items = {
        for (var i = 0; i < 12; i++) 'task-$i': workItem('task-$i'),
      };

      final report = analyse(
        [
          for (var i = 0; i < 12; i++)
            session(
              workItemId: 'task-$i',
              localStart: DateTime(2026, 8, 24, 8, i * 20),
              duration: const Duration(minutes: 10),
            ),
        ],
        workItems: items,
      );

      final insight = findInsight(report, 'switching-load');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.reclaim);
      expect(insight.title, contains('12.0 sessions a day'));
      expect(insight.timeInvolved, const Duration(minutes: 120));
    });

    test('flags idle time once it dominates what the timer captured', () {
      final sessions = [
        for (var day = 24; day >= 22; day--)
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, day, 9),
            duration: const Duration(hours: 2),
          ),
      ];

      final report = analyse(
        sessions,
        idleBySession: {
          for (final s in sessions) s.id: const Duration(minutes: 40),
        },
      );

      final insight = findInsight(report, 'idle-drain');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.reclaim);
      expect(insight.timeInvolved, const Duration(hours: 2));
      expect(insight.finding, contains('33%'));
    });

    test('leaves a modest idle share alone', () {
      final tracked = session(
        workItemId: 'task-a',
        localStart: DateTime(2026, 8, 24, 9),
        duration: const Duration(hours: 8),
      );

      final report = analyse(
        [tracked],
        idleBySession: {tracked.id: const Duration(minutes: 40)},
      );

      expect(findInsight(report, 'idle-drain'), isNull);
    });
  });

  group('delegate — routine work', () {
    test('flags a task that recurs and never needs a deep block', () {
      final report = analyse([
        for (final day in [17, 18, 19, 20])
          for (var i = 0; i < 2; i++)
            session(
              workItemId: 'task-a',
              localStart: DateTime(2026, 8, day, 9 + (i * 3)),
              duration: const Duration(minutes: 20),
            ),
      ]);

      final insight = findInsight(report, 'routine-task:task-a');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.delegate);
      expect(insight.timeInvolved, const Duration(minutes: 160));
      expect(insight.evidence.map((e) => e.label), contains('Longest ever'));
    });

    test('spares a task that ever needed a long unbroken stretch', () {
      final report = analyse([
        for (final day in [17, 18, 19])
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, day, 9),
            duration: const Duration(minutes: 25),
          ),
        session(
          workItemId: 'task-a',
          localStart: DateTime(2026, 8, 20, 9),
          duration: const Duration(minutes: 90),
        ),
      ]);

      expect(findInsight(report, 'routine-task:task-a'), isNull);
    });

    test('does not nominate archived work for delegation', () {
      final report = analyse(
        [
          for (final day in [17, 18, 19, 20])
            session(
              workItemId: 'task-a',
              localStart: DateTime(2026, 8, day, 9),
              duration: const Duration(minutes: 25),
            ),
        ],
        workItems: {
          'task-a': workItem('task-a', archivedAt: DateTime.utc(2026, 8, 21)),
        },
      );

      expect(findInsight(report, 'routine-task:task-a'), isNull);
    });

    test('flags a whole category that never goes deep', () {
      final report = analyse(
        [
          for (final day in [17, 18, 19, 20])
            session(
              workItemId: 'task-a',
              localStart: DateTime(2026, 8, day, 9),
              duration: const Duration(minutes: 25),
              categoryId: 'cat-admin',
            ),
        ],
        categories: {'cat-admin': category('cat-admin', name: 'Admin')},
      );

      final insight = findInsight(report, 'routine-category:cat-admin');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.delegate);
      expect(insight.title, contains('Admin'));
      expect(insight.subject, PatternSubject.category);
    });
  });

  group('delegate — collaboration', () {
    test('flags how much of the window has someone else in it', () {
      final report = analyse(
        [
          for (final day in [17, 18, 19])
            session(
              workItemId: 'task-a',
              localStart: DateTime(2026, 8, day, 9),
              duration: const Duration(hours: 2),
              peopleIds: const ['person-1'],
            ),
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, 20, 9),
            duration: const Duration(hours: 1),
          ),
        ],
        people: {'person-1': person('person-1', name: 'Riya')},
      );

      final insight = findInsight(report, 'collaboration-load');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.delegate);
      expect(insight.timeInvolved, const Duration(hours: 6));
      expect(insight.title, contains('86%'));
    });

    test('reads short repeated sessions with one person as a check-in', () {
      final report = analyse(
        [
          for (final day in [17, 18, 19, 20])
            session(
              workItemId: 'task-a',
              localStart: DateTime(2026, 8, day, 9),
              duration: const Duration(minutes: 15),
              peopleIds: const ['person-1'],
            ),
        ],
        people: {'person-1': person('person-1', name: 'Riya')},
      );

      final insight = findInsight(report, 'check-in:person-1');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.delegate);
      expect(insight.title, contains('Riya'));
      expect(insight.subject, PatternSubject.person);
    });
  });

  group('plan — commitments and schedule', () {
    test('flags a real commitment that has gone quiet', () {
      final report = analyse(
        [
          for (var i = 0; i < 3; i++)
            session(
              workItemId: 'task-b',
              localStart: DateTime(2026, 8, 10, 9 + (i * 2)),
              duration: const Duration(minutes: 40),
            ),
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, 24, 9),
            duration: const Duration(hours: 3),
          ),
        ],
        workItems: {
          'task-a': workItem('task-a'),
          'task-b': workItem('task-b', name: 'Migration write-up'),
        },
        now: DateTime(2026, 8, 25, 18),
      );

      final insight = findInsight(report, 'at-risk:task-b');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.plan);
      expect(insight.title, contains('Migration write-up'));
      expect(insight.title, contains('15 days'));
      expect(insight.timeInvolved, const Duration(hours: 2));
    });

    test('does not call a single exploratory session a commitment', () {
      final report = analyse(
        [
          session(
            workItemId: 'task-b',
            localStart: DateTime(2026, 8, 10, 9),
            duration: const Duration(hours: 2),
          ),
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, 24, 9),
            duration: const Duration(hours: 3),
          ),
        ],
        workItems: {
          'task-a': workItem('task-a'),
          'task-b': workItem('task-b', name: 'Spike'),
        },
      );

      expect(findInsight(report, 'at-risk:task-b'), isNull);
    });

    test('measures evening and weekend work against the active fraction', () {
      final evening = session(
        workItemId: 'task-a',
        localStart: DateTime(2026, 8, 24, 18),
        duration: const Duration(hours: 4),
      );

      final report = analyse(
        [
          evening,
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, 22, 10),
            duration: const Duration(hours: 2),
          ),
        ],
        idleBySession: {evening.id: const Duration(hours: 1)},
      );

      final insight = findInsight(report, 'out-of-hours');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.plan);
      // 19:00-22:00 of a 4h block is three quarters of it; three quarters of
      // the 3h that was not idle is 2h15m. The Saturday adds its whole 2h.
      expect(insight.timeInvolved, const Duration(hours: 4, minutes: 15));
      expect(insight.finding, contains('at weekends'));
    });

    test('splits a Friday night that runs into Saturday', () {
      final report = analyse([
        // 2026-08-21 is a Friday: 23:00-01:00 is two out-of-hours slices, and
        // only the second one is the weekend.
        session(
          workItemId: 'task-a',
          localStart: DateTime(2026, 8, 21, 23),
          duration: const Duration(hours: 2),
        ),
      ]);

      final insight = findInsight(report, 'out-of-hours');
      expect(insight, isNotNull);
      expect(insight!.timeInvolved, const Duration(hours: 2));
      expect(
        insight.evidence.firstWhere((e) => e.label == 'At weekends').value,
        '1h',
      );
    });

    test('flags one project starving the others', () {
      final report = analyse(
        [
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, 24, 9),
            duration: const Duration(hours: 8),
          ),
          session(
            workItemId: 'task-b',
            localStart: DateTime(2026, 8, 20, 9),
            duration: const Duration(minutes: 30),
          ),
          session(
            workItemId: 'task-c',
            localStart: DateTime(2026, 8, 21, 9),
            duration: const Duration(minutes: 20),
          ),
        ],
        workItems: {
          'task-a': workItem('task-a', projectId: 'proj-1'),
          'task-b': workItem('task-b', projectId: 'proj-2'),
          'task-c': workItem('task-c', projectId: 'proj-3'),
        },
        projects: {
          'proj-1': project('proj-1', name: 'Platform'),
          'proj-2': project('proj-2', name: 'Billing'),
          'proj-3': project('proj-3', name: 'Docs'),
        },
      );

      final insight = findInsight(report, 'concentration:proj-1');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.plan);
      expect(insight.title, contains('Platform'));
      expect(insight.finding, contains('Billing'));
    });

    test('moves the band to Plan when short work is eating into it', () {
      final report = analyse([
        for (final day in [17, 18, 19])
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, day, 10),
            duration: const Duration(minutes: 90),
          ),
        // Enough short work inside the same band to spoil it.
        for (final day in [17, 18, 19])
          for (var i = 0; i < 4; i++)
            session(
              workItemId: 'task-a',
              localStart: DateTime(2026, 8, day, 11, i * 12),
              duration: const Duration(minutes: 10),
            ),
      ]);

      expect(report.rhythm.peakFocusHours, [10, 11]);

      final insight = findInsight(report, 'peak-focus');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.plan);
      expect(insight.title, contains('10am–12pm'));
    });
  });

  group('sustain — what is going right', () {
    test('credits a protected focus band rather than warning about it', () {
      final report = analyse([
        for (final day in [17, 18, 19])
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, day, 10),
            duration: const Duration(minutes: 90),
          ),
      ]);

      final insight = findInsight(report, 'peak-focus');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.sustain);
      expect(insight.title, contains('keeping 10am–12pm clear'));
      // The same band never appears in both lanes.
      expect(report.forAction(InsightAction.plan).map((i) => i.id),
          isNot(contains('peak-focus')));
    });

    test('credits deep work that is healthy with no window to compare', () {
      final report = analyse([
        session(
          workItemId: 'task-a',
          localStart: DateTime(2026, 8, 24, 9),
          duration: const Duration(minutes: 90),
        ),
        session(
          workItemId: 'task-a',
          localStart: DateTime(2026, 8, 24, 14),
          duration: const Duration(minutes: 30),
        ),
      ]);

      final insight = findInsight(report, 'deep-work-held');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.sustain);
      expect(insight.severity, InsightSeverity.informational);
      expect(insight.timeInvolved, const Duration(minutes: 90));
      expect(report.hasComparison, isFalse);
    });

    test('prefers the improvement story when a baseline exists', () {
      // Previously: mostly short work. Now: mostly blocks.
      final report = analyse(
        [
          for (final day in [17, 18, 19])
            session(
              workItemId: 'task-a',
              localStart: DateTime(2026, 8, day, 9),
              duration: const Duration(minutes: 60),
            ),
        ],
        previousSessions: [
          for (final day in [6, 7, 8])
            session(
              workItemId: 'task-a',
              localStart: DateTime(2026, 7, day, 9),
              duration: const Duration(minutes: 20),
            ),
        ],
      );

      expect(report.hasComparison, isTrue);

      final insight = findInsight(report, 'deep-work-held');
      expect(insight, isNotNull);
      expect(insight!.title, contains('up'));
      expect(insight.title, contains('points'));
      expect(
        insight.evidence.map((e) => e.label),
        contains('Last window'),
      );
    });

    test('credits switching less than the window before', () {
      final report = analyse(
        [
          for (final day in [17, 18, 19])
            for (var i = 0; i < 2; i++)
              session(
                workItemId: 'task-a',
                localStart: DateTime(2026, 8, day, 9 + (i * 4)),
                duration: const Duration(minutes: 45),
              ),
        ],
        previousSessions: [
          for (final day in [6, 7, 8])
            for (var i = 0; i < 6; i++)
              session(
                workItemId: 'task-a',
                localStart: DateTime(2026, 7, day, 9, i * 20),
                duration: const Duration(minutes: 15),
              ),
        ],
      );

      final insight = findInsight(report, 'switching-improved');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.sustain);
      expect(insight.title, contains('4.0 times a day less'));
    });

    test('says nothing about direction with no baseline to compare', () {
      final report = analyse([
        for (final day in [17, 18, 19])
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, day, 9),
            duration: const Duration(minutes: 45),
          ),
      ]);

      expect(report.hasComparison, isFalse);
      expect(findInsight(report, 'switching-improved'), isNull);
    });

    test('ignores a baseline too thin to mean anything', () {
      final report = analyse(
        [
          for (final day in [17, 18, 19])
            session(
              workItemId: 'task-a',
              localStart: DateTime(2026, 8, day, 9),
              duration: const Duration(minutes: 45),
            ),
        ],
        // A single day is not a window worth comparing against.
        previousSessions: [
          for (var i = 0; i < 6; i++)
            session(
              workItemId: 'task-a',
              localStart: DateTime(2026, 7, 6, 9, i * 20),
              duration: const Duration(minutes: 15),
            ),
        ],
      );

      expect(report.hasComparison, isFalse);
      expect(findInsight(report, 'switching-improved'), isNull);
    });

    test('credits work picked back up after going quiet', () {
      final report = analyse(
        [
          session(
            workItemId: 'task-b',
            localStart: DateTime(2026, 8, 5, 9),
            duration: const Duration(minutes: 60),
          ),
          session(
            workItemId: 'task-b',
            localStart: DateTime(2026, 8, 20, 9),
            duration: const Duration(minutes: 45),
          ),
          session(
            workItemId: 'task-b',
            localStart: DateTime(2026, 8, 24, 9),
            duration: const Duration(minutes: 30),
          ),
        ],
        workItems: {
          'task-b': workItem('task-b', name: 'Migration write-up'),
        },
      );

      final insight = findInsight(report, 'resumed:task-b');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.sustain);
      expect(insight.title, contains('Migration write-up'));
      expect(insight.title, contains('15 quiet days'));
      // Time since it resumed, not the whole investment.
      expect(insight.timeInvolved, const Duration(minutes: 75));

      // It came back, so it is no longer at risk.
      expect(findInsight(report, 'at-risk:task-b'), isNull);
    });

    test('does not call still-quiet work a comeback', () {
      final report = analyse(
        [
          session(
            workItemId: 'task-b',
            localStart: DateTime(2026, 8, 1, 9),
            duration: const Duration(minutes: 60),
          ),
          session(
            workItemId: 'task-b',
            localStart: DateTime(2026, 8, 10, 9),
            duration: const Duration(minutes: 45),
          ),
        ],
        workItems: {'task-b': workItem('task-b', name: 'Stalled thing')},
      );

      expect(findInsight(report, 'resumed:task-b'), isNull);
      expect(findInsight(report, 'at-risk:task-b'), isNotNull);
    });

    test('credits turning up on most of the working days', () {
      // Mon 10 Aug to Fri 21 Aug: ten working days, nine of them tracked.
      final report = analyse(
        [
          for (final day in [10, 11, 12, 13, 14, 17, 18, 19, 20])
            session(
              workItemId: 'task-a',
              localStart: DateTime(2026, 8, day, 9),
              duration: const Duration(minutes: 45),
            ),
        ],
        window: DateRange(
          start: DateTime(2026, 8, 10).toUtc(),
          end: DateTime(2026, 8, 21, 23, 59, 59).toUtc(),
        ),
      );

      final insight = findInsight(report, 'consistent-tracking');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.sustain);
      expect(insight.title, contains('9 of 10 working days'));
    });

    test('credits a week that stayed inside working hours', () {
      final report = analyse([
        for (final day in [17, 18, 19, 20])
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, day, 10),
            duration: const Duration(minutes: 90),
          ),
      ]);

      final insight = findInsight(report, 'hours-respected');
      expect(insight, isNotNull);
      expect(insight!.action, InsightAction.sustain);
      expect(insight.finding, contains('0%'));
      // And never alongside the warning about the same thing.
      expect(findInsight(report, 'out-of-hours'), isNull);
    });

    test('stays quiet about hours when evenings are actually being used', () {
      final report = analyse([
        for (final day in [17, 18, 19, 20])
          session(
            workItemId: 'task-a',
            localStart: DateTime(2026, 8, day, 20),
            duration: const Duration(minutes: 90),
          ),
      ]);

      expect(findInsight(report, 'hours-respected'), isNull);
      expect(findInsight(report, 'out-of-hours'), isNotNull);
    });
  });

  group('rhythm', () {
    test('summarises the shape of the working day', () {
      final report = analyse([
        session(
          workItemId: 'task-a',
          localStart: DateTime(2026, 8, 24, 9),
          duration: const Duration(minutes: 90),
        ),
        session(
          workItemId: 'task-a',
          localStart: DateTime(2026, 8, 24, 11),
          duration: const Duration(minutes: 30),
        ),
        session(
          workItemId: 'task-a',
          localStart: DateTime(2026, 8, 25, 9),
          duration: const Duration(minutes: 60),
        ),
      ]);

      final rhythm = report.rhythm;
      expect(rhythm.trackedDayCount, 2);
      expect(rhythm.switchesPerTrackedDay, 1.5);
      expect(rhythm.longestUnbrokenBlock, const Duration(minutes: 90));
      expect(rhythm.medianSessionLength, const Duration(minutes: 60));
      // Both blocks at or over 45 minutes.
      expect(rhythm.deepWorkTotal, const Duration(minutes: 150));
      expect(rhythm.deepWorkShare, closeTo(150 / 180, 0.001));
    });
  });

  group('ranking', () {
    test('caps each lane and puts the costliest finding first', () {
      const capped = WorkPatternService(
        thresholds: PatternThresholds(maxInsightsPerAction: 1),
      );

      final items = {
        for (var i = 0; i < 3; i++) 'task-$i': workItem('task-$i'),
      };

      // One task per day, so this exercises the cap on fragmentation rather
      // than tripping the switching-load detector as well.
      final report = analyse(
        [
          for (var i = 0; i < 3; i++)
            for (var visit = 0; visit < 5; visit++)
              session(
                workItemId: 'task-$i',
                localStart: DateTime(2026, 8, 17 + i, 8 + visit),
                duration: Duration(minutes: 10 + (i * 5)),
              ),
        ],
        workItems: items,
        using: capped,
      );

      final reclaim = report.forAction(InsightAction.reclaim);
      expect(reclaim, hasLength(1));
      // task-2's visits are the longest, so it carries the most time.
      expect(reclaim.single.subjectId, 'task-2');
    });
  });
}
