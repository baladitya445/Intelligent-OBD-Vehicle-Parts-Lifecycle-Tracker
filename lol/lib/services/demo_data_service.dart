import '../models/vehicle_profile.dart';
import '../models/vehicle_part.dart';

class DemoDataService {
  static List<VehicleProfile> _allVehicles = [];

  static List<VehicleProfile> getAllVehicles() {
    if (_allVehicles.isEmpty) {
      _allVehicles.add(getDemoVehicle());
    }
    return _allVehicles;
  }

  static void addVehicle(VehicleProfile vehicle) {
    _allVehicles.add(vehicle);
  }

  static void removeVehicle(String vehicleId) {
    _allVehicles.removeWhere((v) => v.id == vehicleId);
  }

  static VehicleProfile getDemoVehicle() {
    return VehicleProfile(
      id: 'demo_bike_001',
      name: 'Yamaha R15 V4',
      model: 'R15',
      year: '2021',
      standard: 'BS6',
      registrationNumber: 'TN11AY7333',
      imageUrl: null,
      currentOdometer: 12450,
      obdConnected: false,
      parts: _getDemoParts(),
      recentKmData: [45, 52, 38, 61, 48, 55, 42],
    );
  }

  static List<VehiclePart> _getDemoParts() {
    final now = DateTime.now();
    return [
      VehiclePart(
        id: 'part_001',
        name: 'Engine Oil Filter',
        category: 'Engine',
        installationDate: now.subtract(const Duration(days: 85)),
        installationOdometer: 11200,
        currentOdometer: 12450,
        lifespanKm: 3000,
        qrCode: 'QR-OIL-FILTER-001',
        manufacturer: 'K&N',
        partNumber: 'KN-164',
      ),
      VehiclePart(
        id: 'part_002',
        name: 'Air Filter',
        category: 'Intake',
        installationDate: now.subtract(const Duration(days: 180)),
        installationOdometer: 10200, // Changed to show as needing attention
        currentOdometer: 12450,
        lifespanKm: 2500, // Reduced to show it needs attention
        qrCode: 'QR-AIR-FILTER-002',
        manufacturer: 'K&N',
        partNumber: 'KN-YA-1514',
      ),
      VehiclePart(
        id: 'part_003',
        name: 'Spark Plug',
        category: 'Ignition',
        installationDate: now.subtract(const Duration(days: 180)),
        installationOdometer: 9500,
        currentOdometer: 12450,
        lifespanKm: 8000,
        qrCode: 'QR-SPARK-PLUG-003',
        manufacturer: 'NGK',
        partNumber: 'CR9EIA-9',
      ),
      VehiclePart(
        id: 'part_004',
        name: 'Brake Pads (Front)',
        category: 'Braking',
        installationDate: now.subtract(const Duration(days: 45)),
        installationOdometer: 11900,
        currentOdometer: 12450,
        lifespanKm: 10000,
        qrCode: 'QR-BRAKE-PAD-004',
        manufacturer: 'Brembo',
        partNumber: 'BR-07YA22SA',
      ),
      VehiclePart(
        id: 'part_005',
        name: 'Chain & Sprocket Kit',
        category: 'Transmission',
        installationDate: now.subtract(const Duration(days: 200)),
        installationOdometer: 8950,
        currentOdometer: 12450,
        lifespanKm: 15000,
        qrCode: 'QR-CHAIN-005',
        manufacturer: 'DID',
        partNumber: 'DID-525-VX3',
      ),
    ];
  }

  static Map<String, dynamic> getLiveOBDData() {
    return {
      'speed': 0,
      'engineTemp': 85,
      'voltage': 12.8,
      'fuelLevel': 78,
      'timestamp': DateTime.now(),
    };
  }
}
