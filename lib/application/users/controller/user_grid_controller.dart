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

    // ✅ Recherche instantanée à chaque frappe
    searchController.addListener(() {
      searchProject(searchController.text);
    });

    loadProjects();
  }

  Future<void> loadProjects() async {
    loading.value = true;
    try {
      final list = await ProjectApi.instance.getProjects();
      projects.assignAll(list);
      filtered.assignAll(list);
    } catch (_) {
      projects.clear();
      filtered.clear();
    } finally {
      loading.value = false;
    }
  }

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

        return nom.contains(q) || ent.contains(q) || st.contains(q) || adr.contains(q);
      }).toList(),
    );
  }

  void upsertProject(ProjectGridData p) {
    final idx = projects.indexWhere((x) => x.id == p.id);
    if (idx == -1) {
      projects.insert(0, p);
    } else {
      projects[idx] = p;
    }

    // ✅ Réappliquer le filtre actuel instantanément
    searchProject(searchController.text);
  }

  Future<void> deleteProject(String id) async {
    loading.value = true;
    try {
      await ProjectApi.instance.deleteProject(id);
      projects.removeWhere((p) => p.id == id);
      filtered.removeWhere((p) => p.id == id);
    } finally {
      loading.value = false;
    }
  }

  Future<void> addComment(String projectId, String comment) async {
    await ProjectApi.instance.addComment(projectId, comment);
  }

  @override
  void onClose() {
    searchController.dispose();
    f1.dispose();
    super.onClose();
  }
}
