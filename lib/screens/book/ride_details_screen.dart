import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:rideshareApp/screens/offer/ride_published_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final DocumentReference rideReference;
  final String? bookingId;
  final int? existingBookedSeats;

  const RideDetailsScreen({
    super.key,
    required this.rideData,
    required this.rideReference,
    this.bookingId,
    this.existingBookedSeats,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  Map<String, dynamic>? driverData;
  bool isLoadingDriver = true;
  int selectedSeats = 1;
  bool isBooking = false;

  // For editing
  int maxSeatsAvailable = 1;

  // Local state for detected booking (when coming from search)
  String? _localBookingId;
  int? _localBookedSeats;

  @override
  void initState() {
    super.initState();
    if (widget.bookingId != null && widget.existingBookedSeats != null) {
      selectedSeats = widget.existingBookedSeats!;
    }
    debugPrint("RideDetailsScreen: Init. BookingId: ${widget.bookingId}");

    // Initialize max seats from passed data initially
    maxSeatsAvailable = widget.rideData['seatsAvailable'] ?? 1;

    _fetchDriverDetails();
    _fetchFreshRideData();
    _checkExistingBooking();
  }

  Future<void> _checkExistingBooking() async {
    // If explicitly passed, no need to check
    if (widget.bookingId != null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('bookedTrips')
          .where('rideId', isEqualTo: widget.rideReference.id)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final doc = q.docs.first;
        final data = doc.data();
        debugPrint("RideDetailsScreen: Found existing booking ${doc.id}");
        if (mounted) {
          setState(() {
            _localBookingId = doc.id;
            _localBookedSeats = data['seatsBooked'] as int?;
            // Update selected seats to match what user already has
            if (_localBookedSeats != null) {
              selectedSeats = _localBookedSeats!;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking existing booking: $e");
    }
  }

  Future<void> _fetchFreshRideData() async {
    try {
      final doc = await widget.rideReference.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          maxSeatsAvailable = data['seatsAvailable'] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDriverDetails() async {
    try {
      // rideReference is users/{uid}/driverTrips/{rideId}
      // parent is driverTrips, parent.parent is users/{uid}
      final driverDoc = await widget.rideReference.parent.parent!.get();
      if (driverDoc.exists) {
        setState(() {
          driverData = driverDoc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      debugPrint("Error fetching driver: $e");
    } finally {
      setState(() => isLoadingDriver = false);
    }
  }

  Future<void> _bookRide() async {
    final effectiveBookingId = widget.bookingId ?? _localBookingId;
    final effectiveBookedSeats =
        widget.existingBookedSeats ?? _localBookedSeats;
    final isUpdate = effectiveBookingId != null;

    if (isUpdate && selectedSeats < effectiveBookedSeats!) {
      final diff = effectiveBookedSeats - selectedSeats;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Reduce Seats?",
              style: TextStyle(color: Colors.white)),
          content: Text(
              "You are removing $diff seat(s). This will cancel booking for those seats.",
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("No")),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Yes",
                    style: TextStyle(color: Colors.redAccent))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => isBooking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please login to book")));
        return;
      }
      final uid = user.uid;

      // Fetch user name for booking record
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userName = userDoc.data()?['name'] ?? "Unknown User";
      final userPic = userDoc.data()?['profilePic'];

      // Run transaction to ensure seat availability
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final rideSnapshot = await transaction.get(widget.rideReference);
        if (!rideSnapshot.exists) throw Exception("Ride does not exist");

        final snapshotData = rideSnapshot.data() as Map<String, dynamic>;
        final currentSeats = snapshotData['seatsAvailable'] as int;

        int seatsChange = selectedSeats;
        if (isUpdate) {
          seatsChange = selectedSeats - effectiveBookedSeats!;
        }

        if (seatsChange > 0 && currentSeats < seatsChange) {
          throw Exception("Not enough seats available");
        }

        // Update ride doc
        // Update bookedUsers array: remove old entry if update, add new entry
        List<dynamic> bookedUsers =
            List.from(snapshotData['bookedUsers'] ?? []);

        if (isUpdate) {
          // Remove existing user entry
          bookedUsers.removeWhere((element) => element['uid'] == uid);
        }

        // Add new entry
        bookedUsers.add({
          'uid': uid,
          'name': userName,
          'profilePic': userPic,
          'seats': selectedSeats,
          'bookedAt': DateTime.now().toString()
        });

        transaction.update(widget.rideReference, {
          'seatsAvailable': currentSeats - seatsChange,
          'seatsBooked': FieldValue.increment(seatsChange),
          'bookedUsers': bookedUsers
        });

        // Add to my booked trips
        DocumentReference myBookingRef;
        if (isUpdate) {
          myBookingRef = FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('bookedTrips')
              .doc(effectiveBookingId);

          transaction.update(myBookingRef, {
            'seatsBooked': selectedSeats,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          myBookingRef = FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('bookedTrips')
              .doc();

          final bookingData = Map<String, dynamic>.from(widget.rideData);
          bookingData['seatsBooked'] = selectedSeats; // My booked seats
          bookingData['status'] = 'Upcoming';
          bookingData['bookedAt'] = FieldValue.serverTimestamp();
          bookingData['driverId'] = widget.rideReference.parent.parent!.id;
          bookingData['rideId'] = widget.rideReference.id;

          transaction.set(myBookingRef, bookingData);
        }
      });

      if (!isUpdate) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'ridesTaken': FieldValue.increment(1),
        });
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => RidePublishedScreen(
                rideData: widget.rideData,
                isUpdate: isUpdate,
                isBooking: true)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Booking failed: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => isBooking = false);
    }
  }

  Future<void> _cancelBooking() async {
    final effectiveBookingId = widget.bookingId ?? _localBookingId;
    final effectiveBookedSeats =
        widget.existingBookedSeats ?? _localBookedSeats;

    if (effectiveBookingId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Cancel Booking?",
            style: TextStyle(color: Colors.white)),
        content: const Text(
            "Are you sure you want to cancel this booking? This action cannot be undone.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("No")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Yes, Cancel",
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => isBooking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final uid = user.uid;
      final userBookingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('bookedTrips')
          .doc(effectiveBookingId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final rideSnapshot = await transaction.get(widget.rideReference);
        if (!rideSnapshot.exists)
          throw Exception("Ride does not exist anymore.");

        final snapshotData = rideSnapshot.data() as Map<String, dynamic>;
        List<dynamic> bookedUsers =
            List.from(snapshotData['bookedUsers'] ?? []);

        final userBookingData =
            bookedUsers.firstWhere((b) => b['uid'] == uid, orElse: () => null);

        if (userBookingData != null) {
          transaction.update(widget.rideReference, {
            'seatsAvailable': FieldValue.increment(effectiveBookedSeats!),
            'seatsBooked': FieldValue.increment(-effectiveBookedSeats),
            'bookedUsers': FieldValue.arrayRemove([userBookingData])
          });
        }
        transaction.delete(userBookingRef);
      });

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'ridesTaken': FieldValue.increment(-1),
        'ridesCancelled': FieldValue.increment(1),
      });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => RidePublishedScreen(
                  rideData: widget.rideData,
                  isBooking: true,
                  isCancellation: true)),
          (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cancellation failed: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => isBooking = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Unknown Date";
    try {
      final date = DateFormat("yyyy-MM-dd").parse(dateStr);
      return DateFormat("EEE, dd MMM yyyy").format(date);
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.rideReference.snapshots(),
      builder: (context, snapshot) {
        final data =
            snapshot.hasData && snapshot.data != null && snapshot.data!.exists
                ? snapshot.data!.data() as Map<String, dynamic>
                : widget.rideData;

        final uid = FirebaseAuth.instance.currentUser?.uid;
        final bookedUsers = (data['bookedUsers'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];

        final effectiveBookingId = widget.bookingId ?? _localBookingId;
        final effectiveBookedSeats =
            widget.existingBookedSeats ?? _localBookedSeats;

        // Check if already booked (only for new bookings)
        final isAlreadyBooked = uid != null &&
            effectiveBookingId == null &&
            bookedUsers.any((u) => u['uid'] == uid);

        final int currentSeatsAvailable = data['seatsAvailable'] ?? 0;

        // For UI limits:
        // If new booking: limit is currentSeatsAvailable
        // If update: limit is currentSeatsAvailable + existingBookedSeats
        final int effectiveMaxSeats = effectiveBookingId != null
            ? (currentSeatsAvailable + (effectiveBookedSeats ?? 0))
            : currentSeatsAvailable;

        final bool isFullyBooked = effectiveMaxSeats <= 0;
        final bool canBook = !isBooking &&
            !isAlreadyBooked &&
            !isFullyBooked &&
            selectedSeats <= effectiveMaxSeats;

        final bool isUpdate = effectiveBookingId != null;
        final bool hasChanges =
            !isUpdate || (selectedSeats != (effectiveBookedSeats ?? 0));

        // Calculate End Time
        String endTimeStr = "";
        try {
          final timeStr = data['time'] as String?;
          final durationStr = data['duration'] as String?;
          if (timeStr != null) {
            final cleanTimeStr = timeStr.replaceAll('\u202F', ' ');
            final startTime = DateFormat("h:mm a").parse(cleanTimeStr);
            final duration = _parseDuration(durationStr);
            final endTime = startTime.add(duration);
            endTimeStr = DateFormat("h:mm a").format(endTime);
          }
        } catch (_) {}

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
                effectiveBookingId != null ? "Edit Booking" : "Ride Details",
                style: const TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isAlreadyBooked)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.blueAccent.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.blueAccent, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "You have already booked this ride.",
                                    style: TextStyle(
                                        color: Colors.blueAccent, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (effectiveBookingId != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.blueAccent.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.blueAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                      "You have booked this ride for ${effectiveBookedSeats ?? 0} seat(s).",
                                      style: const TextStyle(
                                          color: Colors.blueAccent,
                                          fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        if (isFullyBooked && !isAlreadyBooked)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.orangeAccent.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.orangeAccent, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "This ride is fully booked.",
                                    style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Driver Info Card
                        _driverCard(),
                        const SizedBox(height: 20),

                        // Ride Info
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              _row(Icons.calendar_today,
                                  _formatDate(data['date'])),
                              const SizedBox(height: 12),
                              _row(Icons.access_time, data['time'] ?? ''),
                              const Divider(color: Colors.white10, height: 24),
                              _locationRow(Icons.circle, Colors.green,
                                  data['from'] ?? '', data['time'] ?? ''),
                              Container(
                                margin: const EdgeInsets.only(left: 11),
                                height: 20,
                                width: 2,
                                color: Colors.white24,
                              ),
                              _locationRow(Icons.location_on, Colors.redAccent,
                                  data['to'] ?? '', endTimeStr),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Seat Selection
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Select Seats",
                                  style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.remove_circle_outline,
                                            color: selectedSeats > 1
                                                ? (canBook
                                                    ? Colors.white
                                                    : Colors.white24)
                                                : Colors.white24),
                                        onPressed: canBook && selectedSeats > 1
                                            ? () =>
                                                setState(() => selectedSeats--)
                                            : null,
                                      ),
                                      Text("$selectedSeats",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18)),
                                      IconButton(
                                        icon: Icon(Icons.add_circle_outline,
                                            color: canBook &&
                                                    selectedSeats <
                                                        effectiveMaxSeats
                                                ? (canBook
                                                    ? Colors.white
                                                    : Colors.white24)
                                                : Colors.white24),
                                        onPressed: canBook &&
                                                selectedSeats <
                                                    effectiveMaxSeats
                                            ? () =>
                                                setState(() => selectedSeats++)
                                            : null,
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "₹${(int.tryParse(data['price']?.toString() ?? '150') ?? 150) * selectedSeats}",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Booked Users
                        if (data['bookedUsers'] != null &&
                            (data['bookedUsers'] as List).isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Booked Users (${(data['bookedUsers'] as List).length})",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: (data['bookedUsers'] as List)
                                      .map<Widget>((user) {
                                    final name = user is Map
                                        ? (user['name'] ?? 'User')
                                        : 'User';
                                    final pic =
                                        user is Map ? user['profilePic'] : null;
                                    return Chip(
                                      backgroundColor: Colors.white10,
                                      avatar: CircleAvatar(
                                        backgroundColor: Colors.grey,
                                        backgroundImage: pic != null
                                            ? NetworkImage(pic)
                                            : null,
                                        child: pic == null
                                            ? const Icon(Icons.person,
                                                size: 12, color: Colors.white)
                                            : null,
                                      ),
                                      label: Text(
                                        name,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: (canBook && hasChanges) ? _bookRide : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white24,
                            disabledForegroundColor: Colors.white38,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isBooking
                              ? const CircularProgressIndicator(
                                  color: Colors.black)
                              : Text(
                                  effectiveBookingId != null
                                      ? "Update Booking"
                                      : "Book Ride",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (effectiveBookingId != null) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: isBooking ? null : _cancelBooking,
                          child: const Text(
                            "Cancel Booking",
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 16),
                          ),
                        )
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _driverCard() {
    if (isLoadingDriver) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    final name = driverData?['name'] ?? "Unknown Driver";
    final rating =
        (driverData?['driverRating'] as num?)?.toStringAsFixed(1) ?? "New";

    final ridesOffered = (driverData?['ridesOffered'] as num?)?.toInt() ?? 0;
    final ridesTaken = (driverData?['ridesTaken'] as num?)?.toInt() ?? 0;
    final cancelledRides =
        (driverData?['ridesCancelled'] as num?)?.toInt() ?? 0;

    String cancelStatus = "Never cancels";
    Color cancelColor = Colors.greenAccent;

    final totalActivity = ridesOffered + ridesTaken + cancelledRides;

    if (cancelledRides > 0 && totalActivity > 0) {
      final ratio = cancelledRides / totalActivity;
      if (ratio > 0.4) {
        cancelStatus = "Often cancels";
        cancelColor = Colors.redAccent;
      } else if (ratio > 0.1) {
        cancelStatus = "Sometimes cancels";
        cancelColor = Colors.orangeAccent;
      } else {
        cancelStatus = "Rarely cancels";
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    Text(" $rating ($ridesOffered rides)",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cancelColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(cancelStatus,
                          style: TextStyle(color: cancelColor, fontSize: 10)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _locationRow(IconData icon, Color color, String text, String time) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (time.isNotEmpty)
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
