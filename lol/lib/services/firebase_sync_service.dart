import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle_profile.dart';
import '../models/vehicle_part.dart';

class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();

  factory FirebaseSyncService() => _instance;
  FirebaseSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _vehiclesCollection = 'vehicles';
  final String _partsCollection = 'parts';

  // Upload vehicle data to Firebase
  Future<void> uploadVehicle(VehicleProfile vehicle) async {
    try {
      print('📤 Uploading vehicle: ${vehicle.name}');

      await _firestore.collection(_vehiclesCollection).doc(vehicle.id).set({
        'id': vehicle.id,
        'name': vehicle.name,
        'model': vehicle.model,
        'year': vehicle.year,
        'standard': vehicle.standard,
        'registrationNumber': vehicle.registrationNumber,
        'currentOdometer': vehicle.currentOdometer,
        'obdConnected': vehicle.obdConnected,
        'recentKmData': vehicle.recentKmData,
        'uploadedAt': FieldValue.serverTimestamp(),
        'lastModified': FieldValue.serverTimestamp(),
      });

      print('✅ Vehicle uploaded successfully');
    } catch (e) {
      print('❌ Error uploading vehicle: $e');
      rethrow;
    }
  }

  // Upload part data to Firebase
  Future<void> uploadPart(VehiclePart part, String vehicleId) async {
    try {
      print('📤 Uploading part: ${part.name}');

      await _firestore
          .collection(_vehiclesCollection)
          .doc(vehicleId)
          .collection(_partsCollection)
          .doc(part.id)
          .set({
        'id': part.id,
        'name': part.name,
        'category': part.category,
        'manufacturer': part.manufacturer,
        'partNumber': part.partNumber,
        'installationDate': part.installationDate.toIso8601String(),
        'installationOdometer': part.installationOdometer,
        'currentOdometer': part.currentOdometer,
        'lifespanKm': part.lifespanKm,
        'qrCode': part.qrCode,
        'kmUsed': part.kmUsed,
        'kmRemaining': part.kmRemaining,
        'lifecyclePercentage': part.lifecyclePercentage,
        'needsReplacementSoon': part.needsReplacementSoon,
        'isOverdue': part.isOverdue,
        'uploadedAt': FieldValue.serverTimestamp(),
        'lastModified': FieldValue.serverTimestamp(),
      });

      print('✅ Part uploaded successfully');
    } catch (e) {
      print('❌ Error uploading part: $e');
      rethrow;
    }
  }

  // Update part data in Firebase
  Future<void> updatePart(VehiclePart part, String vehicleId) async {
    try {
      print('📝 Updating part: ${part.name}');

      await _firestore
          .collection(_vehiclesCollection)
          .doc(vehicleId)
          .collection(_partsCollection)
          .doc(part.id)
          .update({
        'currentOdometer': part.currentOdometer,
        'kmUsed': part.kmUsed,
        'kmRemaining': part.kmRemaining,
        'lifecyclePercentage': part.lifecyclePercentage,
        'needsReplacementSoon': part.needsReplacementSoon,
        'isOverdue': part.isOverdue,
        'lastModified': FieldValue.serverTimestamp(),
      });

      print('✅ Part updated successfully');
    } catch (e) {
      print('❌ Error updating part: $e');
      rethrow;
    }
  }

  // Delete part from Firebase
  Future<void> deletePart(String partId, String vehicleId) async {
    try {
      print('🗑️ Deleting part: $partId');

      await _firestore
          .collection(_vehiclesCollection)
          .doc(vehicleId)
          .collection(_partsCollection)
          .doc(partId)
          .delete();

      print('✅ Part deleted successfully');
    } catch (e) {
      print('❌ Error deleting part: $e');
      rethrow;
    }
  }

  // Get all vehicles from Firebase (for sync status display)
  Stream<QuerySnapshot> getVehiclesStream() {
    return _firestore.collection(_vehiclesCollection).snapshots();
  }

  // Get all parts for a vehicle from Firebase
  Stream<QuerySnapshot> getPartsStream(String vehicleId) {
    return _firestore
        .collection(_vehiclesCollection)
        .doc(vehicleId)
        .collection(_partsCollection)
        .snapshots();
  }

  // Get sync status of a vehicle
  Future<Map<String, dynamic>> getVehicleSyncStatus(String vehicleId) async {
    try {
      final doc = await _firestore
          .collection(_vehiclesCollection)
          .doc(vehicleId)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print('❌ Error getting sync status: $e');
      return {};
    }
  }

  // Get all parts count for a vehicle
  Future<int> getPartsCountForVehicle(String vehicleId) async {
    try {
      final snapshot = await _firestore
          .collection(_vehiclesCollection)
          .doc(vehicleId)
          .collection(_partsCollection)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting parts count: $e');
      return 0;
    }
  }
}
