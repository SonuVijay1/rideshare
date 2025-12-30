import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'offer_ride_options_screen.dart';
import '../../utils/custom_route.dart';

class OfferRideMapScreen extends StatefulWidget {
  final Map<String, dynamic>? existingRideData;
  final String? rideId;

  // Data passed from previous steps
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
  final double existingPrice;
  final String existingBookingMode;

  const OfferRideMapScreen({
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
  State<OfferRideMapScreen> createState() => _OfferRideMapScreenState();
}

class _OfferRideMapScreenState extends State<OfferRideMapScreen> {
  List<LatLng> _routePoints = [];
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    if (widget.routeGeometry != null) {
      _routePoints = _decodePolyline(widget.routeGeometry!);
    }
  }

  // Decodes Google Polyline Algorithm string
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final bounds = LatLngBounds.fromPoints([
      LatLng(widget.fromLat, widget.fromLng),
      LatLng(widget.toLat, widget.toLng),
      ..._routePoints,
    ]);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Map Background
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.only(
                    top: 100, // Clear the top header
                    bottom: 300, // Clear the bottom info card & button
                    left: 40,
                    right: 40,
                  ),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  // CartoDB Dark Matter for dark theme consistency
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.rideshare.app',
                  retinaMode: RetinaMode.isHighDensity(context),
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.fromLat, widget.fromLng),
                      width: 30,
                      height: 30,
                      child: const Icon(Icons.my_location,
                          color: Colors.greenAccent, size: 30),
                    ),
                    Marker(
                      point: LatLng(widget.toLat, widget.toLng),
                      width: 30,
                      height: 30,
                      child: const Icon(Icons.location_on,
                          color: Colors.redAccent, size: 30),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Gradient Overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Route Preview",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 20, bottom: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      child: const Icon(Icons.center_focus_strong),
                      onPressed: () {
                        _mapController.fitCamera(
                          CameraFit.bounds(
                            bounds: bounds,
                            padding: const EdgeInsets.only(
                              top: 100,
                              bottom: 300,
                              left: 40,
                              right: 40,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _glassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _infoItem(Icons.directions_car,
                                "${widget.distanceKm.round()} km"),
                            Container(
                                width: 1, height: 20, color: Colors.white24),
                            _infoItem(Icons.timer, widget.durationStr),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              CustomPageRoute(
                                child: OfferRideOptionsScreen(
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
                                  selectedDate: widget.selectedDate,
                                  selectedTime: widget.selectedTime,
                                  seatsAvailable: widget.seatsAvailable,
                                  existingPrice: widget.existingPrice,
                                  existingBookingMode:
                                      widget.existingBookingMode,
                                ),
                              ),
                            );
                          },
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

  Widget _infoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
