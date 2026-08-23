import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';

void main() {
  group('Domain Models Unit Tests', () {
    test('Workspace model equality and copyWith', () {
      final w1 = Workspace(
        id: 'ws-1',
        name: 'Default',
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 23, 10, 0),
      );
      final w2 = w1.copyWith(name: 'Engineering Workspace');

      expect(w1.id, equals('ws-1'));
      expect(w2.name, equals('Engineering Workspace'));
      expect(w1 == w2, isFalse);
    });

    test('Project model equality and copyWith', () {
      final p1 = Project(
        id: 'p-1',
        workspaceId: 'ws-1',
        name: 'WorkPulse Core',
        colorHex: '#007AFF',
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 23, 10, 0),
      );
      final p2 = p1.copyWith(name: 'WorkPulse Core Updated');

      expect(p1.id, equals('p-1'));
      expect(p1.workspaceId, equals('ws-1'));
      expect(p1.isArchived, isFalse);
      expect(p2.name, equals('WorkPulse Core Updated'));
      expect(p2.colorHex, equals('#007AFF'));
    });

    test('Category model equality and copyWith', () {
      final c1 = Category(
        id: 'c-1',
        workspaceId: 'ws-1',
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
      final tag = Tag(
        id: 't-1',
        workspaceId: 'ws-1',
        name: 'Deep Work',
        colorHex: '#30D158',
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
      );
      final person = Person(
        id: 'per-1',
        workspaceId: 'ws-1',
        name: 'Richard',
        email: 'richard@example.com',
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
      );

      expect(tag.name, equals('Deep Work'));
      expect(tag.workspaceId, equals('ws-1'));
      expect(person.name, equals('Richard'));
      expect(person.email, equals('richard@example.com'));
    });

    test('WorkItem model properties and relations (no hardcoded Jira)', () {
      final workItem = WorkItem(
        id: 'wi-1',
        workspaceId: 'ws-1',
        name: 'Architecture proposal',
        projectId: 'p-1',
        categoryId: 'c-1',
        notes: 'Refactor spec alignment',
        tagIds: const ['t-1', 't-2'],
        peopleIds: const ['per-1'],
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 23, 10, 0),
      );

      expect(workItem.name, equals('Architecture proposal'));
      expect(workItem.workspaceId, equals('ws-1'));
      expect(workItem.tagIds.length, equals(2));
      expect(workItem.peopleIds.first, equals('per-1'));
      expect(workItem.isArchived, isFalse);
    });

    test('Session duration math & active status', () {
      final start = DateTime.utc(2026, 8, 23, 10, 0);
      final end = DateTime.utc(2026, 8, 23, 11, 15);

      final completedSession = Session(
        id: 's-1',
        workItemId: 'wi-1',
        startTime: start,
        endTime: end,
        createdAt: start,
      );

      final activeSession = Session(
        id: 's-2',
        workItemId: 'wi-1',
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

    test('Configurable Attributes models (Definition, Option, Values)', () {
      final def = AttributeDefinition(
        id: 'ad-1',
        workspaceId: 'ws-1',
        key: 'jira_id',
        name: 'Jira ID',
        type: AttributeType.text,
        scope: AttributeScope.task,
        required: false,
        enabled: true,
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 23, 10, 0),
      );

      final opt = AttributeOption(
        id: 'ao-1',
        attributeDefinitionId: 'ad-2',
        value: 'prod',
        label: 'Production',
        colorHex: '#FF3B30',
        displayOrder: 1,
        isDefault: true,
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
      );

      final wiVal = WorkItemAttributeValue(
        id: 'wiav-1',
        workItemId: 'wi-1',
        attributeDefinitionId: 'ad-1',
        textValue: 'PROD-5678',
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 23, 10, 0),
      );

      final sessVal = SessionAttributeValue(
        id: 'sav-1',
        sessionId: 's-1',
        attributeDefinitionId: 'ad-3',
        booleanValue: true,
        createdAt: DateTime.utc(2026, 8, 23, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 23, 10, 0),
      );

      expect(def.key, equals('jira_id'));
      expect(def.type, equals(AttributeType.text));
      expect(def.scope, equals(AttributeScope.task));
      expect(opt.label, equals('Production'));
      expect(opt.isDefault, isTrue);
      expect(wiVal.textValue, equals('PROD-5678'));
      expect(sessVal.booleanValue, isTrue);
    });
  });
}
