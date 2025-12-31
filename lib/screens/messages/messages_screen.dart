import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../repositories/ride_repository.dart';
import '../../repositories/user_repository.dart';
import '../chat/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/custom_route.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final RideRepository _rideRepo = FirebaseRideRepository();
  final UserRepository _userRepo = FirebaseUserRepository();

  List<Map<String, dynamic>> _driverRides = [];
  List<Map<String, dynamic>> _passengerRides = [];
  StreamSubscription? _driverSub;
  StreamSubscription? _passengerSub;
  bool _isLoading = true;

  @override
  void initState() {
    print("DEBUG: MessagesScreen initState START - Screen is initializing");
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    final uid = _userRepo.currentUser?.uid;
    print("DEBUG: MessagesScreen _setupStreams called. UID: $uid");
    if (uid != null) {
      _driverSub = _rideRepo.getDriverTrips(uid).listen((data) {
        print("DEBUG: MessagesScreen received ${data.length} driver trips.");
        if (mounted) {
          setState(() {
            _driverRides = data;
            _isLoading = false;
          });
        }
      }, onError: (e) {});
      _passengerSub = _rideRepo.getBookedTrips(uid).listen((data) {
        if (mounted) {
          setState(() {
            _passengerRides = data;
            _isLoading = false;
          });
        }
      }, onError: (e) {});
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _passengerSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Merge and sort
    final driverChats =
        _driverRides.map((e) => {...e, 'isDriver': true}).toList();
    final passengerChats =
        _passengerRides.map((e) => {...e, 'isDriver': false}).toList();

    // Filter out chats with no messages
    final allChats = [...driverChats, ...passengerChats].where((chat) {
      final msg = chat['lastMessage'];
      return msg != null && (msg as String).isNotEmpty;
    }).toList();

    // Sort by last message time, then by ride date
    allChats.sort((a, b) {
      final tA = a['lastMessageTime'] as Timestamp?;
      final tB = b['lastMessageTime'] as Timestamp?;
      if (tA != null && tB != null) return tB.compareTo(tA);
      if (tA != null) return -1;
      if (tB != null) return 1;
      return (b['date'] ?? '').compareTo(a['date'] ?? '');
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Messages", style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
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
                : allChats.isEmpty
                    ? Center(
                        child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 48, color: Colors.white24),
                          const SizedBox(height: 16),
                          const Text("No active conversations",
                              style: TextStyle(color: Colors.white54)),
                        ],
                      ))
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: allChats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final chat = allChats[index];
                          return _chatTile(chat);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chatTile(Map<String, dynamic> data) {
    final String realRideId = data['rideId'] ?? '';
    final String? lastMessage = data['lastMessage'];
    final bool isDriver = data['isDriver'] == true;
    final String subtitle = lastMessage ?? "Tap to start chatting";

    if (!isDriver) {
      // I am Passenger -> Show Driver Name & Pic
      return FutureBuilder<Map<String, dynamic>?>(
        future: _userRepo.getUser(data['driverId']),
        builder: (context, snapshot) {
          final driver = snapshot.data;
          final name = driver?['name'] ?? 'Driver';
          final pic = driver?['profilePic'];

          return _buildListTile(
            title: name,
            subtitle: subtitle,
            imageUrl: pic,
            onTap: () => _navigateToChat(
              realRideId,
              name,
              data['driverId'] ?? '',
              isDriver,
            ),
          );
        },
      );
    } else {
      // I am Driver -> Show Passenger(s) Name & Pic
      final bookedUsers = (data['bookedUsers'] as List<dynamic>?) ?? [];
      String title;
      String? pic;
      bool isGroup = false;

      if (bookedUsers.isEmpty) {
        title = "Ride: ${data['from']} → ${data['to']}";
      } else if (bookedUsers.length == 1) {
        final u = bookedUsers.first;
        title = u['name'] ?? 'Passenger';
        pic = u['profilePic'];
      } else {
        title = "${bookedUsers[0]['name']} & ${bookedUsers.length - 1} others";
        isGroup = true;
      }

      return _buildListTile(
        title: title,
        subtitle: subtitle,
        imageUrl: pic,
        isGroup: isGroup,
        onTap: () => _navigateToChat(
          realRideId,
          title,
          data['driverId'] ?? '',
          isDriver,
        ),
      );
    }
  }

  void _navigateToChat(
      String rideId, String title, String driverId, bool isDriver) {
    if (rideId.isNotEmpty) {
      Navigator.push(
        context,
        CustomPageRoute(
          child: ChatScreen(
            rideId: rideId,
            title: title,
            driverId: driverId,
            isDriver: isDriver,
          ),
        ),
      );
    }
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    String? imageUrl,
    bool isGroup = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey[800],
              backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
              child: imageUrl == null
                  ? Icon(isGroup ? Icons.group : Icons.person,
                      color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
