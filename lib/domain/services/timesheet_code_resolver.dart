import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/project_model.dart';

enum TimesheetCodeSource {
  /// Matched a (project, option) mapping. The normal, correct case.
  optionMapping,

  /// The project varies its code but this task has no value for the
  /// discriminator, so the project's default applies.
  projectDefault,

  /// The task named an option the project has no mapping for. The default
  /// still applies, but this is a configuration gap and is reported as one.
  unmappedOption,

  /// Nothing to book against: no mapping and no default.
  missingCode,

  /// The record has no project at all.
  unknownProject,
}

class TimesheetCodeResolution extends Equatable {
  final String? code;
  final TimesheetCodeSource source;
  final String? optionId;
  final String? optionLabel;

  const TimesheetCodeResolution({
    this.code,
    required this.source,
    this.optionId,
    this.optionLabel,
  });

  bool get isBookable => code != null && code!.trim().isNotEmpty;

  /// Whether this resolution is something the user should go and fix.
  bool get needsAttention =>
      source == TimesheetCodeSource.unmappedOption ||
      source == TimesheetCodeSource.missingCode ||
      source == TimesheetCodeSource.unknownProject;

  @override
  List<Object?> get props => [code, source, optionId, optionLabel];
}

class TimesheetCodeResolver {
  /// projectId -> (attributeOptionId -> code)
  final Map<String, Map<String, String>> _codesByProject;

  /// optionId -> option, including archived ones (see F5).
  final Map<String, AttributeOption> _optionsById;

  const TimesheetCodeResolver({
    Map<String, Map<String, String>> codesByProject = const {},
    Map<String, AttributeOption> optionsById = const {},
  })  : _codesByProject = codesByProject,
        _optionsById = optionsById;

  TimesheetCodeResolution resolveFor({
    required Project? project,
    required Map<String, List<String>> attributeOptionIds,
  }) {
    if (project == null) {
      return const TimesheetCodeResolution(
        code: null,
        source: TimesheetCodeSource.unknownProject,
      );
    }

    final defaultCode = project.timesheetCode?.trim().isNotEmpty == true
        ? project.timesheetCode!.trim()
        : null;
    final discriminator = project.codeAttributeDefinitionId;

    if (discriminator == null || discriminator.trim().isEmpty) {
      if (defaultCode != null) {
        return TimesheetCodeResolution(
          code: defaultCode,
          source: TimesheetCodeSource.projectDefault,
        );
      } else {
        return const TimesheetCodeResolution(
          code: null,
          source: TimesheetCodeSource.missingCode,
        );
      }
    }

    final ids = attributeOptionIds[discriminator] ?? const [];
    if (ids.isEmpty) {
      if (defaultCode != null) {
        return TimesheetCodeResolution(
          code: defaultCode,
          source: TimesheetCodeSource.projectDefault,
        );
      } else {
        return const TimesheetCodeResolution(
          code: null,
          source: TimesheetCodeSource.missingCode,
        );
      }
    }

    if (ids.length != 1) {
      // Multiple options selected for discriminator
      if (defaultCode != null) {
        return TimesheetCodeResolution(
          code: defaultCode,
          source: TimesheetCodeSource.unmappedOption,
        );
      } else {
        return const TimesheetCodeResolution(
          code: null,
          source: TimesheetCodeSource.missingCode,
        );
      }
    }

    final optionId = ids.single;
    final option = _optionsById[optionId];
    final optionLabel = option?.label;
    final mappedCode = _codesByProject[project.id]?[optionId]?.trim();

    if (mappedCode != null && mappedCode.isNotEmpty) {
      return TimesheetCodeResolution(
        code: mappedCode,
        source: TimesheetCodeSource.optionMapping,
        optionId: optionId,
        optionLabel: optionLabel,
      );
    }

    if (defaultCode != null) {
      return TimesheetCodeResolution(
        code: defaultCode,
        source: TimesheetCodeSource.unmappedOption,
        optionId: optionId,
        optionLabel: optionLabel,
      );
    } else {
      return TimesheetCodeResolution(
        code: null,
        source: TimesheetCodeSource.missingCode,
        optionId: optionId,
        optionLabel: optionLabel,
      );
    }
  }
}
