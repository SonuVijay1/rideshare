import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/ride_repository.dart';
import '../chat/chat_screen.dart';
import '../../utils/custom_route.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? rideId; // Context for chat/call

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.rideId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserRepository _userRepo = FirebaseUserRepository();
  final RideRepository _rideRepo = FirebaseRideRepository();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    final data = await _userRepo.getUser(widget.userId);
    if (mounted) {
      setState(() {
        _userData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _callUser() async {
    if (_userData == null) return;
    final phone = _userData!['phone'] ?? _userData!['phoneNumber'];
    if (phone != null && phone.toString().isNotEmpty) {
      final Uri launchUri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not launch dialer")));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone number not available")));
    }
  }

  void _chatUser() {
    if (widget.rideId == null) return;
    final currentUser = _userRepo.currentUser;
    if (currentUser == null) return;

    // Determine if I am the driver or passenger relative to the ride context
    // This is a simplification; ideally we pass isDriver from previous screen
    // But for now, we just open the chat. The ChatScreen handles logic.
    // We assume if we are viewing a profile, we want to chat in context of rideId.

    Navigator.push(
      context,
      CustomPageRoute(
        child: ChatScreen(
          rideId: widget.rideId!,
          title: widget.userName,
          driverId: widget
              .userId, // This might be inexact if viewing a passenger, but ChatScreen handles senderId
          isDriver:
              false, // Defaulting, ChatScreen logic might need adjustment if strict role required
        ),
      ),
    );
  }

  Future<void> _reportUser() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Report User", style: TextStyle(color: Colors.white)),
        children: [
          _reportOption(ctx, "Inappropriate Behavior"),
          _reportOption(ctx, "Spam or Scam"),
          _reportOption(ctx, "Fake Profile"),
          _reportOption(ctx, "Other"),
        ],
      ),
    );

    if (reason != null) {
      final currentUser = _userRepo.currentUser;
      if (currentUser != null) {
        await _userRepo.reportUser(currentUser.uid, widget.userId, reason);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("User reported successfully.")));
        }
      }
    }
  }

  Widget _reportOption(BuildContext ctx, String text) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, text),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(text, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }

  Future<void> _sendGratitude() async {
    final currentUser = _userRepo.currentUser;
    if (currentUser == null) return;
    await _userRepo.sendGratitude(currentUser.uid, widget.userId);
    _fetchUser(); // Refresh stats
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Gratitude sent!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'report') _reportUser();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'report', child: Text("Report User")),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
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
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    if (widget.rideId != null &&
                        _userRepo.currentUser?.uid != widget.userId)
                      _buildActionButtons(),
                    const SizedBox(height: 24),
                    _buildStatsCard(),
                    const SizedBox(height: 24),
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final pic = _userData?['profilePic'];
    final name = _userData?['name'] ?? widget.userName;
    final occupation = _userData?['occupation'];
    final company = _userData?['company'];

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[800],
          backgroundImage: pic != null ? NetworkImage(pic) : null,
          child: pic == null
              ? const Icon(Icons.person, size: 50, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        if (occupation != null || company != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              "${occupation ?? ''}${occupation != null && company != null ? ' at ' : ''}${company ?? ''}",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _chatUser,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text("Chat"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _callUser,
            icon: const Icon(Icons.phone),
            label: const Text("Call"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _sendGratitude,
            icon: const Icon(Icons.favorite_border),
            label: const Text("Thank"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.pinkAccent,
              side: const BorderSide(color: Colors.pinkAccent),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    final ridesTaken = (_userData?['ridesTaken'] as num?)?.toInt() ?? 0;
    final ridesOffered = (_userData?['ridesOffered'] as num?)?.toInt() ?? 0;
    final ridesCancelled = (_userData?['ridesCancelled'] as num?)?.toInt() ?? 0;
    final rating = (_userData?['driverRating'] as num?)?.toDouble() ?? 5.0;
    final gratitude = (_userData?['gratitudeCount'] as num?)?.toInt() ?? 0;

    // Reliability Calculation
    final total = ridesTaken + ridesOffered + ridesCancelled;
    String reliability = "100%";
    if (total > 0) {
      final percent = ((total - ridesCancelled) / total * 100).round();
      reliability = "$percent%";
    }

    return _glassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Stats & Reliability",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("Rating", rating.toStringAsFixed(1), Icons.star,
                  Colors.amber),
              _statItem(
                  "Gratitude", "$gratitude", Icons.favorite, Colors.pinkAccent),
              _statItem(
                  "Reliability", reliability, Icons.shield, Colors.greenAccent),
            ],
          ),
          const Divider(color: Colors.white10, height: 30),
          const Text("Last Minute Cancellations",
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          // Placeholder logic as backend doesn't track time-specific cancellations yet
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("< 2 hours before", style: TextStyle(color: Colors.white54)),
              Text("0", style: TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("< 24 hours before",
                  style: TextStyle(color: Colors.white54)),
              Text("0", style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildInfoCard() {
    final bio = _userData?['bio'];
    final linkedin = _userData?['linkedin'];
    final sector = _userData?['sector'];
    final achievements = _userData?['achievements'];

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
          ] else
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text("No bio added.",
                  style: TextStyle(
                      color: Colors.white38, fontStyle: FontStyle.italic)),
            ),
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

  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
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
