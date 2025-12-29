import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/autocomplete_service.dart';
import '../../services/location_service.dart';
import '../../screens/avlbl/available_rides_screen.dart';
import '../../utils/geo_utils.dart';
import '../../repositories/ride_repository.dart';

class BookRideScreen extends StatefulWidget {
  const BookRideScreen({super.key});

  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

enum LastEdited { from, to }

class _BookRideScreenState extends State<BookRideScreen>
    with SingleTickerProviderStateMixin {
  // controllers
  final fromController = TextEditingController();
  final toController = TextEditingController();
  final dateController = TextEditingController();
  final seatsController = TextEditingController(text: "1");

  // focus
  final fromFocus = FocusNode();
  final toFocus = FocusNode();

  // error flags
  bool fromError = false;
  bool toError = false;

  // last edited
  LastEdited? _lastEdited;

  // services
  final AutocompleteService _autocompleteService = AutocompleteService();
  final LocationService _locationService = LocationService();

  // coords
  double? fromLat, fromLng, toLat, toLng;

  // route
  double? distanceKm;
  String? durationStr;
  bool isFetchingRoute = false;
  bool isSearching = false;

  // suggestions
  List<Map<String, dynamic>> _fromSuggestions = [];
  List<Map<String, dynamic>> _toSuggestions = [];

  // animation
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  final RideRepository _rideRepo = FirebaseRideRepository();

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
  }

  @override
  void dispose() {
    _shakeController.dispose();
    fromFocus.dispose();
    toFocus.dispose();
    super.dispose();
  }

  /* ---------------- DATE ---------------- */
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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

