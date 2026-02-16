import '../models/vehicle_part.dart';

class PartManagementService {
  static final PartManagementService _instance = PartManagementService._internal();

  factory PartManagementService() => _instance;
  PartManagementService._internal();

  List<VehiclePart> _addedParts = [];

  List<VehiclePart> get addedParts => _addedParts;

  void addPart(VehiclePart part) {
    _addedParts.add(part);
  }

  void removePart(String partId) {
    _addedParts.removeWhere((part) => part.id == partId);
  }

  void updatePart(String partId, VehiclePart updatedPart) {
    final index = _addedParts.indexWhere((part) => part.id == partId);
    if (index != -1) {
      _addedParts[index] = updatedPart;
    }
  }

  void dispose() {
    _addedParts.clear();
  }
}
