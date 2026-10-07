// lib/production_dashboard/service/production_dashboard_service.dart
//
// Client HTTP de GET /production-records/dashboard — UN appel pour tout
// l'écran (KPI, machines, graphiques, dernières productions). Même client
// Dio que le reste du module Production.

import 'package:dio/dio.dart';

import 'package:dash_master_toolkit/providers/api_client.dart';
import '../model/production_dashboard_model.dart';

class ProductionDashboardService {
  static final ProductionDashboardService instance = ProductionDashboardService._();
  ProductionDashboardService._();

  /// [period] : today | week | month | year | custom ([startDate] /
  /// [endDate] au format AAAA-MM-JJ requis pour « custom »).
  Future<ProductionDashboard> fetch({required String period, String? startDate, String? endDate}) async {
    try {
      final res = await ApiClient.instance.dio.get('/production-records/dashboard', queryParameters: {
        'period': period,
        if (period == 'custom' && startDate != null) 'startDate': startDate,
        if (period == 'custom' && endDate != null) 'endDate': endDate,
      });
      final body = res.data;
      final data = body is Map && body['data'] is Map ? body['data'] as Map : (body is Map ? body : const {});
      return ProductionDashboard.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] != null ? data['message'].toString() : null;
      throw Exception(message ?? 'Dashboard Production indisponible (${e.response?.statusCode ?? 'réseau'})');
    }
  }
}
