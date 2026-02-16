import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/obd_reading.dart';
import '../models/error_log.dart';

class DataFormatter {
  static final DataFormatter _instance = DataFormatter._internal();
  factory DataFormatter() => _instance;
  DataFormatter._internal();

  // Format single OBD reading for API upload
  Map<String, dynamic> formatOBDReadingForUpload(OBDReading reading) {
    return {
      'id': reading.id,
      'vehicleId': reading.vehicleId,
      'speed': reading.speed,
      'rpm': reading.rpm,
      'odometer': reading.odometer,
      'errorCodes': reading.errorCodes,
      'timestamp': reading.timestamp.toIso8601String(),
      'timestampUnix': reading.timestamp.millisecondsSinceEpoch ~/ 1000,
      'notes': reading.notes,
      'dataType': 'obd_reading',
      'version': '1.0',
    };
  }

  // Format multiple readings for batch upload
  Map<String, dynamic> formatReadingsBatch(List<OBDReading> readings) {
    return {
      'batchId': _generateBatchId(),
      'timestamp': DateTime.now().toIso8601String(),
      'count': readings.length,
      'readings': readings.map((r) => formatOBDReadingForUpload(r)).toList(),
      'metadata': {
        'source': 'flutter_obd_app',
        'version': '1.0',
        'deviceInfo': _getDeviceInfo(),
      }
    };
  }

  // Format error log for API upload
  Map<String, dynamic> formatErrorLogForUpload(ErrorLog errorLog) {
    return {
      'id': errorLog.id,
      'errorType': errorLog.errorType.name,
      'message': errorLog.message,
      'details': errorLog.details,
      'timestamp': errorLog.timestamp.toIso8601String(),
      'timestampUnix': errorLog.timestamp.millisecondsSinceEpoch ~/ 1000,
      'isResolved': errorLog.isResolved,
      'dataType': 'error_log',
      'version': '1.0',
    };
  }

  // Convert OBD reading to CSV format
  String formatReadingAsCSV(OBDReading reading, {bool includeHeader = false}) {
    StringBuffer csv = StringBuffer();

    if (includeHeader) {
      csv.writeln('ID,VehicleID,Speed,RPM,Odometer,ErrorCodes,Timestamp,Notes');
    }

    csv.write('"${reading.id}",');
    csv.write('"${reading.vehicleId}",');
    csv.write('${reading.speed ?? ""},');
    csv.write('${reading.rpm ?? ""},');
    csv.write('${reading.odometer ?? ""},');
    csv.write('"${reading.errorCodes.join(';')}",');
    csv.write('"${_formatTimestamp(reading.timestamp)}",');
    csv.write('"${reading.notes ?? ""}"');

    return csv.toString();
  }

  // Convert multiple readings to CSV
  String formatReadingsAsCSV(List<OBDReading> readings) {
    if (readings.isEmpty) return '';

    StringBuffer csv = StringBuffer();

    // Header
    csv.writeln('ID,VehicleID,Speed,RPM,Odometer,ErrorCodes,Timestamp,Notes');

    // Data rows
    for (OBDReading reading in readings) {
      csv.writeln(formatReadingAsCSV(reading));
    }

    return csv.toString();
  }

  // Format reading for display in UI
  Map<String, String> formatReadingForDisplay(OBDReading reading) {
    return {
      'ID': reading.id.substring(0, 8) + '...', // Short ID for display
      'Vehicle': reading.vehicleId,
      'Speed': reading.speed != null ? '${reading.speed} km/h' : 'N/A',
      'RPM': reading.rpm != null ? '${reading.rpm} rpm' : 'N/A',
      'Odometer': reading.odometer != null ? '${reading.odometer!.toStringAsFixed(1)} km' : 'N/A',
      'Errors': reading.errorCodes.isNotEmpty ? reading.errorCodes.join(', ') : 'None',
      'Time': _formatTimestamp(reading.timestamp),
      'Status': reading.isUploaded ? 'Synced' : 'Pending',
      'Notes': reading.notes ?? 'None',
    };
  }

  // Format data for sharing (JSON)
  String formatReadingsAsJSON(List<OBDReading> readings, {bool prettyPrint = false}) {
    final data = formatReadingsBatch(readings);

    if (prettyPrint) {
      JsonEncoder encoder = const JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    }

    return jsonEncode(data);
  }

  // Parse uploaded response and extract successful IDs
  List<String> parseUploadResponse(String responseBody) {
    try {
      final Map<String, dynamic> response = jsonDecode(responseBody);

      if (response['success'] == true && response['uploaded_ids'] != null) {
        return List<String>.from(response['uploaded_ids']);
      }

      return [];
    } catch (e) {
      print('Error parsing upload response: $e');
      return [];
    }
  }

  // Validate reading data before upload
  bool validateReadingForUpload(OBDReading reading) {
    // Basic validation rules
    if (reading.id.isEmpty || reading.vehicleId.isEmpty) {
      return false;
    }

    // Speed should be reasonable (0-300 km/h)
    if (reading.speed != null && (reading.speed! < 0 || reading.speed! > 300)) {
      return false;
    }

    // RPM should be reasonable (0-8000 rpm)
    if (reading.rpm != null && (reading.rpm! < 0 || reading.rpm! > 8000)) {
      return false;
    }

    // Timestamp should not be too old or in the future
    final now = DateTime.now();
    final daysDiff = now.difference(reading.timestamp).inDays.abs();
    if (daysDiff > 30) {
      return false;
    }

    return true;
  }

  // Generate summary statistics
  Map<String, dynamic> generateReadingsSummary(List<OBDReading> readings) {
    if (readings.isEmpty) {
      return {
        'count': 0,
        'dateRange': 'No data',
        'avgSpeed': 0.0,
        'avgRPM': 0.0,
        'errorCount': 0,
        'uniqueErrors': <String>[],
      };
    }

    // Sort by timestamp
    readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate averages
    final speeds = readings.where((r) => r.speed != null).map((r) => r.speed!).toList();
    final rpms = readings.where((r) => r.rpm != null).map((r) => r.rpm!).toList();

    final avgSpeed = speeds.isNotEmpty ? speeds.reduce((a, b) => a + b) / speeds.length : 0.0;
    final avgRPM = rpms.isNotEmpty ? rpms.reduce((a, b) => a + b) / rpms.length : 0.0;

    // Collect all error codes
    final allErrors = <String>[];
    for (final reading in readings) {
      allErrors.addAll(reading.errorCodes);
    }
    final uniqueErrors = allErrors.toSet().toList();

    return {
      'count': readings.length,
      'dateRange': '${_formatDate(readings.first.timestamp)} - ${_formatDate(readings.last.timestamp)}',
      'avgSpeed': double.parse(avgSpeed.toStringAsFixed(1)),
      'avgRPM': double.parse(avgRPM.toStringAsFixed(0)),
      'errorCount': allErrors.length,
      'uniqueErrors': uniqueErrors,
      'uploadedCount': readings.where((r) => r.isUploaded).length,
      'pendingCount': readings.where((r) => !r.isUploaded).length,
    };
  }

  // Helper methods
  String _generateBatchId() {
    final now = DateTime.now();
    return 'batch_${now.millisecondsSinceEpoch}';
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
  }

  String _formatDate(DateTime timestamp) {
    return DateFormat('yyyy-MM-dd').format(timestamp);
  }

  Map<String, String> _getDeviceInfo() {
    // This would typically include actual device information
    // For now, return basic info
    return {
      'platform': 'flutter',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
