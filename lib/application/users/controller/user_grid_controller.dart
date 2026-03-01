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

// Search for projects via the frontend filtering
  void searchProject(String query) {
    final q = query.trim().toLowerCase();  // Convert query to lowercase

    if (q.isEmpty) {
      filtered.assignAll(projects);  // If query is empty, show all projects
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

        // Search across multiple fields (nomProjet, entreprise, statut, adresse, etc.)
        return nom.contains(q) ||
            ent.contains(q) ||
            st.contains(q) ||
            adr.contains(q) ||
            engineer.contains(q) ||
            architect.contains(q);
      }).toList(),
    );
  }

  // Add or update a project in the list
  void upsertProject(ProjectGridData p) {
    final idx = projects.indexWhere((x) => x.id == p.id);
    if (idx == -1) {
      projects.insert(0, p);  // Insert at the top if it's a new project
    } else {
      projects[idx] = p;  // Update existing project
    }

    // Reapply the filter immediately after inserting/updating a project
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
  Future<void> refreshProjectById(String id) async {
  try {
    final fresh = await ProjectApi.instance.getProjectById(id);
    upsertProject(fresh);
    forceRefresh();
  } catch (_) {
    // ignore
  }
}
  void forceRefresh() {
    projects.refresh();
    filtered.refresh();
    update();
  }
  @override
  void onClose() {
    searchController.dispose();
    f1.dispose();
    super.onClose();
  }
}
