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

  bool _isSendingEmail = false;
  DateTime? _lastVerificationSentTime;

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

  Future<void> _sendVerificationEmail(String email) async {
    debugPrint("ProfileScreen: Starting email verification process for $email");
    if (_isSendingEmail) {
      debugPrint("ProfileScreen: Already sending email. Aborting.");
      return;
    }

    if (_lastVerificationSentTime != null &&
        DateTime.now().difference(_lastVerificationSentTime!).inSeconds < 60) {
      debugPrint("ProfileScreen: Rate limit active.");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Please wait a minute before resending verification email.")));
      return;
    }

    setState(() => _isSendingEmail = true);

    try {
      final normalizedEmail = email.trim().toLowerCase();
      debugPrint(
          "ProfileScreen: Checking if email is in use: $normalizedEmail");
      final inUse = await _userRepo.isEmailInUse(normalizedEmail);
      if (inUse) {
        debugPrint("ProfileScreen: Email is already in use.");
        if (mounted) _showEmailInUseDialog();
        return;
      }

      debugPrint("ProfileScreen: Calling verifyBeforeUpdateEmail...");

      await _userRepo.verifyBeforeUpdateEmail(normalizedEmail);
      debugPrint("ProfileScreen: verifyBeforeUpdateEmail success.");
      _lastVerificationSentTime = DateTime.now();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Verification Sent",
              style: TextStyle(color: Colors.white)),
          content: Text(
            "We sent a verification link to $email.\n\nPlease check your inbox and SPAM folder. Click the link to complete the update.",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("OK", style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("ProfileScreen: Error sending verification email: $e");
      final err = e as dynamic;
      if (err.toString().contains('requires-recent-login') ||
          err.toString().contains('no-current-user')) {
        _showReLoginDialog();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: ${err.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  void _showReLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Security Update",
            style: TextStyle(color: Colors.white)),
        content: const Text(
          "To update your email, you need to have signed in recently. Please log out and sign in again.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _userRepo.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, "/login", (route) => false);
              }
            },
            child: const Text("Log Out",
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showEmailInUseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Email Already Linked",
            style: TextStyle(color: Colors.white)),
        content: const Text(
          "This email address is already associated with another account.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _showUpdateEmailDialog() {
    final emailC = TextEditingController();

    bool isValidEmail(String email) {
      final regex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
      return regex.hasMatch(email.trim());
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title:
            const Text("Update Email", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your email address. We will send a verification link.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailC,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                  labelText: "Email",
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final email = emailC.text.trim();
              if (email.isEmpty || !isValidEmail(email)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Please enter a valid email address")));
                return;
              }
              if (email == _userRepo.currentUser?.email) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("This is already your current email.")));
                return;
              }
              Navigator.pop(context);
              _sendVerificationEmail(email);
            },
            child: const Text("Verify",
                style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _editGenderDob() async {
    String? gender = _userData?['gender'];
    DateTime? dob;
    if (_userData?['dob'] != null) {
      if (_userData!['dob'] is DateTime) {
        dob = _userData!['dob'];
      } else if (_userData!['dob'] is String) {
        // Try parse if string, though repo converts timestamps
      }
    }

    final dobController = TextEditingController(
        text: dob != null ? DateFormat("dd MMM yyyy").format(dob) : "");

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Edit Personal Details",
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gender Dropdown
              DropdownButtonFormField<String>(
                value: gender,
                dropdownColor: const Color(0xFF2C2C2C),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Gender",
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: ['Male', 'Female', 'Other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => gender = val),
              ),
              const SizedBox(height: 16),
              // DOB Picker
              TextField(
                controller: dobController,
                readOnly: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Date of Birth",
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  suffixIcon:
                      const Icon(Icons.calendar_today, color: Colors.white54),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dob ?? DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.white,
                          onSurface: Colors.white,
                        ),
                        dialogBackgroundColor: Colors.black,
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      dob = picked;
                      dobController.text =
                          DateFormat("dd MMM yyyy").format(picked);
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                if (_userRepo.currentUser != null) {
                  await _userRepo.updateUserData(_userRepo.currentUser!.uid, {
                    'gender': gender,
                    'dob': dob,
                  });
                  _fetchUserData();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text("Save",
                  style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _editField(String title, String key, String currentValue,
      {int maxLines = 1}) async {
    final controller = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("Edit $title", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter $title",
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _userRepo.updateUserData(
                  _userRepo.currentUser!.uid, {key: controller.text.trim()});
              _fetchUserData();
              if (context.mounted) Navigator.pop(context);
            },
            child:
                const Text("Save", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _userRepo.currentUser;
    if (user == null) return const SizedBox();

    // Basic Info
    final name = _userData?['name'] ?? "User";
    final bio = _userData?['bio'] ?? "No bio added";

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
                        _detailTile("Full Name", name, Icons.person,
                            onTap: () => _editField("Full Name", "name", name)),
                        const SizedBox(height: 16),
                        _detailTile("Bio", bio, Icons.info_outline,
                            onTap: () =>
                                _editField("Bio", "bio", bio, maxLines: 3)),
                        const SizedBox(height: 16),
                        _detailTile("Mobile Number", phone, Icons.phone,
                            isVerified: phoneVerified),
                        const SizedBox(height: 16),
                        _detailTile("Email Address", email, Icons.email,
                            isVerified: emailVerified,
                            onTap: _showUpdateEmailDialog,
                            showVerifyAction: !emailVerified),
                        const SizedBox(height: 16),
                        _detailTile("Gender", gender, Icons.person_outline,
                            onTap: _editGenderDob),
                        const SizedBox(height: 16),
                        _detailTile("Date of Birth", dobStr, Icons.cake,
                            onTap: _editGenderDob),
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
      {bool isVerified = false,
      VoidCallback? onTap,
      bool showVerifyAction = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
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
                  const Icon(Icons.verified,
                      color: Colors.greenAccent, size: 20),
                if (showVerifyAction)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text("Verify",
                        style:
                            TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                if (onTap != null && !isVerified && !showVerifyAction)
                  const Icon(Icons.edit, color: Colors.white24, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
