import 'package:get/get.dart';
import '../../providers/api_client.dart';

/// ==============================
/// REMINDER MODEL
/// ==============================
class ReminderModel {

  final String id;
  final String dateRelance;
  final String? message;

  ReminderModel({
    required this.id,
    required this.dateRelance,
    this.message,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {

    return ReminderModel(
      id: json["id"] ?? "",
      dateRelance: json["dateRelance"] ?? "",
      message: json["message"],
    );
  }
}

/// ==============================
/// ACTION MODEL
/// ==============================
class ProjectActionModel {

  final String id;
  final String typeAction;
  final String? commentaire;
  final String dateAction;
  final List<ReminderModel> reminders;

  /// ✅ NEW
  final String? fileUrl;

  ProjectActionModel({
    required this.id,
    required this.typeAction,
    this.commentaire,
    required this.dateAction,
    required this.reminders,
    this.fileUrl, // ✅ NEW
  });

  factory ProjectActionModel.fromJson(Map<String, dynamic> json) {

    final remindersJson = json["reminders"] ?? [];

    return ProjectActionModel(

      id: json["id"],

      typeAction: json["typeAction"] ?? "",

      commentaire: json["commentaire"],

      dateAction: json["dateAction"] ?? json["createdAt"],

      reminders: List<ReminderModel>.from(
        remindersJson.map((r) => ReminderModel.fromJson(r)),
      ),

      /// ✅ NEW (TRÈS IMPORTANT)
      fileUrl: json["fileUrl"],
    );
  }
}

/// ==============================
/// CONTROLLER
/// ==============================
class ProjectTimelineController extends GetxController {

  final actions = <ProjectActionModel>[].obs;
  final loading = false.obs;

  Future loadActions(String projectId) async {

    loading.value = true;

    try {

      final res = await ApiClient.instance.dio.get(
        "/projects/$projectId/actions",
      );

      final data = res.data as List;

      actions.value =
          data.map((e) => ProjectActionModel.fromJson(e)).toList();

    } catch (e) {

      actions.clear();

    } finally {

      loading.value = false;

    }
  }
}