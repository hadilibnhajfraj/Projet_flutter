// lib/services/pipeline_service.dart
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
      _E('/pipeline/kanban',     {'mine': 'true'}),
      _E('/projects/myprojects', {'limit': '1000'}),
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

  // ── Actions ────────────────────────────────────────────────────────────────
  /// Newest-first; relance/rappel excluded.
  Future<List<Map<String, dynamic>>> fetchProjectActions(
      String projectId) async {
    final res =
        await ApiClient.instance.dio.get('/projects/$projectId/actions');
    final List raw = res.data ?? [];
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
  List<Map<String, dynamic>> _parseItems(dynamic data) {
    if (data == null) return [];
    if (data is List) return _toList(data);
    if (data is Map) {
      for (final key in ['items', 'data', 'projects', 'results']) {
        if (data.containsKey(key) && data[key] is List) {
          return _toList(data[key] as List);
        }
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _toList(List raw) =>
      raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// Simple endpoint config struct
class _E {
  final String path;
  final Map<String, String> params;
  const _E(this.path, this.params);
}
