import 'package:dio/dio.dart';
import 'package:dash_master_toolkit/app_shell_route/models/notification.dart';

class NotificationApi {
  NotificationApi._();
  static final instance = NotificationApi._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://localhost:4000", // 🔁 remplace par ton IP serveur
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<NotificationResponse> getMyNotifications(String token) async {
    final res = await _dio.get(
      "/notifications",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
    return NotificationResponse.fromJson(res.data);
  }

  Future<void> markAllRead(String token) async {
    await _dio.put(
      "/notifications/mark-all-read",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
  }

  Future<void> markRead(String token, String id) async {
    await _dio.put(
      "/notifications/$id/read",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
  }
}
