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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                CustomPageRoute(child: const EditProfileScreen()),
              ).then((_) => _fetchUserData());
            },
            child: const Text("Edit", style: TextStyle(color: Colors.white)),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {},
          ),
        ],
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
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[800],
                                backgroundImage:
                                    _userData?['profilePic'] != null
                                        ? NetworkImage(_userData!['profilePic'])
                                        : null,
                                child: _userData?['profilePic'] == null
                                    ? const Icon(Icons.person,
                                        size: 50, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _userData?['name'] ?? "User",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email ?? "",
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 14),
                              ),
                              if (_userData?['occupation'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "${_userData?['occupation']} ${_userData?['company'] != null ? 'at ${_userData?['company']}' : ''}",
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                ),
                            ],
                          ),
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

                        // About Section (Bio & LinkedIn)
                        _buildInfoCard(),
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
                            onPressed: () {
                              // _userRepo.signOut();
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

  Widget _buildInfoCard() {
    final bio = _userData?['bio'];
    final linkedin = _userData?['linkedin'];
    final sector = _userData?['sector'];
    final achievements = _userData?['achievements'];

    if ((bio == null || bio.isEmpty) &&
        (linkedin == null || linkedin.isEmpty) &&
        sector == null &&
        (achievements == null || achievements.isEmpty)) {
      return const SizedBox.shrink();
    }

    return _glassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("About",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 16),
          if (bio != null && bio.isNotEmpty) ...[
            Text(bio,
                style: const TextStyle(color: Colors.white70, height: 1.5)),
            const SizedBox(height: 20),
          ],
          if (sector != null) ...[
            Text("Sector: $sector",
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
          ],
          if (achievements != null && achievements.isNotEmpty) ...[
            const Text("Achievements",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(achievements,
                style: const TextStyle(color: Colors.white70, height: 1.4)),
            const SizedBox(height: 20),
          ],
          if (linkedin != null && linkedin.isNotEmpty)
            InkWell(
              onTap: () async {
                final Uri url = Uri.parse(linkedin);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text("in",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text("View LinkedIn Profile",
                        style: TextStyle(color: Colors.blueAccent)),
                  ),
                  const Icon(Icons.open_in_new,
                      color: Colors.blueAccent, size: 16),
                ],
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
