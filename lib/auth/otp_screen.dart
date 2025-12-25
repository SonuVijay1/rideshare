import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print("📱 OTP SCREEN OPENED");
    print("✔ verificationId = ${widget.verificationId}");
    print("✔ phone = ${widget.phoneNumber}");
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    print("⌨ Entered OTP = $otp");

    if (otp.length != 6) {
      print("❌ OTP INVALID LENGTH");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid 6-digit OTP")),
      );
      return;
    }

    setState(() => _isLoading = true);
    print("🔄 STARTING OTP VERIFICATION…");

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      print("📡 Signing in with credential…");
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;

      if (user == null) {
        print("❌ Firebase returned NULL USER 🚨");
        throw Exception('User is null after OTP verification');
      }

      await _handleAuthSuccess(user);
    } catch (e) {
      print("💥 OTP VERIFICATION FAILED");
      print("ERROR → $e");

      // Workaround for PigeonUserDetails casting error on some Android versions
      // If the error occurred during return value parsing but auth succeeded:
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print("✅ User is actually signed in despite error. Proceeding...");
        await _handleAuthSuccess(currentUser);
        return;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP verification failed")),
        );
      }
    }
  }

  Future<void> _handleAuthSuccess(User user) async {
    print("✅ AUTH SUCCESS");
    print("👤 UID = ${user.uid}");
    print("📞 PHONE = ${user.phoneNumber}");

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    print("🔎 Checking if Firestore user exists…");
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      print("🆕 USER NOT FOUND → CREATING NEW DOCUMENT…");

      await userRef.set({
        'uid': user.uid,
        'phone': user.phoneNumber,
        'name': 'New User',
        'createdAt': FieldValue.serverTimestamp(),
        'ridesTaken': 0,
        'ridesOffered': 0,
        'passengerRating': 0.0,
        'driverRating': 0.0,
        'amountSaved': 0.0,
        'amountEarned': 0.0,
      });

      print("🎉 FIRESTORE USER CREATED SUCCESSFULLY");
    } else {
      print("ℹ USER ALREADY EXISTS — updating merged data…");

      await userRef.set({
        'uid': user.uid,
        'phone': user.phoneNumber,
      }, SetOptions(merge: true));

      print("✔ Existing Firestore user updated");
    }

    if (!mounted) {
      print("⚠ Widget not mounted, stopping navigation");
      return;
    }

    print("🚀 NAVIGATING TO HOME");
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Verify Phone",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Code sent to ${widget.phoneNumber}",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: "",
                    hintText: "000000",
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          "Verify",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
