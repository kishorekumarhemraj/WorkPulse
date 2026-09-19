import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/repositories/attribute_repository.dart';
import 'package:workpulse/domain/repositories/session_repository.dart';
import 'package:workpulse/domain/repositories/work_item_repository.dart';

class WorkItemMergeRequest extends Equatable {
  /// The duplicate work item whose sessions will be moved away.
  final String sourceWorkItemId;

  /// The preserved work item into which sessions and details are merged.
  final String targetWorkItemId;

  /// Whether to append notes from the source item to the target item.
  final bool combineNotes;

  /// Whether to union tags from the source item into the target item.
  final bool combineTags;

  /// Whether to union people from the source item into the target item.
  final bool combinePeople;

  /// Whether to copy custom attribute values from the source item to the target item
  /// for attributes not already defined on the target.
  final bool combineAttributes;

  /// Whether to delete the source work item after a successful merge.
  /// If false, the source work item is archived instead.
  final bool deleteSource;

  const WorkItemMergeRequest({
    required this.sourceWorkItemId,
    required this.targetWorkItemId,
    this.combineNotes = true,
    this.combineTags = true,
    this.combinePeople = true,
    this.combineAttributes = true,
    this.deleteSource = true,
  });

  @override
  List<Object?> get props => [
        sourceWorkItemId,
        targetWorkItemId,
        combineNotes,
        combineTags,
        combinePeople,
        combineAttributes,
        deleteSource,
      ];
}

class WorkItemMergeResult extends Equatable {
  /// The updated target work item.
  final WorkItem targetWorkItem;

  /// Total number of sessions moved from source to target.
  final int sessionsMovedCount;

  /// Whether the source work item was deleted (true) or archived (false).
  final bool sourceDeleted;

  const WorkItemMergeResult({
    required this.targetWorkItem,
    required this.sessionsMovedCount,
    required this.sourceDeleted,
  });

  @override
  List<Object?> get props => [
        targetWorkItem,
        sessionsMovedCount,
        sourceDeleted,
      ];
}

class WorkItemMergeService {
  final WorkItemRepository _workItemRepository;
  final SessionRepository _sessionRepository;
  final AttributeRepository? _attributeRepository;
  final Uuid _uuid;

  WorkItemMergeService({
    required WorkItemRepository workItemRepository,
    required SessionRepository sessionRepository,
    AttributeRepository? attributeRepository,
    Uuid? uuid,
  })  : _workItemRepository = workItemRepository,
        _sessionRepository = sessionRepository,
        _attributeRepository = attributeRepository,
        _uuid = uuid ?? const Uuid();

  /// Merges [request.sourceWorkItemId] into [request.targetWorkItemId].
  ///
  /// Reassigns all sessions from source to target, merges metadata according to
  /// request options, and cleans up the source work item (delete or archive).
  Future<WorkItemMergeResult> mergeWorkItems(
    WorkItemMergeRequest request,
  ) async {
    if (request.sourceWorkItemId == request.targetWorkItemId) {
      throw const ValidationException('Cannot merge a work item into itself.');
    }

    final sourceWorkItem =
        await _workItemRepository.getById(request.sourceWorkItemId);
    if (sourceWorkItem == null) {
      throw NotFoundException(
        'Source work item with id "${request.sourceWorkItemId}" not found.',
      );
    }

    final targetWorkItem =
        await _workItemRepository.getById(request.targetWorkItemId);
    if (targetWorkItem == null) {
      throw NotFoundException(
        'Target work item with id "${request.targetWorkItemId}" not found.',
      );
    }

    if (sourceWorkItem.workspaceId != targetWorkItem.workspaceId) {
      throw const ValidationException(
        'Cannot merge work items from different workspaces.',
      );
    }

    // 1. Reassign all sessions from source to target
    final movedCount = await _sessionRepository.reassignWorkItem(
      fromWorkItemId: sourceWorkItem.id,
      toWorkItemId: targetWorkItem.id,
    );

    // 2. Combine tags
    List<String> combinedTagIds = targetWorkItem.tagIds;
    if (request.combineTags) {
      final tagSet = <String>{...targetWorkItem.tagIds, ...sourceWorkItem.tagIds};
      combinedTagIds = tagSet.toList();
    }

    // 3. Combine people
    List<String> combinedPeopleIds = targetWorkItem.peopleIds;
    if (request.combinePeople) {
      final peopleSet = <String>{
        ...targetWorkItem.peopleIds,
        ...sourceWorkItem.peopleIds,
      };
      combinedPeopleIds = peopleSet.toList();
    }

    // 4. Combine notes
    String? combinedNotes = targetWorkItem.notes;
    if (request.combineNotes &&
        sourceWorkItem.notes != null &&
        sourceWorkItem.notes!.trim().isNotEmpty) {
      final srcNote = sourceWorkItem.notes!.trim();
      if (combinedNotes == null || combinedNotes.trim().isEmpty) {
        combinedNotes = srcNote;
      } else {
        combinedNotes =
            '${combinedNotes.trim()}\n\n---\n[Merged from "${sourceWorkItem.name}"]:\n$srcNote';
      }
    }

    // 5. Update lastWorkedAt to the latest of both
    DateTime? combinedLastWorkedAt = targetWorkItem.lastWorkedAt;
    if (sourceWorkItem.lastWorkedAt != null) {
      if (combinedLastWorkedAt == null ||
          sourceWorkItem.lastWorkedAt!.isAfter(combinedLastWorkedAt)) {
        combinedLastWorkedAt = sourceWorkItem.lastWorkedAt;
      }
    }

    // 6. Persist updated target work item
    final updatedTarget = targetWorkItem.copyWith(
      tagIds: combinedTagIds,
      peopleIds: combinedPeopleIds,
      notes: combinedNotes,
      lastWorkedAt: combinedLastWorkedAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _workItemRepository.update(updatedTarget);

    // 7. Combine custom attributes
    if (request.combineAttributes && _attributeRepository != null) {
      final sourceValues =
          await _attributeRepository.getWorkItemValues(sourceWorkItem.id);
      final targetValues =
          await _attributeRepository.getWorkItemValues(targetWorkItem.id);
      final targetDefIds =
          targetValues.map((v) => v.attributeDefinitionId).toSet();

      final now = DateTime.now().toUtc();
      for (final srcVal in sourceValues) {
        if (!targetDefIds.contains(srcVal.attributeDefinitionId)) {
          final copy = WorkItemAttributeValue(
            id: _uuid.v4(),
            workItemId: targetWorkItem.id,
            attributeDefinitionId: srcVal.attributeDefinitionId,
            textValue: srcVal.textValue,
            numberValue: srcVal.numberValue,
            booleanValue: srcVal.booleanValue,
            dateValue: srcVal.dateValue,
            optionId: srcVal.optionId,
            createdAt: now,
            updatedAt: now,
          );
          await _attributeRepository.setWorkItemValue(copy);
        }
      }
    }

    // 8. Delete or archive source work item
    if (request.deleteSource) {
      await _workItemRepository.delete(sourceWorkItem.id);
    } else {
      await _workItemRepository.archive(sourceWorkItem.id);
    }

    return WorkItemMergeResult(
      targetWorkItem: updatedTarget,
      sessionsMovedCount: movedCount,
      sourceDeleted: request.deleteSource,
    );
  }
}
