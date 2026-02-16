class VehicleData {
  final int? speed;
  final int? rpm;
  final List<String> errorCodes;
  final DateTime timestamp;
  final bool isConnected;

  VehicleData({
    this.speed,
    this.rpm,
    this.errorCodes = const [],
    DateTime? timestamp,
    this.isConnected = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'speed': speed,
      'rpm': rpm,
      'errorCodes': errorCodes,
      'timestamp': timestamp.toIso8601String(),
      'isConnected': isConnected,
    };
  }

  @override
  String toString() {
    return 'VehicleData{speed: $speed, rpm: $rpm, errors: ${errorCodes.length}, connected: $isConnected}';
  }
}

class OBDPIDs {
  static const String VEHICLE_SPEED = '010D';
  static const String ENGINE_RPM = '010C';
  static const String DIAGNOSTIC_CODES = '03';
  static const String CLEAR_CODES = '04';
  static const String SUPPORTED_PIDS = '0100';
}
