import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/app_card.dart';
import 'package:workpulse/core/widgets/confirm_dialog.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/search_field.dart';
import 'package:workpulse/core/widgets/segmented_control.dart';
import 'package:workpulse/core/widgets/skeleton_loader.dart';
import 'package:workpulse/core/widgets/status_badge.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/attributes/views/attribute_definition_form_dialog.dart';
import 'package:workpulse/features/attributes/views/attribute_options_editor_dialog.dart';

/// The scope filter's selection, including "all".
enum _ScopeFilter { all, task, session }

class AttributeDefinitionsView extends ConsumerStatefulWidget {
  const AttributeDefinitionsView({super.key});

  @override
  ConsumerState<AttributeDefinitionsView> createState() =>
      _AttributeDefinitionsViewState();
}

class _AttributeDefinitionsViewState
    extends ConsumerState<AttributeDefinitionsView> {
  String _searchQuery = '';
  _ScopeFilter _scopeFilter = _ScopeFilter.all;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final definitionsAsync = ref.watch(attributeDefinitionsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: PageScaffold(
        title: 'Custom Attributes',
        subtitle:
            'Configure organisation-specific metadata, such as an issue key, '
            'cost centre or billable flag',
        actions: [
          ElevatedButton.icon(
            onPressed: () => AttributeDefinitionFormDialog.show(context),
            icon: const Icon(Icons.add, size: IconSizes.lg),
            label: const Text('New Attribute'),
          ),
        ],
        toolbar: Wrap(
          spacing: Spacing.sm + 2,
          runSpacing: Spacing.sm + 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SearchField(
              hintText: 'Search attributes by name or key…',
              width: 320,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.trim().toLowerCase()),
            ),
            AppSegmentedControl<_ScopeFilter>(
              height: ControlSizes.toolbar,
              selected: _scopeFilter,
              onChanged: (value) => setState(() => _scopeFilter = value),
              options: const [
                SegmentOption(value: _ScopeFilter.all, label: 'All'),
                SegmentOption(value: _ScopeFilter.task, label: 'Task'),
                SegmentOption(value: _ScopeFilter.session, label: 'Session'),
              ],
            ),
          ],
        ),
        child: definitionsAsync.when(
          loading: () => const SkeletonList(itemCount: 5, itemHeight: 84),
          error: (error, _) => ErrorState(
            title: 'Could not load attributes',
            error: error,
            onRetry: () => ref.invalidate(attributeDefinitionsProvider),
          ),
          data: (definitions) {
            final filtered = definitions.where((def) {
              final matchesScope = switch (_scopeFilter) {
                _ScopeFilter.all => true,
                _ScopeFilter.task => def.scope == AttributeScope.task,
                _ScopeFilter.session => def.scope == AttributeScope.session,
              };
              if (!matchesScope) return false;
              if (_searchQuery.isEmpty) return true;
              return def.name.toLowerCase().contains(_searchQuery) ||
                  def.key.toLowerCase().contains(_searchQuery);
            }).toList();

            if (filtered.isEmpty) {
              return EmptyState(
                icon: Icons.tune,
                title: definitions.isEmpty
                    ? 'No custom attributes yet'
                    : 'No attributes match your filters',
                message: definitions.isEmpty
                    ? 'Attributes let you record metadata WorkPulse does not '
                        'model itself, and report on it.'
                    : null,
                action: definitions.isEmpty
                    ? ElevatedButton.icon(
                        onPressed: () =>
                            AttributeDefinitionFormDialog.show(context),
                        icon: const Icon(Icons.add, size: IconSizes.md),
                        label: const Text('Create First Attribute'),
                      )
                    : null,
              );
            }

            final selected =
                filtered.where((d) => d.id == _selectedId).firstOrNull;

            final list = ListView.separated(
              padding: const EdgeInsets.only(bottom: Spacing.xxl),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: Spacing.sm + 2),
              itemBuilder: (context, index) {
                final def = filtered[index];
                return _AttributeRow(
                  definition: def,
                  isSelected: def.id == _selectedId,
                  onTap: () => setState(
                    () => _selectedId = def.id == _selectedId ? null : def.id,
                  ),
                );
              },
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                // Select attributes have options worth editing alongside the
                // list; below the two-pane breakpoint the modal editor
                // (reachable from every row's menu) remains the way in.
                final showOptionsPane =
                    constraints.maxWidth >= Breakpoints.medium;
                if (!showOptionsPane) return list;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: list),
                    const SizedBox(width: Spacing.xl),
                    Expanded(
                      flex: 2,
                      child: selected == null
                          ? const _OptionsPlaceholder()
                          : _OptionsPane(definition: selected),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

IconData _typeIcon(AttributeType type) => switch (type) {
      AttributeType.text => Icons.text_fields,
      AttributeType.number => Icons.numbers,
      AttributeType.boolean => Icons.check_box_outlined,
      AttributeType.singleSelect => Icons.radio_button_checked,
      AttributeType.multiSelect => Icons.checklist,
      AttributeType.date => Icons.calendar_today,
    };

String _typeLabel(AttributeType type) => switch (type) {
      AttributeType.text => 'TEXT',
      AttributeType.number => 'NUMBER',
      AttributeType.boolean => 'BOOLEAN',
      AttributeType.singleSelect => 'SINGLE SELECT',
      AttributeType.multiSelect => 'MULTI SELECT',
      AttributeType.date => 'DATE',
    };

bool _isSelectType(AttributeType type) =>
    type == AttributeType.singleSelect || type == AttributeType.multiSelect;

class _AttributeRow extends ConsumerWidget {
  final AttributeDefinition definition;
  final bool isSelected;
  final VoidCallback onTap;

  const _AttributeRow({
    required this.definition,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final def = definition;

    return AppCard(
      radius: Radii.lg,
      isSelected: isSelected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md + 2,
        vertical: Spacing.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: colors.accentSubtle,
              borderRadius: Radii.mdAll,
            ),
            child: Icon(
              _typeIcon(def.type),
              size: IconSizes.md,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        def.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      def.key,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm - 2),
                Wrap(
                  spacing: Spacing.sm - 2,
                  runSpacing: Spacing.xs,
                  children: [
                    StatusBadge(
                      label:
                          def.scope == AttributeScope.task ? 'TASK' : 'SESSION',
                      tone: BadgeTone.accent,
                      emphasis: true,
                    ),
                    StatusBadge(label: _typeLabel(def.type), emphasis: true),
                    if (def.required)
                      const StatusBadge(
                        label: 'REQUIRED',
                        tone: BadgeTone.danger,
                        emphasis: true,
                      ),
                    if (def.showInQuickCapture)
                      const StatusBadge(
                        label: 'Quick Capture',
                        icon: Icons.bolt,
                        tone: BadgeTone.warning,
                      ),
                    if (def.reportable)
                      const StatusBadge(
                        label: 'Reportable',
                        icon: Icons.insights,
                        tone: BadgeTone.info,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          if (_isSelectType(def.type)) ...[
            OutlinedButton.icon(
              onPressed: () => AttributeOptionsEditorDialog.show(
                context,
                definition: def,
              ),
              icon: const Icon(Icons.list, size: IconSizes.sm),
              label: const Text('Options'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, ControlSizes.toolbar),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              ),
            ),
            const SizedBox(width: Spacing.sm),
          ],
          Tooltip(
            message: def.enabled ? 'Enabled' : 'Disabled',
            child: Switch(
              value: def.enabled,
              onChanged: (value) => ref
                  .read(attributeDefinitionsProvider.notifier)
                  .toggleEnabled(def.id, value),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              size: IconSizes.lg,
              color: colors.textSecondary,
            ),
            tooltip: 'More actions',
            onSelected: (value) async {
              if (value == 'edit') {
                await AttributeDefinitionFormDialog.show(
                  context,
                  definition: def,
                );
              } else if (value == 'options') {
                await AttributeOptionsEditorDialog.show(
                  context,
                  definition: def,
                );
              } else if (value == 'archive') {
                final confirmed = await confirmDestructive(
                  context,
                  title: 'Archive Attribute',
                  message: 'Are you sure you want to archive "${def.name}"? '
                      'Historical work item values will be preserved.',
                  confirmLabel: 'Archive',
                  icon: Icons.archive_outlined,
                );
                if (confirmed) {
                  await ref
                      .read(attributeDefinitionsProvider.notifier)
                      .archiveDefinition(def.id);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: IconSizes.md),
                    SizedBox(width: Spacing.sm),
                    Text('Edit'),
                  ],
                ),
              ),
              if (_isSelectType(def.type))
                const PopupMenuItem(
                  value: 'options',
                  child: Row(
                    children: [
                      Icon(Icons.list, size: IconSizes.md),
                      SizedBox(width: Spacing.sm),
                      Text('Manage Options'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: IconSizes.md,
                      color: colors.danger,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text('Archive', style: TextStyle(color: colors.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Live view of the selected attribute's options.
class _OptionsPane extends ConsumerWidget {
  final AttributeDefinition definition;

  const _OptionsPane({required this.definition});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Radii.xlAll,
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.lg,
              Spacing.md,
              Spacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(definition.name, style: theme.textTheme.titleLarge),
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        definition.description?.trim().isNotEmpty == true
                            ? definition.description!
                            : _typeLabel(definition.type).toLowerCase(),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: IconSizes.md),
                  tooltip: 'Edit attribute',
                  onPressed: () => AttributeDefinitionFormDialog.show(
                    context,
                    definition: definition,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),
          Expanded(
            child: _isSelectType(definition.type)
                ? _OptionsList(definition: definition)
                : EmptyState(
                    icon: _typeIcon(definition.type),
                    title: '${_typeLabel(definition.type)} attribute',
                    message:
                        'Only single- and multi-select attributes have a list '
                        'of options to manage.',
                  ),
          ),
        ],
      ),
    );
  }
}

class _OptionsList extends ConsumerWidget {
  final AttributeDefinition definition;

  const _OptionsList({required this.definition});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final optionsAsync =
        ref.watch(attributeOptionsFamilyProvider(definition.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: optionsAsync.when(
            loading: () => const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: ErrorState(
                title: 'Could not load options',
                error: err,
                compact: true,
                onRetry: () => ref.invalidate(
                  attributeOptionsFamilyProvider(definition.id),
                ),
              ),
            ),
            data: (options) {
              if (options.isEmpty) {
                return const EmptyState(
                  icon: Icons.list,
                  title: 'No options yet',
                  message: 'Add the values users can pick from.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(Spacing.lg),
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final color = ColorUtils.parseHex(
                    option.colorHex,
                    defaultColor: colors.textSecondary,
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: Spacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: Radii.mdAll,
                      border: Border.all(color: colors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm + 2),
                        Expanded(
                          child: Text(
                            option.label,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (option.isDefault) ...[
                          const StatusBadge(
                            label: 'Default',
                            tone: BadgeTone.accent,
                          ),
                          const SizedBox(width: Spacing.sm),
                        ],
                        Text(
                          option.value,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.textTertiary),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Divider(height: 1, color: colors.divider),
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: OutlinedButton.icon(
            onPressed: () => AttributeOptionsEditorDialog.show(
              context,
              definition: definition,
            ),
            icon: const Icon(Icons.tune, size: IconSizes.sm),
            label: const Text('Manage Options'),
          ),
        ),
      ],
    );
  }
}

class _OptionsPlaceholder extends StatelessWidget {
  const _OptionsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: Alphas.muted),
        borderRadius: Radii.xlAll,
        border: Border.all(color: colors.divider),
      ),
      child: const EmptyState(
        icon: Icons.tune,
        title: 'Select an attribute',
        message: 'Its details and select options appear here.',
      ),
    );
  }
}
