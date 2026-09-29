// lib/quality_control/service/quality_control_service.dart
//
// Client HTTP du module CONTRÔLE QUALITÉ (/quality-control) — même client
// Dio que ProductionRecordsService. La liste des fiches à contrôler vient de
// l'existant GET /production-records (ProductionRecordsService), jamais
// dupliquée ici.

import 'package:dio/dio.dart';

import 'package:dash_master_toolkit/providers/api_client.dart';
import '../model/quality_control_model.dart';

/// Erreur métier renvoyée par le backend (code + message + erreurs par
/// paramètre pour VALIDATION_FAILED).
class QualityControlApiException implements Exception {
  final String? code;
  final String message;
  final List<Map<String, dynamic>> errors;
  QualityControlApiException(this.message, {this.code, this.errors = const []});

  Set<String> get parameterKeysInError =>
      errors.map((e) => e['parameterKey']?.toString()).whereType<String>().toSet();

  @override
  String toString() => message;
}

class QualityControlService {
  static final QualityControlService instance = QualityControlService._();
  QualityControlService._();

  static const _basePath = '/quality-control';

  Future<T> _call<T>(Future<Response> Function() request, T Function(dynamic data) parse) async {
    try {
      final res = await request();
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      return parse(body['data']);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        throw QualityControlApiException(
          data['message']?.toString() ?? 'Erreur serveur',
          code: data['code']?.toString(),
          errors: (data['errors'] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList(),
        );
      }
      throw QualityControlApiException(e.message ?? 'Erreur réseau');
    }
  }

  QualityControlModel _control(dynamic data) => QualityControlModel.fromJson(Map<String, dynamic>.from(data as Map));

  List<QualityControlModel> _controls(dynamic data) =>
      (data as List? ?? []).whereType<Map>().map((m) => QualityControlModel.fromJson(Map<String, dynamic>.from(m))).toList();

  Future<List<QualityParameter>> fetchParameters() => _call(
        () => ApiClient.instance.dio.get('$_basePath/parameters'),
        (data) => (data as List? ?? [])
            .whereType<Map>()
            .map((m) => QualityParameter.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );

  Future<List<QualityControlModel>> fetchHistory({String? status, String? productionType, int limit = 100}) => _call(
        () => ApiClient.instance.dio.get(_basePath, queryParameters: {
          'limit': limit.toString(),
          if (status != null && status.isNotEmpty) 'status': status,
          if (productionType != null && productionType.isNotEmpty) 'productionType': productionType,
        }),
        _controls,
      );

  Future<List<QualityControlModel>> fetchForProductionRecord(String productionRecordRef) => _call(
        () => ApiClient.instance.dio.get('$_basePath/production/$productionRecordRef'),
        _controls,
      );

  Future<QualityControlModel> fetchById(String id) =>
      _call(() => ApiClient.instance.dio.get('$_basePath/$id'), _control);

  Future<QualityControlModel> create({required String productionRecordRef}) => _call(
        () => ApiClient.instance.dio.post(_basePath, data: {'productionRecordId': productionRecordRef}),
        _control,
      );

  // `status` n'est pris en compte par le backend que pour un contrôle déjà
  // validé (résultat CONFORME / NON_CONFORME, motif obligatoire).
  Future<QualityControlModel> update(String id,
          {required List<Map<String, dynamic>> items, String? remark, String? status, String? changeReason}) =>
      _call(
        () => ApiClient.instance.dio.put('$_basePath/$id', data: {
          'items': items,
          if (remark != null) 'remark': remark,
          if (status != null) 'status': status,
          if (changeReason != null) 'changeReason': changeReason,
        }),
        _control,
      );

  Future<QualityControlModel> validate(String id, {required List<Map<String, dynamic>> items, String? remark, String? status}) =>
      _call(
        () => ApiClient.instance.dio.post('$_basePath/$id/validate', data: {
          'items': items,
          if (remark != null) 'remark': remark,
          if (status != null) 'status': status,
        }),
        _control,
      );
}
