// lib/production_records/service/production_records_service.dart
//
// Client HTTP pour GET /production-records — même client Dio et même
// parsing d'enveloppe tolérant que PorPromeshService/IndustrialRecordService
// (voir forms/por_promesh/service/por_promesh_service.dart).

import 'package:dash_master_toolkit/providers/api_client.dart';
import '../model/production_record_model.dart';
import '../model/production_summary_model.dart';

class ProductionRecordsService {
  static final ProductionRecordsService instance = ProductionRecordsService._();
  ProductionRecordsService._();

  static const _basePath = '/production-records';

  Future<ProductionRecordPage> fetchPage({
    String? type,
    String? period,
    String? startDate,
    String? endDate,
    String? machineId,
    String? poste,
    String? createdBy,
    String? search,
    String sort = 'date_desc',
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sort': sort,
      if (type != null && type.isNotEmpty && type != 'all') 'type': type,
      if (period != null && period.isNotEmpty && period != 'all') 'period': period,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      if (machineId != null && machineId.isNotEmpty) 'machineId': machineId,
      if (poste != null && poste.isNotEmpty) 'poste': poste,
      // §MODIFICATION — ADMIN > PRODUCTION RECORDS — FILTRE PAR UTILISATEUR :
      // "all" = pas de filtre (dropdown "All users", §12 Reset), jamais
      // envoyé comme id utilisateur littéral.
      if (createdBy != null && createdBy.isNotEmpty && createdBy != 'all') 'createdBy': createdBy,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final res = await ApiClient.instance.dio.get(_basePath, queryParameters: params);
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};

    final items = (body['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ProductionRecordModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final pagination = body['pagination'] is Map
        ? ProductionRecordPagination.fromJson(Map<String, dynamic>.from(body['pagination'] as Map))
        : const ProductionRecordPagination();

    final statistics = body['statistics'] is Map
        ? ProductionRecordStatistics.fromJson(Map<String, dynamic>.from(body['statistics'] as Map))
        : const ProductionRecordStatistics();

    final productionTotals =
        body['productionTotals'] is Map ? ProductionTotals.fromJson(Map<String, dynamic>.from(body['productionTotals'] as Map)) : const ProductionTotals();

    return ProductionRecordPage(items: items, pagination: pagination, statistics: statistics, productionTotals: productionTotals);
  }

  Future<ProductionRecordFilters> fetchFilters() async {
    final res = await ApiClient.instance.dio.get('$_basePath/filters');
    final data = _unwrapObject(res.data);
    return ProductionRecordFilters.fromJson(data);
  }

  // §MODIFICATION — ADMIN > PRODUCTION RECORDS — FILTRE PAR UTILISATEUR (§3) :
  // alimente le dropdown "All users" — jamais codé en dur côté Flutter.
  Future<List<ProductionRecordCreator>> fetchCreators() async {
    final res = await ApiClient.instance.dio.get('$_basePath/creators');
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return (body['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ProductionRecordCreator.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // Détail complet — forme hétérogène selon le type (voir
  // productionRecords.dto.js#buildPromeshDetail/buildProbarDetail), gardée
  // en Map brute plutôt qu'aplatie dans un modèle typé unique : les deux
  // types exposent des sous-structures ("technicalData", "visas",
  // "attachments"...) trop différentes pour un seul schéma commun.
  Future<Map<String, dynamic>> fetchDetail(String compositeId) async {
    final res = await ApiClient.instance.dio.get('$_basePath/$compositeId');
    return _unwrapObject(res.data);
  }

  // "Production Summary" — tableau récapitulatif groupé par Diamètre
  // (+ Taille de maille pour PROMESH), voir productionRecords.service.js#getProductionSummary.
  Future<ProductionSummary> fetchSummary({
    String? type,
    String? period,
    String? startDate,
    String? endDate,
    String? machineId,
    String? poste,
    String? createdBy,
    String? diameter,
    String? status,
  }) async {
    final params = <String, String>{
      if (type != null && type.isNotEmpty && type != 'all') 'type': type,
      if (period != null && period.isNotEmpty && period != 'all') 'period': period,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      if (machineId != null && machineId.isNotEmpty) 'machineId': machineId,
      if (poste != null && poste.isNotEmpty) 'poste': poste,
      if (createdBy != null && createdBy.isNotEmpty && createdBy != 'all') 'createdBy': createdBy,
      if (diameter != null && diameter.isNotEmpty) 'diameter': diameter,
      // Contrairement à `type`/`period` ci-dessus, "all" est ici une valeur
      // FONCTIONNELLE distincte du défaut backend ("validee" si absent, voir
      // resolveSummaryStatus côté service) — elle doit donc être envoyée
      // explicitement, jamais omise.
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final res = await ApiClient.instance.dio.get('$_basePath/summary', queryParameters: params);
    return ProductionSummary.fromJson(_unwrapObject(res.data));
  }

  Map<String, dynamic> _unwrapObject(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}
