import 'dart:ui';
import 'package:flutter/material.dart';
import '../../repositories/user_repository.dart';

class AddEditVehicleScreen extends StatefulWidget {
  final Map<String, dynamic>? existingVehicle;

  const AddEditVehicleScreen({super.key, this.existingVehicle});

  @override
  State<AddEditVehicleScreen> createState() => _AddEditVehicleScreenState();
}

class _AddEditVehicleScreenState extends State<AddEditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final _numberController = TextEditingController();
  final _colorController = TextEditingController();
  String _selectedType = 'Car';
  bool _isLoading = false;

  final UserRepository _userRepo = FirebaseUserRepository();

  final List<String> _vehicleTypes = ['Car', 'Bike', 'SUV', 'Van'];

  @override
  void initState() {
    super.initState();
    if (widget.existingVehicle != null) {
      _modelController.text = widget.existingVehicle!['vehicleModel'] ?? '';
      _numberController.text = widget.existingVehicle!['vehicleNumber'] ?? '';
      _colorController.text = widget.existingVehicle!['vehicleColor'] ?? '';
      _selectedType = widget.existingVehicle!['vehicleType'] ?? 'Car';
    }
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = _userRepo.currentUser;
      if (user == null) return;

      final data = {
        'vehicleModel': _modelController.text.trim(),
        'vehicleNumber': _numberController.text.trim().toUpperCase(),
        'vehicleColor': _colorController.text.trim(),
        'vehicleType': _selectedType,
        'updatedAt': DateTime.now().toString(),
      };

      if (widget.existingVehicle != null) {
        await _userRepo.updateVehicle(
            user.uid, widget.existingVehicle!['id'], data);
      } else {
        data['createdAt'] = DateTime.now().toString();
        await _userRepo.addVehicle(user.uid, data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
            widget.existingVehicle != null ? "Edit Vehicle" : "Add Vehicle",
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1F25), Color(0xFF000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Vehicle Type",
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    _glassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedType,
                          dropdownColor: const Color(0xFF1E1E1E),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.white70),
                          style: const TextStyle(color: Colors.white),
                          items: _vehicleTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null)
                              setState(() => _selectedType = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField("Vehicle Model", "e.g. Honda City",
                        _modelController, Icons.directions_car),
                    const SizedBox(height: 20),
                    _buildTextField("Vehicle Number", "e.g. MH02AB1234",
                        _numberController, Icons.confirmation_number),
                    const SizedBox(height: 20),
                    _buildTextField("Vehicle Color", "e.g. Red",
                        _colorController, Icons.color_lens),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveVehicle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.black)
                            : const Text(
                                "Save Vehicle",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint,
      TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        _glassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              icon: Icon(icon, color: Colors.white54, size: 20),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24),
            ),
            validator: (val) => val == null || val.isEmpty ? "Required" : null,
          ),
        ),
      ],
    );
  }

  Widget _glassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
