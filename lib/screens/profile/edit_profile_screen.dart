import 'dart:ui';
import 'package:flutter/material.dart';
import '../../repositories/user_repository.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _occupationController = TextEditingController();
  final _companyController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _achievementsController = TextEditingController();
  String? _selectedSector;
  final List<String> _sectors = ['Private', 'Government', 'Self-Employed', 'Student', 'Other'];

  final UserRepository _userRepo = FirebaseUserRepository();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _userRepo.currentUser;
    if (user != null) {
      final data = await _userRepo.getUser(user.uid);
      if (data != null) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _occupationController.text = data['occupation'] ?? '';
          _companyController.text = data['company'] ?? '';
          _linkedinController.text = data['linkedin'] ?? '';
          _achievementsController.text = data['achievements'] ?? '';
          _selectedSector = data['sector'];
          if (_selectedSector != null && !_sectors.contains(_selectedSector)) {
            _selectedSector = null;
          }
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = _userRepo.currentUser;
      if (user != null) {
        await _userRepo.updateUserData(user.uid, {
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'occupation': _occupationController.text.trim(),
          'company': _companyController.text.trim(),
          'linkedin': _linkedinController.text.trim(),
          'achievements': _achievementsController.text.trim(),
          'sector': _selectedSector,
        });
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title:
            const Text("Edit Profile", style: TextStyle(color: Colors.white)),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField("Full Name", _nameController),
                    const SizedBox(height: 16),
                    _buildTextField("Bio", _bioController, maxLines: 3),
                    const SizedBox(height: 16),
                    _buildDropdown("Sector", _selectedSector, _sectors, (val) {
                      setState(() => _selectedSector = val);
                    }),
                    const SizedBox(height: 16),
                    _buildTextField("Designation / Role", _occupationController,
                        hint: "e.g. Software Engineer"),
                    const SizedBox(height: 16),
                    _buildTextField("Company Name", _companyController,
                        hint: "e.g. Google"),
                    const SizedBox(height: 16),
                    _buildTextField("Achievements", _achievementsController,
                        maxLines: 3, hint: "e.g. Employee of the month..."),
                    const SizedBox(height: 16),
                    _buildTextField("LinkedIn Profile URL", _linkedinController,
                        hint: "https://linkedin.com/in/..."),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.black)
                            : const Text("Save Changes",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextFormField(
                controller: controller,
                maxLines: maxLines,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.white24),
                ),
                validator: (val) =>
                    val != null && val.isEmpty && label == "Full Name"
                        ? "Required"
                        : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items,
      Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white54),
                  hint: const Text("Select",
                      style: TextStyle(color: Colors.white24)),
                  items: items
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
