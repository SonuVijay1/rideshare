import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rideshareApp/screens/offer/ride_published_screen.dart';
import '../../repositories/ride_repository.dart';
import '../../repositories/user_repository.dart';
import '../reviews/rate_user_screen.dart';
import '../chat/chat_screen.dart';
import '../../utils/custom_route.dart';
import '../profile/user_profile_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final String rideId;
  final String driverId;
  final String? bookingId;
  final int? existingBookedSeats;

  const RideDetailsScreen({
    super.key,
    required this.rideData,
    required this.rideId,
    required this.driverId,
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

  final RideRepository _rideRepo = FirebaseRideRepository();
  final UserRepository _userRepo = FirebaseUserRepository();

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

    final uid = _userRepo.currentUser?.uid;
    if (uid == null) return;

    try {
      final booking = await _rideRepo.getBookingForRide(uid, widget.rideId);
      if (booking != null) {
        if (mounted) {
          setState(() {
            _localBookingId = booking['bookingId'];
            _localBookedSeats = booking['seatsBooked'] as int?;
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
      final data = await _rideRepo.getRide(widget.driverId, widget.rideId);
      if (data != null) {
        setState(() {
          maxSeatsAvailable = data['seatsAvailable'] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDriverDetails() async {
    try {
      final data = await _userRepo.getUser(widget.driverId);
      if (data != null) {
        setState(() {
          driverData = data;
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
      final user = _userRepo.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please login to book")));
        return;
      }
      final uid = user.uid;

      // Fetch user name for booking record
      final userData = await _userRepo.getUser(uid);
      final userName = userData?['name'] ?? "Unknown User";
      final userPic = userData?['profilePic'];

      await _rideRepo.bookRide(
        rideId: widget.rideId,
        driverId: widget.driverId,
        userId: uid,
        userName: userName,
        userPic: userPic,
        seats: selectedSeats,
        rideData: widget.rideData,
        existingBookingId: effectiveBookingId,
        existingBookedSeats: effectiveBookedSeats,
      );

      if (!isUpdate) {
        await _userRepo.incrementUserStat(uid, 'ridesTaken', 1);
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        CustomPageRoute(
            child: RidePublishedScreen(
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
      final user = _userRepo.currentUser;
      if (user == null) return;
      final uid = user.uid;

      await _rideRepo.cancelBooking(
        rideId: widget.rideId,
        driverId: widget.driverId,
        userId: uid,
        bookingId: effectiveBookingId,
        seatsBooked: effectiveBookedSeats!,
      );

      await _userRepo.incrementUserStat(uid, 'ridesTaken', -1);
      await _userRepo.incrementUserStat(uid, 'ridesCancelled', 1);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
          context,
          CustomPageRoute(
              child: RidePublishedScreen(
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
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _rideRepo.getRideStream(widget.driverId, widget.rideId),
      builder: (context, snapshot) {
        final data = snapshot.hasData && snapshot.data != null
            ? snapshot.data!
            : widget.rideData;

        final uid = _userRepo.currentUser?.uid;
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

        // Check if ride is completed
        bool isCompleted = false;
        try {
          if (data['date'] != null) {
            final date = DateFormat("yyyy-MM-dd").parse(data['date']);
            final now = DateTime.now();
            if (date.isBefore(DateTime(now.year, now.month, now.day)))
              isCompleted = true;
          }
        } catch (_) {}

        final canChat = uid != null &&
            (uid == widget.driverId || bookedUsers.any((u) => u['uid'] == uid));

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
                effectiveBookingId != null ? "Edit Booking" : "Ride Details",
                style: const TextStyle(color: Colors.white)),
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
                                      color:
                                          Colors.blueAccent.withOpacity(0.3)),
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
                                            color: Colors.blueAccent,
                                            fontSize: 13),
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
                                      color:
                                          Colors.blueAccent.withOpacity(0.3)),
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
                                      color:
                                          Colors.orangeAccent.withOpacity(0.3)),
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
                            _driverCard(isCompleted),
                            const SizedBox(height: 20),

                            // Ride Info
                            _glassContainer(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _row(Icons.calendar_today,
                                      _formatDate(data['date'])),
                                  const SizedBox(height: 12),
                                  _row(Icons.access_time, data['time'] ?? ''),
                                  const Divider(
                                      color: Colors.white10, height: 24),
                                  _locationRow(Icons.circle, Colors.green,
                                      data['from'] ?? '', data['time'] ?? ''),
                                  Container(
                                    margin: const EdgeInsets.only(left: 11),
                                    height: 20,
                                    width: 2,
                                    color: Colors.white24,
                                  ),
                                  _locationRow(
                                      Icons.location_on,
                                      Colors.redAccent,
                                      data['to'] ?? '',
                                      endTimeStr),
                                ],
                              ),
                            ),

                            if (data['vehicleModel'] != null &&
                                (data['vehicleModel'] as String)
                                    .isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _glassContainer(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    const Icon(Icons.directions_car,
                                        color: Colors.white70),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            "${data['vehicleModel']} (${data['vehicleType'] ?? 'Car'})",
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                        if (data['vehicleColor'] != null)
                                          Text(data['vehicleColor'],
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 13)),
                                        if (data['vehicleNumber'] != null &&
                                            (data['vehicleNumber'] as String)
                                                .isNotEmpty)
                                          Text(data['vehicleNumber'],
                                              style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12)),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Seat Selection
                            _glassContainer(
                              padding: const EdgeInsets.all(20),
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
                                            icon: Icon(
                                                Icons.remove_circle_outline,
                                                color: selectedSeats > 1
                                                    ? (canBook
                                                        ? Colors.white
                                                        : Colors.white24)
                                                    : Colors.white24),
                                            onPressed:
                                                canBook && selectedSeats > 1
                                                    ? () => setState(
                                                        () => selectedSeats--)
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
                                                ? () => setState(
                                                    () => selectedSeats++)
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
                              _glassContainer(
                                padding: const EdgeInsets.all(20),
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
                                        final pic = user is Map
                                            ? user['profilePic']
                                            : null;
                                        return InkWell(
                                          onTap: () {
                                            if (user is Map &&
                                                user['uid'] != null) {
                                              Navigator.push(
                                                  context,
                                                  CustomPageRoute(
                                                      child: UserProfileScreen(
                                                          userId: user['uid'],
                                                          userName: name,
                                                          rideId:
                                                              widget.rideId)));
                                            }
                                          },
                                          child: Chip(
                                            backgroundColor: Colors.white10,
                                            avatar: CircleAvatar(
                                              backgroundColor: Colors.grey,
                                              backgroundImage: pic != null
                                                  ? NetworkImage(pic)
                                                  : null,
                                              child: pic == null
                                                  ? const Icon(Icons.person,
                                                      size: 12,
                                                      color: Colors.white)
                                                  : null,
                                            ),
                                            label: Text(
                                              name,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    if (isCompleted &&
                                        uid == widget.driverId) ...[
                                      const SizedBox(height: 16),
                                      const Text("Rate Passengers:",
                                          style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12)),
                                      const SizedBox(height: 8),
                                      Column(
                                        children: (data['bookedUsers'] as List)
                                            .map<Widget>((user) {
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(Icons.person,
                                                color: Colors.white),
                                            title: Text(user['name'] ?? 'User',
                                                style: const TextStyle(
                                                    color: Colors.white)),
                                            trailing: IconButton(
                                              icon: const Icon(
                                                  Icons.star_border,
                                                  color: Colors.amber),
                                              onPressed: () => _openRateScreen(
                                                  user['uid'],
                                                  user['name'] ?? 'User',
                                                  true),
                                            ),
                                          );
                                        }).toList(),
                                      )
                                    ]
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
                              onPressed:
                                  (canBook && hasChanges) ? _bookRide : null,
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
            ],
          ),
        );
      },
    );
  }

  Widget _driverCard(bool isCompleted) {
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

    return _glassContainer(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          Navigator.push(
              context,
              CustomPageRoute(
                  child: UserProfileScreen(
                      userId: widget.driverId,
                      userName: name,
                      rideId: widget.rideId)));
        },
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
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          Text(" $rating ($ridesOffered rides)",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
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
                  if (isCompleted &&
                      _userRepo.currentUser?.uid != widget.driverId)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: InkWell(
                        onTap: () =>
                            _openRateScreen(widget.driverId, name, false),
                        child: const Text("Rate Driver",
                            style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRateScreen(String userId, String userName, bool isDriverReviewing) {
    Navigator.push(
      context,
      CustomPageRoute(
        child: RateUserScreen(
          rideId: widget.rideId,
          revieweeId: userId,
          revieweeName: userName,
          isDriverReviewing: isDriverReviewing,
        ),
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
