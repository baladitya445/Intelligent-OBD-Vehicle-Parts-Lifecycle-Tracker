import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../services/bluetooth_service.dart';
import '../services/obd_service.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final OBDService _obdService = OBDService();

  List<BluetoothDevice> _devices = [];
  bool _isLoading = false;
  bool _isConnected = false;
  String _statusMessage = 'Not connected';

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadDevices();
  }

  Future<void> _checkPermissionsAndLoadDevices() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking permissions...';
    });

    bool permissionsGranted = await _bluetoothService.requestPermissions();

    if (permissionsGranted) {
      await _loadPairedDevices();
    } else {
      setState(() {
        _statusMessage = 'Bluetooth permissions required';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPairedDevices() async {
    setState(() {
      _statusMessage = 'Loading paired devices...';
    });

    try {
      List<BluetoothDevice> devices = await _bluetoothService.getPairedDevices();
      setState(() {
        _devices = devices;
        _statusMessage = 'Found ${devices.length} paired devices';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading devices: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to ${device.name}...';
    });

    try {
      bool connected = await _bluetoothService.connectToDevice(device.address);

      if (connected) {
        setState(() {
          _statusMessage = 'Connected! Initializing OBD...';
        });

        bool initialized = await _obdService.initialize();

        setState(() {
          _isConnected = initialized;
          _statusMessage = initialized ?
          'Connected and ready!' :
          'Connected but OBD initialization failed';
          _isLoading = false;
        });
      } else {
        setState(() {
          _statusMessage = 'Failed to connect';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnect() async {
    await _bluetoothService.disconnect();
    setState(() {
      _isConnected = false;
      _statusMessage = 'Disconnected';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: $_statusMessage',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isConnected)
                    ElevatedButton(
                      onPressed: _disconnect,
                      child: const Text('Disconnect'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loadPairedDevices,
                      child: const Text('Refresh Devices'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Paired Bluetooth Devices:',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _devices.isEmpty
                ? const Center(
              child: Text('No paired devices found.\nPair your ELM327 in phone settings first.'),
            )
                : ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                BluetoothDevice device = _devices[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(device.name ?? 'Unknown Device'),
                    subtitle: Text(device.address),
                    trailing: _isConnected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.arrow_forward_ios),
                    onTap: _isConnected || _isLoading
                        ? null
                        : () => _connectToDevice(device),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _obdService.dispose();
    super.dispose();
  }
}
