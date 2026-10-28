// lib/production_records/service/production_fiches_service.dart
//
// Client HTTP de GET /production-records/fiches (liste d'une ligne :
// filtres, pagination, compteurs de validation). Même client Dio que le reste
// du module Production ; remplaçable dans les tests.

import 'package:dio/dio.dart';

import 'package:dash_master_toolkit/providers/api_client.dart';
import '../model/production_fiche_list.dart';

abstract class ProductionFichesApi {
  Future<FicheListPage> fetch(String type, FicheListFilters filters);
}

class ProductionFichesService implements ProductionFichesApi {
  static final ProductionFichesService instance = ProductionFichesService._();
  ProductionFichesService._();

  @override
  Future<FicheListPage> fetch(String type, FicheListFilters filters) async {
    try {
      final res = await ApiClient.instance.dio.get('/production-records/fiches', queryParameters: filters.toQuery(type));
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      return FicheListPage.fromJson(body);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] != null ? data['message'].toString() : null;
      throw Exception(message ?? 'Liste des fiches indisponible (${e.response?.statusCode ?? 'réseau'})');
    }
  }
}
