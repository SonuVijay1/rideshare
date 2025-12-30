import 'dart:ui';
import 'package:flutter/material.dart';
import '../../repositories/user_repository.dart';
import 'add_edit_vehicle_screen.dart';
import '../../utils/custom_route.dart';

class MyVehiclesScreen extends StatefulWidget {
  const MyVehiclesScreen({super.key});

  @override
  State<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends State<MyVehiclesScreen> {
  final UserRepository _userRepo = FirebaseUserRepository();

  @override
  Widget build(BuildContext context) {
    final user = _userRepo.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("My Vehicles", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            CustomPageRoute(child: const AddEditVehicleScreen()),
          );
        },
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _userRepo.getUserVehicles(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.white));
                }
                final vehicles = snapshot.data ?? [];

                if (vehicles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car,
                            size: 64, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        const Text("No vehicles added yet",
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: vehicles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index];
                    return _vehicleCard(vehicle);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleCard(Map<String, dynamic> vehicle) {
    return Dismissible(
      key: Key(vehicle['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent.withOpacity(0.2),
        child: const Icon(Icons.delete, color: Colors.redAccent),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Delete Vehicle?",
                style: TextStyle(color: Colors.white)),
            content: const Text("Are you sure you want to remove this vehicle?",
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Delete",
                      style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        );
      },
      onDismissed: (_) {
        _userRepo.deleteVehicle(_userRepo.currentUser!.uid, vehicle['id']);
      },
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            CustomPageRoute(
                child: AddEditVehicleScreen(existingVehicle: vehicle)),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      vehicle['vehicleType'] == 'Bike'
                          ? Icons.two_wheeler
                          : Icons.directions_car,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle['vehicleModel'] ?? 'Unknown Model',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${vehicle['vehicleNumber']} • ${vehicle['vehicleColor']}",
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit, color: Colors.white24, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
