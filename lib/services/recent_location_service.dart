import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentLocationService {
  static const _key = "recent_locations";
  static const int _max = 5;

  static Future<List<Map<String, dynamic>>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];

    return raw
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }

  static Future<void> add(Map<String, dynamic> location) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];

    raw.removeWhere((e) {
      final m = jsonDecode(e);
      return m["lat"] == location["lat"] &&
          m["lng"] == location["lng"];
    });

    raw.insert(0, jsonEncode(location));

    if (raw.length > _max) {
      raw.removeLast();
    }

    await prefs.setStringList(_key, raw);
  }
}
