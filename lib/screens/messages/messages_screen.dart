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
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    final uid = _userRepo.currentUser?.uid;
    if (uid != null) {
      _driverSub = _rideRepo.getDriverTrips(uid).listen((data) {
        if (mounted) {
          setState(() {
            _driverRides = data;
            _isLoading = false;
          });
        }
      });
      _passengerSub = _rideRepo.getBookedTrips(uid).listen((data) {
        if (mounted) {
          setState(() {
            _passengerRides = data;
            _isLoading = false;
          });
        }
      });
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

    final allChats = [...driverChats, ...passengerChats];

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
                    ? const Center(
                        child: Text("No active conversations",
                            style: TextStyle(color: Colors.white54)))
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
    final String rideId = data['rideId'] ??
        data['bookingId'] ??
        ''; // bookingId is doc id, but data has rideId field usually
    // Note: getBookedTrips returns booking docs which contain 'rideId'.
    final String realRideId = data['rideId'] ?? '';
    final String from = data['from'] ?? 'Unknown';
    final String to = data['to'] ?? 'Unknown';
    final String date = data['date'] ?? '';
    final String? lastMessage = data['lastMessage'];
    final bool isDriver = data['isDriver'] == true;

    return InkWell(
      onTap: () {
        if (realRideId.isNotEmpty) {
          Navigator.push(
            context,
            CustomPageRoute(
              child: ChatScreen(
                rideId: realRideId,
                title: "$from → $to",
              ),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                if (!isDriver && data['driverId'] != null)
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _userRepo.getUser(data['driverId']),
                    builder: (context, snapshot) {
                      if (snapshot.hasData &&
                          snapshot.data!['profilePic'] != null) {
                        return CircleAvatar(
                          backgroundImage:
                              NetworkImage(snapshot.data!['profilePic']),
                        );
                      }
                      return const CircleAvatar(
                        backgroundColor: Colors.white10,
                        child: Icon(Icons.person, color: Colors.white),
                      );
                    },
                  )
                else
                  const CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(Icons.directions_car, color: Colors.white),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$from → $to",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMessage ?? date,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white24, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
