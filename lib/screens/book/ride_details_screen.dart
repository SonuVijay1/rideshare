  import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RideDetailsScreen extends StatelessWidget {
  final QueryDocumentSnapshot rideDoc;

  const RideDetailsScreen({
    super.key,
    required this.rideDoc,
  });

  @override
  Widget build(BuildContext context) {
    final ride = rideDoc.data() as Map<String, dynamic>;

    final seatsAvailable = ride["seatsAvailable"] ?? 0;
    final seatsBooked = ride["seatsBooked"] ?? 0;
    final seatsLeft = seatsAvailable - seatsBooked;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        toolbarHeight: 84,
        title: const Text(
          "Ride Details",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rideSummary(ride, seatsLeft),
            const SizedBox(height: 24),
            _driverSection(),
            const SizedBox(height: 24),
            _bookedUsersSection(seatsBooked),
            const SizedBox(height: 30),
            _bookButton(context, seatsLeft),
          ],
        ),
      ),
    );
  }

  /* ---------------- RIDE SUMMARY ---------------- */

  Widget _rideSummary(Map<String, dynamic> ride, int seatsLeft) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${ride["from"]} → ${ride["to"]}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Text(
                  "Pickup: ${ride["time"]}",
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              Expanded(
                child: Text(
                  "Drop: ${_calculateEndTime(ride)}",
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            "${ride["duration"]} • ${ride["distanceKm"].round()} km",
            style: const TextStyle(color: Colors.white54),
          ),

          const SizedBox(height: 10),

          Text(
            "$seatsLeft seats available",
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- DRIVER ---------------- */

  Widget _driverSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white12,
            child: Icon(Icons.person, size: 30, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Vijay Rathod",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text(
                      "4.8 • 126 rides",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  "Rarely cancels rides",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- BOOKED USERS ---------------- */

  Widget _bookedUsersSection(int seatsBooked) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Booked Passengers ($seatsBooked)",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),

          if (seatsBooked == 0)
            const Text(
              "No passengers booked yet",
              style: TextStyle(color: Colors.white54),
            )
          else
            Column(
              children: List.generate(
                seatsBooked,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: const [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white12,
                        child: Icon(Icons.person,
                            size: 14, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Passenger",
                        style: TextStyle(color: Colors.white70),
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

  /* ---------------- BOOK BUTTON ---------------- */

  Widget _bookButton(BuildContext context, int seatsLeft) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: seatsLeft == 0 ? null : () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          "Book Seats",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /* ---------------- END TIME ---------------- */

  static String _calculateEndTime(Map<String, dynamic> ride) {
    try {
      final start = ride["time"];
      final duration = ride["duration"];

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
      final endDate = startDate.add(Duration(hours: h, minutes: m));

      final displayHour =
          endDate.hour > 12 ? endDate.hour - 12 : endDate.hour;
      final suffix = endDate.hour >= 12 ? "PM" : "AM";

      return "${displayHour == 0 ? 12 : displayHour}:${endDate.minute.toString().padLeft(2, '0')} $suffix";
    } catch (_) {
      return "--";
    }
  }
}
