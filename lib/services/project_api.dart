import 'dart:convert';
import 'package:http/http.dart' as http;

class ProjectApi {
  final String baseUrl;
  final Future<String?> Function() getToken;

  ProjectApi({
    required this.baseUrl,
    required this.getToken,
  });

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    final token = await getToken();

    final uri = Uri.parse("$baseUrl/projects");
    final res = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );

    final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (body as Map).cast<String, dynamic>();
    }

    final msg = (body is Map && body["message"] != null) ? body["message"].toString() : "Erreur API";
    throw Exception("$msg (code ${res.statusCode})");
  }
}
