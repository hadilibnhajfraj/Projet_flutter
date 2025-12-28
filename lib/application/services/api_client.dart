import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // Android emulator => 10.0.2.2
  // iOS simulator => localhost
  // device réel => IP de ton PC
  static const String baseUrl = 'http://10.0.2.2:4000';

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...(headers ?? {}),
      },
      body: jsonEncode(body ?? {}),
    );

    final data = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data as Map<String, dynamic>);
    }

    final msg = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : 'HTTP ${res.statusCode}';
    throw Exception(msg);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.get(uri, headers: headers);

    final data = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data as Map<String, dynamic>);
    }

    final msg = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : 'HTTP ${res.statusCode}';
    throw Exception(msg);
  }
}
