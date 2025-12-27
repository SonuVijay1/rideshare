import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with WidgetsBindingObserver {
  String? uid;

  DateTime? _lastVerificationSentTime;
  bool _isSendingEmail = false;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser?.uid;
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
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (e) {
      // Ignore Pigeon/serialization errors on Android
    }

    // Sync Firestore if Auth email is verified
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified && user.email != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email, // This is the verified email from Auth
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    }

    if (mounted) setState(() {}); 
  }

  Future<void> _sendVerificationEmail(String email) async {
  debugPrint("Attempting to send verification email to: $email");

  if (_isSendingEmail) return;

  // Debounce → avoid spam
  if (_lastVerificationSentTime != null &&
      DateTime.now().difference(_lastVerificationSentTime!).inSeconds < 60) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please wait a minute before resending verification email."))
    );
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  setState(() => _isSendingEmail = true);

  try {
    final normalizedEmail = email.trim().toLowerCase();

    // 1️⃣ CHECK FIRESTORE USERS COLLECTION
    final existing = await FirebaseFirestore.instance
        .collection("users")
        .where("email", isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      debugPrint("Email exists in Firestore → show dialog");
      _showEmailInUseDialog();
      return;
    }

    // 2️⃣ CHECK FIREBASE AUTH PROVIDERS
    final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(normalizedEmail);

    if (methods.isNotEmpty) {
      debugPrint("Email exists in Firebase Auth → show dialog");
      _showEmailInUseDialog();
      return;
    }

    debugPrint("Email is free. Sending verification…");

    await user.verifyBeforeUpdateEmail(normalizedEmail);
    _lastVerificationSentTime = DateTime.now();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Verification Sent", style: TextStyle(color: Colors.white)),
        content: Text(
          "We sent a verification link to $email.\n\nOpen the email to complete update.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  } on FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') {
      _showReLoginDialog();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
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
        title: const Text("Security Update", style: TextStyle(color: Colors.white)),
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
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                 Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
              }
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.redAccent)),
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
        title: const Text("Email Already Linked", style: TextStyle(color: Colors.white)),
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
    final regex = RegExp(
      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    );
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

            if (email == FirebaseAuth.instance.currentUser?.email) {
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

  Future<String?> _uploadFile(String path, String storagePath) async {
  try {
    debugPrint("🔥 Upload Started");
    debugPrint("Selected File Path: $path");
    debugPrint("Upload Target Path: $storagePath");

    // Use default Firebase bucket (recommended)
    final storage = FirebaseStorage.instance;

    final ref = storage.ref(storagePath);

    // Fix for Android NullPointerException: Explicitly provide metadata
    final metadata = SettableMetadata(contentType: "image/jpeg");

    final uploadTask = await ref.putFile(File(path), metadata);

    debugPrint("✅ Upload Success");
    final url = await uploadTask.ref.getDownloadURL();
    debugPrint("📸 File URL: $url");

    return url;
  } catch (e) {
    debugPrint("❌ UPLOAD ERROR: $e");
    return null;
  }
}


  Future<void> _pickAndUpload(String fieldName, String storageFolder) async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Uploading...")),
    );

    final url = await _uploadFile(
      picked.path,
      "users/$uid/$storageFolder/${DateTime.now()}",
    );

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload failed")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection("users").doc(uid).set(
      {fieldName: url},
      SetOptions(merge: true),
    );

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
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection("users")
                .doc(uid!)
                .snapshots(),
            builder: (context, snap) {
              final data =
                  snap.hasData && snap.data!.exists ? snap.data!.data()! : {};

              final name = data['name'] ?? "New User";
              final authPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
final phone = (authPhone != null && authPhone.isNotEmpty)
    ? authPhone
    : (data['phone'] ?? "Not Added");
              final email = data['email'] ?? "Not Added";
              final city = data['city'] ?? "Not Added";
              final gender = data['gender'] ?? "Not Specified";
              final age = data['age']?.toString() ?? "--";
              final dob = data['dob'] ?? "Not Added";

              final createdAt = data['createdAt'] as Timestamp?;
              final joined = createdAt != null
                  ? DateFormat("MMM yyyy").format(createdAt.toDate())
                  : "Unknown";

              final ridesTaken = data['ridesTaken'] ?? 0;
              final ridesOffered = data['ridesOffered'] ?? 0;
              final pRating = (data['passengerRating'] as num?)?.toDouble() ?? 0.0;
              final dRating = (data['driverRating'] as num?)?.toDouble() ?? 0.0;

              final pic = data['profilePic'];
              final aadhaar = data['aadhaarUrl'];
              final license = data['licenseUrl'];
              final aadhaarVerified = data['aadhaarVerified'] == true;
              final licenseVerified = data['licenseVerified'] == true;

              final safeData = Map<String, dynamic>.from(data);
              final verified = safeData['verified'] == true;
              final completion = _profileCompletion(safeData);


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
                                            color: Colors.white, fontSize: 26),
                                      )
                                    : null,
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
                                    style: const TextStyle(
                                        color: Colors.white54)),
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

                        const SizedBox(height: 16),

                        LinearProgressIndicator(
                          value: completion,
                          color: Colors.greenAccent,
                          backgroundColor: Colors.white10,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Profile Completion ${(completion * 100).round()}%",
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        )
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _statsCard(ridesTaken, ridesOffered, pRating, dRating),
                          const SizedBox(height: 20),

                          _tile("Date of Birth", dob),
                          _mobileTile(phone),
                          _emailTile(email), // Pass Firestore email as fallback
                          _tile("Gender", gender),
                          _tile("Age", age),
                          _tile("City", city),

                          const SizedBox(height: 20),

                          // DOCUMENTS
                          section("Identity Verification"),
                          _docButton(
                              "Upload Aadhaar", aadhaar, "aadhaarUrl", "aadhaar", aadhaarVerified),
                          _docButton("Upload Driving License", license,
                              "licenseUrl", "license", licenseVerified),

                          const SizedBox(height: 20),

                          section("Emergency Contact"),
                          _emergencyTile(safeData),

                          const SizedBox(height: 25),

                          _logoutButton(() async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                  context, "/login", (route) => false);
                            }
                          }),
                          const SizedBox(height: 25),
                        ],
                      ),
                    ),
                  )
                ],
              );
            }),
      ),
    );
  }

  // UI HELPERS

  Widget _tile(String t, String v) => Container(
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
          ],
        ),
      );

  Widget _emailTile(String firestoreEmail) {
    final user = FirebaseAuth.instance.currentUser;
    final authEmail = user?.email;
    final hasAuthEmail = authEmail != null && authEmail.isNotEmpty;
    
    final displayEmail = hasAuthEmail ? authEmail : (firestoreEmail == "Not Added" ? "Not Added" : firestoreEmail);
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
          if (isVerified) ...[
            const Icon(Icons.verified, color: Colors.greenAccent, size: 18)
          ] else if (hasAuthEmail) ...[
            GestureDetector(
              onTap: () async {
                await user?.reload();
                if (user?.emailVerified ?? false) {
                  setState(() {});
                } else {
                  await user?.sendEmailVerification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verification email sent.")));
                  }
                }
              },
              child: const Text("Verify", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ] else ...[
            GestureDetector(
              onTap: _showUpdateEmailDialog,
              child: const Text("Add Email", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
          if (hasAuthEmail) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _showUpdateEmailDialog, // Re-use link dialog which handles update if already linked
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

  Widget _statsCard(int taken, int offered, double pRate, double dRate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("Rides Taken", "$taken"),
              _statItem("Rides Offered", "$offered"),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("Psngr Rating", pRate.toStringAsFixed(1),
                  icon: Icons.star, iconColor: Colors.amber),
              _statItem("Driver Rating", dRate.toStringAsFixed(1),
                  icon: Icons.star, iconColor: Colors.amber),
            ],
          ),
        ],
      ),
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

  Widget _docButton(String title, String? url, String field, String folder, bool isVerified) {
    return ListTile(
      tileColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        url == null ? "Not Uploaded" : (isVerified ? "Verified" : "Pending Verification"),
        style: TextStyle(color: url == null ? Colors.red : (isVerified ? Colors.greenAccent : Colors.orangeAccent)),
      ),
      trailing: isVerified ? const Icon(Icons.verified, color: Colors.greenAccent) : const Icon(Icons.upload, color: Colors.white),
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
                      await FirebaseFirestore.instance
                          .collection("users")
                          .doc(uid)
                          .set({
                        "emergencyName": name.text.trim(),
                        "emergencyPhone": phone.text.trim()
                      }, SetOptions(merge: true));

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
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold)),
            )),
      );

  void _openEditProfileSheet(BuildContext context, Map<String, dynamic> d) {
    if (uid == null) return;
    final n = TextEditingController(text: d['name'] ?? "");
    final c = TextEditingController(text: d['city'] ?? "");
    final a = TextEditingController(text: d['age']?.toString() ?? "");
    final dobC = TextEditingController(text: d['dob'] ?? "");

    String gender = d['gender'] ?? "Male";

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (context) {
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
                DropdownButtonFormField(
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
                    onChanged: (v) => gender = v!),
                const SizedBox(height: 10),
                _input("Age", a),
                const SizedBox(height: 10),
                _input("City", c),
                const SizedBox(height: 20),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection("users")
                          .doc(uid!)
                          .set({
                        "name": n.text.trim(),
                        "gender": gender,
                        "city": c.text.trim(),
                        "age": int.tryParse(a.text.trim()),
                        "dob": dobC.text.trim(),
                      }, SetOptions(merge: true));

                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text("Save"),
                    ))
              ]));
        });
  }

  InputDecoration _dec(String t) => InputDecoration(
      labelText: t,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.black,
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
}
