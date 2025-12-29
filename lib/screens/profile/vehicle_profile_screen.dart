import 'package:flutter/material.dart';
import '../../repositories/user_repository.dart';

class VehicleProfileScreen extends StatefulWidget {
  const VehicleProfileScreen({super.key});

  @override
  State<VehicleProfileScreen> createState() => _VehicleProfileScreenState();
}

class _VehicleProfileScreenState extends State<VehicleProfileScreen> {
  String? uid;
  final UserRepository _userRepo = FirebaseUserRepository();

  @override
  void initState() {
    super.initState();
    uid = _userRepo.currentUser?.uid;
  }

  void _openEditVehicleSheet(BuildContext context, Map<String, dynamic> d) {
  if (uid == null) return;
  final vm = TextEditingController(text: d['vehicleModel'] ?? "");
  final vn = TextEditingController(text: d['vehicleNumber'] ?? "");
  final vc = TextEditingController(text: d['vehicleColor'] ?? "");
  String vehicleType = d['vehicleType'] ?? "Car";

  final iVm = d['vehicleModel'] ?? "";
  final iVn = d['vehicleNumber'] ?? "";
  final iVc = d['vehicleColor'] ?? "";
  final iType = d['vehicleType'] ?? "Car";

  String? vmError;
  String? vnError;
  String? vcError;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    builder: (context) {
      bool forcePop = false;

      return StatefulBuilder(
        builder: (context, setState) {
          final isModified = vm.text.trim() != iVm ||
              vn.text.trim() != iVn ||
              vc.text.trim() != iVc ||
              vehicleType != iType;

          return PopScope(
            canPop: !isModified || forcePop,
            onPopInvoked: (didPop) async {
              if (didPop) return;

              final shouldPop = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text("Discard Changes?",
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                      "You have unsaved changes. Are you sure you want to discard them?",
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel")),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Discard",
                            style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              );

              if (shouldPop == true) {
                setState(() => forcePop = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) Navigator.of(context).pop();
                });
              }
            },
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20,
                  right: 20,
                  top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Edit Vehicle Details",
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    value: vehicleType,
                    dropdownColor: Colors.black,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec("Vehicle Type"),
                    items: const [
                      DropdownMenuItem(
                          value: "Car", child: Text("Car (4 seats)")),
                      DropdownMenuItem(
                          value: "Bike", child: Text("Bike (1 seat)")),
                      DropdownMenuItem(
                          value: "SUV", child: Text("SUV (6 seats)")),
                      DropdownMenuItem(
                          value: "Bus", child: Text("Bus (20+ seats)")),
                      DropdownMenuItem(value: "Other", child: Text("Other")),
                    ],
                    onChanged: (v) => setState(() => vehicleType = v!),
                  ),

                  const SizedBox(height: 10),
                  _input("Vehicle Model", vm,
                      errorText: vmError,
                      onChanged: (_) => setState(() => vmError = null)),

                  const SizedBox(height: 10),
                  _input("Vehicle Color", vc,
                      errorText: vcError,
                      onChanged: (_) => setState(() => vcError = null)),

                  const SizedBox(height: 10),
                  _input("Vehicle Number", vn,
                      errorText: vnError,
                      onChanged: (_) => setState(() => vnError = null)),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white24,
                        disabledForegroundColor: Colors.white38),
                    onPressed: isModified
                        ? () async {
                            bool isValid = true;

                            setState(() {
                              vmError = null;
                              vnError = null;
                              vcError = null;
                            });

                            if (vm.text.trim().isEmpty) {
                              vmError = "Model is required";
                              isValid = false;
                            }

                            if (vc.text.trim().isEmpty) {
                              vcError = "Color is required";
                              isValid = false;
                            }

                            if (vn.text.trim().isEmpty) {
                              vnError = "Number is required";
                              isValid = false;
                            } else if (vn.text.trim().length < 4) {
                              vnError = "Invalid vehicle number";
                              isValid = false;
                            }

                            setState(() {});
                            if (!isValid) return;

                            await _userRepo.updateUserData(uid!, {
                              "vehicleModel": vm.text.trim(),
                              "vehicleNumber": vn.text.trim(),
                              "vehicleColor": vc.text.trim(),
                              "vehicleType": vehicleType,
                            });

                            if (context.mounted) Navigator.pop(context);
                          }
                        : null,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text("Save"),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  InputDecoration _dec(String t, {String? errorText}) => InputDecoration(
      labelText: t,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.black,
      errorText: errorText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));

  Widget _input(String t, TextEditingController c,
          {String? errorText, ValueChanged<String>? onChanged}) =>
      TextField(
        controller: c,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: _dec(t, errorText: errorText),
      );

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Vehicle Details", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _userRepo.getUserStream(uid!),
        builder: (context, snap) {
          final data = snap.data ?? {};
          final safeData = Map<String, dynamic>.from(data);

          final vType = data['vehicleType'] ?? "Not Added";
          final vModel = data['vehicleModel'] ?? "Not Added";
          final vColor = data['vehicleColor'] ?? "Not Added";
          final vNumber = data['vehicleNumber'] ?? "Not Added";

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                          border: Border.all(
                              color: Colors.greenAccent.withOpacity(0.5),
                              width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.directions_car, size: 60, color: Colors.white),
                      ),
                      const SizedBox(height: 30),
                      
                      _sectionHeader("Vehicle Information"),
                      _tile("Type", vType),
                      _tile("Model", vModel),
                      _tile("Color", vColor),
                      _tile("Number", vNumber),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _openEditVehicleSheet(context, safeData),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Edit Vehicle",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _tile(String t, String v) => Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Text(t, style: const TextStyle(color: Colors.white54)),
            const Spacer(),
            Text(v, style: const TextStyle(color: Colors.white)),
          ],
        ),
      );
}
