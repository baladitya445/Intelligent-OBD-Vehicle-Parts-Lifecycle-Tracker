import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_sync_service.dart';
import '../models/vehicle_profile.dart';

class SyncStatusScreen extends StatefulWidget {
  final VehicleProfile vehicle;

  const SyncStatusScreen({Key? key, required this.vehicle}) : super(key: key);

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  final FirebaseSyncService _syncService = FirebaseSyncService();
  late Stream<QuerySnapshot> _partsStream;

  @override
  void initState() {
    super.initState();
    _partsStream = _syncService.getPartsStream(widget.vehicle.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Firebase Sync Status'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildVehicleSyncCard(),
            _buildPartsSyncCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSyncCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _syncService.getVehicleSyncStatus(widget.vehicle.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange),
            ),
            child: const Text('Vehicle data not synced yet'),
          );
        }

        final data = snapshot.data!;
        final uploadedAt = data['uploadedAt'] as Timestamp?;
        final lastModified = data['lastModified'] as Timestamp?;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_done, color: Colors.green[700], size: 32),
                  const SizedBox(width: 12),
                  const Text(
                    'Vehicle Data Synced',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSyncInfo('Vehicle Name', data['name'] ?? 'N/A'),
              _buildSyncInfo('Registration', data['registrationNumber'] ?? 'N/A'),
              _buildSyncInfo('Odometer', '${data['currentOdometer'] ?? 0} km'),
              if (uploadedAt != null)
                _buildSyncInfo(
                  'Uploaded At',
                  _formatTime(uploadedAt.toDate()),
                ),
              if (lastModified != null)
                _buildSyncInfo(
                  'Last Modified',
                  _formatTime(lastModified.toDate()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartsSyncCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Parts Sync Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: _partsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text('No parts synced yet'),
                );
              }

              final parts = snapshot.data!.docs;

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_done,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${parts.length} parts synced to Firebase',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...parts.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final uploadedAt = data['uploadedAt'] as Timestamp?;
                    final lastModified = data['lastModified'] as Timestamp?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data['name'] ?? 'Unknown Part',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildPartSyncInfo('Category', data['category'] ?? 'N/A'),
                          _buildPartSyncInfo('Manufacturer', data['manufacturer'] ?? 'N/A'),
                          _buildPartSyncInfo('Part Number', data['partNumber'] ?? 'N/A'),
                          _buildPartSyncInfo(
                            'KM Used',
                            '${data['kmUsed'] ?? 0} / ${data['lifespanKm'] ?? 0} km',
                          ),
                          _buildPartSyncInfo(
                            'Lifecycle',
                            '${(data['lifecyclePercentage'] ?? 0).toStringAsFixed(1)}%',
                          ),
                          if (uploadedAt != null)
                            _buildPartSyncInfo(
                              'Uploaded',
                              _formatTime(uploadedAt.toDate()),
                            ),
                          if (lastModified != null)
                            _buildPartSyncInfo(
                              'Updated',
                              _formatTime(lastModified.toDate()),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSyncInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartSyncInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
