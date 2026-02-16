import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../services/demo_data_service.dart';
import '../services/firebase_sync_service.dart';
import '../models/vehicle_profile.dart';
import 'vehicle_details_screen.dart';
import 'add_vehicle_screen.dart';
import 'select_vehicle_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<VehicleProfile> vehicles = [];
  VehicleProfile? connectedVehicle;
  int? odometerAtConnection;
  List<BluetoothDevice> availableDevices = [];
  List<BluetoothDiscoveryResult> discoveredDevices = [];
  BluetoothDevice? savedOBDDevice;
  bool isScanning = false;
  bool obdConnected = false;
  bool _isSyncingVehicle = false;
  final FirebaseSyncService _syncService = FirebaseSyncService();

  @override
  void initState() {
    super.initState();
    vehicles = DemoDataService.getAllVehicles();
    _fetchBondedDevices();
    _startDiscovery();
  }

  Future<void> _fetchBondedDevices() async {
    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        availableDevices = devices;
        // Look for OBDII device
        savedOBDDevice = devices.where((device) {
          final name = device.name?.toUpperCase() ?? '';
          return name.contains('OBD') || name.contains('ELM327');
        }).firstOrNull;
      });
    } catch (e) {
      print('Error fetching devices: $e');
    }
  }

  void _startDiscovery() {
    setState(() {
      isScanning = true;
      discoveredDevices.clear();
    });

    FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
      setState(() {
        if (!discoveredDevices.any((d) => d.device.address == result.device.address)) {
          discoveredDevices.add(result);
        }
      });
    }).onDone(() {
      setState(() {
        isScanning = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Workshop Tracker'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.bluetooth_searching : Icons.refresh),
            onPressed: _startDiscovery,
            tooltip: 'Scan Devices',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchBondedDevices();
          _startDiscovery();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildOBDConnectionSection(),
              _buildAvailableDevicesSection(),
              _buildVehicleSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOBDConnectionSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue[700]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saved OBD Device',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  obdConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                  color: obdConnected ? Colors.green : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OBDII',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        obdConnected
                            ? 'Connected to ${connectedVehicle?.name ?? "Vehicle"}'
                            : 'Not connected',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _isSyncingVehicle
                      ? null
                      : (obdConnected ? _disconnectOBD : _connectToOBD),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: obdConnected ? Colors.red : Colors.blue[700],
                  ),
                  child: _isSyncingVehicle
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(obdConnected ? 'Disconnect' : 'Connect'),
                ),
              ],
            ),
          ),
          if (_isSyncingVehicle)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'Syncing vehicle data to Firebase...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvailableDevicesSection() {
    // Combine bonded and discovered devices
    Set<String> seenAddresses = {};
    List<BluetoothDevice> allDevices = [];

    // Add bonded devices first
    for (var device in availableDevices) {
      if (seenAddresses.add(device.address)) {
        allDevices.add(device);
      }
    }

    // Add discovered devices
    for (var result in discoveredDevices) {
      if (seenAddresses.add(result.device.address)) {
        allDevices.add(result.device);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Devices',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isScanning)
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${discoveredDevices.length} found',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (allDevices.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_disabled,
                      color: Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    const Text('No devices found. Pull down to refresh.'),
                    const SizedBox(height: 12),
                    if (isScanning)
                      const Text(
                        'Scanning...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            ...allDevices.map((device) {
              bool isOBD = device.name?.toUpperCase().contains('OBD') ?? false;
              bool isELM = device.name?.toUpperCase().contains('ELM') ?? false;
              bool isBonded = availableDevices.any((d) => d.address == device.address);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: (isOBD || isELM)
                      ? Border.all(color: Colors.blue[700]!, width: 2)
                      : null,
                ),
                child: ListTile(
                  leading: Icon(
                    (isOBD || isELM) ? Icons.directions_car : Icons.bluetooth,
                    color: (isOBD || isELM) ? Colors.blue[700] : Colors.grey,
                  ),
                  title: Text(device.name ?? 'Unknown Device'),
                  subtitle: Text(device.address),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isBonded)
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                      if (isOBD || isELM)
                        const SizedBox(width: 8),
                      if (isOBD || isELM)
                        const Icon(Icons.verified, color: Colors.blue, size: 20),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildVehicleSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Vehicles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Colors.blue[700],
                onPressed: () async {
                  final newVehicle = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddVehicleScreen(),
                    ),
                  );
                  if (newVehicle != null) {
                    await _addVehicleAndSync(newVehicle);
                  }
                },
                tooltip: 'Add Vehicle',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (vehicles.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('No vehicles added yet'),
              ),
            )
          else
            ...vehicles.map((vehicle) {
              final isConnected = obdConnected && connectedVehicle?.id == vehicle.id;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VehicleDetailsScreen(
                        vehicle: vehicle,
                        isOnline: isConnected,
                        odometerAtConnection: odometerAtConnection,
                      ),
                    ),
                  );
                },
                child: _buildVehicleCard(vehicle, isConnected),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(VehicleProfile vehicle, bool isConnected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.two_wheeler,
              size: 48,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${vehicle.year} ${vehicle.standard}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vehicle.registrationNumber,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConnected ? Icons.online_prediction : Icons.offline_pin,
                        size: 14,
                        color: isConnected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConnected ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToOBD() async {
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a vehicle first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedVehicle = await showDialog<VehicleProfile>(
      context: context,
      builder: (context) => SelectVehicleDialog(vehicles: vehicles),
    );

    if (selectedVehicle != null) {
      try {
        setState(() {
          _isSyncingVehicle = true;
        });

        print('📤 Syncing vehicle to Firebase...');

        // Upload vehicle to Firebase
        await _syncService.uploadVehicle(selectedVehicle);

        // Upload all parts to Firebase
        for (var part in selectedVehicle.parts) {
          await _syncService.uploadPart(part, selectedVehicle.id);
        }

        setState(() {
          obdConnected = true;
          connectedVehicle = selectedVehicle;
          odometerAtConnection = selectedVehicle.currentOdometer;
          _isSyncingVehicle = false;
        });

        print('✅ Vehicle synced successfully');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OBD Connected to ${selectedVehicle.name} - Data synced!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        print('❌ Error syncing vehicle: $e');

        setState(() {
          _isSyncingVehicle = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _disconnectOBD() {
    setState(() {
      obdConnected = false;
      connectedVehicle = null;
      odometerAtConnection = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OBD Disconnected'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _addVehicleAndSync(VehicleProfile newVehicle) async {
    try {
      setState(() {
        vehicles.add(newVehicle);
      });

      // Optionally sync new vehicle to Firebase immediately
      print('📤 New vehicle added: ${newVehicle.name}');

      // Sync when user connects to it, not automatically
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle added. Connect OBD to sync to Firebase.'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('❌ Error adding vehicle: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
