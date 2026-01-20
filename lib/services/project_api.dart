// lib/application/services/project_api.dart

import 'package:dio/dio.dart';
import 'package:dash_master_toolkit/application/services/api_client.dart';
import 'package:dash_master_toolkit/application/users/model/project_grid_data.dart';
import 'package:dash_master_toolkit/application/users/model/project_comment_model.dart';

class ProjectApi {
  ProjectApi._();
  static final instance = ProjectApi._();

  Dio get dio => ApiClient.instance.dio;

  Future<List<ProjectGridData>> getProjects() async {
    final res = await dio.get('/projects');
    final data = res.data;

    if (data is List) {
      return data
          .map((e) => ProjectGridData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<void> deleteProject(String id) async {
    await dio.delete('/projects/$id');
  }

  // ✅ ajouter commentaire / réponse
  Future<void> addComment(String projectId, String body,
      {String? parentId}) async {
    await dio.post(
      '/projects/$projectId/comments',
      data: {
        "body": body,
        if (parentId != null && parentId.isNotEmpty) "parentId": parentId,
      },
    );
  }

  // ✅ modifier commentaire
  Future<void> updateComment(String projectId, String commentId, String body) async {
    await dio.put(
      '/projects/$projectId/comments/$commentId',
      data: {"body": body},
    );
  }

  // ✅ supprimer commentaire
  Future<void> deleteComment(String projectId, String commentId) async {
    await dio.delete('/projects/$projectId/comments/$commentId');
  }

  Future<List<ProjectCommentModel>> getComments(String projectId) async {
    final res = await dio.get('/projects/$projectId/comments');
    final data = res.data;

    if (data is List) {
      return data
          .map((e) => ProjectCommentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}
