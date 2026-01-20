import '../providers/api_client.dart';
import '../application/users/model/project_grid_data.dart';

class ProjectApi {
  ProjectApi._();
  static final ProjectApi instance = ProjectApi._();

  Future<List<ProjectGridData>> getProjects() async {
    final res = await ApiClient.instance.dio.get('/projects');
    final data = res.data;

    if (data is List) {
      return data
          .map((e) => ProjectGridData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getProjectById(String id) async {
    final res = await ApiClient.instance.dio.get('/projects/$id');
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> createProject(Map<String, dynamic> payload) async {
    final res = await ApiClient.instance.dio.post('/projects', data: payload);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> updateProject(String id, Map<String, dynamic> payload) async {
    final res = await ApiClient.instance.dio.put('/projects/$id', data: payload);
    return Map<String, dynamic>.from(res.data);
  }
   Future<void> deleteProject(String id) async {
    await ApiClient.instance.dio.delete('/projects/$id');
  }
 // services/project_api.dart
Future<void> addComment(String projectId, String comment) async {
  await ApiClient.instance.dio.post(
    '/projects/$projectId/comments',
    data: {"body": comment},
  );
}


}
