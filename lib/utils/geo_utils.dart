import 'dart:math';

double calculateDistanceKm(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371; // km

  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) *
          cos(_degToRad(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _degToRad(double deg) {
  return deg * (pi / 180);
}

double calculateBearing(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  final phi1 = lat1 * (3.141592653589793 / 180);
  final phi2 = lat2 * (3.141592653589793 / 180);
  final deltaLon = (lon2 - lon1) * (3.141592653589793 / 180);

  final y = sin(deltaLon) * cos(phi2);
  final x = cos(phi1) * sin(phi2) -
      sin(phi1) * cos(phi2) * cos(deltaLon);

  final bearing = atan2(y, x);
  return (bearing * 180 / 3.141592653589793 + 360) % 360;
}

