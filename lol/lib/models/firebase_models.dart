import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// User model for authentication
class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    DateTime? createdAt,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: UserRole.values.firstWhere(
            (role) => role.name == data['role'],
        orElse: () => UserRole.owner,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }
}

enum UserRole { owner, workshop, admin }

// Vehicle model
class Vehicle {
  final String id;
  final String ownerId;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String vin;
  final double currentOdometer;
  final DateTime lastServiceDate;
  final DateTime createdAt;
  final bool isActive;

  Vehicle({
    required this.id,
    required this.ownerId,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.vin,
    this.currentOdometer = 0.0,
    DateTime? lastServiceDate,
    DateTime? createdAt,
    this.isActive = true,
  }) : lastServiceDate = lastServiceDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'make': make,
      'model': model,
      'year': year,
      'licensePlate': licensePlate,
      'vin': vin,
      'currentOdometer': currentOdometer,
      'lastServiceDate': Timestamp.fromDate(lastServiceDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vehicle(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      make: data['make'] ?? '',
      model: data['model'] ?? '',
      year: data['year'] ?? 0,
      licensePlate: data['licensePlate'] ?? '',
      vin: data['vin'] ?? '',
      currentOdometer: (data['currentOdometer'] ?? 0).toDouble(),
      lastServiceDate: (data['lastServiceDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Vehicle copyWith({
    String? id,
    String? ownerId,
    String? make,
    String? model,
    int? year,
    String? licensePlate,
    String? vin,
    double? currentOdometer,
    DateTime? lastServiceDate,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return Vehicle(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      licensePlate: licensePlate ?? this.licensePlate,
      vin: vin ?? this.vin,
      currentOdometer: currentOdometer ?? this.currentOdometer,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

// Vehicle Part model
class VehiclePart {
  final String id;
  final String vehicleId;
  final String partName;
  final String partNumber;
  final String qrCode;
  final double installationOdometer;
  final DateTime installationDate;
  final double recommendedLifespanKm;
  final int recommendedLifespanMonths;
  final PartStatus status;
  final DateTime? lastReplacementDate;
  final String? notes;

  VehiclePart({
    required this.id,
    required this.vehicleId,
    required this.partName,
    required this.partNumber,
    required this.qrCode,
    required this.installationOdometer,
    DateTime? installationDate,
    this.recommendedLifespanKm = 10000.0,
    this.recommendedLifespanMonths = 12,
    this.status = PartStatus.active,
    this.lastReplacementDate,
    this.notes,
  }) : installationDate = installationDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'partName': partName,
      'partNumber': partNumber,
      'qrCode': qrCode,
      'installationOdometer': installationOdometer,
      'installationDate': Timestamp.fromDate(installationDate),
      'recommendedLifespanKm': recommendedLifespanKm,
      'recommendedLifespanMonths': recommendedLifespanMonths,
      'status': status.name,
      'lastReplacementDate': lastReplacementDate != null ? Timestamp.fromDate(lastReplacementDate!) : null,
      'notes': notes,
    };
  }

  factory VehiclePart.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VehiclePart(
      id: doc.id,
      vehicleId: data['vehicleId'] ?? '',
      partName: data['partName'] ?? '',
      partNumber: data['partNumber'] ?? '',
      qrCode: data['qrCode'] ?? '',
      installationOdometer: (data['installationOdometer'] ?? 0).toDouble(),
      installationDate: (data['installationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recommendedLifespanKm: (data['recommendedLifespanKm'] ?? 10000).toDouble(),
      recommendedLifespanMonths: data['recommendedLifespanMonths'] ?? 12,
      status: PartStatus.values.firstWhere(
            (status) => status.name == data['status'],
        orElse: () => PartStatus.active,
      ),
      lastReplacementDate: (data['lastReplacementDate'] as Timestamp?)?.toDate(),
      notes: data['notes'],
    );
  }

  // Check if part needs replacement based on odometer or time
  bool needsReplacement(double currentOdometer) {
    final kmSinceInstallation = currentOdometer - installationOdometer;
    final monthsSinceInstallation = DateTime.now().difference(installationDate).inDays / 30;

    return kmSinceInstallation >= recommendedLifespanKm ||
        monthsSinceInstallation >= recommendedLifespanMonths;
  }

  double getUsagePercentage(double currentOdometer) {
    final kmSinceInstallation = currentOdometer - installationOdometer;
    final monthsSinceInstallation = DateTime.now().difference(installationDate).inDays / 30;

    final kmUsage = (kmSinceInstallation / recommendedLifespanKm) * 100;
    final timeUsage = (monthsSinceInstallation / recommendedLifespanMonths) * 100;

    return kmUsage > timeUsage ? kmUsage : timeUsage;
  }
}

enum PartStatus { active, needsReplacement, replaced, removed }

// Service Record model
class ServiceRecord {
  final String id;
  final String vehicleId;
  final String workshopId;
  final DateTime serviceDate;
  final double odometerReading;
  final List<String> replacedPartIds;
  final List<String> servicesPerformed;
  final double totalCost;
  final String notes;
  final ServiceStatus status;
  final DateTime? nextServiceDue;

  ServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.workshopId,
    DateTime? serviceDate,
    required this.odometerReading,
    this.replacedPartIds = const [],
    this.servicesPerformed = const [],
    this.totalCost = 0.0,
    this.notes = '',
    this.status = ServiceStatus.completed,
    this.nextServiceDue,
  }) : serviceDate = serviceDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'workshopId': workshopId,
      'serviceDate': Timestamp.fromDate(serviceDate),
      'odometerReading': odometerReading,
      'replacedPartIds': replacedPartIds,
      'servicesPerformed': servicesPerformed,
      'totalCost': totalCost,
      'notes': notes,
      'status': status.name,
      'nextServiceDue': nextServiceDue != null ? Timestamp.fromDate(nextServiceDue!) : null,
    };
  }

  factory ServiceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceRecord(
      id: doc.id,
      vehicleId: data['vehicleId'] ?? '',
      workshopId: data['workshopId'] ?? '',
      serviceDate: (data['serviceDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      odometerReading: (data['odometerReading'] ?? 0).toDouble(),
      replacedPartIds: List<String>.from(data['replacedPartIds'] ?? []),
      servicesPerformed: List<String>.from(data['servicesPerformed'] ?? []),
      totalCost: (data['totalCost'] ?? 0).toDouble(),
      notes: data['notes'] ?? '',
      status: ServiceStatus.values.firstWhere(
            (status) => status.name == data['status'],
        orElse: () => ServiceStatus.completed,
      ),
      nextServiceDue: (data['nextServiceDue'] as Timestamp?)?.toDate(),
    );
  }
}

enum ServiceStatus { scheduled, inProgress, completed, cancelled }

// OBD Reading Firebase model (extends your local model)
class FirebaseOBDReading {
  final String id;
  final String vehicleId;
  final String userId;
  final int? speed;
  final int? rpm;
  final double? odometer;
  final List<String> errorCodes;
  final DateTime timestamp;
  final Map<String, dynamic>? additionalData;

  FirebaseOBDReading({
    required this.id,
    required this.vehicleId,
    required this.userId,
    this.speed,
    this.rpm,
    this.odometer,
    this.errorCodes = const [],
    DateTime? timestamp,
    this.additionalData,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'userId': userId,
      'speed': speed,
      'rpm': rpm,
      'odometer': odometer,
      'errorCodes': errorCodes,
      'timestamp': Timestamp.fromDate(timestamp),
      'additionalData': additionalData,
    };
  }

  factory FirebaseOBDReading.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirebaseOBDReading(
      id: doc.id,
      vehicleId: data['vehicleId'] ?? '',
      userId: data['userId'] ?? '',
      speed: data['speed'],
      rpm: data['rpm'],
      odometer: data['odometer']?.toDouble(),
      errorCodes: List<String>.from(data['errorCodes'] ?? []),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      additionalData: data['additionalData'],
    );
  }
}
