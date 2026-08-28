import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/data/repositories/sqlite_settings_repository.dart';
import 'package:workpulse/features/settings/providers/app_settings_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AppSettingsProvider Tests', () {
    late DatabaseService dbService;
    late SqliteSettingsRepository settingsRepo;
    late ProviderContainer container;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);
      settingsRepo = SqliteSettingsRepository(dbService);

      container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await dbService.close();
    });

    test('defaults to Sunday week start and 0.25 increment', () async {
      final settings = await container.read(appSettingsProvider.future);

      expect(settings.timesheetWeekStartDay, DateTime.sunday);
      expect(settings.timesheetRoundingIncrement, 0.25);
    });

    test('persists and updates timesheetWeekStartDay', () async {
      final notifier = container.read(appSettingsProvider.notifier);
      await notifier.setTimesheetWeekStartDay(DateTime.monday);

      final updated = container.read(appSettingsProvider).value;
      expect(updated?.timesheetWeekStartDay, DateTime.monday);

      // Re-read from new container to assert SQLite persistence
      final container2 = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
        ],
      );
      final persisted = await container2.read(appSettingsProvider.future);
      expect(persisted.timesheetWeekStartDay, DateTime.monday);
      container2.dispose();
    });

    test('persists and updates timesheetRoundingIncrement', () async {
      final notifier = container.read(appSettingsProvider.notifier);
      await notifier.setTimesheetRoundingIncrement(0.50);

      final updated = container.read(appSettingsProvider).value;
      expect(updated?.timesheetRoundingIncrement, 0.50);

      final container2 = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
        ],
      );
      final persisted = await container2.read(appSettingsProvider.future);
      expect(persisted.timesheetRoundingIncrement, 0.50);
      container2.dispose();
    });

    test('labels format correctly', () {
      expect(weekdayName(DateTime.saturday), 'Saturday');
      expect(weekdayName(DateTime.monday), 'Monday');
      expect(roundingIncrementLabel(0.25), '0.25 h (15 min / quarter-hour)');
      expect(roundingIncrementLabel(0.01), '0.01 h (exact to hundredth)');
    });
  });
}
