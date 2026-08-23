import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/features/tags/providers/tags_provider.dart';
import 'package:workpulse/features/tags/views/tag_form_dialog.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';

class TagsView extends ConsumerStatefulWidget {
  const TagsView({super.key});

  @override
  ConsumerState<TagsView> createState() => _TagsViewState();
}

class _TagsViewState extends ConsumerState<TagsView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final workItemsAsync = ref.watch(workItemsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tags',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.getColors(context).textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Flexible labels to categorize and filter your work items',
                        style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => TagFormDialog.show(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Tag'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search bar
            SizedBox(
              width: 320,
              height: 38,
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search tags...',
                  prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.getColors(context).textSecondary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tags List
            Expanded(
              child: tagsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Error loading tags: $error', style: const TextStyle(color: AppTheme.accentRed)),
                ),
                data: (tags) {
                  final filtered = tags.where((t) {
                    if (_searchQuery.isEmpty) return true;
                    return t.name.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.label_off_outlined, size: 48, color: AppTheme.getColors(context).textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? 'No tags created yet' : 'No matching tags',
                            style: TextStyle(fontSize: 16, color: AppTheme.getColors(context).textSecondary),
                          ),
                          if (_searchQuery.isEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => TagFormDialog.show(context),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create First Tag'),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: filtered.map((tag) {
                      final color = ColorUtils.parseHex(tag.colorHex);
                      final taskCount = workItemsAsync.value?.where((w) => w.tagIds.contains(tag.id)).length ?? 0;

                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.getColors(context).surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.getColors(context).divider),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tag.name,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.getColors(context).textPrimary),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.getColors(context).card,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$taskCount',
                                style: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => TagFormDialog.show(context, tag: tag),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(Icons.edit_outlined, size: 15, color: AppTheme.getColors(context).textSecondary),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppTheme.getColors(context).surface,
                                    title: Text('Delete Tag', style: TextStyle(color: AppTheme.getColors(context).textPrimary)),
                                    content: Text('Are you sure you want to delete tag "${tag.name}"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: Colors.white),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref.read(tagsProvider.notifier).deleteTag(tag.id);
                                }
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(Icons.close, size: 15, color: AppTheme.accentRed),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
