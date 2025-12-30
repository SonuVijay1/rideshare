import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:confetti/confetti.dart';

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
  late ConfettiController _confettiController;

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
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    if (!widget.isCancellation) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
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
    final bookingMode = data['bookingMode'] ?? 'instant';

    String title = "Ride Published!";
    String subtitle = "Operation successful.";
    IconData statusIcon = Icons.check_circle;
    Color statusColor = Colors.greenAccent;

    if (widget.isCancellation) {
      title = widget.isBooking ? "Booking Cancelled" : "Ride Cancelled";
      subtitle = widget.isBooking
          ? "Your booking has been successfully cancelled."
          : "Your ride has been cancelled and passengers notified.";
      statusIcon = Icons.cancel;
      statusColor = Colors.redAccent;
    } else if (widget.isBooking) {
      if (bookingMode == 'request') {
        title = "Request Sent";
        subtitle =
            "Your booking request has been sent. Waiting for driver approval.";
        statusIcon = Icons.hourglass_top_rounded;
        statusColor = Colors.orangeAccent;
      } else {
        title = widget.isUpdate ? "Booking Updated!" : "Ride Booked!";
        subtitle = widget.isUpdate
            ? "Your booking has been updated."
            : "Your seat is confirmed.";
      }
    } else {
      // Driver Publishing
      title = widget.isUpdate ? "Ride Updated!" : "Ride Published!";
      if (widget.isUpdate) {
        subtitle = "Your ride details have been updated.";
      } else {
        if (bookingMode == 'request') {
          subtitle =
              "Your ride is live. You will review booking requests manually.";
        } else {
          subtitle = "Your ride is live. Passengers can book instantly.";
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient Background
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
          // Confetti Layer
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2, // down
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  const Spacer(),
                                  ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: Container(
                                      padding: const EdgeInsets.all(30),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: statusColor.withOpacity(0.3),
                                            width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: statusColor.withOpacity(0.2),
                                            blurRadius: 30,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        statusIcon,
                                        color: statusColor,
                                        size: 80,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    subtitle,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        height: 1.5),
                                  ),
                                  const SizedBox(height: 48),
                                  // Ride Details Card
                                  _glassContainer(
                                    child: Column(
                                      children: [
                                        _row(Icons.calendar_today,
                                            _formatDate(data['date'] ?? '')),
                                        const SizedBox(height: 16),
                                        _row(Icons.access_time,
                                            data['time'] ?? ''),
                                        const Divider(
                                            color: Colors.white10, height: 32),
                                        _locationRow(Icons.circle, Colors.green,
                                            data['from'] ?? ''),
                                        Container(
                                          margin:
                                              const EdgeInsets.only(left: 11),
                                          height: 24,
                                          width: 2,
                                          color: Colors.white12,
                                        ),
                                        _locationRow(Icons.location_on,
                                            Colors.redAccent, data['to'] ?? ''),
                                        const Divider(
                                            color: Colors.white10, height: 32),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: _infoItem(
                                                  Icons
                                                      .airline_seat_recline_normal,
                                                  "${data['seatsAvailable']} Seats"),
                                            ),
                                            Flexible(
                                              child: _infoItem(
                                                  Icons.directions_car,
                                                  "${(data['distanceKm'] as num).round()} km"),
                                            ),
                                            Flexible(
                                              child: _infoItem(Icons.timer,
                                                  "${data['duration']}"),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (widget.isCancellation) {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Done",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
