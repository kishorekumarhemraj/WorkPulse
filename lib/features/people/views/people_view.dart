import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/person_model.dart';
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
    final peopleAsync = ref.watch(peopleProvider);
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'People',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Team members, clients, and collaborators you work with',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => PersonFormDialog.show(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Person'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search bar
            SizedBox(
              width: 320,
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search people...',
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryDark),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.dividerDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.dividerDark),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // People List
            Expanded(
              child: peopleAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Error loading people: $error', style: const TextStyle(color: AppTheme.accentRed)),
                ),
                data: (people) {
                  final filtered = people.where((p) {
                    if (_searchQuery.isEmpty) return true;
                    return p.name.toLowerCase().contains(_searchQuery) ||
                        (p.email?.toLowerCase().contains(_searchQuery) ?? false);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_outlined, size: 48, color: AppTheme.textSecondaryDark.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? 'No people added yet' : 'No matching people',
                            style: const TextStyle(fontSize: 16, color: AppTheme.textSecondaryDark),
                          ),
                          if (_searchQuery.isEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => PersonFormDialog.show(context),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add First Person'),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      mainAxisExtent: 130,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final person = filtered[index];
                      final taskCount = workItemsAsync.value?.where((w) => w.peopleIds.contains(person.id)).length ?? 0;
                      return _PersonCard(person: person, taskCount: taskCount);
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

class _PersonCard extends ConsumerWidget {
  final Person person;
  final int taskCount;

  const _PersonCard({required this.person, required this.taskCount});

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerDark, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                child: Text(
                  _getInitials(person.name),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (person.email != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        person.email!,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondaryDark),
                color: AppTheme.surfaceDark,
                onSelected: (value) async {
                  if (value == 'edit') {
                    PersonFormDialog.show(context, person: person);
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surfaceDark,
                        title: const Text('Delete Person', style: TextStyle(color: AppTheme.textPrimaryDark)),
                        content: Text('Are you sure you want to remove "${person.name}"?'),
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
                      await ref.read(peopleProvider.notifier).deletePerson(person.id);
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: AppTheme.textPrimaryDark),
                        SizedBox(width: 8),
                        Text('Edit'),
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
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$taskCount tasks assigned',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryDark),
            ),
          ),
        ],
      ),
    );
  }
}
