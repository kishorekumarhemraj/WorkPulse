import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/widgets/confirm_dialog.dart';
import 'package:workpulse/core/widgets/empty_state.dart';
import 'package:workpulse/core/widgets/entity_grid.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/page_header.dart';
import 'package:workpulse/core/widgets/search_field.dart';
import 'package:workpulse/core/widgets/skeleton_loader.dart';
import 'package:workpulse/features/people/providers/people_provider.dart';
import 'package:workpulse/features/people/views/person_form_dialog.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';

class PeopleView extends ConsumerStatefulWidget {
  const PeopleView({super.key});

  @override
  ConsumerState<PeopleView> createState() => _PeopleViewState();
}

class _PeopleViewState extends ConsumerState<PeopleView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final peopleAsync = ref.watch(peopleProvider);
    final workItemsAsync = ref.watch(workItemsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: PageScaffold(
        title: 'People',
        subtitle: 'Collaborators you can attribute work items and sessions to',
        actions: [
          ElevatedButton.icon(
            onPressed: () => PersonFormDialog.show(context),
            icon: const Icon(Icons.add, size: IconSizes.lg),
            label: const Text('New Person'),
          ),
        ],
        toolbar: SearchField(
          hintText: 'Search people…',
          width: 300,
          onChanged: (value) =>
              setState(() => _searchQuery = value.trim().toLowerCase()),
        ),
        child: peopleAsync.when(
          loading: () => const SkeletonGrid(),
          error: (error, _) => ErrorState(
            title: 'Could not load people',
            error: error,
            onRetry: () => ref.invalidate(peopleProvider),
          ),
          data: (people) {
            final filtered = people.where((p) {
              if (_searchQuery.isEmpty) return true;
              return p.name.toLowerCase().contains(_searchQuery) ||
                  (p.email?.toLowerCase().contains(_searchQuery) ?? false) ||
                  (p.team?.toLowerCase().contains(_searchQuery) ?? false);
            }).toList();

            if (filtered.isEmpty) {
              return EmptyState(
                icon: Icons.people_outline,
                title: _searchQuery.isEmpty
                    ? 'No people yet'
                    : 'No people match "$_searchQuery"',
                message: _searchQuery.isEmpty
                    ? 'Add the people you work with to attribute sessions to '
                        'them and see time split by person.'
                    : null,
                action: _searchQuery.isEmpty
                    ? ElevatedButton.icon(
                        onPressed: () => PersonFormDialog.show(context),
                        icon: const Icon(Icons.add, size: IconSizes.md),
                        label: const Text('Create First Person'),
                      )
                    : null,
              );
            }

            return EntityGrid(
              cardHeight: 148,
              children: [
                for (final person in filtered)
                  EntityCard(
                    name: person.name,
                    icon: Icons.person_outline,
                    details: [
                      if ((person.team ?? '').isNotEmpty)
                        EntityDetail(
                          icon: Icons.groups_outlined,
                          value: person.team!,
                        ),
                      if ((person.email ?? '').isNotEmpty)
                        EntityDetail(
                          icon: Icons.mail_outline,
                          value: person.email!,
                        ),
                    ],
                    count: workItemsAsync.value
                            ?.where((w) => w.peopleIds.contains(person.id))
                            .length ??
                        0,
                    countLabel: 'work items',
                    onTap: () => PersonFormDialog.show(context, person: person),
                    actions: [
                      EntityAction(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        onSelected: () =>
                            PersonFormDialog.show(context, person: person),
                      ),
                      EntityAction(
                        label: 'Delete',
                        icon: Icons.delete_outline,
                        isDestructive: true,
                        onSelected: () async {
                          final confirmed = await confirmDestructive(
                            context,
                            title: 'Delete Person',
                            message:
                                'Are you sure you want to delete "${person.name}"? '
                                'This action cannot be undone.',
                          );
                          if (confirmed) {
                            await ref
                                .read(peopleProvider.notifier)
                                .deletePerson(person.id);
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
