import 'package:flutter/material.dart';
import '../services/demo_data_service.dart';
import 'vehicle_profile_screen.dart';

class BluetoothDevicesScreen extends StatelessWidget {
  const BluetoothDevicesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final devices = DemoDataService.getDemoBluetoothDevices();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Bluetooth Device'),
        backgroundColor: Colors.blue[700],
      ),
      body: ListView.separated(
        itemCount: devices.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final device = devices[index];
          IconData icon;
          Color color;
          if (device['type'] == 'obd') {
            icon = Icons.directions_car;
            color = Colors.red;
          } else if (device['type'] == 'audio') {
            icon = Icons.headset;
            color = Colors.blue;
          } else {
            icon = Icons.watch;
            color = Colors.purple;
          }

          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(device['name']!),
            subtitle: Text(device['address']!),
            trailing: device['type'] == 'obd'
                ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
              ),
              onPressed: () {
                // Mimic connection and show loading, then navigate to vehicle profile!
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    content: Row(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(width: 20),
                        const Text('Connecting OBD...'),
                      ],
                    ),
                  ),
                );
                Future.delayed(const Duration(seconds: 2), () {
                  Navigator.pop(context); // Remove loading
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VehicleProfileScreen(),
                    ),
                  );
                });
              },
              child: const Text('Connect'),
            )
                : null,
          );
        },
      ),
    );
  }
}
