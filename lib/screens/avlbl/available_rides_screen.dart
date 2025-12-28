import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../book/ride_details_screen.dart';

class AvailableRidesScreen extends StatelessWidget {
  final List<QueryDocumentSnapshot> rides;
  final int requiredSeats;

  const AvailableRidesScreen({
    super.key,
    required this.rides,
    required this.requiredSeats,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Available Rides", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: rides.isEmpty
          ? const Center(
              child: Text("No rides found matching your criteria",
                  style: TextStyle(color: Colors.white54)))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: rides.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final doc = rides[index];
                final data = doc.data() as Map<String, dynamic>;

                return _RideTile(
                  initialData: data,
                  rideRef: doc.reference,
                  requiredSeats: requiredSeats,
                );
              },
            ),
    );
  }
}

class _RideTile extends StatelessWidget {
  final Map<String, dynamic> initialData;
  final DocumentReference rideRef;
  final int requiredSeats;

  const _RideTile({
    required this.initialData,
    required this.rideRef,
    required this.requiredSeats,
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
    return StreamBuilder<DocumentSnapshot>(
      stream: rideRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.hasData && snapshot.data != null && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>
            : initialData;

        final seatsAvailable = data['seatsAvailable'] ?? 0;
        final isAvailable = seatsAvailable >= requiredSeats;

        return InkWell(
          onTap: isAvailable
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RideDetailsScreen(
                        rideData: data,
                        rideReference: rideRef,
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
            child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
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
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      seatsAvailable == 0 ? "Fully Booked" : "Not enough seats",
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text(
                      "${_formatDate(data['date'])} • ${data['time'] ?? ''}",
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            _locationRow(Icons.location_on, Colors.redAccent, data['to'] ?? ''),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoItem(Icons.directions_car, "${(data['distanceKm'] as num?)?.round() ?? 0} km"),
                _infoItem(Icons.timer, data['duration'] ?? ''),
                _infoItem(Icons.airline_seat_recline_normal, "${data['seatsAvailable']} Seats"),
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
}