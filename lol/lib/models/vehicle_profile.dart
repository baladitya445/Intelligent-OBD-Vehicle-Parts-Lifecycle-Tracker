import 'vehicle_part.dart';

class VehicleProfile {
  final String id;
  final String name;
  final String model;
  final String year;
  final String standard;
  final String registrationNumber;
  final String? imageUrl;
  final int currentOdometer;
  final bool obdConnected;
  final List<VehiclePart> parts;
  final List<int> recentKmData; // Last 7 days km

  VehicleProfile({
    required this.id,
    required this.name,
    required this.model,
    required this.year,
    required this.standard,
    required this.registrationNumber,
    this.imageUrl,
    required this.currentOdometer,
    required this.obdConnected,
    required this.parts,
    required this.recentKmData,
  });

  String get fullName => '$name $model $year $standard ($registrationNumber)';

  // Calculate average daily km
  double get averageDailyKm {
    if (recentKmData.isEmpty) return 0;
    return recentKmData.reduce((a, b) => a + b) / recentKmData.length;
  }

  // Get parts needing attention
  List<VehiclePart> get partsNeedingAttention {
    return parts.where((part) => part.needsReplacementSoon || part.isOverdue).toList();
  }
}
