import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dash_master_toolkit/core/config/api_config.dart';
import '../application/users/model/commercial_contact_model.dart';
import '../application/users/model/commercial_analytics_model.dart';

class CommercialContactService {
  static String get baseUrl => '${ApiConfig.baseUrl}/commercial-contacts';

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

  debugPrint('API URL = $uri');

  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  debugPrint('STATUS = ${response.statusCode}');
  debugPrint('BODY = ${response.body.length > 600 ? "${response.body.substring(0, 600)}..." : response.body}');

  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);

    // Détection automatique du format de réponse :
    //  - tableau direct        : [...]
    //  - objet paginé          : {"items":[...]} / {"data":[...]} / {"contacts":[...]} / {"results":[...]}
    List<dynamic> items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map) {
      final raw = decoded['items'] ?? decoded['data'] ?? decoded['contacts'] ?? decoded['results'];
      items = raw is List ? raw : [];
    } else {
      items = [];
    }

    debugPrint('Contacts count = ${items.length}');

    return items
        .map((e) => CommercialContact.fromJson(e as Map<String, dynamic>))
        .toList();
  } else {
    throw Exception('Failed to load commercial contacts (${response.statusCode})');
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
  Future<List<String>> getUserNames(String token) async {
  final response = await http.get(
    Uri.parse('$baseUrl/user-names/list'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<String>.from(data);
  } else {
    throw Exception('Failed to load user names');
  }
}

  // GET /commercial-contacts/analytics
  // Retourne des agrégats pré-calculés côté serveur.
  // Si le backend ne dispose pas encore de cet endpoint, utilise fetchMyContacts()
  // et construit la réponse côté client via CommercialAnalyticsModel.fromContacts().
  Future<CommercialAnalyticsModel> fetchAnalytics(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/analytics'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return CommercialAnalyticsModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    // Fallback : construit les analytics depuis la liste complète des contacts
    final contacts = await fetchMyContacts(token: token);
    return CommercialAnalyticsModel.fromContacts(contacts);
  }
}