import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dash_master_toolkit/application/users/model/commercial_action_model.dart';
class CommercialActionService {

  final String baseUrl = "http://localhost:4000";

  Future<List<CommercialAction>> getActions({
    required String token,
    required String contactId,
  }) async {

    final res = await http.get(
      Uri.parse("$baseUrl/commercial-contacts/$contactId/actions"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load actions");
    }

    return CommercialAction.listFromJson(res.body);
  }
}