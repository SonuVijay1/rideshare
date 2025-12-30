import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class LocationService {
  final String openCageKey = "f7f4fe2e62e9480caff5882960ab697f";
  final String orsKey =
      "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjBmODliMmE0MGFhNjQ1ZDc5Mjg0ZmU5ZTUxNWEyZjFiIiwiaCI6Im11cm11cjY0In0=";

  /* ---------------- CURRENT POSITION ---------------- */
  Future<Position?> getCurrentPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  /* ---------------- REVERSE GEOCODING ---------------- */
  Future<Map<String, dynamic>?> reverseGeocode(double lat, double lng) async {
    final url =
        "https://api.opencagedata.com/geocode/v1/json?q=$lat+$lng&key=$openCageKey";

    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    if (data["results"] == null || data["results"].isEmpty) return null;

    final result = data["results"][0];
    return {
      "title": result["formatted"],
      "subtitle": result["components"]["state"] ?? "",
    };
  }

  /* ---------------- CURRENT LOCATION (UI READY) ---------------- */
  Future<Map<String, dynamic>?> getCurrentLocationSuggestion() async {
    final pos = await getCurrentPosition();
    if (pos == null) return null;

    final address = await reverseGeocode(pos.latitude, pos.longitude);

    return {
      "type": "current",
      "title": address?["title"] ?? "Current location",
      "subtitle": address?["subtitle"] ?? "Using GPS",
      "lat": pos.latitude,
      "lng": pos.longitude,
    };
  }

  /* ---------------- ROUTE ---------------- */
  Future<Map<String, dynamic>?> getRouteDetails(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    final url = "https://api.openrouteservice.org/v2/directions/driving-car";

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": orsKey,
      },
      body: jsonEncode({
        "coordinates": [
          [startLng, startLat],
          [endLng, endLat],
        ]
      }),
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    if (data["routes"] == null || data["routes"].isEmpty) return null;

    final summary = data["routes"][0]["summary"];
    return {
      "distanceKm": (summary["distance"] as num).toDouble() / 1000,
      "duration": _formatDuration(
        (summary["duration"] as num).toDouble(),
      ),
      "geometry": data["routes"][0]["geometry"],
    };
  }

  String _formatDuration(double seconds) {
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).round();
    if (h > 0 && m > 0) return "${h}h ${m}m";
    if (h > 0) return "${h}h";
    return "${m}m";
  }
}
