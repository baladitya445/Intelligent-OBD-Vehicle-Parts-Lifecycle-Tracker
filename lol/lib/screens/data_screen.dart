import 'package:flutter/material.dart';
import 'dart:async';
import '../services/obd_service.dart';
import '../models/vehicle_data.dart';
import '../services/logging_service.dart';
import '../models/obd_reading.dart';
import '../utils/data_formatter.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final OBDService _obdService = OBDService();
  final LoggingService _loggingService = LoggingService();
  Timer? _dataTimer;

  VehicleData _currentData = VehicleData();
  bool _isReading = false;

  // Step 2: New logging variables
  List<OBDReading> _recentReadings = [];
  Map<String, dynamic> _loggingStats = {};

  @override
  void initState() {
    super.initState();
    _startDataReading();
    _loadRecentReadings(); // Step 2: Load logging data
  }

  void _startDataReading() {
    _dataTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _readVehicleData();
    });
  }

  Future<void> _readVehicleData() async {
    if (_isReading) return;

    setState(() {
      _isReading = true;
    });

    try {
      VehicleData data = await _obdService.getAllData();
      setState(() {
        _currentData = data;
      });
    } catch (e) {
      print('Error reading vehicle data: $e');
    } finally {
      setState(() {
        _isReading = false;
      });
    }
  }

  // Step 2: New methods for logging functionality
  Future<void> _loadRecentReadings() async {
    try {
      final readings = await _loggingService.getRecentReadings(limit: 10);
      final stats = await _loggingService.getStatistics();
      setState(() {
        _recentReadings = readings;
        _loggingStats = stats;
      });
    } catch (e) {
      print('Error loading readings: $e');
    }
  }

  void _toggleLogging() async {
    if (_loggingService.isLogging) {
      _loggingService.stopLogging();
    } else {
      await _loggingService.startLogging();
    }
    await _loadRecentReadings();
  }

  Future<void> _collectSingleReading() async {
    final reading = await _loggingService.collectSingleReading();
    if (reading != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reading collected and saved!')),
      );
      await _loadRecentReadings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to collect reading')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Connection Status Card
          Card(
            color: _currentData.isConnected ? Colors.green[50] : Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    _currentData.isConnected ? Icons.check_circle : Icons.error,
                    color: _currentData.isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentData.isConnected ? 'OBD Connected' : 'OBD Disconnected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _currentData.isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_isReading) const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Vehicle Data Cards
          Expanded(
            child: _currentData.isConnected
                ? SingleChildScrollView(
              child: Column(
                children: [
                  // Speed Card
                  _buildDataCard(
                    'Vehicle Speed',
                    _currentData.speed?.toString() ?? '--',
                    'km/h',
                    Icons.speed,
                    Colors.blue,
                  ),

                  const SizedBox(height: 12),

                  // RPM Card
                  _buildDataCard(
                    'Engine RPM',
                    _currentData.rpm?.toString() ?? '--',
                    'rpm',
                    Icons.settings,
                    Colors.orange,
                  ),

                  const SizedBox(height: 12),

                  // Error Codes Card
                  _buildErrorCard(),

                  const SizedBox(height: 12),

                  // Step 2: Logging Control Card
                  _buildLoggingCard(),

                  const SizedBox(height: 12),

                  // Step 2: Recent Readings Card
                  _buildRecentReadingsCard(),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isReading ? null : _readVehicleData,
                          child: const Text('Refresh Data'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _currentData.isConnected && !_isReading
                              ? _collectSingleReading
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('Save Reading'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
                : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Connect to OBD device first',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Go to Bluetooth tab to connect',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(String title, String value, String unit, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _currentData.errorCodes.isEmpty ? Icons.check_circle : Icons.warning,
                  color: _currentData.errorCodes.isEmpty ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Text(
                  'Diagnostic Codes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_currentData.errorCodes.isEmpty)
              const Text(
                'No error codes detected',
                style: TextStyle(color: Colors.green),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _currentData.errorCodes.map((code) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '• $code',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // Step 2: New logging control card
  Widget _buildLoggingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _loggingService.isLogging ? Icons.play_circle : Icons.pause_circle,
                  color: _loggingService.isLogging ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Logging',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _loggingService.isLogging ? 'Active (Every 30s)' : 'Stopped',
                      style: TextStyle(
                        color: _loggingService.isLogging ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _currentData.isConnected ? _toggleLogging : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _loggingService.isLogging ? Colors.red : Colors.green,
                  ),
                  child: Text(_loggingService.isLogging ? 'Stop' : 'Start'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_loggingStats['totalReadings'] ?? 0}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Text('Total Logged', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_loggingStats['unuploadedReadings'] ?? 0}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const Text('Pending Upload', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_loggingStats['unresolvedErrors'] ?? 0}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const Text('Errors', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Step 2: Recent readings display card
  Widget _buildRecentReadingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Recent Readings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: _loadRecentReadings,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_recentReadings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'No readings logged yet',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentReadings.length > 5 ? 5 : _recentReadings.length,
                  itemBuilder: (context, index) {
                    final reading = _recentReadings[index];
                    return Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${reading.speed ?? 0} km/h',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('${reading.rpm ?? 0} rpm'),
                          if (reading.errorCodes.isNotEmpty)
                            Text(
                              '${reading.errorCodes.length} errors',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          const Spacer(),
                          Text(
                            _formatTime(reading.timestamp),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Row(
                            children: [
                              Icon(
                                reading.isUploaded ? Icons.cloud_done : Icons.cloud_upload,
                                size: 12,
                                color: reading.isUploaded ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                reading.isUploaded ? 'Synced' : 'Pending',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: reading.isUploaded ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    _loggingService.dispose(); // Step 2: Clean up logging service
    super.dispose();
  }
}
