import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/ride_repository.dart';
import '../book/book_ride_screen.dart';
import '../offer/offer_ride_screen.dart';
import '../book/ride_details_screen.dart';
import '../profile/ride_history_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../utils/custom_route.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final UserRepository _userRepo = FirebaseUserRepository();
  final RideRepository _rideRepo = FirebaseRideRepository();
  String _userName = "Traveler";

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    final user = _userRepo.currentUser;
    if (user != null) {
      final data = await _userRepo.getUser(user.uid);
      if (data != null && mounted) {
        setState(() {
          _userName = data['name'] ?? "Traveler";
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                              context,
                              CustomPageRoute(
                                  child: const NotificationsScreen()));
                        },
                        child: _glassContainer(
                          padding: const EdgeInsets.all(8),
                          borderRadius: 12,
                          child: const Icon(Icons.notifications_none,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _actionCard(
                          "Book a Ride",
                          Icons.search,
                          Colors.blueAccent,
                          () => Navigator.push(
                            context,
                            CustomPageRoute(child: const BookRideScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _actionCard(
                          "Offer a Ride",
                          Icons.directions_car,
                          Colors.greenAccent,
                          () => Navigator.push(
                            context,
                            CustomPageRoute(child: const OfferRideScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Upcoming Rides Section
                  _buildSectionHeader("Booked Rides (Today/Tomorrow)"),
                  const SizedBox(height: 16),
                  _buildUpcomingBookedRides(),

                  const SizedBox(height: 30),
                  _buildSectionHeader("Offered Rides (Today/Tomorrow)"),
                  const SizedBox(height: 16),
                  _buildUpcomingOfferedRides(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  bool _isTodayOrTomorrow(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final date = DateFormat("yyyy-MM-dd").parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final check = DateTime(date.year, date.month, date.day);
      return check == today || check == tomorrow;
    } catch (_) {
      return false;
    }
  }

  Widget _buildUpcomingBookedRides() {
    final user = _userRepo.currentUser;
    if (user == null) {
      return const Text("Please login to see rides",
          style: TextStyle(color: Colors.white54));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _rideRepo.getBookedTrips(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }
        final rides = snapshot.data ?? [];
        final upcoming =
            rides.where((r) => _isTodayOrTomorrow(r['date'])).toList();

        if (upcoming.isEmpty) {
          return _glassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text("No booked rides for today or tomorrow.",
                    style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 12),
                _viewHistoryButton(0),
              ],
            ),
          );
        }

        return Column(
          children: [
            ...upcoming.map((ride) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _rideTile(ride),
                )),
            _viewHistoryButton(0),
          ],
        );
      },
    );
  }

  Widget _buildUpcomingOfferedRides() {
    final user = _userRepo.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _rideRepo.getDriverTrips(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }
        final rides = snapshot.data ?? [];
        final upcoming =
            rides.where((r) => _isTodayOrTomorrow(r['date'])).toList();

        if (upcoming.isEmpty) {
          return _glassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text("No offered rides for today or tomorrow.",
                    style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 12),
                _viewHistoryButton(1),
              ],
            ),
          );
        }

        return Column(
          children: [
            ...upcoming.map((ride) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _rideTile(ride),
                )),
            _viewHistoryButton(1),
          ],
        );
      },
    );
  }

  Widget _viewHistoryButton(int tabIndex) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          CustomPageRoute(
            child: RideHistoryScreen(initialIndex: tabIndex),
          ),
        );
      },
      child: const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text("View Full History",
            style: TextStyle(color: Colors.blueAccent)),
      ),
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
      child: _glassContainer(
        padding: const EdgeInsets.all(16),
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
                  Text(
                    "${ride['from']} → ${ride['to']}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${ride['date']} • ${ride['time']}",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ride['status'] ?? 'Confirmed',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: _glassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double borderRadius = 16,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
