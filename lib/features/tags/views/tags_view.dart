import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/confirm_dialog.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/entity_grid.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/search_field.dart';
import 'package:workpulse/core/widgets/skeleton_loader.dart';
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
    final colors = context.colors;
    final tagsAsync = ref.watch(tagsProvider);
    final workItemsAsync = ref.watch(workItemsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: PageScaffold(
        title: 'Tags',
        subtitle: 'Cross-cutting labels for filtering and reporting on work',
        actions: [
          ElevatedButton.icon(
            onPressed: () => TagFormDialog.show(context),
            icon: const Icon(Icons.add, size: IconSizes.lg),
            label: const Text('New Tag'),
          ),
        ],
        toolbar: SearchField(
          hintText: 'Search tags…',
          width: 300,
          onChanged: (value) =>
              setState(() => _searchQuery = value.trim().toLowerCase()),
        ),
        child: tagsAsync.when(
          loading: () =>
              const SkeletonGrid(maxCrossAxisExtent: 240, itemHeight: 96),
          error: (error, _) => ErrorState(
            title: 'Could not load tags',
            error: error,
            onRetry: () => ref.invalidate(tagsProvider),
          ),
          data: (tags) {
            final filtered = tags.where((t) {
              if (_searchQuery.isEmpty) return true;
              return t.name.toLowerCase().contains(_searchQuery);
            }).toList();

            if (filtered.isEmpty) {
              return EmptyState(
                icon: Icons.label_outline,
                title: _searchQuery.isEmpty
                    ? 'No tags yet'
                    : 'No tags match "$_searchQuery"',
                message: _searchQuery.isEmpty
                    ? 'Tags cut across projects and categories — useful for '
                        'things like "urgent" or "billable".'
                    : null,
                action: _searchQuery.isEmpty
                    ? ElevatedButton.icon(
                        onPressed: () => TagFormDialog.show(context),
                        icon: const Icon(Icons.add, size: IconSizes.md),
                        label: const Text('Create First Tag'),
                      )
                    : null,
              );
            }

            // Tags carry less information than the other library entities, so
            // their cards are smaller and pack more densely — but they use the
            // same card, so hover, menus and counts behave identically.
            return EntityGrid(
              maxCardWidth: 250,
              cardHeight: 104,
              children: [
                for (final tag in filtered)
                  EntityCard(
                    name: tag.name,
                    color: ColorUtils.parseHex(tag.colorHex),
                    count: workItemsAsync.value
                            ?.where((w) => w.tagIds.contains(tag.id))
                            .length ??
                        0,
                    countLabel: 'work items',
                    onTap: () => TagFormDialog.show(context, tag: tag),
                    actions: [
                      EntityAction(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        onSelected: () => TagFormDialog.show(context, tag: tag),
                      ),
                      EntityAction(
                        label: 'Delete',
                        icon: Icons.delete_outline,
                        isDestructive: true,
                        onSelected: () async {
                          final confirmed = await confirmDestructive(
                            context,
                            title: 'Delete Tag',
                            message:
                                'Are you sure you want to delete tag "${tag.name}"? '
                                'It will be removed from any work items using it.',
                          );
                          if (confirmed) {
                            await ref
                                .read(tagsProvider.notifier)
                                .deleteTag(tag.id);
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
