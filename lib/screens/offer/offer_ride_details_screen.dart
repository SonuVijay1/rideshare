import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/ride_repository.dart';
import '../../repositories/user_repository.dart';
import 'offer_ride_map_screen.dart';

class OfferRideDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? existingRideData;
  final String? rideId;

  // Data passed from Step 1
  final String from;
  final String to;
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final double distanceKm;
  final String durationStr;
  final String? routeGeometry;
  final String vehicleModel;
  final String vehicleNumber;
  final String vehicleColor;
  final String vehicleType;
  final int seatsBooked;

  const OfferRideDetailsScreen({
    super.key,
    this.existingRideData,
    this.rideId,
    required this.from,
    required this.to,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    required this.distanceKm,
    required this.durationStr,
    this.routeGeometry,
    required this.vehicleModel,
    required this.vehicleNumber,
    required this.vehicleColor,
    required this.vehicleType,
    required this.seatsBooked,
  });

  @override
  State<OfferRideDetailsScreen> createState() => _OfferRideDetailsScreenState();
}

class _OfferRideDetailsScreenState extends State<OfferRideDetailsScreen> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  int seats = 1;
  int _maxSeats = 4;
  double _existingPrice = 0;
  String _existingBookingMode = 'instant';

  bool isPublishing = false;

  @override
  void initState() {
    super.initState();
    _maxSeats = _calculateMaxSeats(widget.vehicleType);
    seats = _maxSeats; // Default to max seats

    if (widget.existingRideData != null) {
      _prefillData();
    }
  }

  void _prefillData() {
    final data = widget.existingRideData!;
    if (data['date'] != null) {
      try {
        selectedDate = DateFormat("yyyy-MM-dd").parse(data['date']);
      } catch (_) {}
    }
    if (data['time'] != null) {
      String t = data['time'].replaceAll('\u202F', ' ');
      try {
        final dt = DateFormat("h:mm a").parse(t);
        selectedTime = TimeOfDay.fromDateTime(dt);
      } catch (_) {
        try {
          final dt = DateFormat("HH:mm").parse(t);
          selectedTime = TimeOfDay.fromDateTime(dt);
        } catch (_) {}
      }
    }
    seats = data['seatsAvailable'] ?? 1;
    if (data['price'] != null) {
      _existingPrice = (data['price'] as num).toDouble();
    }
    _existingBookingMode = data['bookingMode'] ?? 'instant';
  }

  int _calculateMaxSeats(String type) {
    if (type == "Bike") return 1;
    if (type == "Car") return 4;
    if (type == "SUV") return 6;
    if (type == "Bus") return 30;
    return 4;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          dialogBackgroundColor: Colors.black,
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          dialogBackgroundColor: Colors.black,
          colorScheme: const ColorScheme.dark(
            primary: Colors.white,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) setState(() => selectedTime = time);
  }

  void _onNext() {
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all details")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfferRideMapScreen(
          existingRideData: widget.existingRideData,
          rideId: widget.rideId,
          from: widget.from,
          to: widget.to,
          fromLat: widget.fromLat,
          fromLng: widget.fromLng,
          toLat: widget.toLat,
          toLng: widget.toLng,
          distanceKm: widget.distanceKm,
          durationStr: widget.durationStr,
          routeGeometry: widget.routeGeometry,
          vehicleModel: widget.vehicleModel,
          vehicleNumber: widget.vehicleNumber,
          vehicleColor: widget.vehicleColor,
          vehicleType: widget.vehicleType,
          seatsBooked: widget.seatsBooked,
          // Step 2 Data
          selectedDate: selectedDate!,
          selectedTime: selectedTime!,
          seatsAvailable: seats,
          // Existing Data for Step 3
          existingPrice: _existingPrice,
          existingBookingMode: _existingBookingMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRestricted = widget.seatsBooked > 0;

    return Scaffold(
      backgroundColor: Colors.black,
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
                _header(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _picker(
                          "Date",
                          selectedDate == null
                              ? "Select Date"
                              : DateFormat("EEE, dd MMM yyyy")
                                  .format(selectedDate!),
                          Icons.calendar_today,
                          _pickDate,
                          enabled: !isRestricted,
                        ),
                        const SizedBox(height: 16),
                        _picker(
                          "Time",
                          selectedTime == null
                              ? "Select Time"
                              : selectedTime!.format(context),
                          Icons.access_time,
                          _pickTime,
                          enabled: !isRestricted,
                        ),
                        const SizedBox(height: 16),
                        _seatsCard(),
                        const SizedBox(height: 16),
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
                          onPressed: _onNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            "Next",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            "Ride Details",
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _picker(String label, String value, IconData icon, VoidCallback tap,
      {bool enabled = true}) {
    // Custom date formatting for "Today" and "Tomorrow"
    if (label == "Date" && selectedDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final check =
          DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);

      if (check == today)
        value = "Today";
      else if (check == tomorrow) value = "Tomorrow";
    }

    return InkWell(
      onTap: enabled ? tap : null,
      child: _glassContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: enabled ? Colors.white70 : Colors.white30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: TextStyle(
                          color: enabled ? Colors.white : Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (enabled)
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white12, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _seatsCard() {
    final canDecrease = seats > 1 && seats > widget.seatsBooked;
    return _glassContainer(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Passengers",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              SizedBox(height: 4),
              Text("Total Seats",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          Row(
            children: [
              _circleBtn(
                  Icons.remove, canDecrease, () => setState(() => seats--)),
              SizedBox(
                  width: 16,
                  child: Center(
                      child: Text("$seats",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)))),
              _circleBtn(
                  Icons.add, seats < _maxSeats, () => setState(() => seats++)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white24 : Colors.white10,
        ),
        child: Icon(icon,
            color: enabled ? Colors.white : Colors.white38, size: 20),
      ),
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
