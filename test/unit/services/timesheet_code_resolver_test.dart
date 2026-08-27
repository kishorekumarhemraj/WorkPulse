import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';

void main() {
  group('TimesheetCodeResolver Unit Tests', () {
    final now = DateTime.utc(2026, 8, 27, 10, 0);

    final releaseOption1 = AttributeOption(
      id: 'opt-r24-1',
      attributeDefinitionId: 'attr-release',
      label: 'R24.1',
      value: 'r24.1',
      displayOrder: 0,
      createdAt: now,
    );

    final releaseOption2 = AttributeOption(
      id: 'opt-r24-2',
      attributeDefinitionId: 'attr-release',
      label: 'R24.2',
      value: 'r24.2',
      displayOrder: 1,
      createdAt: now,
    );

    final archivedOption = AttributeOption(
      id: 'opt-r23-old',
      attributeDefinitionId: 'attr-release',
      label: 'R23 (Archived)',
      value: 'r23',
      displayOrder: 2,
      archivedAt: now,
      createdAt: now,
    );

    final projectWithDiscriminator = Project(
      id: 'proj-lwaste',
      workspaceId: 'ws-1',
      name: 'L-Waste',
      timesheetCode: 'DEFAULT-CODE',
      codeAttributeDefinitionId: 'attr-release',
      createdAt: now,
      updatedAt: now,
    );

    final projectWithoutDiscriminator = Project(
      id: 'proj-simple',
      workspaceId: 'ws-1',
      name: 'Simple Project',
      timesheetCode: 'SIMPLE-CODE',
      createdAt: now,
      updatedAt: now,
    );

    final projectWithNoCodes = Project(
      id: 'proj-empty',
      workspaceId: 'ws-1',
      name: 'No Code Project',
      createdAt: now,
      updatedAt: now,
    );

    final resolver = TimesheetCodeResolver(
      codesByProject: {
        'proj-lwaste': {
          'opt-r24-1': 'LWASTE-241',
          'opt-r24-2': 'LWASTE-242',
          'opt-r23-old': 'LWASTE-230',
        },
      },
      optionsById: {
        'opt-r24-1': releaseOption1,
        'opt-r24-2': releaseOption2,
        'opt-r23-old': archivedOption,
      },
    );

    test('resolves optionMapping when matching project and option code exists',
        () {
      final res = resolver.resolveFor(
        project: projectWithDiscriminator,
        attributeOptionIds: {
          'attr-release': ['opt-r24-1'],
        },
      );

      expect(res.source, equals(TimesheetCodeSource.optionMapping));
      expect(res.code, equals('LWASTE-241'));
      expect(res.optionId, equals('opt-r24-1'));
      expect(res.optionLabel, equals('R24.1'));
      expect(res.isBookable, isTrue);
      expect(res.needsAttention, isFalse);
    });

    test('resolves projectDefault when discriminator attribute has no value',
        () {
      final res = resolver.resolveFor(
        project: projectWithDiscriminator,
        attributeOptionIds: {},
      );

      expect(res.source, equals(TimesheetCodeSource.projectDefault));
      expect(res.code, equals('DEFAULT-CODE'));
      expect(res.isBookable, isTrue);
      expect(res.needsAttention, isFalse);
    });

    test('resolves projectDefault when project has no discriminator configured',
        () {
      final res = resolver.resolveFor(
        project: projectWithoutDiscriminator,
        attributeOptionIds: {
          'attr-release': ['opt-r24-1'],
        },
      );

      expect(res.source, equals(TimesheetCodeSource.projectDefault));
      expect(res.code, equals('SIMPLE-CODE'));
      expect(res.isBookable, isTrue);
      expect(res.needsAttention, isFalse);
    });

    test('resolves unmappedOption when option has no mapped code in project',
        () {
      final res = resolver.resolveFor(
        project: projectWithDiscriminator,
        attributeOptionIds: {
          'attr-release': ['opt-unmapped'],
        },
      );

      expect(res.source, equals(TimesheetCodeSource.unmappedOption));
      expect(res.code, equals('DEFAULT-CODE'));
      expect(res.optionId, equals('opt-unmapped'));
      expect(res.isBookable, isTrue);
      expect(res.needsAttention, isTrue);
    });

    test('resolves missingCode when project has no mapping and no default code',
        () {
      final res = resolver.resolveFor(
        project: projectWithNoCodes,
        attributeOptionIds: {},
      );

      expect(res.source, equals(TimesheetCodeSource.missingCode));
      expect(res.code, isNull);
      expect(res.isBookable, isFalse);
      expect(res.needsAttention, isTrue);
    });

    test('resolves unknownProject when project is null', () {
      final res = resolver.resolveFor(
        project: null,
        attributeOptionIds: {
          'attr-release': ['opt-r24-1'],
        },
      );

      expect(res.source, equals(TimesheetCodeSource.unknownProject));
      expect(res.code, isNull);
      expect(res.isBookable, isFalse);
      expect(res.needsAttention, isTrue);
    });

    test('archived option still resolves to its code', () {
      final res = resolver.resolveFor(
        project: projectWithDiscriminator,
        attributeOptionIds: {
          'attr-release': ['opt-r23-old'],
        },
      );

      expect(res.source, equals(TimesheetCodeSource.optionMapping));
      expect(res.code, equals('LWASTE-230'));
      expect(res.optionLabel, equals('R23 (Archived)'));
      expect(res.isBookable, isTrue);
      expect(res.needsAttention, isFalse);
    });

    test('renaming an option label does not affect resolution', () {
      final renamedOption = AttributeOption(
        id: 'opt-r24-1',
        attributeDefinitionId: 'attr-release',
        label: 'Release 2024.1 Renamed',
        value: 'r24.1',
        displayOrder: 0,
        createdAt: now,
      );

      final resolverWithRenamed = TimesheetCodeResolver(
        codesByProject: {
          'proj-lwaste': {
            'opt-r24-1': 'LWASTE-241',
          },
        },
        optionsById: {
          'opt-r24-1': renamedOption,
        },
      );

      final res = resolverWithRenamed.resolveFor(
        project: projectWithDiscriminator,
        attributeOptionIds: {
          'attr-release': ['opt-r24-1'],
        },
      );

      expect(res.source, equals(TimesheetCodeSource.optionMapping));
      expect(res.code, equals('LWASTE-241'));
      expect(res.optionLabel, equals('Release 2024.1 Renamed'));
    });

    test(
        'a discriminator holding two option ids yields unmappedOption without guessing',
        () {
      final res = resolver.resolveFor(
        project: projectWithDiscriminator,
        attributeOptionIds: {
          'attr-release': ['opt-r24-1', 'opt-r24-2'],
        },
      );

      expect(res.source, equals(TimesheetCodeSource.unmappedOption));
      expect(res.code, equals('DEFAULT-CODE'));
      expect(res.needsAttention, isTrue);
    });

    test('a project with no discriminator and no default yields missingCode',
        () {
      final res = resolver.resolveFor(
        project: projectWithNoCodes,
        attributeOptionIds: {
          'attr-release': ['opt-r24-1'],
        },
      );

      expect(res.source, equals(TimesheetCodeSource.missingCode));
      expect(res.code, isNull);
      expect(res.needsAttention, isTrue);
    });
  });
}
