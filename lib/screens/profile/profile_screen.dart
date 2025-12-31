import 'dart:ui';
import 'package:flutter/material.dart';
import '../../repositories/user_repository.dart';
import 'my_vehicles_screen.dart';
import 'ride_history_screen.dart';
import 'payments_screen.dart';
import 'help_support_screen.dart';
import '../../utils/custom_route.dart';
import 'edit_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'personal_details_screen.dart';
import 'professional_details_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserRepository _userRepo = FirebaseUserRepository();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = _userRepo.currentUser;
    if (user != null) {
      final data = await _userRepo.getUser(user.uid);
      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _userRepo.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: Text("Please login", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("My Profile", style: TextStyle(color: Colors.white)),
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Profile Header
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: _userData?['profilePic'] != null
                                  ? NetworkImage(_userData!['profilePic'])
                                  : null,
                              child: _userData?['profilePic'] == null
                                  ? const Icon(Icons.person,
                                      size: 40, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userData?['name'] ?? "User",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (_userData?['occupation'] != null)
                                    Text(
                                      "${_userData?['occupation']} ${_userData?['company'] != null ? '@ ${_userData?['company']}' : ''}",
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.phoneNumber ??
                                        _userData?['phone'] ??
                                        "No Mobile",
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 13),
                                  ),
                                  Text(
                                    user.email ?? _userData?['email'] ?? "",
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Stats
                        Row(
                          children: [
                            Expanded(
                                child: _statCard("Rides Taken",
                                    "${_userData?['ridesTaken'] ?? 0}")),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _statCard("Rides Offered",
                                    "${_userData?['ridesOffered'] ?? 0}")),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _statCard("Rating",
                                    "${(_userData?['driverRating'] as num?)?.toStringAsFixed(1) ?? 'New'}")),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _statCard("Gratitude",
                                    "${_userData?['gratitudeCount'] ?? 0}")),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Menu Options
                        _menuItem(Icons.person_outline, "Personal Details", () {
                          Navigator.push(
                            context,
                            CustomPageRoute(
                                child: const PersonalDetailsScreen()),
                          );
                        }),
                        const SizedBox(height: 12),
                        _menuItem(Icons.work_outline, "Professional Details",
                            () {
                          Navigator.push(
                            context,
                            CustomPageRoute(
                                child: const ProfessionalDetailsScreen()),
                          );
                        }),
                        const SizedBox(height: 12),
                        _menuItem(Icons.directions_car, "My Vehicles", () {
                          Navigator.push(
                            context,
                            CustomPageRoute(child: const MyVehiclesScreen()),
                          );
                        }),
                        const SizedBox(height: 12),
                        _menuItem(Icons.history, "Ride History", () {
                          Navigator.push(
                            context,
                            CustomPageRoute(child: const RideHistoryScreen()),
                          );
                        }),
                        const SizedBox(height: 12),
                        _menuItem(Icons.payment, "Payments", () {
                          Navigator.push(
                            context,
                            CustomPageRoute(child: const PaymentsScreen()),
                          );
                        }),
                        const SizedBox(height: 12),
                        _menuItem(Icons.help_outline, "Help & Support", () {
                          Navigator.push(
                            context,
                            CustomPageRoute(child: const HelpSupportScreen()),
                          );
                        }),
                        const SizedBox(height: 30),

                        // Logout
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () async {
                              final shouldLogout = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  title: const Text("Log Out",
                                      style: TextStyle(color: Colors.white)),
                                  content: const Text(
                                      "Are you sure you want to log out?",
                                      style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text("Log Out",
                                          style: TextStyle(
                                              color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              );
                              if (shouldLogout == true) {
                                await _userRepo.signOut();
                                if (context.mounted) {
                                  Navigator.pushNamedAndRemoveUntil(
                                      context, "/login", (route) => false);
                                }
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor:
                                  Colors.redAccent.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Log Out",
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return _glassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: _glassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white24, size: 14),
          ],
        ),
      ),
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
