import 'package:flutter/material.dart';
import '../models/vehicle_part.dart';
import '../services/firebase_sync_service.dart';

class AddPartScreen extends StatefulWidget {
  final String? qrData;

  const AddPartScreen({Key? key, this.qrData}) : super(key: key);

  @override
  State<AddPartScreen> createState() => _AddPartScreenState();
}

class _AddPartScreenState extends State<AddPartScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController manufacturerController;
  late TextEditingController partNumberController;
  late TextEditingController lifespanController;
  late TextEditingController odometerController;
  String selectedCategory = 'Engine';
  bool _isSaving = false;

  final List<String> categories = [
    'Engine',
    'Intake',
    'Ignition',
    'Braking',
    'Transmission',
    'Suspension',
    'Electrical',
    'Cooling',
    'Wheels',
    'Bodywork',
    'Exhaust',
    'Fuel System',
    'Lighting',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    manufacturerController = TextEditingController();
    partNumberController = TextEditingController(text: _qrData ?? '');
    lifespanController = TextEditingController();
    odometerController = TextEditingController();
  }

  String? get _qrData => widget.qrData;

  @override
  void dispose() {
    nameController.dispose();
    manufacturerController.dispose();
    partNumberController.dispose();
    lifespanController.dispose();
    odometerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Part'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_qrData != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QR Code Scanned',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _qrData!,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              _buildTextField('Part Name', nameController, Icons.build),
              const SizedBox(height: 12),
              _buildTextField('Manufacturer', manufacturerController, Icons.factory),
              const SizedBox(height: 12),
              _buildCategoryDropdown(),
              const SizedBox(height: 12),
              _buildTextField('Part Number', partNumberController, Icons.tag),
              const SizedBox(height: 12),
              _buildTextField('Lifespan (km)', lifespanController, Icons.trending_down, isNumber: true),
              const SizedBox(height: 12),
              _buildTextField('Current Odometer (km)', odometerController, Icons.speed, isNumber: true),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _addPart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text('Add Part', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              if (_isSaving)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_upload, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Text(
                        'Syncing to Firebase...',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon, {
        bool isNumber = false,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      enabled: !_isSaving,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedCategory,
      items: categories
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: _isSaving
          ? null
          : (value) {
        setState(() {
          selectedCategory = value ?? 'Engine';
        });
      },
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(Icons.category),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _addPart() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        final newPart = VehiclePart(
          id: 'part_${DateTime.now().millisecondsSinceEpoch}',
          name: nameController.text,
          category: selectedCategory,
          installationDate: DateTime.now(),
          installationOdometer: int.tryParse(odometerController.text) ?? 0,
          currentOdometer: int.tryParse(odometerController.text) ?? 0,
          lifespanKm: int.tryParse(lifespanController.text) ?? 5000,
          qrCode: _qrData ?? partNumberController.text,
          manufacturer: manufacturerController.text,
          partNumber: partNumberController.text,
        );

        print('✅ Part created: ${newPart.name}');
        print('📤 Ready to sync to Firebase from vehicle details screen');

        // Return the part to the previous screen
        // The actual Firebase sync will happen in vehicle_details_screen.dart
        Navigator.pop(context, newPart);
      } catch (e) {
        print('❌ Error creating part: $e');
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
