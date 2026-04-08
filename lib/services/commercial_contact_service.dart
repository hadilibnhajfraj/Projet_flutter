import 'dart:convert';
import 'package:http/http.dart' as http;
import '../application/users/model/commercial_contact_model.dart';

class CommercialContactService {
  static const String baseUrl = 'https://api.crmprobar.com/commercial-contacts';

Future<List<CommercialContact>> fetchMyContacts({
  required String token,
  String? query,
  String? userNom,
  String? typeClient,
}) async {
  final queryParams = <String, String>{};

  if (query != null && query.trim().isNotEmpty) {
    queryParams['q'] = query.trim();
  }

  if (userNom != null && userNom.isNotEmpty) {
    queryParams['user_nom'] = userNom;
  }

  if (typeClient != null && typeClient.isNotEmpty) {
    queryParams['typeClient'] = typeClient;
  }

  final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);

    return data
        .map((e) => CommercialContact.fromJson(e as Map<String, dynamic>))
        .toList();
  } else {
    throw Exception('Failed to load commercial contacts');
  }
}

  Future<CommercialContact> updateContact({
    required String token,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return CommercialContact.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(body['message']?.toString() ?? 'Update failed');
    }
  }

  Future<void> deleteContact({
    required String token,
    required String id,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(body['message']?.toString() ?? 'Delete failed');
    }
  }
}