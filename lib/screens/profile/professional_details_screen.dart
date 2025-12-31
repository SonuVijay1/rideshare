import 'dart:ui';
import 'package:flutter/material.dart';
import '../../repositories/user_repository.dart';

class ProfessionalDetailsScreen extends StatefulWidget {
  const ProfessionalDetailsScreen({super.key});

  @override
  State<ProfessionalDetailsScreen> createState() =>
      _ProfessionalDetailsScreenState();
}

class _ProfessionalDetailsScreenState extends State<ProfessionalDetailsScreen> {
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
    }
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
    controller.dispose();
  }

  Future<void> _editSector(String? currentSector) async {
    String? selected = currentSector;
    final List<String> sectors = [
      'Private',
      'Government',
      'Self-Employed',
      'Student',
      'Other'
    ];
    if (selected != null && !sectors.contains(selected)) selected = null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title:
              const Text("Edit Sector", style: TextStyle(color: Colors.white)),
          content: DropdownButtonFormField<String>(
            value: selected,
            dropdownColor: const Color(0xFF2C2C2C),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Sector",
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.black,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: sectors
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => selected = val),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                await _userRepo.updateUserData(
                    _userRepo.currentUser!.uid, {'sector': selected});
                _fetchUserData();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Save",
                  style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = _userData?['company'] ?? "Not Added";
    final occupation = _userData?['occupation'] ?? "Not Added";
    final sector = _userData?['sector'] ?? "Not Added";
    final linkedin = _userData?['linkedin'] ?? "Not Added";
    final achievements = _userData?['achievements'] ?? "Not Added";
    final workExperience = _userData?['workExperience'] ?? "Not Added";

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Professional Details",
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
                        _detailTile("Company", company, Icons.business,
                            onTap: () =>
                                _editField("Company", "company", company)),
                        const SizedBox(height: 16),
                        _detailTile("Designation", occupation, Icons.badge,
                            onTap: () => _editField(
                                "Designation", "occupation", occupation)),
                        const SizedBox(height: 16),
                        _detailTile("Sector", sector, Icons.work_outline,
                            onTap: () => _editSector(sector)),
                        const SizedBox(height: 16),
                        _detailTile("LinkedIn", linkedin, Icons.link,
                            isLink: true,
                            onTap: () =>
                                _editField("LinkedIn", "linkedin", linkedin)),
                        const SizedBox(height: 16),
                        _detailTile(
                            "Achievements", achievements, Icons.emoji_events,
                            onTap: () => _editField(
                                "Achievements", "achievements", achievements,
                                maxLines: 3)),
                        const SizedBox(height: 16),
                        _detailTile("Work Experience", workExperience,
                            Icons.history_edu,
                            onTap: () => _editField("Work Experience",
                                "workExperience", workExperience, maxLines: 3)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value, IconData icon,
      {bool isLink = false, VoidCallback? onTap}) {
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
                          style: TextStyle(
                              color: isLink ? Colors.blueAccent : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.edit, color: Colors.white24, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
