import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/work_item_reminder_record.dart';
import 'package:workpulse/domain/repositories/reminder_repository.dart';

final remindersProvider =
    AsyncNotifierProvider<RemindersNotifier, List<WorkItemReminderRecord>>(
  RemindersNotifier.new,
);

class RemindersNotifier extends AsyncNotifier<List<WorkItemReminderRecord>> {
  ReminderRepository get _repo => ref.read(reminderRepositoryProvider);

  @override
  Future<List<WorkItemReminderRecord>> build() async {
    return _repo.getAll(limit: 50);
  }

  Future<void> markRead(String id) async {
    final now = DateTime.now().toUtc();
    await _repo.markRead(id, now);
    final current = state.value ?? [];
    state = AsyncData(
      current.map((r) => r.id == id ? r.copyWith(readAt: now) : r).toList(),
    );
  }

  Future<void> markAllRead() async {
    final now = DateTime.now().toUtc();
    await _repo.markAllRead(now);
    final current = state.value ?? [];
    state = AsyncData(
      current.map((r) => r.copyWith(readAt: now)).toList(),
    );
  }

  Future<void> snooze(String id, Duration duration) async {
    final until = DateTime.now().toUtc().add(duration);
    await _repo.snooze(id, until);
    final current = state.value ?? [];
    state = AsyncData(
      current
          .map((r) => r.id == id ? r.copyWith(snoozedUntil: until) : r)
          .toList(),
    );
  }
}

final unreadRemindersCountProvider = Provider<int>((ref) {
  final reminders = ref.watch(remindersProvider).value ?? [];
  return reminders.where((r) => !r.isRead).length;
});
