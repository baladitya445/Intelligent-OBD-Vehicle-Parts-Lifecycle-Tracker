import 'dart:async';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/obd_reading.dart';
import '../models/error_log.dart';
import 'database_service.dart';
import 'obd_service.dart';
import 'bluetooth_service.dart';
// NEW FIREBASE IMPORT:
import 'firebase_service.dart';

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final OBDService _obdService = OBDService();
  final BluetoothService _bluetoothService = BluetoothService();
  final Uuid _uuid = const Uuid();
  // NEW FIREBASE SERVICE:
  final FirebaseService _firebaseService = FirebaseService();

  Timer? _loggingTimer;
  Timer? _syncTimer; // NEW: Timer for periodic Firebase sync
  bool _isLogging = false;
  bool _isSyncing = false; // NEW: Track sync status
  String _currentVehicleId = 'default_vehicle';

  // Configuration
  Duration loggingInterval = const Duration(seconds: 30); // Log every 30 seconds
  Duration syncInterval = const Duration(minutes: 5); // Sync every 5 minutes
  int maxRetries = 3;
  bool autoSyncEnabled = true; // NEW: Auto-sync toggle

  // Statistics
  int _successfulReadings = 0;
  int _failedReadings = 0;
  int _successfulSyncs = 0; // NEW: Track successful syncs
  int _failedSyncs = 0; // NEW: Track failed syncs
  DateTime? _lastSuccessfulReading;
  DateTime? _lastSuccessfulSync; // NEW: Track last sync

  // Getters for statistics
  bool get isLogging => _isLogging;
  bool get isSyncing => _isSyncing; // NEW
  int get successfulReadings => _successfulReadings;
  int get failedReadings => _failedReadings;
  int get successfulSyncs => _successfulSyncs; // NEW
  int get failedSyncs => _failedSyncs; // NEW
  DateTime? get lastSuccessfulReading => _lastSuccessfulReading;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync; // NEW

  void setVehicleId(String vehicleId) {
    _currentVehicleId = vehicleId;
  }

  void setLoggingInterval(Duration interval) {
    loggingInterval = interval;
    if (_isLogging) {
      stopLogging();
      startLogging();
    }
  }

  // NEW: Set sync interval
  void setSyncInterval(Duration interval) {
    syncInterval = interval;
    if (autoSyncEnabled) {
      _startAutoSync();
    }
  }

  // NEW: Toggle auto-sync
  void setAutoSync(bool enabled) {
    autoSyncEnabled = enabled;
    if (enabled) {
      _startAutoSync();
    } else {
      _stopAutoSync();
    }
  }

  // Start periodic logging
  Future<void> startLogging() async {
    if (_isLogging) {
      await logError(
        ErrorType.dataValidation,
        'Attempted to start logging while already running',
      );
      return;
    }

    print('Starting OBD data logging every ${loggingInterval.inSeconds} seconds');
    _isLogging = true;

    // Take an immediate reading
    await _performDataCollection();

    // Schedule periodic readings
    _loggingTimer = Timer.periodic(loggingInterval, (timer) async {
      await _performDataCollection();
    });

    // NEW: Start auto-sync if enabled
    if (autoSyncEnabled) {
      _startAutoSync();
    }
  }

  // Stop periodic logging
  void stopLogging() {
    print('Stopping OBD data logging');
    _loggingTimer?.cancel();
    _loggingTimer = null;
    _isLogging = false;

    // NEW: Stop auto-sync
    _stopAutoSync();
  }

  // NEW: Start automatic Firebase sync
  void _startAutoSync() {
    _stopAutoSync(); // Stop any existing sync timer

    _syncTimer = Timer.periodic(syncInterval, (timer) async {
      if (!_isSyncing) {
        await syncToFirebase();
      }
    });
  }

  // NEW: Stop automatic Firebase sync
  void _stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Perform a single data collection cycle
  Future<void> _performDataCollection() async {
    if (!_bluetoothService.isConnected) {
      await logError(
        ErrorType.bluetoothConnection,
        'Cannot collect data: Bluetooth not connected',
      );
      _failedReadings++;
      return;
    }

    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        // Get OBD data
        final vehicleData = await _obdService.getAllData();

        if (vehicleData.isConnected) {
          // Create OBD reading
          final reading = OBDReading(
            id: _uuid.v4(),
            vehicleId: _currentVehicleId,
            speed: vehicleData.speed,
            rpm: vehicleData.rpm,
            errorCodes: vehicleData.errorCodes,
            notes: _generateReadingNotes(vehicleData.speed, vehicleData.rpm),
          );

          // Save to database
          await _databaseService.insertOBDReading(reading);

          _successfulReadings++;
          _lastSuccessfulReading = DateTime.now();

          print('Logged OBD reading: ${reading.toString()}');

          // Log any new error codes
          if (vehicleData.errorCodes.isNotEmpty) {
            await logError(
              ErrorType.obdCommunication,
              'Vehicle error codes detected: ${vehicleData.errorCodes.join(', ')}',
              details: 'Speed: ${vehicleData.speed}, RPM: ${vehicleData.rpm}',
            );
          }

          // NEW: Try immediate sync for important readings (errors or high frequency)
          if (vehicleData.errorCodes.isNotEmpty || _successfulReadings % 10 == 0) {
            if (!_isSyncing && autoSyncEnabled) {
              // Don't await - let it sync in background
              syncToFirebase();
            }
          }

          return; // Success, exit retry loop
        } else {
          throw Exception('OBD connection lost or invalid data received');
        }
      } catch (e, stackTrace) {
        retryCount++;
        print('Data collection attempt $retryCount failed: $e');

        if (retryCount >= maxRetries) {
          await logError(
            ErrorType.obdCommunication,
            'Failed to collect OBD data after $maxRetries attempts: $e',
            details: 'Vehicle ID: $_currentVehicleId',
            stackTrace: stackTrace.toString(),
          );
          _failedReadings++;
        } else {
          // Wait before retry
          await Future.delayed(Duration(seconds: 2 * retryCount));
        }
      }
    }
  }

  // Manual data collection (for testing or on-demand readings)
  Future<OBDReading?> collectSingleReading() async {
    try {
      final vehicleData = await _obdService.getAllData();

      if (vehicleData.isConnected) {
        final reading = OBDReading(
          id: _uuid.v4(),
          vehicleId: _currentVehicleId,
          speed: vehicleData.speed,
          rpm: vehicleData.rpm,
          errorCodes: vehicleData.errorCodes,
          notes: 'Manual reading',
        );

        await _databaseService.insertOBDReading(reading);

        // NEW: Immediate sync for manual readings
        if (autoSyncEnabled && !_isSyncing) {
          syncToFirebase();
        }

        return reading;
      }
    } catch (e, stackTrace) {
      await logError(
        ErrorType.obdCommunication,
        'Manual reading failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }
    return null;
  }

  // NEW: Sync data to Firebase
  Future<bool> syncToFirebase() async {
    if (_isSyncing) {
      print('Sync already in progress, skipping...');
      return false;
    }

    try {
      _isSyncing = true;
      print('Starting Firebase sync...');

      final unuploadedReadings = await _databaseService.getUnuploadedReadings();

      if (unuploadedReadings.isEmpty) {
        print('No readings to sync');
        return true;
      }

      // Sync readings to Firebase
      await _firebaseService.syncOBDReadings(unuploadedReadings);

      // Mark as uploaded in local database
      final ids = unuploadedReadings.map((r) => r.id).toList();
      await _databaseService.markAsUploaded(ids);

      _successfulSyncs++;
      _lastSuccessfulSync = DateTime.now();

      print('Successfully synced ${unuploadedReadings.length} readings to Firebase');
      return true;

    } catch (e, stackTrace) {
      _failedSyncs++;
      await logError(
        ErrorType.networkUpload,
        'Failed to sync to Firebase: $e',
        details: 'Attempted to sync readings to cloud',
        stackTrace: stackTrace.toString(),
      );
      print('Firebase sync failed: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  // NEW: Force immediate sync
  Future<bool> forceSyncToFirebase() async {
    if (_isSyncing) {
      print('Stopping current sync to force new sync...');
      await Future.delayed(Duration(seconds: 2));
    }

    return await syncToFirebase();
  }

  // NEW: Get sync status
  Map<String, dynamic> getSyncStatus() {
    return {
      'isSyncing': _isSyncing,
      'autoSyncEnabled': autoSyncEnabled,
      'successfulSyncs': _successfulSyncs,
      'failedSyncs': _failedSyncs,
      'lastSuccessfulSync': _lastSuccessfulSync?.toIso8601String(),
      'syncInterval': syncInterval.inMinutes,
    };
  }

  // Log errors to database
  Future<void> logError(
      ErrorType type,
      String message, {
        String? details,
        String? stackTrace,
      }) async {
    try {
      final errorLog = ErrorLog(
        id: _uuid.v4(),
        errorType: type,
        message: message,
        details: details,
        stackTrace: stackTrace,
      );

      await _databaseService.insertErrorLog(errorLog);
      print('Error logged: ${errorLog.toString()}');

      // NEW: Try to sync error logs immediately if critical
      if (type == ErrorType.obdCommunication || type == ErrorType.bluetoothConnection) {
        if (autoSyncEnabled && !_isSyncing) {
          // Don't await - let it sync in background
          syncToFirebase();
        }
      }
    } catch (e) {
      print('Failed to log error to database: $e');
      // This is a critical error - we can't even log errors!
    }
  }

  // Get recent readings for display
  Future<List<OBDReading>> getRecentReadings({int limit = 50}) async {
    try {
      final allReadings = await _databaseService.getAllOBDReadings();
      return allReadings.take(limit).toList();
    } catch (e) {
      await logError(
        ErrorType.databaseOperation,
        'Failed to retrieve recent readings: $e',
      );
      return [];
    }
  }

  // Get readings that need to be uploaded
  Future<List<OBDReading>> getUnuploadedReadings() async {
    try {
      return await _databaseService.getUnuploadedReadings();
    } catch (e) {
      await logError(
        ErrorType.databaseOperation,
        'Failed to retrieve unuploaded readings: $e',
      );
      return [];
    }
  }

  // Mark readings as uploaded (for when backend sync is implemented)
  Future<bool> markReadingsAsUploaded(List<String> readingIds) async {
    try {
      await _databaseService.markAsUploaded(readingIds);
      return true;
    } catch (e) {
      await logError(
        ErrorType.databaseOperation,
        'Failed to mark readings as uploaded: $e',
      );
      return false;
    }
  }

  // Get error logs
  Future<List<ErrorLog>> getErrorLogs() async {
    try {
      return await _databaseService.getAllErrorLogs();
    } catch (e) {
      print('Failed to retrieve error logs: $e');
      return [];
    }
  }

  // Clean up old data
  Future<void> performMaintenance() async {
    try {
      await _databaseService.cleanOldData(daysToKeep: 30);
      print('Database maintenance completed');

      // NEW: Sync any remaining data before cleanup
      if (autoSyncEnabled && !_isSyncing) {
        await syncToFirebase();
      }
    } catch (e) {
      await logError(
        ErrorType.databaseOperation,
        'Database maintenance failed: $e',
      );
    }
  }

  // Get logging statistics (UPDATED with sync stats)
  Future<Map<String, dynamic>> getStatistics() async {
    final dbStats = await _databaseService.getDatabaseStats();
    final syncStats = getSyncStatus();

    return {
      'isLogging': _isLogging,
      'successfulReadings': _successfulReadings,
      'failedReadings': _failedReadings,
      'lastSuccessfulReading': _lastSuccessfulReading?.toIso8601String(),
      'loggingInterval': loggingInterval.inSeconds,
      'currentVehicleId': _currentVehicleId,
      // NEW SYNC STATISTICS:
      ...syncStats,
      ...dbStats,
    };
  }

  // Helper method to generate reading notes
  String? _generateReadingNotes(int? speed, int? rpm) {
    List<String> notes = [];

    if (speed != null && speed > 120) {
      notes.add('High speed detected');
    }

    if (rpm != null && rpm > 4000) {
      notes.add('High RPM detected');
    }

    if (speed != null && rpm != null && speed > 0 && rpm < 800) {
      notes.add('Possible engine issue - low RPM at speed');
    }

    return notes.isNotEmpty ? notes.join(', ') : null;
  }

  // Cleanup resources (UPDATED)
  void dispose() {
    stopLogging();
    _stopAutoSync(); // NEW: Stop sync timer
  }
}
