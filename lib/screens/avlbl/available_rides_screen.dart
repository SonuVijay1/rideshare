import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../book/ride_details_screen.dart';
import '../../repositories/ride_repository.dart';
import '../../utils/custom_route.dart';

class AvailableRidesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> rides;
  final int requiredSeats;

  const AvailableRidesScreen({
    super.key,
    required this.rides,
    required this.requiredSeats,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Available Rides",
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
            child: rides.isEmpty
                ? const Center(
                    child: Text("No rides found matching your criteria",
                        style: TextStyle(color: Colors.white54)))
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: rides.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final doc = rides[index];

                      return _RideTile(
                        initialData: doc,
                        requiredSeats: requiredSeats,
                        rideId: doc['rideId'],
                        driverId: doc['driverId'],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  final Map<String, dynamic> initialData;
  final String rideId;
  final String driverId;
  final int requiredSeats;
  final RideRepository _rideRepo = FirebaseRideRepository();

  _RideTile({
    super.key,
    required this.initialData,
    required this.requiredSeats,
    required this.rideId,
    required this.driverId,
  });

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Unknown Date";
    try {
      final date = DateFormat("yyyy-MM-dd").parse(dateStr);
      return DateFormat("EEE, dd MMM").format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _rideRepo.getRideStream(driverId, rideId),
      builder: (context, snapshot) {
        final data = snapshot.hasData && snapshot.data != null
            ? snapshot.data!
            : initialData;

        final seatsAvailable = data['seatsAvailable'] ?? 0;
        final isAvailable = seatsAvailable >= requiredSeats;
        final bookingMode = data['bookingMode'] ?? 'instant';

        return InkWell(
          onTap: isAvailable
              ? () {
                  Navigator.push(
                    context,
                    CustomPageRoute(
                      child: RideDetailsScreen(
                        rideData: data,
                        rideId: rideId,
                        driverId: driverId,
                      ),
                    ),
                  );
                }
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(seatsAvailable == 0
                          ? "This ride is fully booked"
                          : "Only $seatsAvailable seat(s) available"),
                    ),
                  );
                },
          child: Opacity(
            opacity: isAvailable ? 1.0 : 0.5,
            child: _glassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isAvailable)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orangeAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.orangeAccent, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            seatsAvailable == 0
                                ? "Fully Booked"
                                : "Not enough seats",
                            style: const TextStyle(
                                color: Colors.orangeAccent, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 14, color: Colors.white54),
                          const SizedBox(width: 6),
                          Text(
                            "${_formatDate(data['date'])} • ${data['time'] ?? ''}",
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Icon(
                        bookingMode == 'instant'
                            ? Icons.flash_on
                            : Icons.person_add,
                        color: Colors.white38,
                        size: 16,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "₹${data['price'] ?? '150'}",
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _locationRow(Icons.circle, Colors.green, data['from'] ?? ''),
                  Container(
                    margin: const EdgeInsets.only(left: 11),
                    height: 16,
                    width: 2,
                    color: Colors.white12,
                  ),
                  _locationRow(
                      Icons.location_on, Colors.redAccent, data['to'] ?? ''),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoItem(Icons.directions_car,
                          "${(data['distanceKm'] as num?)?.round() ?? 0} km"),
                      _infoItem(Icons.timer, data['duration'] ?? ''),
                      _infoItem(Icons.airline_seat_recline_normal,
                          "${data['seatsAvailable']} Seats"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _locationRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _infoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
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
