// lib/forms/production_fiche_approval/fiche_approval_service.dart
//
// Client HTTP de la validation des fiches de production. Les droits
// (responsable logistique seul décideur, créateurs limités à leurs fiches)
// sont vérifiés par le backend ; l'interface ne fait que les refléter.

import 'package:dio/dio.dart' show DioException;

import 'package:dash_master_toolkit/providers/api_client.dart';

import 'fiche_approval_record.dart';

/// Contrat utilisé par les écrans (remplaçable dans les tests).
abstract class FicheApprovalApi {
  Future<FicheApprovalPermissions> permissions();
  /// Compteurs ; avec [filters], mêmes fiches que la liste (statut ignoré).
  Future<FicheApprovalCounts> summary([FicheApprovalFilters? filters]);
  /// Fiches selon les filtres (statut, période, producteur, type, machine, poste).
  Future<List<FicheApprovalItem>> list(FicheApprovalFilters filters);
  Future<FicheApprovalItem> detail(String ficheType, String id);
  /// Décision sur la soumission et le contenu affichés (version, updatedAt).
  Future<FicheApprovalItem> approve(FicheApprovalItem item);
  Future<FicheApprovalItem> reject(FicheApprovalItem item, {required String comment});
  Future<FicheApprovalItem> resubmit(String ficheType, String id, {String? comment});
}

class FicheApprovalService implements FicheApprovalApi {
  static final FicheApprovalService instance = FicheApprovalService._();
  FicheApprovalService._();

  static const _base = '/production-fiche-approvals';

  Map<String, dynamic> _data(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  @override
  Future<FicheApprovalPermissions> permissions() async =>
      FicheApprovalPermissions.fromJson(_data((await ApiClient.instance.dio.get('$_base/permissions')).data));

  @override
  Future<FicheApprovalCounts> summary([FicheApprovalFilters? filters]) async {
    final d = _data((await ApiClient.instance.dio.get('$_base/summary', queryParameters: filters?.toSummaryQuery())).data);
    int n(String k) => (d[k] as num?)?.toInt() ?? 0;
    return (pending: n('pending'), approved: n('approved'), rejected: n('rejected'), processed: n('processed'));
  }

  @override
  Future<List<FicheApprovalItem>> list(FicheApprovalFilters filters) async {
    final res = await ApiClient.instance.dio.get(_base, queryParameters: {...filters.toQuery(), 'pageSize': 500});
    final body = res.data is Map ? res.data as Map : const {};
    return [
      for (final r in (body['data'] as List? ?? const []))
        if (r is Map) FicheApprovalItem.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  @override
  Future<FicheApprovalItem> detail(String ficheType, String id) async =>
      FicheApprovalItem.fromJson(_data((await ApiClient.instance.dio.get('$_base/$ficheType/$id')).data));

  Map<String, dynamic> _decision(FicheApprovalItem item, [String? comment]) => {
        'version': item.version,
        if (item.updatedAtRaw != null) 'ficheUpdatedAt': item.updatedAtRaw,
        if (comment != null) 'comment': comment.trim(),
      };

  @override
  Future<FicheApprovalItem> approve(FicheApprovalItem item) async => FicheApprovalItem.fromJson(_data(
      (await ApiClient.instance.dio.post('$_base/${item.ficheType}/${item.id}/approve', data: _decision(item))).data));

  @override
  Future<FicheApprovalItem> reject(FicheApprovalItem item, {required String comment}) async =>
      FicheApprovalItem.fromJson(_data((await ApiClient.instance.dio
              .post('$_base/${item.ficheType}/${item.id}/reject', data: _decision(item, comment)))
          .data));

  @override
  Future<FicheApprovalItem> resubmit(String ficheType, String id, {String? comment}) async =>
      FicheApprovalItem.fromJson(_data((await ApiClient.instance.dio
              .post('$_base/$ficheType/$id/resubmit', data: {if (comment != null) 'comment': comment.trim()}))
          .data));

  /// Message lisible d'une erreur API (message du backend en priorité).
  static String friendlyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final m = data is Map ? data['message']?.toString() : null;
      if (m != null && m.isNotEmpty) return m;
      if (e.response == null) return 'Serveur injoignable. Vérifiez votre connexion puis réessayez.';
      return 'Erreur HTTP ${e.response!.statusCode}.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}
