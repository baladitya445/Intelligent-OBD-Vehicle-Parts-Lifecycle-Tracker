class VehiclePart {
  final String id;
  final String name;
  final String category;
  final DateTime installationDate;
  final int installationOdometer;
  final int currentOdometer;
  final int lifespanKm;
  final String qrCode;
  final String manufacturer;
  final String partNumber;

  VehiclePart({
    required this.id,
    required this.name,
    required this.category,
    required this.installationDate,
    required this.installationOdometer,
    required this.currentOdometer,
    required this.lifespanKm,
    required this.qrCode,
    required this.manufacturer,
    required this.partNumber,
  });

  // Calculate kilometers used
  int get kmUsed => currentOdometer - installationOdometer;

  // Calculate remaining kilometers
  int get kmRemaining => lifespanKm - kmUsed;

  // Calculate lifecycle percentage
  double get lifecyclePercentage => (kmUsed / lifespanKm * 100).clamp(0, 100);

  // Check if part needs replacement soon
  bool get needsReplacementSoon => lifecyclePercentage > 80;

  // Check if part is overdue
  bool get isOverdue => lifecyclePercentage >= 100;

  // Get status color
  String get statusColor {
    if (isOverdue) return 'red';
    if (needsReplacementSoon) return 'orange';
    return 'green';
  }

  // Get days since installation
  int get daysSinceInstallation => DateTime.now().difference(installationDate).inDays;
}
