import '../../../providers/api_client.dart';
import 'package:dash_master_toolkit/application/users/model/project_action.dart';

class ProjectActionApi {

  static final ProjectActionApi instance = ProjectActionApi();

  Future<List<ProjectAction>> getActions(String projectId) async {

    final res = await ApiClient.instance.dio
        .get("/projects/$projectId/actions");

    final data = List.from(res.data);

    return data.map((e)=>ProjectAction.fromJson(e)).toList();

  }

  Future<void> createAction({

    required String projectId,
    required String type,
    String? commentaire,
    String? dateRelance

  }) async {

    await ApiClient.instance.dio.post(

      "/projects/$projectId/actions",

      data:{

        "typeAction":type,
        "commentaire":commentaire,
        "dateRelance":dateRelance

      }

    );

  }

}