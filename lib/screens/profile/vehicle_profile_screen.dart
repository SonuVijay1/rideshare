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

  void _openVehicleSheet(BuildContext context, [Map<String, dynamic>? d]) {
    if (uid == null) return;
    final isEditing = d != null;
    final vm = TextEditingController(text: d?['vehicleModel'] ?? "");
    final vn = TextEditingController(text: d?['vehicleNumber'] ?? "");
    final vc = TextEditingController(text: d?['vehicleColor'] ?? "");
    String vehicleType = d?['vehicleType'] ?? "Car";

    final iVm = d?['vehicleModel'] ?? "";
    final iVn = d?['vehicleNumber'] ?? "";
    final iVc = d?['vehicleColor'] ?? "";
    final iType = d?['vehicleType'] ?? "Car";

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
                    Text(isEditing ? "Edit Vehicle" : "Add Vehicle",
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

                              final vNum = vn.text
                                  .trim()
                                  .toUpperCase()
                                  .replaceAll(RegExp(r'[^A-Z0-9]'), '');
                              final vReg = RegExp(
                                  r"^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{4}$");

                              if (vn.text.trim().isEmpty) {
                                vnError = "Number is required";
                                isValid = false;
                              } else if (!vReg.hasMatch(vNum)) {
                                vnError = "Invalid format (e.g. MH12AB1234)";
                                isValid = false;
                              }

                              setState(() {});
                              if (!isValid) return;

                              final data = {
                                "vehicleModel": vm.text.trim(),
                                "vehicleNumber": vNum,
                                "vehicleColor": vc.text.trim(),
                                "vehicleType": vehicleType,
                              };

                              if (isEditing) {
                                await _userRepo.updateVehicle(
                                    uid!, d!['id'], data);
                              } else {
                                await _userRepo.addVehicle(uid!, data);
                              }

                              if (context.mounted) Navigator.pop(context);
                            }
                          : null,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text("Save"),
                      ),
                    ),
                    if (isEditing) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    title: const Text("Delete Vehicle?",
                                        style: TextStyle(color: Colors.white)),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: const Text("Cancel")),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: const Text("Delete",
                                              style: TextStyle(
                                                  color: Colors.red))),
                                    ],
                                  ));
                          if (confirm == true) {
                            await _userRepo.deleteVehicle(uid!, d!['id']);
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        child: const Text("Delete Vehicle",
                            style: TextStyle(color: Colors.redAccent)),
                      )
                    ]
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
        title: const Text("My Vehicles", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _userRepo.getUserVehicles(uid!),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }

          final vehicles = snap.data ?? [];

          if (vehicles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_car,
                      size: 80, color: Colors.white24),
                  const SizedBox(height: 20),
                  const Text("No vehicles added yet",
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => _openVehicleSheet(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Add Vehicle"),
                  )
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final v = vehicles[index];
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        const Icon(Icons.directions_car, color: Colors.white),
                  ),
                  title: Text(v['vehicleModel'] ?? "Unknown Model",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("${v['vehicleColor']} • ${v['vehicleType']}",
                          style: const TextStyle(color: Colors.white70)),
                      Text(v['vehicleNumber'] ?? "",
                          style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white70),
                    onPressed: () => _openVehicleSheet(context, v),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openVehicleSheet(context),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}
