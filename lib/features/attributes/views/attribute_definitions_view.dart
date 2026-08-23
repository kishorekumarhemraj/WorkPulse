import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/attributes/views/attribute_definition_form_dialog.dart';
import 'package:workpulse/features/attributes/views/attribute_options_editor_dialog.dart';

class AttributeDefinitionsView extends ConsumerStatefulWidget {
  const AttributeDefinitionsView({super.key});

  @override
  ConsumerState<AttributeDefinitionsView> createState() =>
      _AttributeDefinitionsViewState();
}

class _AttributeDefinitionsViewState
    extends ConsumerState<AttributeDefinitionsView> {
  String _searchQuery = '';
  AttributeScope? _scopeFilter;

  IconData _getTypeIcon(AttributeType type) {
    switch (type) {
      case AttributeType.text:
        return Icons.text_fields;
      case AttributeType.number:
        return Icons.numbers;
      case AttributeType.boolean:
        return Icons.check_box_outlined;
      case AttributeType.singleSelect:
        return Icons.radio_button_checked;
      case AttributeType.multiSelect:
        return Icons.checklist;
      case AttributeType.date:
        return Icons.calendar_today;
    }
  }

  String _formatType(AttributeType type) {
    switch (type) {
      case AttributeType.text:
        return 'TEXT';
      case AttributeType.number:
        return 'NUMBER';
      case AttributeType.boolean:
        return 'BOOLEAN';
      case AttributeType.singleSelect:
        return 'SINGLE SELECT';
      case AttributeType.multiSelect:
        return 'MULTI SELECT';
      case AttributeType.date:
        return 'DATE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final definitionsAsync = ref.watch(attributeDefinitionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.getColors(context).background,
      body: Padding(
        padding: EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Attributes',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getColors(context).textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Configure organisation-specific metadata (Jira Key, Cost Centre, Billable, etc.)',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.getColors(context)
                                .textSecondary
                                .withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => AttributeDefinitionFormDialog.show(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Attribute'),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Controls Bar (Search + Scope Filter Pills)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.getColors(context).textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search attributes by name or key...',
                        prefixIcon: Icon(Icons.search,
                            size: 18,
                            color: AppTheme.getColors(context).textSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (val) => setState(
                          () => _searchQuery = val.trim().toLowerCase()),
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // Scope Filters
                _buildScopeFilterChip(label: 'All Scopes', scope: null),
                SizedBox(width: 6),
                _buildScopeFilterChip(
                    label: 'Task Scope', scope: AttributeScope.task),
                SizedBox(width: 6),
                _buildScopeFilterChip(
                    label: 'Session Scope', scope: AttributeScope.session),
              ],
            ),
            SizedBox(height: 16),

            // Attribute Cards List
            Expanded(
              child: definitionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Error loading attributes: $e',
                        style: TextStyle(color: AppTheme.accentRed))),
                data: (definitions) {
                  var filtered =
                      definitions.where((d) => !d.isArchived).toList();

                  if (_scopeFilter != null) {
                    filtered =
                        filtered.where((d) => d.scope == _scopeFilter).toList();
                  }

                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered.where((d) {
                      return d.name.toLowerCase().contains(_searchQuery) ||
                          d.key.toLowerCase().contains(_searchQuery);
                    }).toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.tune,
                              size: 48,
                              color: AppTheme.getColors(context)
                                  .textSecondary
                                  .withValues(alpha: 0.3)),
                          SizedBox(height: 12),
                          Text('No custom attributes found',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      AppTheme.getColors(context).textPrimary)),
                          SizedBox(height: 6),
                          Text(
                              'Add custom attributes to capture organization-specific workflow data',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.getColors(context)
                                      .textSecondary)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final def = filtered[index];
                      return _buildAttributeCard(context, def);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeFilterChip(
      {required String label, required AttributeScope? scope}) {
    final isSelected = _scopeFilter == scope;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.getColors(context).divider),
      ),
      child: Material(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.2)
            : AppTheme.getColors(context).surface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () => setState(() => _scopeFilter = scope),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.getColors(context).textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttributeCard(BuildContext context, AttributeDefinition def) {
    final isSelectType = def.type == AttributeType.singleSelect ||
        def.type == AttributeType.multiSelect;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getColors(context).surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.getColors(context).divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type Icon Box
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getTypeIcon(def.type),
                color: AppTheme.primaryColor, size: 20),
          ),
          SizedBox(width: 14),

          // Main Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      def.name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getColors(context).textPrimary),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.getColors(context).card,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppTheme.getColors(context).divider),
                      ),
                      child: Text(
                        def.key,
                        style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Courier',
                            color: AppTheme.getColors(context).textSecondary),
                      ),
                    ),
                    // Scope Pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: def.scope == AttributeScope.task
                            ? AppTheme.accentPurple.withValues(alpha: 0.2)
                            : AppTheme.accentOrange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        def.scope == AttributeScope.task ? 'TASK' : 'SESSION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: def.scope == AttributeScope.task
                              ? AppTheme.accentPurple
                              : AppTheme.accentOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                if (def.description != null && def.description!.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    def.description!,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.getColors(context).textSecondary),
                  ),
                ],
                SizedBox(height: 10),

                // Properties Wrap
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildPillBadge(
                        _formatType(def.type), Colors.grey.shade400),
                    if (def.required)
                      _buildPillBadge('REQUIRED', AppTheme.accentRed),
                    if (def.showInQuickCapture)
                      _buildPillBadge('QUICK CAPTURE', AppTheme.accentGreen),
                    if (def.searchable)
                      _buildPillBadge('SEARCHABLE', AppTheme.primaryColor),
                  ],
                ),
              ],
            ),
          ),

          // Options Button (if select type)
          if (isSelectType) ...[
            OutlinedButton.icon(
              onPressed: () =>
                  AttributeOptionsEditorDialog.show(context, definition: def),
              icon: Icon(Icons.list, size: 14),
              label: Text('Options', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.getColors(context).textPrimary,
                side: BorderSide(color: AppTheme.getColors(context).divider),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
            SizedBox(width: 12),
          ],

          // Enabled Switch
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: def.enabled,
              onChanged: (val) => ref
                  .read(attributeDefinitionsProvider.notifier)
                  .toggleEnabled(def.id, val),
              activeTrackColor: AppTheme.primaryColor,
            ),
          ),

          // Actions Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert,
                size: 18, color: AppTheme.getColors(context).textSecondary),
            color: AppTheme.getColors(context).surface,
            onSelected: (val) async {
              if (val == 'edit') {
                await AttributeDefinitionFormDialog.show(context,
                    definition: def);
              } else if (val == 'options') {
                await AttributeOptionsEditorDialog.show(context,
                    definition: def);
              } else if (val == 'archive') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.getColors(context).surface,
                    title: Text('Archive Attribute',
                        style: TextStyle(
                            color: AppTheme.getColors(context).textPrimary)),
                    content: Text(
                        'Are you sure you want to archive "${def.name}"? Historical work item values will be preserved.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentRed,
                            foregroundColor: Colors.white),
                        child: Text('Archive'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(attributeDefinitionsProvider.notifier)
                      .archiveDefinition(def.id);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Edit')
                ]),
              ),
              if (isSelectType)
                const PopupMenuItem(
                  value: 'options',
                  child: Row(children: [
                    Icon(Icons.format_list_bulleted, size: 16),
                    SizedBox(width: 8),
                    Text('Manage Options')
                  ]),
                ),
              const PopupMenuItem(
                value: 'archive',
                child: Row(children: [
                  Icon(Icons.archive_outlined,
                      size: 16, color: AppTheme.accentRed),
                  SizedBox(width: 8),
                  Text('Archive', style: TextStyle(color: AppTheme.accentRed))
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
