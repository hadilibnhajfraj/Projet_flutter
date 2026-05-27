// lib/services/pipeline_service.dart
import 'package:flutter/foundation.dart';
import 'package:dash_master_toolkit/providers/api_client.dart';

class PipelineService {
  static final PipelineService instance = PipelineService._();
  PipelineService._();

  // ── Kanban ─────────────────────────────────────────────────────────────────
  /// mine=false → ALL projects (tries /projects, then /pipeline/kanban)
  /// mine=true  → current user's projects only
  Future<List<Map<String, dynamic>>> fetchKanban({bool mine = false}) async {
    return mine ? _fetchMine() : _fetchAll();
  }

  Future<List<Map<String, dynamic>>> _fetchAll() async {
    // Try explicit "all projects" endpoints in priority order
    for (final cfg in [
      _E('/projects',           {'limit': '1000'}),
      _E('/pipeline/kanban',    {}),
      _E('/projects/all',       {'limit': '1000'}),
    ]) {
      try {
        final res = await ApiClient.instance.dio
            .get(cfg.path, queryParameters: cfg.params);
        final items = _parseItems(res.data);
        if (items.isNotEmpty) return items;
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchMine() async {
    for (final cfg in [
      _E('/pipeline/projects',   {'myProjects': 'true'}),
      _E('/projects',            {'myProjects': 'true', 'limit': '1000'}),
      _E('/pipeline/kanban',     {'myProjects': 'true', 'mine': 'true'}),
      _E('/projects/myprojects', {'limit': '1000'}),
    ]) {
      try {
        debugPrint('[Pipeline] _fetchMine → GET ${cfg.path} ${cfg.params}');
        final res = await ApiClient.instance.dio
            .get(cfg.path, queryParameters: cfg.params);
        final items = _parseItems(res.data);
        debugPrint('[Pipeline] _fetchMine ← ${items.length} projects');
        if (items.isNotEmpty) return items;
      } catch (e) {
        debugPrint('[Pipeline] _fetchMine endpoint ${cfg.path} failed: $e');
        continue;
      }
    }
    return [];
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  /// Newest-first; relance/rappel excluded.
  Future<List<Map<String, dynamic>>> fetchProjectActions(
      String projectId) async {
    final res =
        await ApiClient.instance.dio.get('/projects/$projectId/actions');
    // Unwrap envelope: bare list  OR  {data: [...]}  OR  {success:true, data:[...]}
    final raw = _unwrapList(res.data);
    final actions = _toList(raw)
      ..sort((a, b) {
        final da = DateTime.tryParse(a['dateAction'] ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['dateAction'] ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });
    return actions
        .where((a) {
          final t = (a['typeAction'] ?? '').toString().toLowerCase();
          return !t.contains('relance') && !t.contains('rappel');
        })
        .toList();
  }

  /// Post a stage-change action.
  Future<void> moveProject({
    required String projectId,
    required String newStage,
    String comment = 'Stage updated via pipeline',
  }) async {
    await ApiClient.instance.dio.post(
      '/projects/$projectId/actions',
      data: {'typeAction': newStage, 'commentaire': comment},
    );
  }

  // ── Stages ─────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchStages() async {
    try {
      final res = await ApiClient.instance.dio.get('/pipeline/stages');
      return _toList(res.data ?? []);
    } catch (_) {
      return [];
    }
  }

  Future<void> addStage({
    required String name,
    required String color,
    int order = 0,
  }) async {
    await ApiClient.instance.dio.post('/pipeline/stages',
        data: {'name': name, 'color': color, 'order': order});
  }

  Future<void> updateStage(String id,
      {String? name, String? color, int? order}) async {
    await ApiClient.instance.dio.put('/pipeline/stages/$id', data: {
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (order != null) 'order': order,
    });
  }

  Future<void> deleteStage(String id) async {
    await ApiClient.instance.dio.delete('/pipeline/stages/$id');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static const _kListKeys = [
    'items', 'data', 'projects', 'results', 'cards', 'docs',
  ];

  // Keys that identify a "stage row" in a grouped kanban response.
  static const _kStageProjectKeys = ['projects', 'cards', 'items', 'docs'];
  static const _kStageLabelKeys   = ['stage', 'name', 'id', 'stageId', 'stageName'];

  /// Extracts a flat project list from ANY API shape:
  ///   • bare list
  ///   • {data: [...]}
  ///   • {data: {projects: [...]}}
  ///   • stage-grouped: [{stage:"Visite", projects:[...]}, ...]  ← kanban format
  List<Map<String, dynamic>> _parseItems(dynamic data) {
    final raw = _toList(_unwrapList(data));
    if (raw.isEmpty) return raw;

    // Detect stage-grouped format: first item has a stage-label key AND a
    // nested list under a project key (e.g. {stage:"Visite", projects:[...]}).
    final first = raw.first;
    final hasStageLabel = _kStageLabelKeys.any(first.containsKey);
    final projectKey = _kStageProjectKeys
        .firstWhere((k) => first[k] is List, orElse: () => '');

    if (hasStageLabel && projectKey.isNotEmpty) {
      return _flattenStageGroups(raw, projectKey);
    }

    return raw;
  }

  /// Extracts projects from a [{stage, projects:[...]}, ...] structure.
  /// Stamps each project with the stage id so _resolveStageId can use it.
  List<Map<String, dynamic>> _flattenStageGroups(
      List<Map<String, dynamic>> stages, String projectKey) {
    final result = <Map<String, dynamic>>[];
    for (final stage in stages) {
      final stageId = _firstStr(stage, _kStageLabelKeys);
      final list = stage[projectKey];
      if (list is! List) continue;
      for (final raw in list) {
        if (raw is! Map) continue;
        final p = Map<String, dynamic>.from(raw);
        // Stamp computedStage only if the project doesn't already have one.
        p.putIfAbsent('computedStage', () => stageId);
        result.add(p);
      }
    }
    return result;
  }

  static String _firstStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  /// Extracts a raw List from an envelope (does NOT flatten stage groups).
  List _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in _kListKeys) {
        final val = data[key];
        if (val is List) return val;
        if (val is Map) {
          for (final k2 in _kListKeys) {
            final v2 = val[k2];
            if (v2 is List) return v2;
          }
        }
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _toList(List raw) => raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

// Simple endpoint config struct
class _E {
  final String path;
  final Map<String, String> params;
  const _E(this.path, this.params);
}
