import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../repositories/user_repository.dart';
import '../../repositories/storage_repository.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with WidgetsBindingObserver {
  String? uid;

  DateTime? _lastVerificationSentTime;
  bool _isSendingEmail = false;

  final UserRepository _userRepo = FirebaseUserRepository();
  final StorageRepository _storageRepo = FirebaseStorageRepository();

  @override
  void initState() {
    super.initState();
    uid = _userRepo.currentUser?.uid;
    if (uid != null) {
      WidgetsBinding.instance.addObserver(this);
      _reloadUser();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadUser();
    }
  }

  Future<void> _reloadUser() async {
    try {
      await _userRepo.reloadUser();
    } catch (e) {
      // Ignore Pigeon/serialization errors on Android
    }

    // Sync Firestore if Auth email is verified
    final user = _userRepo.currentUser;
    if (user != null && user.emailVerified && user.email != null) {
      // Logic to sync email can be moved to repo, but for now we rely on
      // the repo update method if needed.
      // _userRepo.updateUserData(user.uid, {'email': user.email});
    }

    if (mounted) setState(() {});
  }

  Future<void> _sendVerificationEmail(String email) async {
    debugPrint("Attempting to send verification email to: $email");

    if (_isSendingEmail) return;

    // Debounce → avoid spam
    if (_lastVerificationSentTime != null &&
        DateTime.now().difference(_lastVerificationSentTime!).inSeconds < 60) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Please wait a minute before resending verification email.")));
      return;
    }

    final user = _userRepo.currentUser;
    if (user == null) return;

    setState(() => _isSendingEmail = true);

    try {
      final normalizedEmail = email.trim().toLowerCase();

      final inUse = await _userRepo.isEmailInUse(normalizedEmail);
      if (inUse) {
        if (mounted) _showEmailInUseDialog();
        return;
      }

      debugPrint("Email is free. Sending verification…");

      await _userRepo.verifyBeforeUpdateEmail(normalizedEmail);
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
            "We sent a verification link to $email.\n\nOpen the email to complete update.",
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
      final err = e as dynamic;
      if (err.code == 'requires-recent-login') {
        _showReLoginDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${err.message ?? err.toString()}")));
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

    bool _isValidEmail(String email) {
      final regex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
      return regex.hasMatch(email.trim());
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          "Update Email",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your email address. We will send a verification link.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _input("Email", emailC),
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

              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Email cannot be empty")),
                );
                return;
              }

              if (!_isValidEmail(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Please enter a valid email address")),
                );
                return;
              }

              if (email == _userRepo.currentUser?.email) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("This is already your current email.")),
                );
                return;
              }

              Navigator.pop(context);
              debugPrint("User requested email update to: $email");
              _sendVerificationEmail(email);
            },
            child: const Text(
              "Verify",
              style: TextStyle(color: Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
  }

  // _uploadFile removed, using _storageRepo.uploadFile

  Future<void> _pickAndUpload(String fieldName, String storageFolder) async {
    try {
      final picker = ImagePicker();
      // 1. Pick Image with initial compression
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Initial compression to save memory
        maxWidth: 1024, // Resize large images immediately
      );

      if (picked == null) return;

      // 2. Crop & Compress
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressQuality: 70, // High compression for storage optimization
        maxWidth: 1024, // Ensure uploaded file isn't huge
        maxHeight: 1024,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop & Upload',
            toolbarColor: Colors.white, // High contrast toolbar
            toolbarWidgetColor:
                Colors.black, // Black icons (Checkmark will be visible)
            activeControlsWidgetColor: Colors.deepPurple,
            statusBarColor: Colors.black,
            initAspectRatio:
                CropAspectRatioPreset.square, // Default to square for profile
            lockAspectRatio: false,
            backgroundColor: Colors.black,
            dimmedLayerColor: const Color(0x99000000),
            cropFrameColor: Colors.white,
            cropGridColor: Colors.white54,
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Edit Photo',
            doneButtonTitle: 'Upload',
            cancelButtonTitle: 'Cancel',
          ),
        ],
      );

      if (cropped == null) return; // User cancelled crop

      // Fetch old URL to delete later
      String? oldUrl;
      try {
        final userData = await _userRepo.getUser(uid!);
        oldUrl = userData?[fieldName];
      } catch (e) {
        debugPrint("Error fetching old URL: $e");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploading...")),
      );

      final url = await _storageRepo.uploadFile(
        cropped.path,
        "users/$uid/$storageFolder/${DateTime.now()}",
      );

      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload failed")),
        );
        return;
      }

      await _userRepo.updateUserData(uid!, {fieldName: url});

      // Delete old image if exists
      if (oldUrl != null) {
        try {
          await _storageRepo.deleteFile(oldUrl);
          debugPrint("Deleted old image: $oldUrl");
        } catch (e) {
          debugPrint("Failed to delete old image: $e");
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploaded successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload error: $e")),
      );
    }
  }

  double _profileCompletion(Map<String, dynamic> d) {
    int done = 0;
    if (d['name'] != null) done++;
    if (d['email'] != null) done++;
    if (d['gender'] != null) done++;
    if (d['age'] != null) done++;
    if (d['city'] != null) done++;
    if (d['profilePic'] != null) done++;
    if (d['aadhaarUrl'] != null) done++;
    if (d['licenseUrl'] != null) done++;
    if (d['emergencyName'] != null) done++;
    if (d['dob'] != null) done++;

    return (done / 10.0).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      // This can happen during the logout transition.
      // Return an empty, themed scaffold to avoid visual glitches.
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
            stream: _userRepo.getUserStream(uid!),
            builder: (context, snap) {
              final data = snap.data ?? {};

              final name = data['name'] ?? "New User";
              final authPhone = _userRepo.currentUser?.phoneNumber;
              final phone = (authPhone != null && authPhone.isNotEmpty)
                  ? authPhone
                  : (data['phone'] ?? "Not Added");
              final email = data['email'] ?? "Not Added";
              final city = data['city'] ?? "Not Added";
              final gender = data['gender'] ?? "Not Specified";
              final age = data['age']?.toString() ?? "--";
              final dob = data['dob'] ?? "Not Added";

              final createdAt = data['createdAt'];
              final joined = createdAt != null && createdAt is DateTime
                  ? DateFormat("MMM yyyy").format(createdAt)
                  : "Unknown";

              final ridesTaken = (data['ridesTaken'] as num?)?.toInt() ?? 0;
              final ridesOffered = (data['ridesOffered'] as num?)?.toInt() ?? 0;
              final ridesCancelled =
                  (data['ridesCancelled'] as num?)?.toInt() ?? 0;
              final pRating =
                  (data['passengerRating'] as num?)?.toDouble() ?? 0.0;
              final dRating = (data['driverRating'] as num?)?.toDouble() ?? 0.0;

              final pic = data['profilePic'];
              final aadhaar = data['aadhaarUrl'];
              final license = data['licenseUrl'];
              final aadhaarVerified = data['aadhaarVerified'] == true;
              final licenseVerified = data['licenseVerified'] == true;

              final safeData = Map<String, dynamic>.from(data);
              final verified = safeData['verified'] == true;
              final completion = _profileCompletion(safeData);

              final cancelStatus = _calculateCancellationStatus(
                  ridesTaken, ridesOffered, ridesCancelled);

              return Column(
                children: [
                  // HEADER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(30)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              "Account",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (verified)
                              const Icon(Icons.verified,
                                  color: Colors.blueAccent),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  _pickAndUpload("profilePic", "profile"),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.blueAccent.withOpacity(0.8),
                                      width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueAccent.withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 35,
                                  backgroundImage:
                                      pic != null ? NetworkImage(pic) : null,
                                  backgroundColor: Colors.deepPurple,
                                  child: pic == null
                                      ? Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : "?",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 26),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 18)),
                                Text(phone,
                                    style:
                                        const TextStyle(color: Colors.white54)),
                                const SizedBox(height: 4),
                                Text("Joined $joined",
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                            const Spacer(),
                            TextButton(
                                onPressed: () =>
                                    _openEditProfileSheet(context, safeData),
                                child: const Text("Edit",
                                    style: TextStyle(color: Colors.white)))
                          ],
                        ),
                        const SizedBox(height: 24),
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Profile Completion",
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: completion == 1.0
                                          ? Colors.greenAccent.withOpacity(0.2)
                                          : Colors.blueAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text("${(completion * 100).round()}%",
                                      style: TextStyle(
                                          color: completion == 1.0
                                              ? Colors.greenAccent
                                              : Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: completion),
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.easeOutExpo,
                              builder: (context, value, _) => Container(
                                height: 10,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: LinearGradient(
                                        colors: value == 1.0
                                            ? [Colors.green, Colors.greenAccent]
                                            : [
                                                Colors.blue,
                                                Colors.purpleAccent
                                              ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (value == 1.0
                                                  ? Colors.greenAccent
                                                  : Colors.blueAccent)
                                              .withOpacity(0.5),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _reloadUser,
                      color: Colors.white,
                      backgroundColor: Colors.black,
                      child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              _statsCard(
                                  ridesTaken,
                                  ridesOffered,
                                  ridesCancelled,
                                  pRating,
                                  dRating,
                                  cancelStatus),
                              const SizedBox(height: 20),

                              _tile("Date of Birth", dob),
                              _mobileTile(phone),
                              _emailTile(
                                  email), // Pass Firestore email as fallback
                              _tile("Gender", gender),
                              _tile("Age", age),
                              _tile("City", city),

                              const SizedBox(height: 20),
                              section("Vehicle Details"),
                              _tile("Type", data['vehicleType'] ?? "Not Added",
                                  onTap: () =>
                                      _openEditProfileSheet(context, safeData)),
                              _tile(
                                  "Model", data['vehicleModel'] ?? "Not Added",
                                  onTap: () =>
                                      _openEditProfileSheet(context, safeData)),
                              _tile(
                                  "Color", data['vehicleColor'] ?? "Not Added",
                                  onTap: () =>
                                      _openEditProfileSheet(context, safeData)),
                              _tile("Number",
                                  data['vehicleNumber'] ?? "Not Added",
                                  onTap: () =>
                                      _openEditProfileSheet(context, safeData)),

                              const SizedBox(height: 20),

                              // DOCUMENTS
                              section("Identity Verification"),
                              _docButton("Upload Aadhaar", aadhaar,
                                  "aadhaarUrl", "aadhaar", aadhaarVerified),
                              _docButton("Upload Driving License", license,
                                  "licenseUrl", "license", licenseVerified),

                              const SizedBox(height: 20),

                              section("Emergency Contact"),
                              _emergencyTile(safeData),

                              const SizedBox(height: 25),

                              _logoutButton(() async {
                                await _userRepo.signOut();
                                if (context.mounted) {
                                  Navigator.pushNamedAndRemoveUntil(
                                      context, "/login", (route) => false);
                                }
                              }),
                              const SizedBox(height: 25),
                            ],
                          )),
                    ),
                  )
                ],
              );
            }),
      ),
    );
  }

  // UI HELPERS

  Widget _tile(String t, String v, {VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Text(t, style: const TextStyle(color: Colors.white54)),
              const Spacer(),
              Text(v, style: const TextStyle(color: Colors.white)),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.edit, size: 14, color: Colors.white24)
              ]
            ],
          ),
        ),
      );

  Widget _emailTile(String firestoreEmail) {
    final user = _userRepo.currentUser;
    final authEmail = user?.email;
    final hasAuthEmail = authEmail != null && authEmail.isNotEmpty;

    final displayEmail = hasAuthEmail
        ? authEmail
        : (firestoreEmail == "Not Added" ? "Not Added" : firestoreEmail);
    final isVerified = hasAuthEmail && (user?.emailVerified ?? false);

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Text("Email", style: TextStyle(color: Colors.white54)),
          const Spacer(),
          Text(displayEmail!, style: const TextStyle(color: Colors.white)),
          const SizedBox(width: 8),
          if (isVerified)
            const Icon(Icons.verified, color: Colors.greenAccent, size: 18)
          else if (hasAuthEmail)
            GestureDetector(
              onTap: () async {
                await _userRepo.reloadUser();
                if (user?.emailVerified ?? false) {
                  setState(() {});
                } else {
                  await _userRepo.sendEmailVerification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Verification email sent.")));
                  }
                }
              },
              child: const Text("Verify",
                  style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            )
          else
            GestureDetector(
              onTap: _showUpdateEmailDialog,
              child: const Text("Add Email",
                  style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          if (hasAuthEmail) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap:
                  _showUpdateEmailDialog, // Re-use link dialog which handles update if already linked
              child: const Icon(Icons.edit, color: Colors.white70, size: 18),
            ),
          ]
        ],
      ),
    );
  }

  Widget _mobileTile(String phone) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Text("Mobile", style: TextStyle(color: Colors.white54)),
          const Spacer(),
          Text(phone, style: const TextStyle(color: Colors.white)),
          const SizedBox(width: 8),
          const Icon(Icons.verified, color: Colors.greenAccent, size: 18),
        ],
      ),
    );
  }

  String _calculateCancellationStatus(int taken, int offered, int cancelled) {
    if (cancelled == 0) return "Never";
    final total = taken + offered + cancelled;
    if (total == 0) return "Never";

    final ratio = cancelled / total;
    if (ratio >= 1.0) return "Always";
    if (ratio > 0.4) return "Often";
    if (ratio > 0.1) return "Sometimes";
    return "Rarely";
  }

  Widget _statsCard(int taken, int offered, int cancelled, double pRate,
      double dRate, String cancelStatus) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person, color: Colors.blueAccent, size: 16),
                        SizedBox(width: 8),
                        Text("Passenger",
                            style: TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _statItem("Rides Taken", "$taken"),
                    const SizedBox(height: 12),
                    _statItem("Rating", pRate.toStringAsFixed(1),
                        icon: Icons.star, iconColor: Colors.amber),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car,
                            color: Colors.greenAccent, size: 16),
                        SizedBox(width: 8),
                        Text("Driver",
                            style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _statItem("Rides Offered", "$offered"),
                    const SizedBox(height: 12),
                    _statItem("Rating", dRate.toStringAsFixed(1),
                        icon: Icons.star, iconColor: Colors.amber),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield, color: Colors.orangeAccent, size: 16),
                  SizedBox(width: 8),
                  Text("Reliability",
                      style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem("Cancelled", "$cancelled"),
                  _statItem("Frequency", cancelStatus,
                      icon: Icons.info_outline, iconColor: Colors.white70),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statItem(String label, String value,
      {IconData? icon, Color? iconColor}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 16, color: iconColor),
            if (icon != null) const SizedBox(width: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget section(String t) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(t,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );

  Widget _docButton(
      String title, String? url, String field, String folder, bool isVerified) {
    return ListTile(
      tileColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        url == null
            ? "Not Uploaded"
            : (isVerified ? "Verified" : "Pending Verification"),
        style: TextStyle(
            color: url == null
                ? Colors.red
                : (isVerified ? Colors.greenAccent : Colors.orangeAccent)),
      ),
      trailing: isVerified
          ? const Icon(Icons.verified, color: Colors.greenAccent)
          : const Icon(Icons.upload, color: Colors.white),
      onTap: () => _pickAndUpload(field, folder),
    );
  }

  Widget _emergencyTile(Map<String, dynamic> d) {
    return ListTile(
      tileColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Emergency Contact",
          style: TextStyle(color: Colors.white)),
      subtitle: Text(
          d['emergencyName'] == null
              ? "Not Added"
              : "${d['emergencyName']} (${d['emergencyPhone']})",
          style: const TextStyle(color: Colors.white54)),
      trailing: const Icon(Icons.phone, color: Colors.white),
      onTap: () => _addEmergency(),
    );
  }

  Future<void> _addEmergency() async {
    final name = TextEditingController();
    final phone = TextEditingController();

    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text("Emergency Contact",
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _input("Name", name),
                  const SizedBox(height: 10),
                  _input("Phone", phone)
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      await _userRepo.updateUserData(uid!, {
                        "emergencyName": name.text.trim(),
                        "emergencyPhone": phone.text.trim()
                      });

                      // verified only if aadhaar + license + emergency
                      Navigator.pop(c);
                    },
                    child: const Text("Save"))
              ],
            ));
  }

  Widget _input(String t, TextEditingController c) => TextField(
        controller: c,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
            labelText: t,
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      );

  Widget _logoutButton(VoidCallback onTap) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            onPressed: onTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text("Logout",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
            )),
      );

  void _openEditProfileSheet(BuildContext context, Map<String, dynamic> d) {
    if (uid == null) return;
    final n = TextEditingController(text: d['name'] ?? "");
    final c = TextEditingController(text: d['city'] ?? "");
    final a = TextEditingController(text: d['age']?.toString() ?? "");
    final dobC = TextEditingController(text: d['dob'] ?? "");
    final vm = TextEditingController(text: d['vehicleModel'] ?? "");
    final vn = TextEditingController(text: d['vehicleNumber'] ?? "");
    final vc = TextEditingController(text: d['vehicleColor'] ?? "");

    String gender = d['gender'] ?? "Male";
    String vehicleType = d['vehicleType'] ?? "Car";

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 20,
                    right: 20,
                    top: 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text("Edit Profile",
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 20),
                  _input("Name", n),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now()
                            .subtract(const Duration(days: 365 * 18)),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                                primary: Colors.white, onSurface: Colors.white),
                            dialogBackgroundColor: const Color(0xFF1E1E1E),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        dobC.text = DateFormat("yyyy-MM-dd").format(picked);
                      }
                    },
                    child: AbsorbPointer(child: _input("Date of Birth", dobC)),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                      value: gender,
                      dropdownColor: Colors.black,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec("Gender"),
                      items: const [
                        DropdownMenuItem(
                            value: "Male",
                            child: Text("Male",
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: "Female",
                            child: Text("Female",
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: "Other",
                            child: Text("Other",
                                style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (v) => setState(() => gender = v!)),
                  const SizedBox(height: 10),
                  _input("Age", a),
                  const SizedBox(height: 10),
                  _input("City", c),
                  const SizedBox(height: 10),
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
                      onChanged: (v) => setState(() => vehicleType = v!)),
                  const SizedBox(height: 10),
                  _input("Vehicle Model", vm),
                  const SizedBox(height: 10),
                  _input("Vehicle Color", vc),
                  const SizedBox(height: 10),
                  _input("Vehicle Number", vn),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black),
                      onPressed: () async {
                        await _userRepo.updateUserData(uid!, {
                          "name": n.text.trim(),
                          "gender": gender,
                          "city": c.text.trim(),
                          "age": int.tryParse(a.text.trim()),
                          "dob": dobC.text.trim(),
                          "vehicleModel": vm.text.trim(),
                          "vehicleNumber": vn.text.trim(),
                          "vehicleColor": vc.text.trim(),
                          "vehicleType": vehicleType,
                        });

                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text("Save"),
                      ))
                ]));
          });
        });
  }

  InputDecoration _dec(String t) => InputDecoration(
      labelText: t,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.black,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
}
