import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/user_repository.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
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
    if (user == null) return const SizedBox();

    final phone = user.phoneNumber ?? _userData?['phone'] ?? "Not Added";
    final email = user.email ?? _userData?['email'] ?? "Not Added";
    final emailVerified = user.emailVerified;
    // Assuming phone is verified if present in Auth object (Phone Auth)
    final phoneVerified = user.phoneNumber != null;

    final gender = _userData?['gender'] ?? "Not Added";
    final dob = _userData?['dob'];
    String dobStr = "Not Added";
    if (dob != null) {
      if (dob is DateTime) {
        dobStr = DateFormat("dd MMM yyyy").format(dob);
      } else if (dob is String) {
        dobStr = dob;
      }
    }

    final emergencyName = _userData?['emergencyName'];
    final emergencyPhone = _userData?['emergencyPhone'];
    String emergencyStr = "Not Added";
    if (emergencyName != null) {
      emergencyStr = "$emergencyName\n$emergencyPhone";
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Personal Details",
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
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
                        _detailTile("Mobile Number", phone, Icons.phone,
                            isVerified: phoneVerified),
                        const SizedBox(height: 16),
                        _detailTile("Email Address", email, Icons.email,
                            isVerified: emailVerified),
                        const SizedBox(height: 16),
                        _detailTile("Gender", gender, Icons.person_outline),
                        const SizedBox(height: 16),
                        _detailTile("Date of Birth", dobStr, Icons.cake),
                        const SizedBox(height: 16),
                        _detailTile("Emergency Contact", emergencyStr,
                            Icons.contact_phone),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value, IconData icon,
      {bool isVerified = false}) {
    return ClipRRect(
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white70, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (isVerified)
                const Icon(Icons.verified, color: Colors.greenAccent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
