import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/widgets/app_snack_bar.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/domain/services/work_item_merge_service.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/tasks/providers/task_sessions_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/providers/task_duration_provider.dart';

/// Dialog enabling users to merge two duplicate or related work items.
///
/// Moves all tracked sessions from the source item into the target item,
/// combines metadata (tags, people, notes, attributes), and safely cleans up
/// or archives the source item.
class WorkItemMergeDialog extends ConsumerStatefulWidget {
  final WorkItem initialSourceItem;
  final WorkItem? initialTargetItem;

  const WorkItemMergeDialog({
    super.key,
    required this.initialSourceItem,
    this.initialTargetItem,
  });

  static Future<WorkItemMergeResult?> show(
    BuildContext context, {
    required WorkItem sourceItem,
    WorkItem? targetItem,
  }) {
    return showDialog<WorkItemMergeResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) => WorkItemMergeDialog(
        initialSourceItem: sourceItem,
        initialTargetItem: targetItem,
      ),
    );
  }

  @override
  ConsumerState<WorkItemMergeDialog> createState() =>
      _WorkItemMergeDialogState();
}

class _WorkItemMergeDialogState extends ConsumerState<WorkItemMergeDialog> {
  late WorkItem _sourceItem;
  WorkItem? _targetItem;

  bool _combineNotes = true;
  bool _combineTags = true;
  bool _combinePeople = true;
  bool _combineAttributes = true;
  bool _deleteSource = true;

  bool _isSubmitting = false;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _sourceItem = widget.initialSourceItem;
    _targetItem = widget.initialTargetItem;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _swapItems() {
    if (_targetItem == null) return;
    setState(() {
      final temp = _sourceItem;
      _sourceItem = _targetItem!;
      _targetItem = temp;
      _errorMessage = null;
    });
  }