    if (picked != null) {
      dateController.text = DateFormat("yyyy-MM-dd").format(picked);
    }
  }

  /* ---------------- AUTOCOMPLETE ---------------- */
  Future<void> _onLocationChanged(String value, bool isFrom) async {
    _lastEdited = isFrom ? LastEdited.from : LastEdited.to;

    if (value.trim().length < 3) {
      setState(() {
        isFrom ? _fromSuggestions = [] : _toSuggestions = [];
      });
      return;
    }

    final res = await _autocompleteService.getSuggestions(value.trim());
    setState(() {
      isFrom ? _fromSuggestions = res : _toSuggestions = res;
    });
  }

  Future<void> _onSuggestionSelected(
      Map<String, dynamic> s, bool isFrom) async {
    _lastEdited = isFrom ? LastEdited.from : LastEdited.to;

    setState(() {
      if (isFrom) {
        fromController.text = s["title"];
        fromLat = s["lat"];
        fromLng = s["lng"];
        _fromSuggestions = [];
      } else {
        toController.text = s["title"];
        toLat = s["lat"];
        toLng = s["lng"];
        _toSuggestions = [];
      }
    });

    await _computeRoute();
  }

  /* ---------------- ROUTE ---------------- */
  Future<void> _computeRoute() async {
    if (fromLat == null || toLat == null) return;

    // 🚫 same pickup & drop
    if (fromLat == toLat && fromLng == toLng) {
      setState(() {
        distanceKm = null;
        durationStr = null;
        isFetchingRoute = false;

        fromError = false;
        toError = false;

        if (_lastEdited == LastEdited.from) {
          fromError = true;
          fromController.clear();
          fromLat = null;
          fromLng = null;
          FocusScope.of(context).requestFocus(fromFocus);
        } else {
          toError = true;
          toController.clear();
          toLat = null;
          toLng = null;
          FocusScope.of(context).requestFocus(toFocus);
        }
      });

      _shakeController.forward(from: 0);
      return;
    }

    setState(() => isFetchingRoute = true);

    final route = await _locationService.getRouteDetails(
      fromLat!,
      fromLng!,
      toLat!,
      toLng!,
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

  /* ---------------- SEARCH ---------------- */
  Future<void> _searchRides() async {
    if (fromLat == null || toLat == null) return;

    setState(() => isSearching = true);

    try {
      // The repo now handles the query.
      // Note: The repo implementation provided earlier returns raw data.
      // We still need the filtering logic here or move it to repo.
      // For this refactor, I'll fetch via repo and filter here to keep logic intact.
      final rides =
          await _rideRepo.searchRides(fromLat!, fromLng!, toLat!, toLng!, 1);

      final matchedRides = <Map<String, dynamic>>[];

      for (final ride in rides) {
        // Filter by time: show only rides >= (now - 1 hour)
        try {
          final dateStr = ride['date'] as String?;
          final timeStr = ride['time'] as String?;

          if (dateStr != null && timeStr != null) {
            final date = DateFormat("yyyy-MM-dd").parse(dateStr);
            DateTime rideDt = DateTime(date.year, date.month, date.day);

            final cleanTime = timeStr.replaceAll('\u202F', ' ');
            DateTime t;
            try {
              t = DateFormat("h:mm a").parse(cleanTime);
            } catch (_) {
              t = DateFormat("HH:mm").parse(cleanTime);
            }
            rideDt = rideDt.add(Duration(hours: t.hour, minutes: t.minute));

            if (rideDt
                .isBefore(DateTime.now().subtract(const Duration(hours: 1)))) {
              continue;
            }
          }
        } catch (_) {}

        final double? rFromLat = (ride["fromLat"] as num?)?.toDouble();
        final double? rFromLng = (ride["fromLng"] as num?)?.toDouble();
        final double? rToLat = (ride["toLat"] as num?)?.toDouble();
        final double? rToLng = (ride["toLng"] as num?)?.toDouble();

        if (rFromLat == null ||
            rFromLng == null ||
            rToLat == null ||
            rToLng == null) continue;

        final pickupDist =
            calculateDistanceKm(fromLat!, fromLng!, rFromLat, rFromLng);
        final dropDist = calculateDistanceKm(toLat!, toLng!, rToLat, rToLng);

        final userBearing =
            calculateBearing(fromLat!, fromLng!, toLat!, toLng!);
        final rideBearing =
            calculateBearing(rFromLat, rFromLng, rToLat, rToLng);

        final diff = (userBearing - rideBearing).abs();
        final normDiff = diff > 180 ? 360 - diff : diff;

        if (pickupDist <= 30 && dropDist <= 30 && normDiff <= 45) {
          matchedRides.add(ride);
        }
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AvailableRidesScreen(
            rides: matchedRides,
            requiredSeats: int.tryParse(seatsController.text) ?? 1,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isSearching = false);
    }
  }

  /* ---------------- INPUT CARD ---------------- */
  Widget _inputCard({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool enableAutocomplete = false,
    bool isFrom = false,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final hasError = enableAutocomplete && (isFrom ? fromError : toError);

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
                Icon(icon, color: hasError ? Colors.redAccent : Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: enableAutocomplete
                        ? (isFrom ? fromFocus : toFocus)
                        : null,
                    readOnly: readOnly,
                    onTap: onTap,
                    onChanged: enableAutocomplete
                        ? (v) {
                            fromError = false;
                            toError = false;
                            _onLocationChanged(v, isFrom);
                          }
                        : null,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (enableAutocomplete)
                  IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.white70),
                    onPressed: () async {
                      _lastEdited = isFrom ? LastEdited.from : LastEdited.to;

                      controller.text = "Fetching current location…";
                      fromError = false;
                      toError = false;

                      final loc =
                          await _locationService.getCurrentLocationSuggestion();
                      if (loc == null) {
                        controller.clear();
                        return;
                      }

                      setState(() {
                        controller.text = loc["title"];
                        if (isFrom) {
                          fromLat = loc["lat"];
                          fromLng = loc["lng"];
                          _fromSuggestions = [];
                        } else {
                          toLat = loc["lat"];
                          toLng = loc["lng"];
                          _toSuggestions = [];
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
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _suggestions(List<Map<String, dynamic>> list, bool isFrom) {
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      children: list.map((e) {
        return GestureDetector(
          onTap: () => _onSuggestionSelected(e, isFrom),
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.place, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e["title"] ?? "",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        e["subtitle"] ?? "",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _swapLocations() {
    if (fromLat == null || toLat == null) return;

    setState(() {
      // swap text
      final tempText = fromController.text;
      fromController.text = toController.text;
      toController.text = tempText;

      // swap coords
      final tempLat = fromLat;
      final tempLng = fromLng;
      fromLat = toLat;
      fromLng = toLng;
      toLat = tempLat;
      toLng = tempLng;

      // reset errors
      fromError = false;
      toError = false;

      // clear suggestions
      _fromSuggestions.clear();
      _toSuggestions.clear();
    });

    _computeRoute();
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
                    _inputCard(
                      hint: "Pickup location",
                      icon: Icons.location_on,
                      controller: fromController,
                      enableAutocomplete: true,
                      isFrom: true,
                    ),
                    _suggestions(_fromSuggestions, true),
                    const SizedBox(height: 6),
                    Center(
                      child: IconButton(
                        icon: const Icon(Icons.swap_vert,
                            color: Colors.white70, size: 28),
                        onPressed: _swapLocations,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _inputCard(
                      hint: "Drop location",
                      icon: Icons.flag,
                      controller: toController,
                      enableAutocomplete: true,
                    ),
                    _suggestions(_toSuggestions, false),
                    const SizedBox(height: 15),
                    _inputCard(
                      hint: "Select date",
                      icon: Icons.calendar_today,
                      controller: dateController,
                      readOnly: true,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 15),
                    _inputCard(
                      hint: "Seats required",
                      icon: Icons.chair_alt,
                      controller: seatsController,
                    ),
                    const SizedBox(height: 10),
                    if (isFetchingRoute)
                      const CircularProgressIndicator(color: Colors.white)
                    else if (distanceKm != null)
                      Text(
                        "Approx: $durationStr • ${distanceKm!.round()} km",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isSearching ? null : _searchRides,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isSearching
                            ? const CircularProgressIndicator(
                                color: Colors.black)
                            : const Text(
                                "Search Rides",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
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
              "Book a Ride",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Find nearby rides easily",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
}
