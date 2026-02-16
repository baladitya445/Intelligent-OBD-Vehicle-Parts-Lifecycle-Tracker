import 'package:intl/intl.dart';

enum ErrorType {
  bluetoothConnection,
  obdCommunication,
  dataValidation,
  databaseOperation,
  networkUpload,
  unknown,
}

class ErrorLog {
  final String id;
  final ErrorType errorType;
  final String message;
  final String? details;
  final String? stackTrace;
  final DateTime timestamp;
  final bool isResolved;

  ErrorLog({
    required this.id,
    required this.errorType,
    required this.message,
    this.details,
    this.stackTrace,
    DateTime? timestamp,
    this.isResolved = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'errorType': errorType.index,
      'message': message,
      'details': details,
      'stackTrace': stackTrace,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isResolved': isResolved ? 1 : 0,
    };
  }

  factory ErrorLog.fromMap(Map<String, dynamic> map) {
    return ErrorLog(
      id: map['id'] ?? '',
      errorType: ErrorType.values[map['errorType'] ?? 0],
      message: map['message'] ?? '',
      details: map['details'],
      stackTrace: map['stackTrace'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      isResolved: (map['isResolved'] ?? 0) == 1,
    );
  }

  ErrorLog copyWith({
    String? id,
    ErrorType? errorType,
    String? message,
    String? details,
    String? stackTrace,
    DateTime? timestamp,
    bool? isResolved,
  }) {
    return ErrorLog(
      id: id ?? this.id,
      errorType: errorType ?? this.errorType,
      message: message ?? this.message,
      details: details ?? this.details,
      stackTrace: stackTrace ?? this.stackTrace,
      timestamp: timestamp ?? this.timestamp,
      isResolved: isResolved ?? this.isResolved,
    );
  }

  String get formattedTimestamp {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
  }

  @override
  String toString() {
    return 'ErrorLog{type: $errorType, message: $message, time: $formattedTimestamp}';
  }
}
