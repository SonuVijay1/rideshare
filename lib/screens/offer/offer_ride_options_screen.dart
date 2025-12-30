import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/ride_repository.dart';
import '../../repositories/user_repository.dart';
import 'ride_published_screen.dart';

class OfferRideOptionsScreen extends StatefulWidget {
  final Map<String, dynamic>? existingRideData;
  final String? rideId;

  // Data passed from Step 1 & 2
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
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final int seatsAvailable;

  // Existing data for Step 3
  final double existingPrice;
  final String existingBookingMode;

  const OfferRideOptionsScreen({
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
    required this.selectedDate,
    required this.selectedTime,
    required this.seatsAvailable,
    required this.existingPrice,
    required this.existingBookingMode,
  });

  @override
  State<OfferRideOptionsScreen> createState() => _OfferRideOptionsScreenState();
}

class _OfferRideOptionsScreenState extends State<OfferRideOptionsScreen> {
  final RideRepository _rideRepo = FirebaseRideRepository();
  final UserRepository _userRepo = FirebaseUserRepository();

  double _currentPrice = 0;
  double _minPrice = 0;
  double _maxPrice = 0;
  double _recPrice = 0;
  String _bookingMode = 'instant'; // 'instant' or 'request'

  bool isPublishing = false;

  @override
  void initState() {
    super.initState();
    _calculatePriceRange();
    _bookingMode = widget.existingBookingMode;

    if (widget.existingPrice > 0) {
      _currentPrice = widget.existingPrice;
      // Ensure existing price fits in range (or expand range)
      if (_currentPrice < _minPrice) _minPrice = _currentPrice;
      if (_currentPrice > _maxPrice) _maxPrice = _currentPrice;
    }
  }

  void _calculatePriceRange() {
    double dist = widget.distanceKm;
    if (dist < 1) dist = 1;

    // Updated Logic: Min ~1.2x, Max ~2.5x, Rec ~1.75x
    _minPrice = dist * 1.2;
    _maxPrice = dist * 2.5;
    _recPrice = dist * 1.75;

    // Ensure reasonable minimums
    if (_minPrice < 50) _minPrice = 50;
    if (_maxPrice <= _minPrice) _maxPrice = _minPrice + 50;

    // Round to nearest 10
    _minPrice = (_minPrice / 10).ceil() * 10.0;
    _maxPrice = (_maxPrice / 10).ceil() * 10.0;
    _recPrice = (_recPrice / 10).round() * 10.0;

    // Default to recommended
    _currentPrice = _recPrice;
    if (_currentPrice < _minPrice) _currentPrice = _minPrice;
    if (_currentPrice > _maxPrice) _currentPrice = _maxPrice;
  }

  Future<void> _publishRide() async {
    setState(() => isPublishing = true);

    try {
      final user = _userRepo.currentUser;
      if (user == null) return;

      final Map<String, dynamic> rideData = {
        "from": widget.from,
        "fromLat": widget.fromLat,
        "fromLng": widget.fromLng,
        "to": widget.to,
        "toLat": widget.toLat,
        "toLng": widget.toLng,
        "date": DateFormat("yyyy-MM-dd").format(widget.selectedDate),
        "time": widget.selectedTime.format(context),
        "distanceKm": widget.distanceKm,
        "duration": widget.durationStr,
        "routeGeometry": widget.routeGeometry,
        "seatsAvailable": widget.seatsAvailable,
        "seatsBooked": widget.seatsBooked,
        "price": _currentPrice.round(),
        "bookingMode": _bookingMode,
        "vehicleModel": widget.vehicleModel,
        "vehicleNumber": widget.vehicleNumber,
        "vehicleColor": widget.vehicleColor,
        "vehicleType": widget.vehicleType,
      };

      if (widget.rideId != null) {
        rideData["updatedAt"] = DateTime.now().toString();
        await _rideRepo.publishRide(user.uid, rideData, rideId: widget.rideId);

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  RidePublishedScreen(rideData: rideData, isUpdate: true)),
          (route) => route.isFirst,
        );
      } else {
        rideData["seatsBooked"] = 0;
        rideData["status"] = "Upcoming";
        rideData["createdAt"] = DateTime.now().toString();

        await _rideRepo.publishRide(user.uid, rideData);
        await _userRepo.incrementUserStat(user.uid, 'ridesOffered', 1);

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => RidePublishedScreen(rideData: rideData)),
          (route) => route.isFirst,
        );
      }
    } finally {
      if (mounted) setState(() => isPublishing = false);
    }
  }

  Future<void> _cancelRide() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title:
            const Text("Cancel Ride?", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Reason",
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Back")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: const Text("Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => isPublishing = true);
    try {
      final user = _userRepo.currentUser;
      if (user != null) {
        await _rideRepo.cancelRide(user.uid, widget.rideId!, reason);
        await _userRepo.incrementUserStat(user.uid, 'ridesOffered', -1);
        await _userRepo.incrementUserStat(user.uid, 'ridesCancelled', 1);

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => RidePublishedScreen(
                  rideData: widget.existingRideData ?? {},
                  isCancellation: true)),
          (route) => route.isFirst,
        );
      }
    } finally {
      if (mounted) setState(() => isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        _priceCard(),
                        const SizedBox(height: 20),
                        _bookingModeCard(),
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
                          onPressed: isPublishing ? null : _publishRide,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isPublishing
                              ? const CircularProgressIndicator(
                                  color: Colors.black)
                              : Text(
                                  widget.rideId != null
                                      ? "Update Ride"
                                      : "Publish Ride",
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      if (widget.rideId != null) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: isPublishing ? null : _cancelRide,
                          child: const Text("Cancel Ride",
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
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
            "Ride Options",
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _priceCard() {
    return _glassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Price per seat",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text("₹${_currentPrice.round()}",
                  style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _currentPrice,
              min: _minPrice,
              max: _maxPrice,
              divisions: (_maxPrice - _minPrice) > 0
                  ? ((_maxPrice - _minPrice) / 5).round()
                  : 1,
              label: "₹${_currentPrice.round()}",
              onChanged: (val) {
                setState(() {
                  _currentPrice = val;
                });
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("₹${_minPrice.round()}",
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              Text("₹${_maxPrice.round()}",
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "Recommended: ₹${_recPrice.round()}",
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingModeCard() {
    return _glassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Booking Mode",
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          _radioOption(
            "Instant Booking",
            "Passengers can book immediately without approval.",
            Icons.flash_on,
            'instant',
          ),
          const Divider(color: Colors.white10, height: 24),
          _radioOption(
            "Request Booking",
            "You approve each booking request manually.",
            Icons.person_add,
            'request',
          ),
        ],
      ),
    );
  }

  Widget _radioOption(
      String title, String subtitle, IconData icon, String value) {
    final isSelected = _bookingMode == value;
    return InkWell(
      onTap: () => setState(() => _bookingMode = value),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: isSelected ? Colors.black : Colors.white54, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
        ],
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
