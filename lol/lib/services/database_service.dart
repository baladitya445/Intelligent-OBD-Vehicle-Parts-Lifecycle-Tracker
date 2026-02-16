import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/obd_reading.dart';
import '../models/error_log.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static const String _databaseName = 'obd_tracker.db';
  static const int _databaseVersion = 1;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create OBD readings table
    await db.execute('''
      CREATE TABLE obd_readings(
        id TEXT PRIMARY KEY,
        vehicleId TEXT NOT NULL,
        speed INTEGER,
        rpm INTEGER,
        odometer REAL,
        errorCodes TEXT,
        timestamp INTEGER NOT NULL,
        isUploaded INTEGER NOT NULL DEFAULT 0,
        notes TEXT
      )
    ''');

    // Create error logs table
    await db.execute('''
      CREATE TABLE error_logs(
        id TEXT PRIMARY KEY,
        errorType INTEGER NOT NULL,
        message TEXT NOT NULL,
        details TEXT,
        stackTrace TEXT,
        timestamp INTEGER NOT NULL,
        isResolved INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_obd_timestamp ON obd_readings(timestamp)');
    await db.execute('CREATE INDEX idx_obd_uploaded ON obd_readings(isUploaded)');
    await db.execute('CREATE INDEX idx_error_timestamp ON error_logs(timestamp)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here if needed in future versions
    if (oldVersion < 2) {
      // Example upgrade logic
      // await db.execute('ALTER TABLE obd_readings ADD COLUMN newColumn TEXT');
    }
  }

  // OBD Reading operations
  Future<String> insertOBDReading(OBDReading reading) async {
    final db = await database;
    await db.insert('obd_readings', reading.toMap());
    return reading.id;
  }

  Future<List<OBDReading>> getAllOBDReadings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'obd_readings',
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return OBDReading.fromMap(maps[i]);
    });
  }

  Future<List<OBDReading>> getUnuploadedReadings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'obd_readings',
      where: 'isUploaded = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return OBDReading.fromMap(maps[i]);
    });
  }

  Future<List<OBDReading>> getReadingsByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'obd_readings',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return OBDReading.fromMap(maps[i]);
    });
  }

  Future<int> updateOBDReading(OBDReading reading) async {
    final db = await database;
    return await db.update(
      'obd_readings',
      reading.toMap(),
      where: 'id = ?',
      whereArgs: [reading.id],
    );
  }

  Future<int> markAsUploaded(List<String> ids) async {
    final db = await database;
    return await db.update(
      'obd_readings',
      {'isUploaded': 1},
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<int> deleteOBDReading(String id) async {
    final db = await database;
    return await db.delete(
      'obd_readings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Error Log operations
  Future<String> insertErrorLog(ErrorLog errorLog) async {
    final db = await database;
    await db.insert('error_logs', errorLog.toMap());
    return errorLog.id;
  }

  Future<List<ErrorLog>> getAllErrorLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'error_logs',
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return ErrorLog.fromMap(maps[i]);
    });
  }

  Future<List<ErrorLog>> getUnresolvedErrors() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'error_logs',
      where: 'isResolved = ?',
      whereArgs: [0],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return ErrorLog.fromMap(maps[i]);
    });
  }

  Future<int> markErrorAsResolved(String id) async {
    final db = await database;
    return await db.update(
      'error_logs',
      {'isResolved': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Utility operations
  Future<void> cleanOldData({int daysToKeep = 30}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    await db.delete(
      'obd_readings',
      where: 'timestamp < ? AND isUploaded = ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch, 1],
    );

    await db.delete(
      'error_logs',
      where: 'timestamp < ? AND isResolved = ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch, 1],
    );
  }

  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;

    final totalReadings = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM obd_readings'),
    ) ?? 0;

    final unuploadedReadings = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM obd_readings WHERE isUploaded = 0'),
    ) ?? 0;

    final totalErrors = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM error_logs'),
    ) ?? 0;

    final unresolvedErrors = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM error_logs WHERE isResolved = 0'),
    ) ?? 0;

    return {
      'totalReadings': totalReadings,
      'unuploadedReadings': unuploadedReadings,
      'totalErrors': totalErrors,
      'unresolvedErrors': unresolvedErrors,
    };
  }

  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
