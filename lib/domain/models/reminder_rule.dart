/// The rules that trigger automated reminder notifications for planned work.
enum ReminderRule {
  dueMorning,
  due1h,
  overdueDaily,
  startMorning;

  String get label => switch (this) {
        ReminderRule.dueMorning => 'Morning of due date (09:00)',
        ReminderRule.due1h => '1 hour before due time',
        ReminderRule.overdueDaily => 'Daily overdue reminder (09:00)',
        ReminderRule.startMorning => 'Morning of planned start (09:00)',
      };
}
