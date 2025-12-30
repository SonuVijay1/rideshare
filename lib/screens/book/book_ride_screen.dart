import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

import '../../services/location_service.dart';
import '../../screens/avlbl/available_rides_screen.dart';
import '../../utils/geo_utils.dart';
import '../../repositories/ride_repository.dart';
import 'location_search_screen.dart';

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
  DateTime? selectedDate;
  int seats = 1;

  // error flags
  bool fromError = false;
  bool toError = false;

  final LocationService _locationService = LocationService();

  // coords
  double? fromLat, fromLng, toLat, toLng;

  // route
  double? distanceKm;
  String? durationStr;
  bool isFetchingRoute = false;
  bool isSearching = false;

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
    super.dispose();
  }

  /* ---------------- DATE ---------------- */
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
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

    if (picked != null) {
      _setDate(picked);
    }
  }

  void _setDate(DateTime date) {
    setState(() {
      selectedDate = date;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final checkDate = DateTime(date.year, date.month, date.day);

      if (checkDate == today) {
        dateController.text = "Today";
      } else if (checkDate == tomorrow) {
        dateController.text = "Tomorrow";
      } else {
        final day = date.day;
        String suffix = 'th';
        if (day >= 11 && day <= 13) {
          suffix = 'th';
        } else {
          switch (day % 10) {
            case 1:
              suffix = 'st';
              break;
            case 2:
              suffix = 'nd';
              break;
            case 3:
              suffix = 'rd';
              break;
            default:
              suffix = 'th';
          }
        }
        dateController.text =
            "$day$suffix ${DateFormat("MMM yyyy").format(date)}";
      }
    });
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

        // Just shake the whole card, don't clear inputs immediately
        // to let user see why it failed
        fromError = true;
        toError = true;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Pickup and drop cannot be the same")));
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
            requiredSeats: seats,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isSearching = false);
    }
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
    });

    _computeRoute();
  }

  Future<void> _openSearch(bool isFrom) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSearchScreen(
          hintText: isFrom ? "Where from?" : "Where to?",
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        if (isFrom) {
          fromController.text = result['title'];
          fromLat = result['lat'];
          fromLng = result['lng'];
        } else {
          toController.text = result['title'];
          toLat = result['lat'];
          toLng = result['lng'];
        }
      });
      _computeRoute();
    }
  }

  /* ---------------- UI ---------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false, // Prevents background from jumping
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Background Gradient
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
                        _buildLocationCard(),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _buildDateSelector()),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSeatSelector()),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (isFetchingRoute)
                          const CircularProgressIndicator(color: Colors.white)
                        else if (distanceKm != null)
                          _glassContainer(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_car,
                                    color: Colors.white70, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Approx: $durationStr • ${distanceKm!.round()} km",
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isSearching ? null : _searchRides,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white24,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSearching
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              "Search Rides",
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

  Widget _header() => Padding(
        padding: const EdgeInsets.all(20.0),
        child: _glassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    "Book a Ride",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.map_outlined, color: Colors.white30, size: 32),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Find nearby rides easily.\nTravel comfortably.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildLocationCard() {
    return _glassContainer(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildLocationField(
            "From",
            fromController,
            Icons.my_location,
            true,
            fromError,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              children: [
                Container(
                  height: 20,
                  width: 20,
                ),
                // Dashed line or solid line connector
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.white10,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_vert,
                      color: Colors.white54, size: 20),
                  onPressed: _swapLocations,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.white10,
                  ),
                ),
                const SizedBox(
                  width: 20,
                  height: 20,
                ),
              ],
            ),
          ),
          _buildLocationField(
            "To",
            toController,
            Icons.location_on,
            false,
            toError,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField(String hint, TextEditingController controller,
      IconData icon, bool isFrom, bool hasError) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (_, child) => Transform.translate(
        offset: Offset(hasError ? _shakeAnimation.value : 0, 0),
        child: child,
      ),
      child: InkWell(
        onTap: () => _openSearch(isFrom),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon,
                  color: hasError ? Colors.redAccent : Colors.white70,
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
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white12, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final hasDate = dateController.text.isNotEmpty;
    return GestureDetector(
      onTap: _pickDate,
      child: _glassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Date",
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasDate ? dateController.text : "Select",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatSelector() {
    return _glassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Passengers",
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  if (seats > 1) setState(() => seats--);
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.remove, color: Colors.white70, size: 20),
                ),
              ),
              Text("$seats",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              InkWell(
                onTap: () {
                  if (seats < 8) setState(() => seats++);
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.add, color: Colors.white70, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double borderRadius = 16,
  }) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
