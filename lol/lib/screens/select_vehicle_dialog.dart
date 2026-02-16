import 'package:flutter/material.dart';
import '../models/vehicle_profile.dart';

class SelectVehicleDialog extends StatelessWidget {
  final List<VehicleProfile> vehicles;

  const SelectVehicleDialog({Key? key, required this.vehicles}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Vehicle'),
      content: SizedBox(
        width: double.maxFinite,
        child: vehicles.isEmpty
            ? const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No vehicles available. Add a vehicle first.'),
        )
            : ListView.builder(
          shrinkWrap: true,
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            return ListTile(
              leading: Icon(Icons.two_wheeler, color: Colors.blue[700]),
              title: Text(vehicle.name),
              subtitle: Text(vehicle.registrationNumber),
              onTap: () {
                Navigator.pop(context, vehicle);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
