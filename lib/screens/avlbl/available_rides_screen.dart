import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rideshareApp/screens/book/ride_details_screen.dart';

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
    final grouped = _groupRidesByDay(rides);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        toolbarHeight: 88,
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Available Rides",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: grouped.isEmpty
          ? const Center(
              child: Text(
                "No rides found",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: grouped.entries
                  .map(
                    (entry) =>
                        _buildSection(context, entry.key, entry.value),
                  )
                  .toList(),
            ),
    );
  }

  /* ---------------- SECTION ---------------- */

  Widget _buildSection(
    BuildContext context,
    String title,
    List<QueryDocumentSnapshot> rides,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...rides.map((doc) => _buildRideTile(context, doc)).toList(),
      ],
    );
  }

  /* ---------------- RIDE TILE ---------------- */

  Widget _buildRideTile(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) {
    final ride = doc.data() as Map<String, dynamic>;

    final seatsAvailable = ride["seatsAvailable"] ?? 0;
    final seatsBooked = ride["seatsBooked"] ?? 0;
    final seatsLeft = seatsAvailable - seatsBooked;

    if (seatsLeft < requiredSeats) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- FROM → TO ----------
          Row(
            children: [
              Expanded(
                child: Text(
                  "${ride["from"]} → ${ride["to"]}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                "$seatsLeft seats",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ---------- TIMES ----------
          Row(
            children: [
              Expanded(
                child: Text(
                  "Pickup: ${ride["time"]}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  "Drop: ${_calculateEndTime(ride)}",
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ---------- DURATION ----------
          Text(
            "${ride["duration"]} • ${ride["distanceKm"].round()} km",
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 16),

          // ---------- ACTION ----------
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RideDetailsScreen(
                      rideDoc: doc,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Open Ride Details",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  /* ---------------- GROUPING ---------------- */

  Map<String, List<QueryDocumentSnapshot>> _groupRidesByDay(
    List<QueryDocumentSnapshot> rides,
  ) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};

    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    for (final ride in rides) {
      final data = ride.data() as Map<String, dynamic>;
      final dateStr = data["date"];
      if (dateStr == null) continue;

      final date = DateTime.parse(dateStr);

      String key;
      if (_isSameDay(date, today)) {
        key = "Today";
      } else if (_isSameDay(date, tomorrow)) {
        key = "Tomorrow";
      } else {
        key = "${date.day}/${date.month}/${date.year}";
      }

      grouped.putIfAbsent(key, () => []).add(ride);
    }

    return grouped;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  /* ---------------- END TIME ---------------- */

  static String _calculateEndTime(Map<String, dynamic> ride) {
    try {
      final start = ride["time"]; // "7:02 PM"
      final duration = ride["duration"]; // "7h 36m"

      if (start == null || duration == null) return "--";

      final startParts = start.split(" ");
      final timeParts = startParts[0].split(":");
      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final bool isPm = startParts[1] == "PM";

      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;

      final h = int.parse(duration.split("h")[0]);
      final m =
          int.parse(duration.split("h")[1].replaceAll("m", "").trim());

      final startDate = DateTime(2024, 1, 1, hour, minute);
      final endDate =
          startDate.add(Duration(hours: h, minutes: m));

      final displayHour =
          endDate.hour > 12 ? endDate.hour - 12 : endDate.hour;
      final suffix = endDate.hour >= 12 ? "PM" : "AM";

      return "${displayHour == 0 ? 12 : displayHour}:${endDate.minute.toString().padLeft(2, '0')} $suffix";
    } catch (_) {
      return "--";
    }
  }
}
