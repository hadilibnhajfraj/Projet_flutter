import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/project_api.dart';
import '../model/project_grid_data.dart';

class UserGridController extends GetxController {
  static UserGridController get to => Get.find<UserGridController>();

  TextEditingController searchController = TextEditingController();
  FocusNode f1 = FocusNode();

  RxList<ProjectGridData> projects = <ProjectGridData>[].obs;
  RxList<ProjectGridData> filtered = <ProjectGridData>[].obs;
  RxBool loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProjects();
  }

  Future<void> loadProjects() async {
    loading.value = true;
    try {
      final list = await ProjectApi.instance.getProjects();
      projects.value = list;
      filtered.value = List.from(list);
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
      filtered.value = List.from(projects);
      return;
    }

    filtered.value = projects.where((p) {
      return p.nomProjet.toLowerCase().contains(q) ||
          p.entreprise.toLowerCase().contains(q) ||
          p.statut.toLowerCase().contains(q) ||
          p.adresse.toLowerCase().contains(q);
    }).toList();
  }

  // ✅ Update instantané (sans re-fetch)
  void upsertProject(ProjectGridData p) {
    final idx = projects.indexWhere((x) => x.id == p.id);
    if (idx == -1) {
      projects.insert(0, p);
    } else {
      projects[idx] = p;
    }

    // ✅ garder le filtre actuel (si l'utilisateur a tapé dans search)
    final q = searchController.text.trim();
    if (q.isEmpty) {
      filtered.value = List.from(projects);
    } else {
      searchProject(q);
    }
  }

  Future<void> deleteProject(String id) async {
    loading.value = true;
    try {
      await ProjectApi.instance.deleteProject(id);

      projects.removeWhere((p) => p.id == id);
      filtered.removeWhere((p) => p.id == id);
    } catch (e) {
      rethrow; // ✅ important pour afficher l’erreur dans UI
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    f1.dispose();
    super.onClose();
  }
}
