import 'dart:ui';
import 'package:flutter/material.dart';
import 'offer_ride_options_screen.dart';

class OfferRideMapScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    String pathParam = "";
    if (routeGeometry != null) {
      // Check length to prevent URL overflow (LocationIQ limit ~8192 chars)
      // If route is too long (e.g. > 500km), geometry string might exceed limit.
      // We fallback to markers only if geometry is too large to ensure map loads.
      if (routeGeometry!.length < 7500) {
        pathParam =
            "&path=weight:5|color:0x3b82f6|enc:${Uri.encodeComponent(routeGeometry!)}";
      }
    }

    // LocationIQ Static Map URL
    final mapUrl =
        "https://maps.locationiq.com/v3/staticmap?key=pk.b47010d748ec9c1e2ee4fb9dce51f322&markers=icon:large-green-cutout|$fromLat,$fromLng&markers=icon:large-red-cutout|$toLat,$toLng$pathParam&size=600x800";

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Map Background
          Positioned.fill(
            child: Image.network(
              mapUrl,
              fit: BoxFit.cover,
              loadingBuilder: (ctx, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              },
              errorBuilder: (ctx, error, stackTrace) => Container(
                color: const Color(0xFF1A1F25),
                child: const Center(
                    child: Icon(Icons.map_outlined,
                        color: Colors.white24, size: 64)),
              ),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _glassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _infoItem(Icons.directions_car,
                                "${distanceKm.round()} km"),
                            Container(
                                width: 1, height: 20, color: Colors.white24),
                            _infoItem(Icons.timer, durationStr),
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
                              MaterialPageRoute(
                                builder: (_) => OfferRideOptionsScreen(
                                  existingRideData: existingRideData,
                                  rideId: rideId,
                                  from: from,
                                  to: to,
                                  fromLat: fromLat,
                                  fromLng: fromLng,
                                  toLat: toLat,
                                  toLng: toLng,
                                  distanceKm: distanceKm,
                                  durationStr: durationStr,
                                  routeGeometry: routeGeometry,
                                  vehicleModel: vehicleModel,
                                  vehicleNumber: vehicleNumber,
                                  vehicleColor: vehicleColor,
                                  vehicleType: vehicleType,
                                  seatsBooked: seatsBooked,
                                  selectedDate: selectedDate,
                                  selectedTime: selectedTime,
                                  seatsAvailable: seatsAvailable,
                                  existingPrice: existingPrice,
                                  existingBookingMode: existingBookingMode,
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
