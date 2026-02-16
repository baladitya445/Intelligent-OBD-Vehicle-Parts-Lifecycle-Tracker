import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/firebase_models.dart';
import '../models/obd_reading.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Vehicle CRUD operations
  Future<String> createVehicle(Vehicle vehicle) async {
    try {
      final docRef = await _firestore.collection('vehicles').add(vehicle.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create vehicle: $e');
    }
  }

  Stream<List<Vehicle>> getUserVehicles(String userId) {
    return _firestore
        .collection('vehicles')
        .where('ownerId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Vehicle.fromFirestore(doc)).toList());
  }

  Future<Vehicle?> getVehicle(String vehicleId) async {
    try {
      final doc = await _firestore.collection('vehicles').doc(vehicleId).get();
      if (doc.exists) {
        return Vehicle.fromFirestore(doc);
      }
    } catch (e) {
      print('Error getting vehicle: $e');
    }
    return null;
  }

  Future<void> updateVehicle(String vehicleId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).update(data);
    } catch (e) {
      throw Exception('Failed to update vehicle: $e');
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to delete vehicle: $e');
    }
  }

  // Vehicle Parts CRUD operations
  Future<String> createVehiclePart(VehiclePart part) async {
    try {
      final docRef = await _firestore.collection('vehicle_parts').add(part.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create vehicle part: $e');
    }
  }

  Stream<List<VehiclePart>> getVehicleParts(String vehicleId) {
    return _firestore
        .collection('vehicle_parts')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', whereIn: [PartStatus.active.name, PartStatus.needsReplacement.name])
        .orderBy('installationDate', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => VehiclePart.fromFirestore(doc)).toList());
  }

  Future<VehiclePart?> getPartByQRCode(String qrCode) async {
    try {
      final querySnapshot = await _firestore
          .collection('vehicle_parts')
          .where('qrCode', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return VehiclePart.fromFirestore(querySnapshot.docs.first);
      }
    } catch (e) {
      print('Error getting part by QR code: $e');
    }
    return null;
  }

  Future<void> updateVehiclePart(String partId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('vehicle_parts').doc(partId).update(data);
    } catch (e) {
      throw Exception('Failed to update vehicle part: $e');
    }
  }

  Future<void> markPartAsReplaced(String partId, String serviceRecordId) async {
    try {
      await _firestore.collection('vehicle_parts').doc(partId).update({
        'status': PartStatus.replaced.name,
        'lastReplacementDate': Timestamp.now(),
        'replacementServiceId': serviceRecordId,
      });
    } catch (e) {
      throw Exception('Failed to mark part as replaced: $e');
    }
  }

  // Service Records CRUD operations
  Future<String> createServiceRecord(ServiceRecord record) async {
    try {
      final docRef = await _firestore.collection('service_records').add(record.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create service record: $e');
    }
  }

  Stream<List<ServiceRecord>> getVehicleServiceRecords(String vehicleId) {
    return _firestore
        .collection('service_records')
        .where('vehicleId', isEqualTo: vehicleId)
        .orderBy('serviceDate', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => ServiceRecord.fromFirestore(doc)).toList());
  }

  Future<void> updateServiceRecord(String recordId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('service_records').doc(recordId).update(data);
    } catch (e) {
      throw Exception('Failed to update service record: $e');
    }
  }

  // OBD Readings sync
  Future<void> syncOBDReadings(List<OBDReading> readings) async {
    try {
      final batch = _firestore.batch();

      for (final reading in readings) {
        if (currentUserId == null) continue;

        final firebaseReading = FirebaseOBDReading(
          id: reading.id,
          vehicleId: reading.vehicleId,
          userId: currentUserId!,
          speed: reading.speed,
          rpm: reading.rpm,
          odometer: reading.odometer,
          errorCodes: reading.errorCodes,
          timestamp: reading.timestamp,
          additionalData: {
            'notes': reading.notes,
          },
        );

        final docRef = _firestore.collection('obd_readings').doc(reading.id);
        batch.set(docRef, firebaseReading.toMap());
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to sync OBD readings: $e');
    }
  }

  Stream<List<FirebaseOBDReading>> getVehicleOBDReadings(String vehicleId, {int limit = 100}) {
    return _firestore
        .collection('obd_readings')
        .where('vehicleId', isEqualTo: vehicleId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => FirebaseOBDReading.fromFirestore(doc)).toList());
  }

  // Analytics and Statistics
  Future<Map<String, dynamic>> getVehicleStatistics(String vehicleId) async {
    try {
      // Get total OBD readings
      final obdCount = await _firestore
          .collection('obd_readings')
          .where('vehicleId', isEqualTo: vehicleId)
          .count()
          .get();

      // Get parts count
      final partsCount = await _firestore
          .collection('vehicle_parts')
          .where('vehicleId', isEqualTo: vehicleId)
          .where('status', isEqualTo: PartStatus.active.name)
          .count()
          .get();

      // Get service records count
      final servicesCount = await _firestore
          .collection('service_records')
          .where('vehicleId', isEqualTo: vehicleId)
          .count()
          .get();

      // Get parts needing replacement
      final partsQuery = await _firestore
          .collection('vehicle_parts')
          .where('vehicleId', isEqualTo: vehicleId)
          .where('status', isEqualTo: PartStatus.needsReplacement.name)
          .count()
          .get();

      return {
        'totalReadings': obdCount.count,
        'activeParts': partsCount.count,
        'totalServices': servicesCount.count,
        'partsNeedingReplacement': partsQuery.count,
      };
    } catch (e) {
      print('Error getting vehicle statistics: $e');
      return {
        'totalReadings': 0,
        'activeParts': 0,
        'totalServices': 0,
        'partsNeedingReplacement': 0,
      };
    }
  }

  // Real-time updates for workshops
  Stream<List<Vehicle>> getWorkshopAssignedVehicles(String workshopId) {
    return _firestore
        .collection('service_records')
        .where('workshopId', isEqualTo: workshopId)
        .where('status', whereIn: [ServiceStatus.scheduled.name, ServiceStatus.inProgress.name])
        .snapshots()
        .asyncMap((snapshot) async {
      final vehicleIds = snapshot.docs
          .map((doc) => ServiceRecord.fromFirestore(doc).vehicleId)
          .toSet()
          .toList();

      if (vehicleIds.isEmpty) return <Vehicle>[];

      final vehiclesQuery = await _firestore
          .collection('vehicles')
          .where(FieldPath.documentId, whereIn: vehicleIds)
          .get();

      return vehiclesQuery.docs.map((doc) => Vehicle.fromFirestore(doc)).toList();
    });
  }
}
