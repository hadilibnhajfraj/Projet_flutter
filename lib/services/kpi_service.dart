import 'package:dio/dio.dart'; // ✅ AJOUT
import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
import '../tables/model/project_map_item.dart';

class KpiService {
  static Future<List<ProjectMapItem>> fetchMapProjects() async {
    final token = AuthService().accessToken;

    final res = await ApiClient.instance.dio.get(
      "/projects/kpi/map-projects",
      options: token == null || token.isEmpty
          ? null
          : Options(headers: {"Authorization": "Bearer $token"}),
    );

    final data = res.data;

    if (data is List) {
      return data
          .map((e) => ProjectMapItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (data is Map && data["items"] is List) {
      final list = data["items"] as List;
      return list
          .map((e) => ProjectMapItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    throw Exception("Format API invalide: ${data.runtimeType}");
  }
}
