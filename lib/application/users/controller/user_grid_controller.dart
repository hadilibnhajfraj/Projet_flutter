import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/project_api.dart';
import '../model/project_grid_data.dart';

class UserGridController extends GetxController {
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

  @override
  void onClose() {
    searchController.dispose();
    f1.dispose();
    super.onClose();
  }
}
