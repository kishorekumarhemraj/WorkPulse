import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/icon_utils.dart';
import 'package:workpulse/core/widgets/confirm_dialog.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/entity_grid.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/search_field.dart';
import 'package:workpulse/core/widgets/skeleton_loader.dart';
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
    final colors = context.colors;
    final categoriesAsync = ref.watch(categoriesProvider);
    final workItemsAsync = ref.watch(workItemsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: PageScaffold(
        title: 'Categories',
        subtitle:
            'Classify the kind of work you do, such as coding or meetings',
        actions: [
          ElevatedButton.icon(
            onPressed: () => CategoryFormDialog.show(context),
            icon: const Icon(Icons.add, size: IconSizes.lg),
            label: const Text('New Category'),
          ),
        ],
        toolbar: SearchField(
          hintText: 'Search categories…',
          width: 300,
          onChanged: (value) =>
              setState(() => _searchQuery = value.trim().toLowerCase()),
        ),
        child: categoriesAsync.when(
          loading: () => const SkeletonGrid(),
          error: (error, _) => ErrorState(
            title: 'Could not load categories',
            error: error,
            onRetry: () => ref.invalidate(categoriesProvider),
          ),
          data: (categories) {
            final filtered = categories.where((c) {
              if (_searchQuery.isEmpty) return true;
              return c.name.toLowerCase().contains(_searchQuery);
            }).toList();

            if (filtered.isEmpty) {
              return EmptyState(
                icon: Icons.category_outlined,
                title: _searchQuery.isEmpty
                    ? 'No categories yet'
                    : 'No categories match "$_searchQuery"',
                message: _searchQuery.isEmpty
                    ? 'Categories describe the type of work, and drive the '
                        '"Time by Category" breakdown on the dashboard.'
                    : null,
                action: _searchQuery.isEmpty
                    ? ElevatedButton.icon(
                        onPressed: () => CategoryFormDialog.show(context),
                        icon: const Icon(Icons.add, size: IconSizes.md),
                        label: const Text('Create First Category'),
                      )
                    : null,
              );
            }

            return EntityGrid(
              cardHeight: 132,
              children: [
                for (final category in filtered)
                  EntityCard(
                    name: category.name,
                    icon: IconUtils.getIcon(category.iconName),
                    count: workItemsAsync.value
                            ?.where((w) => w.categoryId == category.id)
                            .length ??
                        0,
                    countLabel: 'work items',
                    onTap: () =>
                        CategoryFormDialog.show(context, category: category),
                    actions: [
                      EntityAction(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        onSelected: () => CategoryFormDialog.show(
                          context,
                          category: category,
                        ),
                      ),
                      EntityAction(
                        label: 'Archive',
                        icon: Icons.archive_outlined,
                        onSelected: () => ref
                            .read(categoriesProvider.notifier)
                            .archiveCategory(category.id),
                      ),
                      EntityAction(
                        label: 'Delete',
                        icon: Icons.delete_outline,
                        isDestructive: true,
                        onSelected: () async {
                          final confirmed = await confirmDestructive(
                            context,
                            title: 'Delete Category',
                            message:
                                'Are you sure you want to delete "${category.name}"? '
                                'This action cannot be undone.',
                          );
                          if (confirmed) {
                            await ref
                                .read(categoriesProvider.notifier)
                                .deleteCategory(category.id);
                          }
                        },
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
