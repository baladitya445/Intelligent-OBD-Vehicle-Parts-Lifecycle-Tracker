class OBDReading {
  final String id;
  final String vehicleId;
  final int? speed;
  final int? rpm;
  final double? odometer;
  final List<String> errorCodes;
  final DateTime timestamp;
  final bool isUploaded;
  final String? notes;

  OBDReading({
    required this.id,
    required this.vehicleId,
    this.speed,
    this.rpm,
    this.odometer,
    this.errorCodes = const [],
    DateTime? timestamp,
    this.isUploaded = false,
    this.notes,
  }) : timestamp = timestamp ?? DateTime.now();

  // Convert OBDReading to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'speed': speed,
      'rpm': rpm,
      'odometer': odometer,
      'errorCodes': errorCodes.join(','), // Store as comma-separated string
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isUploaded': isUploaded ? 1 : 0,
      'notes': notes,
    };
  }

  // Create OBDReading from database Map
  factory OBDReading.fromMap(Map<String, dynamic> map) {
    return OBDReading(
      id: map['id'] ?? '',
      vehicleId: map['vehicleId'] ?? '',
      speed: map['speed'],
      rpm: map['rpm'],
      odometer: map['odometer']?.toDouble(),
      errorCodes: map['errorCodes'] != null && map['errorCodes'].isNotEmpty
          ? map['errorCodes'].split(',')
          : [],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      isUploaded: (map['isUploaded'] ?? 0) == 1,
      notes: map['notes'],
    );
  }

  // Create copy with updated fields
  OBDReading copyWith({
    String? id,
    String? vehicleId,
    int? speed,
    int? rpm,
    double? odometer,
    List<String>? errorCodes,
    DateTime? timestamp,
    bool? isUploaded,
    String? notes,
  }) {
    return OBDReading(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      speed: speed ?? this.speed,
      rpm: rpm ?? this.rpm,
      odometer: odometer ?? this.odometer,
      errorCodes: errorCodes ?? this.errorCodes,
      timestamp: timestamp ?? this.timestamp,
      isUploaded: isUploaded ?? this.isUploaded,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'OBDReading{id: $id, speed: $speed, rpm: $rpm, timestamp: $timestamp, errors: ${errorCodes.length}}';
  }
}
