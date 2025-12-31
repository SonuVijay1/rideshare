import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/ride_repository.dart';
import '../chat/chat_screen.dart';
import '../../utils/custom_route.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseUserRepository().currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title:
            const Text("Notifications", style: TextStyle(color: Colors.white)),
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
            child: user == null
                ? const Center(
                    child: Text("Please login",
                        style: TextStyle(color: Colors.white)))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('userId', isEqualTo: user.uid)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white));
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text("No notifications yet",
                              style: TextStyle(color: Colors.white54)),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          return _notificationTile(
                              context, docs[index].id, data);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _notificationTile(
      BuildContext context, String docId, Map<String, dynamic> data) {
    IconData icon = Icons.notifications;
    Color color = Colors.blueAccent;

    if (data['type'] == 'cancellation') {
      icon = Icons.cancel;
      color = Colors.redAccent;
    } else if (data['type'] == 'booking') {
      icon = Icons.check_circle;
      color = Colors.greenAccent;
    } else if (data['type'] == 'message') {
      icon = Icons.chat_bubble;
      color = Colors.white;
    }

    final bool isRead = data['isRead'] == true;

    return InkWell(
      onTap: () async {
        // Mark as read
        FirebaseFirestore.instance
            .collection('notifications')
            .doc(docId)
            .update({'isRead': true});

        if (data['type'] == 'message' && data['referenceId'] != null) {
          final rideId = data['referenceId'];
          final rideRepo = FirebaseRideRepository();
          final userRepo = FirebaseUserRepository();
          final currentUser = userRepo.currentUser;

          if (currentUser != null) {
            // Fetch ride to get details for chat screen
            final ride = await rideRepo.getRide('', rideId);
            if (ride != null) {
              final driverId = ride['driverId'];
              final isDriver = currentUser.uid == driverId;

              // Construct title
              String title = "Chat";
              if (isDriver) {
                // If I am driver, title could be generic or we can try to find sender name from body
                title = "Passenger";
              } else {
                // If I am passenger, title is Driver
                final driverUser = await userRepo.getUser(driverId);
                title = driverUser?['name'] ?? "Driver";
              }

              if (context.mounted) {
                Navigator.push(
                    context,
                    CustomPageRoute(
                        child: ChatScreen(
                            rideId: rideId,
                            title: title,
                            driverId: driverId,
                            isDriver: isDriver)));
              }
            }
          }
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isRead
                  ? Colors.white.withOpacity(0.02)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['title'] ?? 'Notification',
                          style: TextStyle(
                              color: isRead ? Colors.white70 : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(data['body'] ?? '',
                          style: TextStyle(
                              color: isRead ? Colors.white38 : Colors.white70,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
