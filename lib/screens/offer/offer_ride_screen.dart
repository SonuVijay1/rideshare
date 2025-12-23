import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:rideshareApp/services/autocomplete_service.dart';
import 'package:rideshareApp/services/location_service.dart';
import 'package:rideshareApp/services/recent_location_service.dart';

enum LastEdited { pickup, drop }

class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen>
    with TickerProviderStateMixin {
  // focus
  final pickupFocus = FocusNode();
  final dropFocus = FocusNode();

  // controllers
  final pickupController = TextEditingController();
  final dropController = TextEditingController();
  final carModelController = TextEditingController();
  final carNumberController = TextEditingController();

  // errors
  bool pickupError = false;
  bool dropError = false;

  // last edited
  LastEdited? _lastEdited;

  // services
  final AutocompleteService _autocompleteService = AutocompleteService();
  final LocationService _locationService = LocationService();

  // date & time
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  // seats
  int seats = 1;

  // coords
  double? pickupLat, pickupLng, dropLat, dropLng;

  // route
  double? distanceKm;
  String? durationStr;
  bool isFetchingRoute = false;
  bool isPublishing = false;

  // suggestions
  List<Map<String, dynamic>> _pickupSuggestions = [];
  List<Map<String, dynamic>> _dropSuggestions = [];

  // animations
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  late final AnimationController _swapController;

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
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _swapController.dispose();
    pickupFocus.dispose();
    dropFocus.dispose();
    super.dispose();
  }

  /* ---------------- DATE ---------------- */
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

  /* ---------------- TIME ---------------- */
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

  /* ---------------- AUTOCOMPLETE ---------------- */
  Future<void> _onLocationChanged(String v, bool isPickup) async {
    _lastEdited = isPickup ? LastEdited.pickup : LastEdited.drop;

    final recent = await RecentLocationService.getRecent();

    if (v.trim().isEmpty) {
      setState(() {
        isPickup
            ? _pickupSuggestions = [...recent]
            : _dropSuggestions = [...recent];
      });
      return;
    }

    final api = await _autocompleteService.getSuggestions(v.trim());
    setState(() {
      isPickup ? _pickupSuggestions = api : _dropSuggestions = api;
    });
  }

  Future<void> _onSuggestionSelected(
    Map<String, dynamic> s,
    bool isPickup,
  ) async {
    _lastEdited = isPickup ? LastEdited.pickup : LastEdited.drop;
    await RecentLocationService.add(s);

    setState(() {
      if (isPickup) {
        pickupController.text = s["title"];
        pickupLat = s["lat"];
        pickupLng = s["lng"];
        _pickupSuggestions = [];
      } else {
        dropController.text = s["title"];
        dropLat = s["lat"];
        dropLng = s["lng"];
        _dropSuggestions = [];
      }
    });

    await _computeRoute();
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
          FocusScope.of(context).requestFocus(pickupFocus);
        } else {
          dropError = true;
          dropController.clear();
          dropLat = null;
          dropLng = null;
          FocusScope.of(context).requestFocus(dropFocus);
        }

        distanceKm = null;
        durationStr = null;
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
      }
      isFetchingRoute = false;
    });
  }

  /* ---------------- SWAP ---------------- */
  void _swapPickupDrop() {
    if (pickupController.text.isEmpty &&
        dropController.text.isEmpty) return;

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
      _pickupSuggestions.clear();
      _dropSuggestions.clear();

      distanceKm = null;
      durationStr = null;
    });

    _computeRoute();
  }

  /* ---------------- FIRESTORE ---------------- */
  Future<void> publishRide() async {
    if (pickupController.text.isEmpty ||
        dropController.text.isEmpty ||
        selectedDate == null ||
        selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all required fields")),
      );
      return;
    }

    setState(() => isPublishing = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? "demoUser";

      final doc = FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("driverTrips")
          .doc();

      await doc.set({
        "from": pickupController.text.trim(),
        "fromLat": pickupLat,
        "fromLng": pickupLng,
        "to": dropController.text.trim(),
        "toLat": dropLat,
        "toLng": dropLng,
        "date": DateFormat("yyyy-MM-dd").format(selectedDate!),
        "time": selectedTime!.format(context),
        "distanceKm": distanceKm ?? 0,
        "duration": durationStr ?? "",
        "seatsAvailable": seats,
        "seatsBooked": 0,
        "carModel": carModelController.text.trim(),
        "carNumber": carNumberController.text.trim(),
        "status": "Upcoming",
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ride published successfully")),
      );
    } finally {
      if (mounted) setState(() => isPublishing = false);
    }
  }

  /* ---------------- UI ---------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _input(
                      "Pickup Location",
                      Icons.location_on,
                      pickupController,
                      isPickup: true,
                    ),
                    _suggestions(_pickupSuggestions, true),

                    const SizedBox(height: 6),
                    Center(
                      child: RotationTransition(
                        turns:
                            Tween(begin: 0.0, end: 0.5).animate(_swapController),
                        child: IconButton(
                          icon: const Icon(Icons.swap_vert,
                              color: Colors.white70, size: 28),
                          onPressed: _swapPickupDrop,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    _input(
                      "Drop Location",
                      Icons.flag,
                      dropController,
                      isDrop: true,
                    ),
                    _suggestions(_dropSuggestions, false),
                    const SizedBox(height: 15),

                    _picker(
                      "Select Date",
                      selectedDate == null
                          ? "Pick Date"
                          : DateFormat("dd MMM yyyy").format(selectedDate!),
                      Icons.calendar_today,
                      _pickDate,
                    ),
                    const SizedBox(height: 15),

                    _picker(
                      "Select Time",
                      selectedTime == null
                          ? "Pick Time"
                          : selectedTime!.format(context),
                      Icons.access_time,
                      _pickTime,
                    ),
                    const SizedBox(height: 15),

                    _seatsCard(),
                    const SizedBox(height: 10),

                    if (isFetchingRoute)
                      const CircularProgressIndicator(color: Colors.white)
                    else if (distanceKm != null)
                      Text(
                        "Approx: $durationStr • ${distanceKm!.round()} km",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),

                    const SizedBox(height: 20),
                    _input("Car Model (optional)",
                        Icons.directions_car, carModelController),
                    const SizedBox(height: 15),
                    _input("Car Number (optional)",
                        Icons.confirmation_number, carNumberController),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isPublishing ? null : publishRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isPublishing
                            ? const CircularProgressIndicator(
                                color: Colors.black)
                            : const Text(
                                "Publish Ride",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ---------------- WIDGETS ---------------- */

  Widget _header() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Offer a Ride",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Share your ride & earn.\nHelp others travel safely.",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );

  Widget _input(
    String hint,
    IconData icon,
    TextEditingController c, {
    bool isPickup = false,
    bool isDrop = false,
  }) {
    final hasError = isPickup ? pickupError : isDrop ? dropError : false;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (_, child) => Transform.translate(
        offset: Offset(hasError ? _shakeAnimation.value : 0, 0),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasError ? Colors.redAccent : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    color: hasError ? Colors.redAccent : Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: c,
                    focusNode: isPickup
                        ? pickupFocus
                        : isDrop
                            ? dropFocus
                            : null,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: hasError
                            ? Colors.redAccent.withOpacity(0.8)
                            : Colors.white38,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) {
                      if (hasError) {
                        setState(() {
                          pickupError = false;
                          dropError = false;
                        });
                      }
                      _onLocationChanged(v, isPickup);
                    },
                  ),
                ),
                if (isPickup || isDrop)
                  IconButton(
                    icon:
                        const Icon(Icons.my_location, color: Colors.white70),
                    onPressed: () async {
                      _lastEdited =
                          isPickup ? LastEdited.pickup : LastEdited.drop;

                      setState(() {
                        c.text = "Fetching current location…";
                        pickupError = false;
                        dropError = false;
                      });

                      final loc = await _locationService
                          .getCurrentLocationSuggestion();
                      if (loc == null) {
                        setState(() => c.clear());
                        return;
                      }

                      setState(() {
                        c.text = loc["title"];
                        if (isPickup) {
                          pickupLat = loc["lat"];
                          pickupLng = loc["lng"];
                          _pickupSuggestions = [];
                        } else {
                          dropLat = loc["lat"];
                          dropLng = loc["lng"];
                          _dropSuggestions = [];
                        }
                      });

                      await _computeRoute();
                    },
                  ),
              ],
            ),
          ),
          if (hasError)
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 6),
              child: Text(
                "Pickup and drop locations must be different",
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _suggestions(List<Map<String, dynamic>> list, bool isPickup) {
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      children: list.map((e) {
        IconData icon = Icons.place;
        if (e["type"] == "current") icon = Icons.my_location;
        if (e["type"] == "recent") icon = Icons.history;

        return ListTile(
          leading: Icon(icon, color: Colors.white70),
          title: Text(
            e["title"] ?? "",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: e["subtitle"] != null
              ? Text(
                  e["subtitle"],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                )
              : null,
          onTap: () => _onSuggestionSelected(e, isPickup),
        );
      }).toList(),
    );
  }

  Widget _picker(
      String label, String value, IconData icon, VoidCallback tap) {
    return InkWell(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 15)),
            ),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _seatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Available Seats",
              style: TextStyle(color: Colors.white70)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.white),
                onPressed: () {
                  if (seats > 1) setState(() => seats--);
                },
              ),
              Text("$seats",
                  style:
                      const TextStyle(color: Colors.white, fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: Colors.white),
                onPressed: () => setState(() => seats++),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
