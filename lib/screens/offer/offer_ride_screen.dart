import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:intl/intl.dart';

import 'package:rideshareApp/services/location_service.dart';
import 'package:rideshareApp/services/recent_location_service.dart';
import '../book/location_search_screen.dart';
import '../../repositories/ride_repository.dart';
import '../../repositories/user_repository.dart';

import 'offer_ride_details_screen.dart';

enum LastEdited { pickup, drop }

class OfferRideScreen extends StatefulWidget {
  final Map<String, dynamic>? existingRideData;
  final String? rideId;

  const OfferRideScreen({super.key, this.existingRideData, this.rideId});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen>
    with TickerProviderStateMixin {
  // controllers
  final pickupController = TextEditingController();
  final dropController = TextEditingController();
  final carModelController = TextEditingController();
  final carNumberController = TextEditingController();
  final carColorController = TextEditingController();

  // errors
  bool pickupError = false;
  bool dropError = false;

  // last edited
  LastEdited? _lastEdited;

  // services
  final LocationService _locationService = LocationService();

  // seats
  int seatsBooked = 0;

  // coords
  double? pickupLat, pickupLng, dropLat, dropLng;

  // route
  double? distanceKm;
  String? durationStr;
  String? routeGeometry;
  bool isFetchingRoute = false;

  // animations
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  late final AnimationController _swapController;

  // Initial values for change detection
  String _selectedVehicleType = "Car";

  StreamSubscription<List<Map<String, dynamic>>>? _vehicleSub;
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;

  final UserRepository _userRepo = FirebaseUserRepository();

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 0), weight: 1),
    ]).animate(_shakeController);

    _swapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    if (widget.existingRideData != null) {
      _prefillData();
    } else {
      // _checkVehicleDetails(); // Replaced by stream listener
    }
    _setupVehicleStream();
  }

  void _setupVehicleStream() {
    final user = _userRepo.currentUser;
    if (user == null) return;

    _vehicleSub = _userRepo.getUserVehicles(user.uid).listen((vehicles) {
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
      });

      if (vehicles.isEmpty) {
        _showNoVehiclesDialog();
      } else {
        // If creating new ride and no vehicle selected, select first
        if (widget.existingRideData == null && _selectedVehicleId == null) {
          _selectVehicle(vehicles.first);
        }
        // If editing, try to match existing vehicle number to set dropdown ID
        if (widget.existingRideData != null && _selectedVehicleId == null) {
          final num = widget.existingRideData!['vehicleNumber'];
          try {
            final match = vehicles.firstWhere((v) => v['vehicleNumber'] == num);
            setState(() {
              _selectedVehicleId = match['id'];
            });
          } catch (_) {}
        }
      }
    });
  }

  void _selectVehicle(Map<String, dynamic> v) {
    setState(() {
      _selectedVehicleId = v['id'];
      carModelController.text = v['vehicleModel'] ?? '';
      carNumberController.text = v['vehicleNumber'] ?? '';
      carColorController.text = v['vehicleColor'] ?? '';
      _selectedVehicleType = v['vehicleType'] ?? 'Car';
    });
  }

  Future<void> _showNoVehiclesDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("No Vehicles Found",
            style: TextStyle(color: Colors.white)),
        content: const Text(
          "Please add a vehicle in your Account section before offering a ride.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("OK", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _prefillData() {
    final data = widget.existingRideData!;
    pickupController.text = data['from'] ?? '';
    dropController.text = data['to'] ?? '';
    pickupLat = data['fromLat'];
    pickupLng = data['fromLng'];
    dropLat = data['toLat'];
    dropLng = data['toLng'];

    seatsBooked = data['seatsBooked'] ?? 0;
    distanceKm = (data['distanceKm'] as num?)?.toDouble();
    durationStr = data['duration'];
    routeGeometry = data['routeGeometry'];
    carModelController.text = data['vehicleModel'] ?? '';
    carNumberController.text = data['vehicleNumber'] ?? '';
    carColorController.text = data['vehicleColor'] ?? '';
    _selectedVehicleType = data['vehicleType'] ?? 'Car';
  }

  @override
  void dispose() {
    _vehicleSub?.cancel();
    _shakeController.dispose();
    _swapController.dispose();
    super.dispose();
  }

  /* ---------------- ROUTE ---------------- */
  Future<void> _computeRoute() async {
    if (pickupLat == null || dropLat == null) return;

    if (pickupLat == dropLat && pickupLng == dropLng) {
      setState(() {
        pickupError = false;
        dropError = false;

        if (_lastEdited == LastEdited.pickup) {
          pickupError = true;
          pickupController.clear();
          pickupLat = null;
          pickupLng = null;
        } else {
          dropError = true;
          dropController.clear();
          dropLat = null;
          dropLng = null;
        }

        distanceKm = null;
        durationStr = null;
        routeGeometry = null;
        isFetchingRoute = false;
      });

      _shakeController.forward(from: 0);
      return;
    }

    setState(() => isFetchingRoute = true);

    final route = await _locationService.getRouteDetails(
      pickupLat!,
      pickupLng!,
      dropLat!,
      dropLng!,
    );

    if (!mounted) return;

    setState(() {
      if (route != null) {
        distanceKm = route["distanceKm"];
        durationStr = route["duration"];
        routeGeometry = route["geometry"];
      }
      isFetchingRoute = false;
    });
  }

  /* ---------------- SWAP ---------------- */
  void _swapPickupDrop() {
    if (pickupController.text.isEmpty && dropController.text.isEmpty) return;

    _swapController.forward(from: 0);

    setState(() {
      final tText = pickupController.text;
      pickupController.text = dropController.text;
      dropController.text = tText;

      final tLat = pickupLat;
      final tLng = pickupLng;
      pickupLat = dropLat;
      pickupLng = dropLng;
      dropLat = tLat;
      dropLng = tLng;

      pickupError = false;
      dropError = false;

      distanceKm = null;
      durationStr = null;
      routeGeometry = null;
    });

    _computeRoute();
  }

  Future<void> _openSearch(bool isPickup) async {
    if (seatsBooked > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Cannot change location when seats are booked")),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSearchScreen(
          hintText: isPickup ? "Where from?" : "Where to?",
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      await RecentLocationService.add(result);
      setState(() {
        if (isPickup) {
          pickupController.text = result['title'];
          pickupLat = result['lat'];
          pickupLng = result['lng'];
        } else {
          dropController.text = result['title'];
          dropLat = result['lat'];
          dropLng = result['lng'];
        }
      });
      _computeRoute();
    }
  }

  void _onNext() {
    if (pickupController.text.isEmpty ||
        dropController.text.isEmpty ||
        _selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select locations and vehicle")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfferRideDetailsScreen(
          existingRideData: widget.existingRideData,
          rideId: widget.rideId,
          from: pickupController.text.trim(),
          to: dropController.text.trim(),
          fromLat: pickupLat!,
          fromLng: pickupLng!,
          toLat: dropLat!,
          toLng: dropLng!,
          distanceKm: distanceKm ?? 0,
          durationStr: durationStr ?? "",
          routeGeometry: routeGeometry,
          vehicleModel: carModelController.text.trim(),
          vehicleNumber: carNumberController.text.trim(),
          vehicleColor: carColorController.text.trim(),
          vehicleType: _selectedVehicleType,
          seatsBooked: seatsBooked,
        ),
      ),
    );
  }

  /* ---------------- UI ---------------- */
  @override
  Widget build(BuildContext context) {
    final bool isRestricted = seatsBooked > 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Ambient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1F25), // Deep Blue-Grey
                    Color(0xFF000000), // Black
                  ],
                ),
              ),
            ),
          ),
          // 3. Content
          SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (isRestricted)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _glassContainer(
                              color: Colors.orange.withOpacity(0.1),
                              borderColor: Colors.orangeAccent.withOpacity(0.3),
                              padding: const EdgeInsets.all(12),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.orangeAccent, size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Some fields are locked because you have bookings.",
                                      style: TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        _buildLocationCard(isRestricted),
                        const SizedBox(height: 15),
                        if (isFetchingRoute)
                          const CircularProgressIndicator(color: Colors.white)
                        else if (distanceKm != null)
                          Text(
                            "Approx: $durationStr • ${distanceKm!.round()} km",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        const SizedBox(height: 20),
                        if (_vehicles.isNotEmpty) ...[
                          _glassContainer(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: (_selectedVehicleId != null &&
                                        _vehicles.any((v) =>
                                            v['id'] == _selectedVehicleId))
                                    ? _selectedVehicleId
                                    : null,
                                hint: const Text("Select Vehicle",
                                    style: TextStyle(color: Colors.white54)),
                                dropdownColor: const Color(0xFF1E1E1E),
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down,
                                    color: Colors.white70),
                                style: const TextStyle(color: Colors.white),
                                items: _vehicles.map((v) {
                                  return DropdownMenuItem<String>(
                                    value: v['id'],
                                    child: Text(
                                        "${v['vehicleModel']} (${v['vehicleNumber']})"),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val == null) return;
                                  final v = _vehicles
                                      .firstWhere((e) => e['id'] == val);
                                  _selectVehicle(v);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
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
                          onPressed: _onNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white24,
                            disabledForegroundColor: Colors.white38,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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

  /* ---------------- WIDGETS ---------------- */

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: _glassContainer(
        padding: const EdgeInsets.all(24),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.rideId != null ? "Edit Ride" : "Offer a Ride",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Share your ride & earn.\nHelp others travel safely.",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(bool isRestricted) {
    return _glassContainer(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildLocationField(
            "Pickup Location",
            pickupController,
            Icons.my_location,
            true,
            pickupError,
            isRestricted,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              children: [
                Container(height: 20, width: 20),
                Expanded(child: Container(height: 1, color: Colors.white10)),
                RotationTransition(
                  turns: Tween(begin: 0.0, end: 0.5).animate(_swapController),
                  child: IconButton(
                    icon: Icon(Icons.swap_vert,
                        color: isRestricted ? Colors.white24 : Colors.white54,
                        size: 20),
                    onPressed: isRestricted ? null : _swapPickupDrop,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                Expanded(child: Container(height: 1, color: Colors.white10)),
                const SizedBox(width: 20, height: 20),
              ],
            ),
          ),
          _buildLocationField(
            "Drop Location",
            dropController,
            Icons.location_on,
            false,
            dropError,
            isRestricted,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField(String hint, TextEditingController controller,
      IconData icon, bool isPickup, bool hasError, bool isRestricted) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (_, child) => Transform.translate(
        offset: Offset(hasError ? _shakeAnimation.value : 0, 0),
        child: child,
      ),
      child: InkWell(
        onTap: isRestricted ? null : () => _openSearch(isPickup),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon,
                  color: hasError
                      ? Colors.redAccent
                      : (isRestricted ? Colors.white30 : Colors.white70),
                  size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hint.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.text.isEmpty
                          ? "Select Location"
                          : controller.text,
                      style: TextStyle(
                        color: controller.text.isEmpty
                            ? Colors.white24
                            : Colors.white,
                        fontSize: 16,
                        fontWeight: controller.text.isEmpty
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isRestricted)
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white12, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double borderRadius = 16,
    Color? color,
    Color? borderColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
