import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../repositories/user_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  String? uid;
  DateTime? _lastVerificationSentTime;
  bool _isSendingEmail = false;

  final UserRepository _userRepo = FirebaseUserRepository();

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
      debugPrint("ProfileScreen: Reloading user...");
      await _userRepo.reloadUser();

      // Sync Firestore if Auth email is verified and different
      final user = _userRepo.currentUser;
      if (user != null && user.email != null && user.emailVerified) {
        final dbUser = await _userRepo.getUser(user.uid);
        if (dbUser != null && dbUser['email'] != user.email) {
          debugPrint("ProfileScreen: Syncing email ${user.email} to Firestore");
          await _userRepo.updateUserData(user.uid, {'email': user.email});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Email verified and updated successfully!")));
          }
        }
      }
    } catch (e) {
      debugPrint("ProfileScreen: Error reloading user: $e");
    }
    if (mounted) setState(() {});
  }

  /* ---------------- EMAIL LOGIC (Moved from Account) ---------------- */

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
      if (err.code == 'requires-recent-login' ||
          err.code == 'no-current-user') {
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

  /* ---------------- EDIT SHEET ---------------- */

  void _openEditPersonalSheet(BuildContext context, Map<String, dynamic> d) {
    if (uid == null) return;
    final n = TextEditingController(text: d['name'] ?? "");
    final c = TextEditingController(text: d['city'] ?? "");
    final a = TextEditingController(text: d['age']?.toString() ?? "");
    final dobC = TextEditingController(text: d['dob'] ?? "");
    String gender = d['gender'] ?? "Male";

    // Capture initial values for dirty check
    final iName = d['name'] ?? "";
    final iCity = d['city'] ?? "";
    final iAge = d['age']?.toString() ?? "";
    final iDob = d['dob'] ?? "";
    final iGender = d['gender'] ?? "Male";

    // Validation state
    String? nameError;
    String? ageError;
    String? cityError;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (context) {
          bool forcePop = false;
          return StatefulBuilder(builder: (context, setState) {
            final isModified = n.text.trim() != iName ||
                c.text.trim() != iCity ||
                a.text.trim() != iAge ||
                dobC.text.trim() != iDob ||
                gender != iGender;

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
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Discard",
                            style: TextStyle(color: Colors.redAccent)),
                      ),
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text("Edit Personal Details",
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 20),
                  _input("Name", n, onChanged: (_) => setState(() { nameError = null; }), errorText: nameError),
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
                        setState(() {});
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
                  _input("Age", a, onChanged: (_) => setState(() { ageError = null; }), errorText: ageError),
                  const SizedBox(height: 10),
                  _input("City", c, onChanged: (_) => setState(() { cityError = null; }), errorText: cityError),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white24,
                          disabledForegroundColor: Colors.white38),
                      onPressed: isModified ? () async {
                        // Validation
                        bool isValid = true;
                        setState(() {
                          nameError = null;
                          ageError = null;
                          cityError = null;
                        });

                        if (n.text.trim().isEmpty) {
                          nameError = "Name is required";
                          isValid = false;
                        }

                        final ageVal = int.tryParse(a.text.trim());
                        if (ageVal == null || ageVal < 18 || ageVal > 100) {
                          ageError = "Valid age (18-100) required";
                          isValid = false;
                        }

                        if (c.text.trim().isEmpty) {
                          cityError = "City is required";
                          isValid = false;
                        }

                        setState(() {}); // Update UI with errors
                        if (!isValid) return;

                        await _userRepo.updateUserData(uid!, {
                          "name": n.text.trim(),
                          "gender": gender,
                          "city": c.text.trim(),
                          "age": ageVal,
                          "dob": dobC.text.trim(),
                        });
                        if (context.mounted) Navigator.pop(context);
                      } : null,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text("Save"),
                      )),
                  const SizedBox(height: 20),
                ])));
          });
        });
  }

  Widget _input(String t, TextEditingController c,
          {ValueChanged<String>? onChanged, String? errorText}) =>
      TextField(
        controller: c,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: _dec(t, errorText: errorText),
      );

  InputDecoration _dec(String t, {String? errorText}) => InputDecoration(
      labelText: t,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.black,
      errorText: errorText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));

  /* ---------------- UI ---------------- */

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
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _userRepo.getUserStream(uid!),
        builder: (context, snap) {
          final data = snap.data ?? {};
          final safeData = Map<String, dynamic>.from(data);

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
          final pic = data['profilePic'];

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
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
                          radius: 50,
                          backgroundColor: Colors.deepPurple,
                          backgroundImage:
                              pic != null ? NetworkImage(pic) : null,
                          child: pic == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : "?",
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 40),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 30),

                      // Details
                      _sectionHeader("Personal Details"),
                      _tile("Name", name),
                      _tile("Date of Birth", dob),
                      _tile("Gender", gender),
                      _tile("Age", age),
                      _tile("City", city),

                      const SizedBox(height: 20),
                      _sectionHeader("Contact Info"),
                      _mobileTile(phone),
                      _emailTile(email),
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
                    onPressed: () => _openEditPersonalSheet(context, safeData),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Edit Profile",
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

  Widget _mobileTile(String phone) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
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

  Widget _emailTile(String firestoreEmail) {
    final user = _userRepo.currentUser;
    final authEmail = user?.email;
    final hasAuthEmail = authEmail != null && authEmail.isNotEmpty;

    final displayEmail = hasAuthEmail
        ? authEmail
        : (firestoreEmail == "Not Added" ? "Not Added" : firestoreEmail);
    final isVerified = hasAuthEmail && (user?.emailVerified ?? false);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
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
              child: const Text("Add",
                  style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          if (hasAuthEmail) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _showUpdateEmailDialog,
              child: const Icon(Icons.edit, color: Colors.white70, size: 18),
            ),
          ]
        ],
      ),
    );
  }
}
