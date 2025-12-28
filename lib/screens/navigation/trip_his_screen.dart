import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rideshareApp/screens/offer/offer_ride_screen.dart';
import 'package:rideshareApp/screens/book/ride_details_screen.dart';
import '../../repositories/ride_repository.dart';
import '../../repositories/user_repository.dart';

class TripHistoryScreen extends StatelessWidget {
  TripHistoryScreen({super.key});

  final RideRepository _rideRepo = FirebaseRideRepository();
  final UserRepository _userRepo = FirebaseUserRepository();

  @override
  Widget build(BuildContext context) {
    final user = _userRepo.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Text("Please login to view your trips",
              style: TextStyle(color: Colors.white70, fontSize: 16)),
        ),
      );
    }
    final uid = user.uid;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _rideRepo.getDriverTrips(uid),
      builder: (context, driverSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _rideRepo.getBookedTrips(uid),
          builder: (context, bookedSnap) {
            if (driverSnap.hasError || bookedSnap.hasError) {
              return Scaffold(
                backgroundColor: const Color(0xFF121212),
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  title: const Text("My Trips",
                      style: TextStyle(color: Colors.white)),
                ),
                body: Center(
                  child: Text(
                    "Error loading trips. Check console for index link.\n${driverSnap.error ?? bookedSnap.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            }

            if (driverSnap.connectionState == ConnectionState.waiting ||
                bookedSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF121212),
                body: Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              );
            }

            final driverTrips = driverSnap.data ?? [];
            final bookedTrips = bookedSnap.data ?? [];
            final hasOffered = driverTrips.isNotEmpty;
            final hasBooked = bookedTrips.isNotEmpty;

            if (hasOffered && hasBooked) {
              return DefaultTabController(
                length: 2,
                child: Scaffold(
                  backgroundColor: const Color(0xFF121212),
                  appBar: AppBar(
                    backgroundColor: Colors.black,
                    elevation: 0,
                    title: const Text(
                      "My Trips",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    bottom: const TabBar(
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(text: "Offered"),
                        Tab(text: "Booked"),
                      ],
                    ),
                  ),
                  body: TabBarView(
                    children: [
                      _TripsList(trips: driverTrips, isOffered: true),
                      _TripsList(trips: bookedTrips, isOffered: false),
                    ],
                  ),
                ),
              );
            } else if (hasOffered) {
              return Scaffold(
                backgroundColor: const Color(0xFF121212),
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  centerTitle: true,
                  title: const Text(
                    "Offered",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                body: _TripsList(trips: driverTrips, isOffered: true),
              );
            } else if (hasBooked) {
              return Scaffold(
                backgroundColor: const Color(0xFF121212),
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  centerTitle: true,
                  title: const Text(
                    "Booked",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                body: _TripsList(trips: bookedTrips, isOffered: false),
              );
            } else {
              return Scaffold(
                backgroundColor: const Color(0xFF121212),
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  title: const Text(
                    "My Trips",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                body: const Center(
                  child: Text(
                    "No Bookings or Offerings",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _TripsList extends StatelessWidget {
  final List<Map<String, dynamic>> trips;
  final bool isOffered;

  const _TripsList({super.key, required this.trips, required this.isOffered});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffered ? Icons.directions_car : Icons.confirmation_number,
              size: 64,
              color: Colors.white12,
            ),
            const SizedBox(height: 16),
            Text(
              isOffered
                  ? "You haven't offered any rides yet."
                  : "You haven't booked any rides yet.",
              style: const TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: trips.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final data = trips[index];
        final id =
            isOffered ? (data['rideId'] ?? '') : (data['bookingId'] ?? '');
        return _TripCard(data: data, rideId: id, isOffered: isOffered);
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String rideId;
  final bool isOffered;

  const _TripCard(
      {required this.data, required this.rideId, required this.isOffered});

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Unknown Date";
    try {
      final date = DateFormat("yyyy-MM-dd").parse(dateStr);
      return DateFormat("EEE, dd MMM").format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Duration _parseDuration(String? durationStr) {
    if (durationStr == null) return const Duration(hours: 2); // Default
    int hours = 0;
    int mins = 0;
    final hMatch = RegExp(r'(\d+)\s*(h|hr|hour|hours)').firstMatch(durationStr);
    final mMatch =
        RegExp(r'(\d+)\s*(m|min|mins|minute|minutes)').firstMatch(durationStr);
    if (hMatch != null) hours = int.parse(hMatch.group(1)!);
    if (mMatch != null) mins = int.parse(mMatch.group(1)!);
    if (hours == 0 && mins == 0) return const Duration(hours: 2);
    return Duration(hours: hours, minutes: mins);
  }

  Map<String, dynamic> _getStatus(Map<String, dynamic> data) {
    if (data['status'] == 'Cancelled') {
      return _statusStyle("Cancelled", Colors.redAccent);
    }

    try {
      final dateStr = data['date'] as String?;
      final timeStr = data['time'] as String?;
      final durationStr = data['duration'] as String?;

      if (dateStr == null || timeStr == null) {
        return _statusStyle("Upcoming", Colors.greenAccent);
      }

      final date = DateFormat("yyyy-MM-dd").parse(dateStr);
      DateTime dateTime = DateTime(date.year, date.month, date.day);

      // Attempt to parse time (Handle both "5:30 PM" and "17:30")
      DateTime timeDate;
      try {
        final cleanTimeStr =
            timeStr.replaceAll('\u202F', ' '); // Handle narrow nbsp
        final time = DateFormat("h:mm a").parse(cleanTimeStr);
        dateTime =
            dateTime.add(Duration(hours: time.hour, minutes: time.minute));
      } catch (_) {
        try {
          final time = DateFormat("HH:mm").parse(timeStr);
          dateTime =
              dateTime.add(Duration(hours: time.hour, minutes: time.minute));
        } catch (e) {
          // Fallback if time parsing fails
        }
      }

      final now = DateTime.now();

      final duration = _parseDuration(durationStr);

      final endDateTime = dateTime.add(duration);

      if (now.isBefore(dateTime)) {
        return _statusStyle("Upcoming", Colors.greenAccent);
      } else if (now.isAfter(dateTime) && now.isBefore(endDateTime)) {
        return _statusStyle("In Progress", Colors.orangeAccent);
      } else {
        return _statusStyle("Completed", Colors.grey);
      }
    } catch (e) {
      return _statusStyle("Upcoming", Colors.greenAccent);
    }
  }

  Map<String, dynamic> _statusStyle(String text, Color color) {
    return {"text": text, "color": color, "bg": color.withOpacity(0.15)};
  }

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatus(data);
    final statusText = statusInfo['text'];
    final statusColor = statusInfo['color'];
    final statusBg = statusInfo['bg'];
    final isCompleted = statusText == "Completed";

    // Calculate End Time for display
    String endTimeStr = "";
    try {
      final dateStr = data['date'] as String?;
      final timeStr = data['time'] as String?;
      final durationStr = data['duration'] as String?;
      if (dateStr != null && timeStr != null) {
        // Re-using logic implicitly or we could refactor.
        // For UI simplicity, let's just parse time + duration
        final cleanTimeStr = timeStr.replaceAll('\u202F', ' ');
        final startTime =
            DateFormat("h:mm a").parse(cleanTimeStr); // simplistic
        final duration = _parseDuration(durationStr);
        final endTime = startTime.add(duration);
        endTimeStr = DateFormat("h:mm a").format(endTime);
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isCompleted ? Colors.white10 : Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date, Time, Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Colors.white54),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(data['date']),
                    style: TextStyle(
                        color: isCompleted ? Colors.white38 : Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isOffered && statusText == "Upcoming")
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OfferRideScreen(
                                  existingRideData: data, rideId: rideId),
                            ),
                          );
                        },
                        child: const Icon(Icons.edit,
                            color: Colors.white70, size: 18),
                      ),
                    ),
                  if (!isOffered && statusText == "Upcoming")
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: InkWell(
                        onTap: () {
                          final driverId = data['driverId'];
                          final rId = data['rideId'];
                          if (driverId != null && rId != null) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => RideDetailsScreen(
                                          rideData: data,
                                          rideId: rId,
                                          driverId: driverId,
                                          bookingId: rideId,
                                          existingBookedSeats:
                                              data['seatsBooked'] ?? 0,
                                        )));
                          }
                        },
                        child: const Icon(Icons.edit,
                            color: Colors.white70, size: 18),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),

          if (statusText == "Cancelled" &&
              data['cancellationReason'] != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Cancellation Reason:",
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(data['cancellationReason'],
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],

          // Route
          _locationRow(Icons.circle, isCompleted ? Colors.grey : Colors.green,
              data['from'] ?? 'Origin', data['time'] ?? '', isCompleted),
          Container(
            margin: const EdgeInsets.only(left: 11),
            height: 20,
            width: 2,
            color: Colors.white12,
          ),
          _locationRow(
              Icons.location_on,
              isCompleted ? Colors.grey : Colors.redAccent,
              data['to'] ?? 'Destination',
              endTimeStr,
              isCompleted),

          const SizedBox(height: 20),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoItem(
                  Icons.directions_car,
                  "${(data['distanceKm'] as num?)?.round() ?? 0} km",
                  isCompleted),
              _infoItem(Icons.timer, data['duration'] ?? '', isCompleted),
              if (isOffered)
                _infoItem(Icons.airline_seat_recline_normal,
                    "${data['seatsAvailable'] ?? 0} Seats", isCompleted)
              else
                _LiveSeatsInfo(
                  driverId: data['driverId'],
                  rideId: data['rideId'],
                  initialSeats: data['seatsAvailable'] ?? 0,
                  isCompleted: isCompleted,
                ),
            ],
          ),

          // Booked Users Section
          if (isOffered &&
              data['bookedUsers'] != null &&
              (data['bookedUsers'] as List).isNotEmpty) ...[
            const Divider(color: Colors.white10, height: 24),
            const Text(
              "Booked by:",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: (data['bookedUsers'] as List).map<Widget>((user) {
                // Assuming user is a Map or String. Adjust based on actual data structure.
                final name = user is Map ? user['name'] : user.toString();
                return Chip(
                  backgroundColor: Colors.white10,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  avatar: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 12, color: Colors.white),
                  ),
                  label: Text(
                    name,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          ],

          // Driver Info Section for Booked Rides
          if (!isOffered && data['driverId'] != null) ...[
            const Divider(color: Colors.white10, height: 24),
            _DriverInfo(driverId: data['driverId']),
          ],
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String text, bool isCompleted) {
    return Row(
      children: [
        Icon(icon,
            color: isCompleted ? Colors.white24 : Colors.white54, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
              color: isCompleted ? Colors.white38 : Colors.white70,
              fontSize: 13),
        ),
      ],
    );
  }

  Widget _locationRow(
      IconData icon, Color color, String text, String time, bool isCompleted) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: isCompleted ? Colors.white60 : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
              if (time.isNotEmpty)
                Text(
                  time,
                  style: TextStyle(
                      color: isCompleted ? Colors.white24 : Colors.white54,
                      fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveSeatsInfo extends StatelessWidget {
  final String? driverId;
  final String? rideId;
  final int initialSeats;
  final bool isCompleted;
  final RideRepository _rideRepo = FirebaseRideRepository();

  _LiveSeatsInfo({
    super.key,
    required this.driverId,
    required this.rideId,
    required this.initialSeats,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (driverId == null || rideId == null) {
      return _buildRow(initialSeats);
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _rideRepo.getRideStream(driverId!, rideId!),
      builder: (context, snapshot) {
        int seats = initialSeats;
        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          seats = data['seatsAvailable'] ?? 0;
        }
        return _buildRow(seats);
      },
    );
  }

  Widget _buildRow(int seats) {
    return Row(
      children: [
        Icon(Icons.airline_seat_recline_normal,
            color: isCompleted ? Colors.white24 : Colors.white54, size: 16),
        const SizedBox(width: 6),
        Text(
          "$seats Seats",
          style: TextStyle(
              color: isCompleted ? Colors.white38 : Colors.white70,
              fontSize: 13),
        ),
      ],
    );
  }
}

class _DriverInfo extends StatelessWidget {
  final String driverId;
  final UserRepository _userRepo = FirebaseUserRepository();
  _DriverInfo({required this.driverId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _userRepo.getUser(driverId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink(); // Or a loading/error state
        }

        final driverData = snapshot.data!;
        final driverName = driverData['name'] ?? 'Driver';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ride offered by:",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Chip(
              backgroundColor: Colors.white10,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              avatar: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 12, color: Colors.white),
              ),
              label: Text(
                driverName,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            )
          ],
        );
      },
    );
  }
}
