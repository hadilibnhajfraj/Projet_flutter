import 'package:dio/dio.dart';
import 'package:dash_master_toolkit/application/services/api_client.dart';

class AdminUsersService {
  AdminUsersService._();
  static final AdminUsersService instance = AdminUsersService._();

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      final res = await ApiClient.instance.dio.get('/admin/users');

      if (res.data is List) {
        return (res.data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (status != null ? 'HTTP $status' : 'Erreur réseau (backend inaccessible)');

      throw Exception(msg);
    }
  }

  Future<void> setActive(String userId, bool active) async {
    try {
      await ApiClient.instance.dio.put(
        '/admin/users/$userId/active',
        data: {'active': active},
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (status != null ? 'HTTP $status' : 'Erreur réseau');

      throw Exception(msg);
    }
  }
}
