import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/task_model.dart';

void main() {
  group('Domain Models Unit Tests', () {
    test('Project model equality and copyWith', () {
      final now = DateTime.utc(2026, 8, 23, 10, 0);
      const p1 = Project(
        id: 'p-1',
        name: 'OpenText Platform',
        colorHex: '#007AFF',
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 23, 10, 0),
      );
      final p2 = p1.copyWith(name: 'OpenText Platform Updated');

      expect(p1.id, equals('p-1'));
      expect(p1.isArchived, isFalse);
      expect(p2.name, equals('OpenText Platform Updated'));
      expect(p2.colorHex, equals('#007AFF'));
    });

    test('Category model equality and copyWith', () {
      const c1 = Category(
        id: 'c-1',
        name: 'Engineering',
        iconName: 'code',
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 23, 10, 0),
      );
      final c2 = c1.copyWith(archivedAt: DateTime.utc(2026, 8, 23, 12, 0));

      expect(c1.isArchived, isFalse);
      expect(c2.isArchived, isTrue);
    });

    test('Tag & Person model properties', () {
      const tag = Tag(
        id: 't-1',
        name: 'Deep Work',
        colorHex: '#30D158',
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
      );
      const person = Person(
        id: 'per-1',
        name: 'Richard',
        email: 'richard@example.com',
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
      );

      expect(tag.name, equals('Deep Work'));
      expect(person.name, equals('Richard'));
      expect(person.email, equals('richard@example.com'));
    });

    test('Session duration math & active status', () {
      final start = DateTime.utc(2026, 8, 23, 10, 0);
      final end = DateTime.utc(2026, 8, 23, 11, 15);

      final completedSession = Session(
        id: 's-1',
        taskId: 'task-1',
        startTime: start,
        endTime: end,
        createdAt: start,
      );

      final activeSession = Session(
        id: 's-2',
        taskId: 'task-1',
        startTime: start,
        endTime: null,
        createdAt: start,
      );

      expect(completedSession.isActive, isFalse);
      expect(completedSession.duration.inMinutes, equals(75));
      expect(activeSession.isActive, isTrue);
    });

    test('IdlePeriod resolution parsing and duration math', () {
      final start = DateTime.utc(2026, 8, 23, 10, 15);
      final end = DateTime.utc(2026, 8, 23, 10, 45);

      final idle = IdlePeriod(
        id: 'idle-1',
        sessionId: 's-1',
        startTime: start,
        endTime: end,
        resolution: IdleResolution.fromString('mark_idle'),
        createdAt: end,
      );

      expect(idle.resolution, equals(IdleResolution.markIdle));
      expect(idle.duration.inMinutes, equals(30));
    });

    test('Task model properties and relations', () {
      const task = Task(
        id: 'task-1',
        name: 'Architecture proposal',
        projectId: 'p-1',
        categoryId: 'c-1',
        jiraId: 'PLAT-1234',
        tagIds: ['t-1', 't-2'],
        peopleIds: ['per-1'],
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 23, 10, 0),
      );

      expect(task.name, equals('Architecture proposal'));
      expect(task.jiraId, equals('PLAT-1234'));
      expect(task.tagIds.length, equals(2));
      expect(task.peopleIds.first, equals('per-1'));
    });
  });
}
