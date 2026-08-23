import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/categories/views/category_form_dialog.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';

class CategoriesView extends ConsumerStatefulWidget {
  const CategoriesView({super.key});

  @override
  ConsumerState<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends ConsumerState<CategoriesView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
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
                        'Categories',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.getColors(context).textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Functional classifications for your tracked time and work',
                        style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => CategoryFormDialog.show(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Category'),
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
                  hintText: 'Search categories...',
                  prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.getColors(context).textSecondary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Categories List
            Expanded(
              child: categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Error loading categories: $error', style: const TextStyle(color: AppTheme.accentRed)),
                ),
                data: (categories) {
                  final filtered = categories.where((c) {
                    if (_searchQuery.isEmpty) return true;
                    return c.name.toLowerCase().contains(_searchQuery) ||
                        (c.description?.toLowerCase().contains(_searchQuery) ?? false);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_outlined, size: 48, color: AppTheme.getColors(context).textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? 'No categories found' : 'No matching categories',
                            style: TextStyle(fontSize: 16, color: AppTheme.getColors(context).textSecondary),
                          ),
                          if (_searchQuery.isEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => CategoryFormDialog.show(context),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create First Category'),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      mainAxisExtent: 160,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final category = filtered[index];
                      final taskCount = workItemsAsync.value?.where((w) => w.categoryId == category.id).length ?? 0;
                      return _CategoryCard(category: category, taskCount: taskCount);
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
}

class _CategoryCard extends ConsumerWidget {
  final Category category;
  final int taskCount;

  const _CategoryCard({required this.category, required this.taskCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getColors(context).surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.getColors(context).divider, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  IconUtils.getIcon(category.iconName),
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.getColors(context).textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: AppTheme.getColors(context).textSecondary),
                color: AppTheme.getColors(context).surface,
                onSelected: (value) async {
                  if (value == 'edit') {
                    await CategoryFormDialog.show(context, category: category);
                  } else if (value == 'archive') {
                    await ref.read(categoriesProvider.notifier).archiveCategory(category.id);
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.getColors(context).surface,
                        title: Text('Delete Category', style: TextStyle(color: AppTheme.getColors(context).textPrimary)),
                        content: Text('Are you sure you want to delete "${category.name}"? This action cannot be undone.'),
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
                      await ref.read(categoriesProvider.notifier).deleteCategory(category.id);
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: AppTheme.getColors(context).textPrimary),
                        const SizedBox(width: 8),
                        const Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 16, color: AppTheme.getColors(context).textPrimary),
                        const SizedBox(width: 8),
                        const Text('Archive'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: AppTheme.accentRed),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppTheme.accentRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              category.description ?? 'No description provided.',
              style: TextStyle(
                fontSize: 12,
                color: category.description != null ? AppTheme.getColors(context).textSecondary : AppTheme.getColors(context).textSecondary.withValues(alpha: 0.5),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Divider(color: AppTheme.getColors(context).divider, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.getColors(context).card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$taskCount tasks',
                  style: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Updated ${_formatDate(category.updatedAt)}',
                  style: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
