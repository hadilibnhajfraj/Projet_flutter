import 'package:dio/dio.dart';
import '../providers/api_client.dart';

class TaskApi {
  TaskApi._();
  static final instance = TaskApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<List<Map<String, dynamic>>> listTasks() async {
    final res = await _dio.get("/tasks");
    final data = res.data;
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  Future<Map<String, dynamic>> createTask({
    required String title,
    required DateTime startAt,
    String? description,
    DateTime? endAt,
  }) async {
    final res = await _dio.post("/tasks", data: {
      "title": title,
      "description": description,
      "startAt": startAt.toIso8601String(),
      "endAt": endAt?.toIso8601String(),
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> updateTask({
    required String id,
    String? title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    String? status,
  }) async {
    final res = await _dio.put("/tasks/$id", data: {
      if (title != null) "title": title,
      if (description != null) "description": description,
      if (startAt != null) "startAt": startAt.toIso8601String(),
      if (endAt != null) "endAt": endAt.toIso8601String(),
      if (status != null) "status": status,
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> deleteTask({required String id}) async {
    await _dio.delete("/tasks/$id");
  }
}