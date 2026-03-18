import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dash_master_toolkit/application/users/model/user_project_model.dart';

class UserProjectService {
  final String baseUrl;

  UserProjectService({required this.baseUrl});

  Future<UserProjectsResponse> fetchMyProjects({
    required String token,
    String? architecte,
    String? promoteur,
    String? ingenieur,
    String? createdBy,
    String? societe,
    String? q,
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if ((architecte ?? '').trim().isNotEmpty) {
      queryParams['architecte'] = architecte!.trim();
    }
    if ((promoteur ?? '').trim().isNotEmpty) {
      queryParams['promoteur'] = promoteur!.trim();
    }
    if ((ingenieur ?? '').trim().isNotEmpty) {
      queryParams['ingenieur'] = ingenieur!.trim();
    }
    if ((societe ?? '').trim().isNotEmpty) {
      queryParams['societe'] = societe!.trim();
    }
    if ((q ?? '').trim().isNotEmpty) {
      queryParams['q'] = q!.trim();
    }
    if (createdBy != null && createdBy.isNotEmpty) {
  queryParams['createdBy'] = createdBy;
}

    final uri = Uri.parse('$baseUrl/projects/my-projects')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    return UserProjectsResponse.fromJson(Map<String, dynamic>.from(decoded));
  }
}