import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/project_api.dart';
import '../model/project_grid_data.dart';

class UserGridController extends GetxController {

  static UserGridController get to => Get.find<UserGridController>();

  final TextEditingController searchController = TextEditingController();
  final FocusNode f1 = FocusNode();

  final RxList<ProjectGridData> projects = <ProjectGridData>[].obs;
  final RxList<ProjectGridData> filtered = <ProjectGridData>[].obs;

  final RxBool loading = false.obs;

  @override
  void onInit() {
    super.onInit();

    /// 🔎 instant search
    searchController.addListener(() {
      searchProject(searchController.text);
    });

    loadProjects();
  }

  /// LOAD PROJECTS
  Future<void> loadProjects() async {

    loading.value = true;

    try {

      final list = await ProjectApi.instance.getProjects();

      projects.assignAll(list);
      filtered.assignAll(list);

    } catch (e) {

      debugPrint("loadProjects error: $e");

      projects.clear();
      filtered.clear();

    } finally {

      loading.value = false;

    }
  }

  /// SEARCH PROJECT
  void searchProject(String query) {

    final q = query.trim().toLowerCase();

    if (q.isEmpty) {

      filtered.assignAll(projects);
      return;

    }

    filtered.assignAll(

      projects.where((p) {

        final nom = (p.nomProjet ?? "").toLowerCase();
        final ent = (p.entreprise ?? "").toLowerCase();
        final st = (p.statut ?? "").toLowerCase();
        final adr = (p.adresse ?? "").toLowerCase();
        final engineer = (p.ingenieurResponsable ?? "").toLowerCase();
        final architect = (p.architecte ?? "").toLowerCase();

        return nom.contains(q) ||
            ent.contains(q) ||
            st.contains(q) ||
            adr.contains(q) ||
            engineer.contains(q) ||
            architect.contains(q);

      }).toList(),

    );

  }

  /// INSERT OR UPDATE PROJECT
  void upsertProject(ProjectGridData p) {

    final idx = projects.indexWhere((x) => x.id == p.id);

    if (idx == -1) {

      projects.insert(0, p);

    } else {

      projects[idx] = p;

    }

    /// reapply filter
    searchProject(searchController.text);
  }

  /// DELETE PROJECT
  Future<void> deleteProject(String id) async {

    loading.value = true;

    try {

      await ProjectApi.instance.deleteProject(id);

      projects.removeWhere((p) => p.id == id);
      filtered.removeWhere((p) => p.id == id);

    } catch (e) {

      debugPrint("deleteProject error: $e");

    } finally {

      loading.value = false;

    }
  }

  /// ADD COMMENT
  Future<void> addComment(String projectId, String comment) async {

    try {

      await ProjectApi.instance.addComment(projectId, comment);

      /// 🔄 refresh project counts
      await refreshProjectById(projectId);

    } catch (e) {

      debugPrint("addComment error: $e");

    }

  }

  /// REFRESH SINGLE PROJECT
  Future<void> refreshProjectById(String id) async {

    try {

      final fresh = await ProjectApi.instance.getProjectById(id);

      upsertProject(fresh);

      forceRefresh();

    } catch (e) {

      debugPrint("refreshProjectById error: $e");

    }

  }

  /// REFRESH UI
  void forceRefresh() {

    projects.refresh();
    filtered.refresh();

    update();

  }

  /// AFTER UPDATE PROJECT
  Future<void> afterProjectUpdate(String id) async {

    await refreshProjectById(id);

  }

  @override
  void onClose() {

    searchController.dispose();
    f1.dispose();

    super.onClose();

  }
}