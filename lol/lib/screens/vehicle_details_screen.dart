import 'package:flutter/material.dart';
import '../models/vehicle_profile.dart';
import '../models/vehicle_part.dart';
import '../services/firebase_sync_service.dart';
import 'add_part_screen.dart';
import 'qr_scanner_screen.dart';
import 'sync_status_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final VehicleProfile vehicle;
  final bool isOnline;
  final int? odometerAtConnection;

  const VehicleDetailsScreen({
    Key? key,
    required this.vehicle,
    required this.isOnline,
    this.odometerAtConnection,
  }) : super(key: key);

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  late List<VehiclePart> allParts;
  final FirebaseSyncService _syncService = FirebaseSyncService();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    allParts = [...widget.vehicle.parts];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Vehicle Details'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isSyncing ? Icons.cloud_upload : Icons.cloud_done,
              color: _isSyncing ? Colors.orange : Colors.white,
            ),
            tooltip: 'Sync Status',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SyncStatusScreen(vehicle: widget.vehicle),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildVehicleHeader(),
            _buildConnectionStatus(),
            _buildVehicleMetrics(),
            _buildPartsSection(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPartOptions(),
        icon: const Icon(Icons.add),
        label: const Text('Add Part'),
        backgroundColor: Colors.blue[700],
      ),
    );
  }

  Widget _buildVehicleHeader() {
    return Container(
      color: Colors.blue[700],
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.two_wheeler,
              size: 60,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.vehicle.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.vehicle.year} ${widget.vehicle.standard}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.vehicle.currentOdometer} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      margin: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.isOnline ? Icons.online_prediction : Icons.offline_pin,
              color: widget.isOnline ? Colors.green : Colors.grey,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehicle Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isOnline ? 'ONLINE - OBD Connected' : 'OFFLINE - Not Connected',
                  style: TextStyle(
                    color: widget.isOnline ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleMetrics() {
    final kmSinceConnected = widget.isOnline && widget.odometerAtConnection != null
        ? widget.vehicle.currentOdometer - widget.odometerAtConnection!
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Odometer',
                  '${widget.vehicle.currentOdometer} km',
                  Icons.speed,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'KMs Since Connected',
                  '$kmSinceConnected km',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.vehicle.partsNeedingAttention.isNotEmpty)
            _buildMetricCard(
              'Parts Needing Attention',
              '${widget.vehicle.partsNeedingAttention.length} parts',
              Icons.warning,
              Colors.red,
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Parts & Maintenance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.vehicle.partsNeedingAttention.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.vehicle.partsNeedingAttention.length} need attention',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (allParts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('No parts added yet'),
              ),
            )
          else
            ...allParts.map((part) => _buildPartCard(part)).toList(),
        ],
      ),
    );
  }

  Widget _buildPartCard(VehiclePart part) {
    Color statusColor = part.isOverdue
        ? Colors.red
        : part.needsReplacementSoon
        ? Colors.orange
        : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getPartIcon(part.category),
            color: statusColor,
            size: 24,
          ),
        ),
        title: Text(
          part.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${part.manufacturer} • ${part.category}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: part.lifecyclePercentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${part.kmUsed} / ${part.lifespanKm} km',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${part.lifecyclePercentage.toStringAsFixed(1)}% used',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailRow(
                        'Part Number',
                        part.partNumber,
                        Icons.tag,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailRow(
                        'Installed',
                        '${part.daysSinceInstallation} days ago',
                        Icons.calendar_today,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailRow(
                        'Installation ODO',
                        '${part.installationOdometer} km',
                        Icons.pin_drop,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailRow(
                        'Remaining',
                        '${part.kmRemaining} km',
                        Icons.trending_down,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'QR Code',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            QrImageView(
                              data: part.qrCode,
                              version: QrVersions.auto,
                              size: 100,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              part.qrCode,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete Part',
                      onPressed: () => _deletePart(part.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getPartIcon(String category) {
    switch (category.toLowerCase()) {
      case 'engine':
        return Icons.settings;
      case 'intake':
        return Icons.air;
      case 'ignition':
        return Icons.flash_on;
      case 'braking':
        return Icons.phonelink_lock;
      case 'transmission':
        return Icons.link;
      case 'suspension':
        return Icons.speed;
      case 'electrical':
        return Icons.electrical_services;
      case 'cooling':
        return Icons.ac_unit;
      case 'wheels':
        return Icons.circle;
      case 'bodywork':
        return Icons.build;
      default:
        return Icons.build;
    }
  }

  void _deletePart(String partId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Part?'),
        content: const Text('Are you sure you want to delete this part?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                setState(() {
                  _isSyncing = true;
                });

                // Delete from Firebase
                await _syncService.deletePart(partId, widget.vehicle.id);

                setState(() {
                  allParts.removeWhere((p) => p.id == partId);
                  _isSyncing = false;
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Part deleted and synced to Firebase'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                setState(() {
                  _isSyncing = false;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddPartOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Part'),
        content: const Text('How would you like to add the part?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QRScannerScreen(),
                ),
              ).then((scannedData) {
                if (scannedData != null) {
                  _navigateToAddPartScreen(scannedData);
                }
              });
            },
            child: const Text('Scan QR Code'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddPartScreen(),
                ),
              ).then((newPart) {
                if (newPart != null) {
                  _addPartAndSync(newPart);
                }
              });
            },
            child: const Text('Manual Entry'),
          ),
        ],
      ),
    );
  }


  void _navigateToAddPartScreen(String qrData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPartScreen(qrData: qrData),
      ),
    ).then((newPart) {
      if (newPart != null) {
        _addPartAndSync(newPart);
      }
    });
  }

  Future<void> _addPartAndSync(VehiclePart newPart) async {
    try {
      setState(() {
        _isSyncing = true;
      });

      // Upload to Firebase
      await _syncService.uploadPart(newPart, widget.vehicle.id);

      setState(() {
        allParts.add(newPart);
        _isSyncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Part added and synced to Firebase'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isSyncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error syncing part: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