  Future<void> _submitMerge() async {
    if (_targetItem == null) {
      setState(() {
        _errorMessage = 'Please select a destination work item to merge into.';
      });
      return;
    }

    if (_targetItem!.id == _sourceItem.id) {
      setState(() {
        _errorMessage = 'Cannot merge a work item into itself.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final request = WorkItemMergeRequest(
        sourceWorkItemId: _sourceItem.id,
        targetWorkItemId: _targetItem!.id,
        combineNotes: _combineNotes,
        combineTags: _combineTags,
        combinePeople: _combinePeople,
        combineAttributes: _combineAttributes,
        deleteSource: _deleteSource,
      );

      final result =
          await ref.read(workItemsProvider.notifier).mergeWorkItems(request);

      if (mounted) {
        Navigator.of(context).pop(result);
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            message:
                'Successfully merged "${_sourceItem.name}" into "${result.targetWorkItem.name}". '
                '${result.sessionsMovedCount} session${result.sessionsMovedCount == 1 ? '' : 's'} moved.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final projectsAsync = ref.watch(projectsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final allItemsAsync = ref.watch(unfilteredWorkItemsProvider);

    final projectMap = {
      for (final p in projectsAsync.value ?? <Project>[]) p.id: p,
    };
    final categoryMap = {
      for (final c in categoriesAsync.value ?? <Category>[]) c.id: c,
    };

    final availableCandidates = (allItemsAsync.value ?? <WorkItem>[])
        .where((item) => item.id != _sourceItem.id)
        .where((item) {
      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final matchName = item.name.toLowerCase().contains(query);
      final projectName =
          projectMap[item.projectId]?.name.toLowerCase() ?? '';
      final categoryName =
          categoryMap[item.categoryId]?.name.toLowerCase() ?? '';
      return matchName ||
          projectName.contains(query) ||
          categoryName.contains(query);
    }).toList();

    return AppDialog(
      title: 'Merge Work Items',
      subtitle:
          'Consolidate duplicate work items and combine their tracked time.',
      icon: Icons.merge_type,
      width: DialogWidth.large,
      onSubmit: _isSubmitting || _targetItem == null ? null : _submitMerge,
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _targetItem == null ? null : _submitMerge,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: colors.onAccent,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.xl,
              vertical: Spacing.md,
            ),
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.onAccent),
                  ),
                )
              : const Text('Merge Work Items'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              margin: const EdgeInsets.only(bottom: Spacing.lg),
              decoration: BoxDecoration(
                color: colors.dangerSubtle,
                borderRadius: Radii.mdAll,
                border: Border.all(
                  color: colors.danger.withValues(alpha: Alphas.subtle),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colors.danger, size: 20),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Visual merge mapping card
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: Radii.lgAll,
              border: Border.all(color: colors.divider),
            ),
            child: Column(
              children: [
                // SOURCE ITEM CARD
                _ItemCard(
                  title: 'Source Work Item (will be deleted / archived)',
                  badgeLabel: _deleteSource ? 'WILL BE DELETED' : 'WILL BE ARCHIVED',
                  badgeColor: colors.danger,
                  badgeBgColor: colors.dangerSubtle,
                  item: _sourceItem,
                  projectName: projectMap[_sourceItem.projectId]?.name,
                  projectColor: ColorUtils.parseHex(
                      projectMap[_sourceItem.projectId]?.colorHex),
                  categoryName: categoryMap[_sourceItem.categoryId]?.name,
                ),

                const SizedBox(height: Spacing.md),

                // FLOW ARROW & SWAP BUTTON
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 1,
                      width: 80,
                      color: colors.divider,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Tooltip(
                      message: _targetItem != null
                          ? 'Swap source and destination'
                          : 'Select destination first to enable swap',
                      child: OutlinedButton.icon(
                        onPressed: _targetItem == null ? null : _swapItems,
                        icon: const Icon(Icons.swap_vert, size: 16),
                        label: const Text('Swap Direction'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.md,
                            vertical: Spacing.xs,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Container(
                      height: 1,
                      width: 80,
                      color: colors.divider,
                    ),
                  ],
                ),

                const SizedBox(height: Spacing.md),

                // TARGET ITEM CARD OR SELECTION
                if (_targetItem != null) ...[
                  _ItemCard(
                    title: 'Destination Work Item (will keep & receive sessions)',
                    badgeLabel: 'DESTINATION',
                    badgeColor: colors.success,
                    badgeBgColor: colors.successSubtle,
                    item: _targetItem!,
                    projectName: projectMap[_targetItem!.projectId]?.name,
                    projectColor: ColorUtils.parseHex(
                        projectMap[_targetItem!.projectId]?.colorHex),
                    categoryName: categoryMap[_targetItem!.categoryId]?.name,
                    onClear: () => setState(() => _targetItem = null),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: Radii.mdAll,
                      border: Border.all(
                        color: colors.accent.withValues(alpha: Alphas.muted),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.call_merge,
                                color: colors.accent, size: 18),
                            const SizedBox(width: Spacing.sm),
                            Text(
                              'Select Destination Work Item',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.sm),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search work item by name, project, category…',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md,
                              vertical: Spacing.sm,
                            ),
                          ),
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                        ),
                        const SizedBox(height: Spacing.sm),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: availableCandidates.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(Spacing.md),
                                  child: Center(
                                    child: Text(
                                      'No other work items found in this workspace.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colors.textTertiary,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: availableCandidates.length,
                                  separatorBuilder: (_, __) =>
                                      Divider(height: 1, color: colors.divider),
                                  itemBuilder: (context, index) {
                                    final item = availableCandidates[index];
                                    final proj = projectMap[item.projectId];
                                    final cat = categoryMap[item.categoryId];
                                    return Material(
                                      type: MaterialType.transparency,
                                      child: ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        title: Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${proj?.name ?? 'No project'} • ${cat?.name ?? 'No category'}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colors.textTertiary,
                                          ),
                                        ),
                                        trailing: TextButton(
                                          onPressed: () {
                                            setState(() => _targetItem = item);
                                          },
                                          child: const Text('Select'),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: Spacing.lg),

          // MERGE SUMMARY & IMPACT PREVIEW
          if (_targetItem != null) ...[
            _MergeImpactPreview(
              sourceItem: _sourceItem,
              targetItem: _targetItem!,
            ),
            const SizedBox(height: Spacing.lg),
          ],

          // OPTIONS
          Text(
            'Merge Options',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: Spacing.xs),

          CheckboxListTile(
            value: _combineNotes,
            onChanged: (val) => setState(() => _combineNotes = val ?? true),
            title: const Text('Combine Notes', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              'Appends notes from the source item to the destination item.',
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            value: _combineTags,
            onChanged: (val) => setState(() => _combineTags = val ?? true),
            title: const Text('Combine Tags', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              'Adds all tags from the source item to the destination item.',
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            value: _combinePeople,
            onChanged: (val) => setState(() => _combinePeople = val ?? true),
            title: const Text('Combine People', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              'Assigns all people from the source item to the destination item.',
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            value: _combineAttributes,
            onChanged: (val) => setState(() => _combineAttributes = val ?? true),
            title: const Text('Combine Custom Attributes',
                style: TextStyle(fontSize: 13)),
            subtitle: Text(
              'Copies non-conflicting custom field values into the destination.',
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            value: _deleteSource,
            onChanged: (val) => setState(() => _deleteSource = val ?? true),
            title: Text(
              _deleteSource
                  ? 'Delete source work item permanently'
                  : 'Archive source work item instead of deleting',
              style: TextStyle(
                fontSize: 13,
                color: _deleteSource ? colors.danger : colors.textPrimary,
                fontWeight: _deleteSource ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              _deleteSource
                  ? 'All sessions are safely moved before deletion. No session data is lost.'
                  : 'The source work item will be marked as archived after its sessions are moved.',
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final String title;
  final String badgeLabel;
  final Color badgeColor;
  final Color badgeBgColor;
  final WorkItem item;
  final String? projectName;
  final Color? projectColor;
  final String? categoryName;
  final VoidCallback? onClear;

  const _ItemCard({
    required this.title,
    required this.badgeLabel,
    required this.badgeColor,
    required this.badgeBgColor,
    required this.item,
    this.projectName,
    this.projectColor,
    this.categoryName,
    this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sessionsAsync = ref.watch(sessionsForWorkItemProvider(item.id));
    final durationAsync = ref.watch(taskTotalDurationProvider(item.id));

    final sessionCount = sessionsAsync.value?.length ?? 0;
    final totalDuration = durationAsync.value ?? Duration.zero;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: Radii.xsAll,
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onClear != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: 'Change destination',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClear,
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              if (projectColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: projectColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                projectName ?? 'No Project',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(width: Spacing.md),
              Icon(Icons.folder_outlined,
                  size: 13, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                categoryName ?? 'No Category',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const Spacer(),
              Icon(Icons.timer_outlined, size: 14, color: colors.textTertiary),
              const SizedBox(width: 4),
              Text(
                '$sessionCount session${sessionCount == 1 ? '' : 's'} (${TimerService.formatDuration(totalDuration, includeSeconds: false)})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MergeImpactPreview extends ConsumerWidget {
  final WorkItem sourceItem;
  final WorkItem targetItem;

  const _MergeImpactPreview({
    required this.sourceItem,
    required this.targetItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    final srcSessions =
        ref.watch(sessionsForWorkItemProvider(sourceItem.id)).value?.length ?? 0;
    final tgtSessions =
        ref.watch(sessionsForWorkItemProvider(targetItem.id)).value?.length ?? 0;
    final srcDuration =
        ref.watch(taskTotalDurationProvider(sourceItem.id)).value ?? Duration.zero;
    final tgtDuration =
        ref.watch(taskTotalDurationProvider(targetItem.id)).value ?? Duration.zero;

    final combinedSessions = srcSessions + tgtSessions;
    final combinedDuration = srcDuration + tgtDuration;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: Alphas.subtle),
        borderRadius: Radii.mdAll,
        border: Border.all(
          color: colors.accent.withValues(alpha: Alphas.muted),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.insights, color: colors.accent, size: 20),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impact Summary',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Moving $srcSessions session${srcSessions == 1 ? '' : 's'} (${TimerService.formatDuration(srcDuration, includeSeconds: false)}) to "${targetItem.name}". '
                  'Destination will total $combinedSessions sessions (${TimerService.formatDuration(combinedDuration, includeSeconds: false)}).',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
