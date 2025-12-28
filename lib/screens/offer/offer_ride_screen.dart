import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:rideshareApp/services/autocomplete_service.dart';
import 'package:rideshareApp/services/location_service.dart';
import 'package:rideshareApp/services/recent_location_service.dart';
import '../../repositories/ride_repository.dart';
import '../../repositories/user_repository.dart';

import 'ride_published_screen.dart';

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
  // focus
  final pickupFocus = FocusNode();
  final dropFocus = FocusNode();

  // controllers
  final pickupController = TextEditingController();
  final dropController = TextEditingController();
  // final carModelController = TextEditingController();
  // final carNumberController = TextEditingController();

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
  int seatsBooked = 0;

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

  // Initial values for change detection
  String? _initialPickup;
  String? _initialDrop;
  double? _initialPickupLat, _initialPickupLng;
  double? _initialDropLat, _initialDropLng;
  DateTime? _initialDate;
  TimeOfDay? _initialTime;
  int? _initialSeats;

  final RideRepository _rideRepo = FirebaseRideRepository();
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
    }
  }

  void _prefillData() {
    final data = widget.existingRideData!;
    pickupController.text = data['from'] ?? '';
    dropController.text = data['to'] ?? '';
    pickupLat = data['fromLat'];
    pickupLng = data['fromLng'];
    dropLat = data['toLat'];
    dropLng = data['toLng'];

    if (data['date'] != null) {
      try {
        selectedDate = DateFormat("yyyy-MM-dd").parse(data['date']);
      } catch (_) {}
    }

    if (data['time'] != null) {
      String t = data['time'];
      t = t.replaceAll('\u202F', ' ');
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
    seatsBooked = data['seatsBooked'] ?? 0;
    distanceKm = (data['distanceKm'] as num?)?.toDouble();
    durationStr = data['duration'];

    // Capture initial state
    _initialPickup = pickupController.text;
    _initialDrop = dropController.text;
    _initialPickupLat = pickupLat;
    _initialPickupLng = pickupLng;
    _initialDropLat = dropLat;
    _initialDropLng = dropLng;
    _initialDate = selectedDate;
    _initialTime = selectedTime;
    _initialSeats = seats;
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

    final recent = (await RecentLocationService.getRecent())
        .where((e) => e["type"] != "current")
        .toList();

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
      _pickupSuggestions.clear();
      _dropSuggestions.clear();

      distanceKm = null;
      durationStr = null;
    });

    _computeRoute();
  }

  bool get _hasChanges {
    if (widget.rideId == null) return true;

    if (pickupController.text != _initialPickup) return true;
    if (dropController.text != _initialDrop) return true;
    if (pickupLat != _initialPickupLat) return true;
    if (pickupLng != _initialPickupLng) return true;
    if (dropLat != _initialDropLat) return true;
    if (dropLng != _initialDropLng) return true;
    if (selectedDate != _initialDate) return true;
    if (selectedTime != _initialTime) return true;
    if (seats != _initialSeats) return true;

    return false;
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
      final user = _userRepo.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please login to publish a ride")),
        );
        return;
      }
      final uid = user.uid;

      final Map<String, dynamic> rideData = {
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
        "seatsBooked": seatsBooked,
        // "carModel": carModelController.text.trim(),
        // "carNumber": carNumberController.text.trim(),
      };

      if (widget.rideId != null) {
        rideData["updatedAt"] = DateTime.now()
            .toString(); // Repo handles server timestamp if needed
        await _rideRepo.publishRide(uid, rideData, rideId: widget.rideId);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  RidePublishedScreen(rideData: rideData, isUpdate: true)),
        );
      } else {
        rideData["seatsBooked"] = 0;
        rideData["status"] = "Upcoming";
        rideData["createdAt"] = DateTime.now().toString();

        await _rideRepo.publishRide(uid, rideData);
        await _userRepo.incrementUserStat(uid, 'ridesOffered', 1);

        if (!mounted) return;
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => RidePublishedScreen(rideData: rideData)));
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Please provide a reason. This will notify all booked passengers.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Reason (e.g. Car issue)",
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Back")),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, reasonController.text.trim());
            },
            child: const Text("Cancel Ride",
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (reason == null) return;

    setState(() => isPublishing = true);

    try {
      final user = _userRepo.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please login to continue")));
        return;
      }
      final uid = user.uid;

      await _rideRepo.cancelRide(uid, widget.rideId!, reason);
      await _userRepo.incrementUserStat(uid, 'ridesOffered', -1);
      await _userRepo.incrementUserStat(uid, 'ridesCancelled', 1);

      // Note: In a real app, we'd fetch the updated data from repo to pass to screen
      final data = widget.existingRideData ?? {};

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
                RidePublishedScreen(rideData: data, isCancellation: true)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isPublishing = false);
    }
  }

  /* ---------------- UI ---------------- */
  @override
  Widget build(BuildContext context) {
    final bool isRestricted = seatsBooked > 0;

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
                    if (isRestricted)
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
                            Icon(Icons.info_outline,
                                color: Colors.orangeAccent, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Some fields are locked because you have bookings.",
                                style: TextStyle(
                                    color: Colors.orangeAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _input(
                      "Pickup Location",
                      Icons.location_on,
                      pickupController,
                      isPickup: true,
                      enabled: !isRestricted,
                    ),
                    _suggestions(_pickupSuggestions, true),

                    const SizedBox(height: 6),
                    Center(
                      child: RotationTransition(
                        turns: Tween(begin: 0.0, end: 0.5)
                            .animate(_swapController),
                        child: IconButton(
                          icon: Icon(Icons.swap_vert,
                              color: isRestricted
                                  ? Colors.white24
                                  : Colors.white70,
                              size: 28),
                          onPressed: isRestricted ? null : _swapPickupDrop,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    _input(
                      "Drop Location",
                      Icons.flag,
                      dropController,
                      isDrop: true,
                      enabled: !isRestricted,
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
                      enabled: !isRestricted,
                    ),
                    const SizedBox(height: 15),

                    _picker(
                      "Select Time",
                      selectedTime == null
                          ? "Pick Time"
                          : selectedTime!.format(context),
                      Icons.access_time,
                      _pickTime,
                      enabled: !isRestricted,
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
                    // _input("Car Model (optional)",
                    //     Icons.directions_car, carModelController),
                    // const SizedBox(height: 15),
                    // _input("Car Number (optional)",
                    //     Icons.confirmation_number, carNumberController),
                    // const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: (isPublishing ||
                                (widget.rideId != null && !_hasChanges))
                            ? null
                            : publishRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white24,
                          disabledForegroundColor: Colors.white38,
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
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    if (widget.rideId != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: TextButton(
                          onPressed: isPublishing ? null : _cancelRide,
                          child: const Text(
                            "Cancel Ride",
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
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

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
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
    );
  }

  Widget _input(
    String hint,
    IconData icon,
    TextEditingController c, {
    bool isPickup = false,
    bool isDrop = false,
    bool enabled = true,
  }) {
    final hasError = isPickup
        ? pickupError
        : isDrop
            ? dropError
            : false;

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
              color: enabled
                  ? const Color(0xFF1E1E1E)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasError ? Colors.redAccent : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    color: hasError
                        ? Colors.redAccent
                        : (enabled ? Colors.white70 : Colors.white30)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    readOnly: !enabled,
                    controller: c,
                    focusNode: isPickup
                        ? pickupFocus
                        : isDrop
                            ? dropFocus
                            : null,
                    style: TextStyle(
                        color: enabled ? Colors.white : Colors.white54),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: hasError
                            ? Colors.redAccent.withOpacity(0.8)
                            : (enabled ? Colors.white38 : Colors.white24),
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
                if ((isPickup || isDrop) && enabled)
                  IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.white70),
                    onPressed: () async {
                      _lastEdited =
                          isPickup ? LastEdited.pickup : LastEdited.drop;

                      setState(() {
                        c.text = "Fetching current location…";
                        pickupError = false;
                        dropError = false;
                      });

                      final loc =
                          await _locationService.getCurrentLocationSuggestion();
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

  Widget _picker(String label, String value, IconData icon, VoidCallback tap,
      {bool enabled = true}) {
    return InkWell(
      onTap: enabled
          ? tap
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text("Cannot edit this field when seats are booked")),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF1E1E1E)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: enabled ? Colors.white70 : Colors.white30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: enabled ? Colors.white38 : Colors.white24,
                      fontSize: 15)),
            ),
            Text(value,
                style: TextStyle(
                    color: enabled ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _seatsCard() {
    final canDecrease = seats > 1 && seats > seatsBooked;

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
                icon: Icon(Icons.remove_circle_outline,
                    color: canDecrease ? Colors.white : Colors.white24),
                onPressed: () {
                  if (canDecrease) {
                    setState(() => seats--);
                  } else if (seats <= seatsBooked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text("Cannot reduce seats below booked count")),
                    );
                  }
                },
              ),
              Text("$seats",
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                onPressed: () => setState(() => seats++),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
