import 'dart:convert';
import 'package:http/http.dart' as http;

class AutocompleteService {
  final String locationIqKey = "pk.b47010d748ec9c1e2ee4fb9dce51f322";

  Future<List<Map<String, dynamic>>> getSuggestions(String query) async {
    if (query.trim().isEmpty) return [];

    final url =
        "https://api.locationiq.com/v1/autocomplete"
        "?key=$locationIqKey"
        "&q=$query"
        "&limit=6"
        "&normalizeaddress=1";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) return [];

    final List data = jsonDecode(response.body);

    return data.map<Map<String, dynamic>>((item) {
      final displayName = item["display_name"] ?? "";

      // Split main place name vs rest of address
      final parts = displayName.split(",");
      final title = parts.isNotEmpty ? parts.first.trim() : displayName;
      final subtitle =
          parts.length > 1 ? parts.sublist(1).join(",").trim() : "";

      return {
        "title": title,                 // ✅ REQUIRED
        "subtitle": subtitle,           // ✅ REQUIRED
        "lat": double.tryParse(item["lat"] ?? "0") ?? 0,
        "lng": double.tryParse(item["lon"] ?? "0") ?? 0,
      };
    }).toList();
  }
}
