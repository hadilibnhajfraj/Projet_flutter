// lib/production_compliance/service/production_requests_service.dart
//
// Client HTTP de /production-requests/* — statistiques, historique et
// traçabilité des demandes Production (autorisation de backfill /
// désarchivage). Lecture seule : les décisions restent sur les services
// existants (ProductionComplianceService / ProductionDraftArchiveService).
// Le backend revérifie chaque permission (production.*) à chaque appel.

import 'package:dash_master_toolkit/providers/api_client.dart';

class ProductionRequestsService {
  static final ProductionRequestsService instance = ProductionRequestsService._();
  ProductionRequestsService._();

  static const _base = '/production-requests';

  Map<String, dynamic> _object(dynamic data) {
    if (data is Map && data['data'] is Map) return Map<String, dynamic>.from(data['data'] as Map);
    return {};
  }

  List<Map<String, dynamic>> _list(dynamic data) {
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Map<String, String> _params({
    String? from,
    String? to,
    String? production,
    String? userId,
    String? type,
    String? status,
    String? granularity,
  }) =>
      {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (production != null && production.isNotEmpty) 'production': production,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
        if (type != null && type.isNotEmpty) 'type': type,
        if (status != null && status.isNotEmpty) 'status': status,
        if (granularity != null && granularity.isNotEmpty) 'granularity': granularity,
      };

  Future<List<String>> fetchPermissions() async {
    final res = await ApiClient.instance.dio.get('$_base/permissions');
    return (_object(res.data)['permissions'] as List? ?? []).map((e) => e.toString()).toList();
  }

  Future<Map<String, dynamic>> fetchStatistics({
    String? from,
    String? to,
    String? production,
    String? userId,
    String? type,
    String? status,
    String granularity = 'day',
  }) async {
    final res = await ApiClient.instance.dio.get(
      '$_base/statistics',
      queryParameters: _params(from: from, to: to, production: production, userId: userId, type: type, status: status, granularity: granularity),
    );
    return _object(res.data);
  }

  Future<List<Map<String, dynamic>>> fetchHistory({
    String? from,
    String? to,
    String? production,
    String? userId,
    String? type,
    String? status,
  }) async {
    final res = await ApiClient.instance.dio.get(
      '$_base/history',
      queryParameters: _params(from: from, to: to, production: production, userId: userId, type: type, status: status),
    );
    return _list(res.data);
  }

  /// `type` : 'authorization' | 'unarchive'.
  Future<Map<String, dynamic>> fetchRequestHistory(String type, String id) async {
    final res = await ApiClient.instance.dio.get('$_base/$type/$id/history');
    return _object(res.data);
  }
}
