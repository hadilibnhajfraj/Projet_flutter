import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

class AddressSuggestion {
  final String displayName;
  final double lat;
  final double lon;

  AddressSuggestion({
    required this.displayName,
    required this.lat,
    required this.lon,
  });
}

class AddressService {
  static const String _apiBaseWeb = "http://localhost:4000";
  static const String _apiBaseAndroidEmu = "http://10.0.2.2:4000";
  static const String _apiBaseOther = "http://localhost:4000";

  static String get apiBase {
    if (kIsWeb) return _apiBaseWeb;
    if (defaultTargetPlatform == TargetPlatform.android) return _apiBaseAndroidEmu;
    return _apiBaseOther;
  }

  static Future<List<AddressSuggestion>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return [];

    final uri = Uri.parse("$apiBase/utils/geocode").replace(queryParameters: {"q": q});

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];

      final decoded = utf8.decode(res.bodyBytes);
      final data = jsonDecode(decoded);
      if (data is! List) return [];

      final out = <AddressSuggestion>[];
      for (final j in data) {
        final name = (j["displayName"] ?? "").toString().trim();
        final lat = (j["lat"] is num) ? (j["lat"] as num).toDouble() : double.tryParse("${j["lat"]}");
        final lon = (j["lon"] is num) ? (j["lon"] as num).toDouble() : double.tryParse("${j["lon"]}");

        if (name.isEmpty || lat == null || lon == null) continue;

        out.add(AddressSuggestion(displayName: name, lat: lat, lon: lon));
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}
