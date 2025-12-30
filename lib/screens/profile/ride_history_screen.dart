import 'dart:ui';
import 'package:flutter/material.dart';
import '../../repositories/ride_repository.dart';
import '../../repositories/user_repository.dart';
import '../book/ride_details_screen.dart';
import '../../utils/custom_route.dart';

class RideHistoryScreen extends StatefulWidget {
  final int initialIndex;
  const RideHistoryScreen({super.key, this.initialIndex = 0});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RideRepository _rideRepo = FirebaseRideRepository();
  final UserRepository _userRepo = FirebaseUserRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    final user = _userRepo.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title:
            const Text("Ride History", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Booked"),
            Tab(text: "Offered"),
          ],
        ),
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(_rideRepo.getBookedTrips(user.uid), isBooked: true),
                _buildList(_rideRepo.getDriverTrips(user.uid), isBooked: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(Stream<List<Map<String, dynamic>>> stream,
      {required bool isBooked}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }
        final rides = snapshot.data ?? [];
        if (rides.isEmpty) {
          return Center(
            child: Text(
              isBooked ? "No rides booked yet" : "No rides offered yet",
              style: const TextStyle(color: Colors.white54),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: rides.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final ride = rides[index];
            return _rideTile(ride);
          },
        );
      },
    );
  }

  Widget _rideTile(Map<String, dynamic> ride) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          CustomPageRoute(
            child: RideDetailsScreen(
              rideData: ride,
              rideId: ride['rideId'],
              driverId: ride['driverId'],
              bookingId: ride['bookingId'],
              existingBookedSeats: ride['seatsBooked'],
            ),
          ),
        );
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.directions_car, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${ride['from']} → ${ride['to']}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text("${ride['date']} • ${ride['time']}",
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
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
