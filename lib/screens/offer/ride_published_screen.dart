import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RidePublishedScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final bool isUpdate;
  final bool isBooking;
  final bool isCancellation;

  const RidePublishedScreen(
      {super.key,
      required this.rideData,
      this.isUpdate = false,
      this.isBooking = false,
      this.isCancellation = false});

  @override
  State<RidePublishedScreen> createState() => _RidePublishedScreenState();
}

class _RidePublishedScreenState extends State<RidePublishedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateFormat("yyyy-MM-dd").parse(dateStr);
      return DateFormat("EEE, dd MMM yyyy").format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.rideData;

    String title = "Ride Published!";
    if (widget.isCancellation) {
      title = widget.isBooking ? "Booking Cancelled" : "Ride Cancelled";
    } else if (widget.isBooking) {
      final mode = widget.rideData['bookingMode'] ?? 'instant';
      if (mode == 'request') {
        title = "Request Sent";
      } else {
        title = widget.isUpdate ? "Booking Updated!" : "Ride Booked!";
      }
    } else {
      title = widget.isUpdate ? "Ride Updated!" : "Ride Published!";
    }

    String subtitle = widget.isUpdate
        ? "Your details have been updated."
        : "Operation successful.";
    if (widget.isCancellation) {
      subtitle = widget.isBooking
          ? "Your booking has been successfully cancelled."
          : "Your ride has been cancelled and passengers notified.";
    } else if (widget.isBooking) {
      final mode = widget.rideData['bookingMode'] ?? 'instant';
      if (mode == 'request') {
        subtitle =
            "Your booking request has been sent. Waiting for driver approval.";
      } else {
        subtitle = widget.isUpdate
            ? "Your booking has been updated."
            : "Your seat is confirmed.";
      }
    } else {
      subtitle = widget.isUpdate
          ? "Your ride details have been updated."
          : "Your ride has been successfully posted.";
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Spacer(),
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Colors.greenAccent,
                              size: 80,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 40),
                        // Ride Details Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              _row(Icons.calendar_today,
                                  _formatDate(data['date'] ?? '')),
                              const SizedBox(height: 12),
                              _row(Icons.access_time, data['time'] ?? ''),
                              const Divider(color: Colors.white10, height: 30),
                              _locationRow(Icons.circle, Colors.green,
                                  data['from'] ?? ''),
                              Container(
                                margin: const EdgeInsets.only(left: 11),
                                height: 20,
                                width: 2,
                                color: Colors.white24,
                              ),
                              _locationRow(Icons.location_on, Colors.redAccent,
                                  data['to'] ?? ''),
                              const Divider(color: Colors.white10, height: 30),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _infoItem(Icons.airline_seat_recline_normal,
                                      "${data['seatsAvailable']} Seats"),
                                  _infoItem(Icons.directions_car,
                                      "${(data['distanceKm'] as num).round()} km"),
                                  _infoItem(Icons.timer, "${data['duration']}"),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () {
                              if (widget.isCancellation) {
                                Navigator.popUntil(
                                    context, (route) => route.isFirst);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "Done",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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

  Widget _locationRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}
