// lib/forms/providers/pipeline_provider.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:dash_master_toolkit/services/pipeline_service.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

class PipelineProvider extends GetxController {
  static PipelineProvider get to => Get.find<PipelineProvider>();

  final _service = PipelineService.instance;
  final _box     = GetStorage();

  // ── Observables ────────────────────────────────────────────────────────────
  final RxBool    loading     = true.obs;
  /// true = show only current user's projects (server + client filtered)
  /// false = show ALL projects (no filter)
  final RxBool    myOnly      = false.obs;
  final RxString  search      = ''.obs;
  final RxnString filterStage = RxnString();

  final RxList<PipelineStage> stages =
      <PipelineStage>[...kDefaultPipelineStages].obs;

  final RxMap<String, List<Map<String, dynamic>>> grouped =
      <String, List<Map<String, dynamic>>>{}.obs;

  // KPI counters
  final RxInt total  = 0.obs;
  final RxInt won    = 0.obs;
  final RxInt lost   = 0.obs;
  final RxInt active = 0.obs;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _initGrouped();
    load(); // myOnly=false → fetches ALL projects
  }

  void _initGrouped() {
    grouped.value = {for (final s in stages) s.id: <Map<String, dynamic>>[]};
  }

  // ── Filtered view ──────────────────────────────────────────────────────────
  /// Search and stage-dropdown filters are always client-side.
  /// Mine filter is handled server-side (re-fetch) + client-side guard.
  Map<String, List<Map<String, dynamic>>> get filtered {
    final q  = search.value.toLowerCase().trim();
    final sf = filterStage.value;

    // No active client-side filters → return raw grouped data
    if (q.isEmpty && sf == null) return Map.from(grouped);

    final result = <String, List<Map<String, dynamic>>>{};
    for (final s in stages) {
      if (sf != null && sf != s.id) {
        result[s.id] = [];
        continue;
      }
      result[s.id] = (grouped[s.id] ?? []).where((p) {
        if (q.isNotEmpty) {
          final nom = (p['nomProjet']  ?? '').toString().toLowerCase();
          final cie = (p['entreprise'] ?? '').toString().toLowerCase();
          if (!nom.contains(q) && !cie.contains(q)) return false;
        }
        return true;
      }).toList();
    }
    return result;
  }

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> load({bool silent = false}) async {
    if (!silent) loading.value = true;
    try {
      // Service handles mine=false (all) vs mine=true (user's only)
      final projects = await _service.fetchKanban(mine: myOnly.value);

      final stageIds = stages.map((s) => s.id).toList();
      final map = <String, List<Map<String, dynamic>>>{
        for (final id in stageIds) id: [],
      };

      // Fetch actions in parallel — don't block the board on slow endpoints
      final enriched = await Future.wait(
        projects.map((raw) => _enrichProject(Map<String, dynamic>.from(raw))),
      );

      for (final project in enriched) {
        final stageId = _resolveStageId(project, stageIds);
        project['computedStage'] = stageId;
        (map[stageId] ?? map[stageIds.first])!.add(project);
      }

      grouped.value = map;
      _recalcKpi();
    } catch (e) {
      debugPrint('PipelineProvider.load error: $e');
    } finally {
      loading.value = false;
    }
  }

  // ── Stage resolver (statut field + lastAction.typeAction) ─────────────────
  /// Priority: lastAction.typeAction → project.statut → first stage
  String _resolveStageId(Map<String, dynamic> project, List<String> validIds) {
    // 1. Last non-relance action type (most up-to-date)
    final lastType =
        (project['lastAction'] as Map?)?['typeAction']?.toString() ?? '';
    if (lastType.isNotEmpty) {
      final fromAction = normalizeStage(lastType);
      if (validIds.contains(fromAction)) return fromAction;
    }

    // 2. Project's statut field
    final statut = (project['statut'] ?? '').toString().trim();
    if (statut.isNotEmpty) {
      // Direct match first
      if (validIds.contains(statut)) return statut;
      final fromStatut = normalizeStage(statut);
      if (validIds.contains(fromStatut)) return fromStatut;
    }

    // 3. Default to first stage
    return validIds.isNotEmpty ? validIds.first : kDefaultPipelineStages.first.id;
  }

  // ── Enrich project with its actions ───────────────────────────────────────
  Future<Map<String, dynamic>> _enrichProject(
      Map<String, dynamic> project) async {
    final id = (project['id'] ?? '').toString();
    if (id.isEmpty) {
      project['lastAction'] = null;
      project['allActions'] = <Map<String, dynamic>>[];
      return project;
    }
    try {
      final actions = await _service.fetchProjectActions(id);
      project['lastAction'] = actions.isNotEmpty ? actions.first : null;
      project['allActions'] = actions;
    } catch (_) {
      project['lastAction'] = null;
      project['allActions'] = <Map<String, dynamic>>[];
    }
    return project;
  }

  // ── Move project between stages ────────────────────────────────────────────
  Future<bool> moveProject(
      Map<String, dynamic> project, String newStageId) async {
    final oldStageId =
        (project['computedStage'] as String?) ?? stages.first.id;
    if (oldStageId == newStageId) return false;

    // Optimistic update
    grouped[oldStageId]?.removeWhere((p) => p['id'] == project['id']);
    project['computedStage'] = newStageId;
    (grouped[newStageId] ??= []).add(project);
    _recalcKpi();
    grouped.refresh();

    try {
      await _service.moveProject(
          projectId: project['id'].toString(), newStage: newStageId);
      return true;
    } catch (_) {
      // Rollback
      grouped[newStageId]?.removeWhere((p) => p['id'] == project['id']);
      project['computedStage'] = oldStageId;
      (grouped[oldStageId] ??= []).add(project);
      _recalcKpi();
      grouped.refresh();
      return false;
    }
  }

  // ── Stage CRUD ─────────────────────────────────────────────────────────────
  Future<void> addStage({
    required String id,
    required String label,
    required Color color,
  }) async {
    final stage = PipelineStage(
      id: id,
      label: label,
      color: color,
      icon: Icons.folder_special_rounded,
      order: stages.length,
      isSystem: false,
    );
    stages.add(stage);
    grouped[stage.id] = [];
    try {
      await _service.addStage(
        name: id,
        color: '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
        order: stage.order,
      );
    } catch (_) {
      stages.removeLast();
      grouped.remove(stage.id);
    }
  }

  Future<void> renameStage(String stageId, String newLabel) async {
    final idx = stages.indexWhere((s) => s.id == stageId);
    if (idx < 0) return;
    stages[idx] = stages[idx].copyWith(label: newLabel);
    stages.refresh();
    try {
      await _service.updateStage(stageId, name: newLabel);
    } catch (_) {}
  }

  Future<void> recolorStage(String stageId, Color color) async {
    final idx = stages.indexWhere((s) => s.id == stageId);
    if (idx < 0) return;
    stages[idx] = stages[idx].copyWith(color: color);
    stages.refresh();
    grouped.refresh();
    try {
      await _service.updateStage(stageId,
          color: '#${color.value.toRadixString(16).substring(2).toUpperCase()}');
    } catch (_) {}
  }

  Future<void> removeStage(String stageId) async {
    final stage = stages.firstWhereOrNull((s) => s.id == stageId);
    if (stage == null || stage.isSystem) return;

    final displaced =
        List<Map<String, dynamic>>.from(grouped[stageId] ?? []);
    stages.removeWhere((s) => s.id == stageId);
    grouped.remove(stageId);

    if (stages.isNotEmpty && displaced.isNotEmpty) {
      final firstId = stages.first.id;
      for (final p in displaced) p['computedStage'] = firstId;
      (grouped[firstId] ??= []).addAll(displaced);
    }
    _recalcKpi();
    grouped.refresh();
    try {
      await _service.deleteStage(stageId);
    } catch (_) {}
  }

  // ── Filter helpers ─────────────────────────────────────────────────────────
  /// Toggle "My Projects": re-fetches from server with mine param.
  void toggleMyOnly() {
    myOnly.toggle();
    load(silent: true);
  }

  void setSearch(String q) => search.value = q;
  void setFilterStage(String? s) => filterStage.value = s;

  void clearFilters() {
    search.value = '';
    filterStage.value = null;
    if (myOnly.value) {
      myOnly.value = false;
      load(silent: true);
    }
  }

  bool get hasActiveFilters =>
      search.value.isNotEmpty ||
      filterStage.value != null ||
      myOnly.value;

  // ── KPI ────────────────────────────────────────────────────────────────────
  void _recalcKpi() {
    final all = grouped.values.expand((l) => l).toList();
    total.value  = all.length;
    won.value    = (grouped['Commande gagnée'] ?? []).length;
    lost.value   = (grouped['Commande perdue'] ?? []).length;
    active.value = total.value - won.value - lost.value;
  }

  double get convRate =>
      total.value > 0 ? won.value / total.value * 100 : 0.0;
}
