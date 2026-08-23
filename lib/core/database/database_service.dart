import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/constants/app_constants.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';

class DatabaseService {
  static DatabaseService? _instance;
  Database? _db;

  DatabaseService._();

  factory DatabaseService() {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  /// Construct with an existing Database instance (ideal for in-memory testing)
  DatabaseService.withDatabase(Database database) {
    _db = database;
  }

  Database get database {
    if (_db == null) {
      throw const AppDatabaseException(
          'Database has not been initialized. Call initialize() first.');
    }
    return _db!;
  }

  bool get isInitialized => _db != null;

  /// Initialize SQLite database on macOS / Desktop
  Future<Database> initialize(
      {String? customPath, bool inMemory = false}) async {
    if (_db != null) {
      return _db!;
    }

    // Initialize FFI for macOS desktop
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    if (inMemory) {
      _db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: AppConstants.dbVersion,
          onConfigure: _onConfigure,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
      return _db!;
    }

    final dbPath = customPath ?? await _getDefaultDatabasePath();
    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppConstants.dbVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );

    return _db!;
  }

  Future<void> _onConfigure(Database db) async {
    // Enforce foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    await MigrationV1.execute(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations will be dispatched here incrementally
  }

  Future<String> _getDefaultDatabasePath() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(appSupportDir.path, 'WorkPulse'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    return p.join(dbDir.path, AppConstants.dbName);
  }

  /// Checks for sessions that were left open due to crash/unexpected termination.
  /// Returns the session ID if a dangling session is found, null otherwise.
  Future<Map<String, dynamic>?> findDanglingSession() async {
    final results = await database.query(
      'sessions',
      where: 'end_time IS NULL',
      orderBy: 'start_time DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
