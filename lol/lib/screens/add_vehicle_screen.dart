import 'package:flutter/material.dart';
import '../models/vehicle_profile.dart';
import '../models/vehicle_part.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({Key? key}) : super(key: key);

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _standardController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _odometerController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _standardController.dispose();
    _regNumberController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Vehicle'),
        backgroundColor: Colors.blue[700],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTextField('Vehicle Name', _nameController, Icons.directions_car),
              const SizedBox(height: 16),
              _buildTextField('Model', _modelController, Icons.category),
              const SizedBox(height: 16),
              _buildTextField('Year', _yearController, Icons.calendar_today),
              const SizedBox(height: 16),
              _buildTextField('Standard (e.g., BS6)', _standardController, Icons.eco),
              const SizedBox(height: 16),
              _buildTextField('Registration Number', _regNumberController, Icons.pin),
              const SizedBox(height: 16),
              _buildTextField('Current Odometer (km)', _odometerController, Icons.speed, isNumber: true),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveVehicle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Add Vehicle', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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

  void _saveVehicle() {
    if (_formKey.currentState!.validate()) {
      final newVehicle = VehicleProfile(
        id: 'vehicle_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        model: _modelController.text,
        year: _yearController.text,
        standard: _standardController.text,
        registrationNumber: _regNumberController.text,
        currentOdometer: int.tryParse(_odometerController.text) ?? 0,
        obdConnected: false,
        parts: [],
        recentKmData: [0, 0, 0, 0, 0, 0, 0],
      );

      Navigator.pop(context, newVehicle);
    }
  }
}
