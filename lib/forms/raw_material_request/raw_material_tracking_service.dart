// lib/forms/raw_material_request/raw_material_tracking_service.dart
//
// Client HTTP du suivi des demandes de matières premières (menu « Matières
// premières »). Les droits (visibilité, changement de statut) et les filtres
// sont appliqués par le backend ; cet écran ne fait que les appeler.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' show DioException, Options, ResponseType;

import 'package:dash_master_toolkit/providers/api_client.dart';

import 'raw_material_request_record.dart';
import 'raw_material_request_service.dart' show RawMaterialLine, RawMaterialRequestService;

/// Contrat utilisé par la page de suivi (remplaçable dans les tests).
abstract class RawMaterialTrackingApi {
  Future<RawMaterialPermissions> permissions();
  Future<({List<RawMaterialRequestRecord> items, int total})> list(RawMaterialFilters filters);
  Future<List<({String userId, String userEmail})>> requesters();
  Future<RawMaterialRequestRecord> detail(String id);
  /// [expectedStatus] : statut affiché au moment de la décision ; si un autre
  /// responsable l'a modifié entre-temps, le backend refuse (409).
  Future<RawMaterialRequestRecord> changeStatus(String id, {required String status, String? comment, String? expectedStatus});
  Future<({Uint8List bytes, String fileName})> exportExcel(RawMaterialFilters filters);
  /// Bandeau du responsable : en attente, en retard, échéance proche.
  Future<({int pending, int overdue, int dueSoon})> pendingSummary();
  /// Correction d'une demande rejetée par son demandeur.
  Future<Map<String, dynamic>> resubmit(String id, List<RawMaterialLine> lines);
  /// Shift soir : prise en charge avec les quantités réelles (code matière → KG).
  Future<RawMaterialRequestRecord> eveningAccept(String id, Map<String, double> actualQuantities);
  /// Shift soir : refus motivé.
  Future<RawMaterialRequestRecord> eveningRefuse(String id, {required String comment});
}

class RawMaterialTrackingService implements RawMaterialTrackingApi {
  static final RawMaterialTrackingService instance = RawMaterialTrackingService._();
  RawMaterialTrackingService._();

  static const _base = '/raw-material-requests';

  Map<String, dynamic> _data(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  @override
  Future<RawMaterialPermissions> permissions() async =>
      RawMaterialPermissions.fromJson(_data((await ApiClient.instance.dio.get('$_base/permissions')).data));

  @override
  Future<({List<RawMaterialRequestRecord> items, int total})> list(RawMaterialFilters filters) async {
    final res = await ApiClient.instance.dio.get(_base, queryParameters: filters.toQuery());
    final body = res.data is Map ? res.data as Map : const {};
    final items = [
      for (final r in (body['data'] as List? ?? const []))
        if (r is Map) RawMaterialRequestRecord.fromJson(Map<String, dynamic>.from(r)),
    ];
    return (items: items, total: (body['count'] as num?)?.toInt() ?? items.length);
  }

  @override
  Future<List<({String userId, String userEmail})>> requesters() async {
    final res = await ApiClient.instance.dio.get('$_base/requesters');
    final body = res.data is Map ? res.data as Map : const {};
    return [
      for (final r in (body['data'] as List? ?? const []))
        if (r is Map) (userId: r['userId'].toString(), userEmail: r['userEmail'].toString()),
    ];
  }

  @override
  Future<({int pending, int overdue, int dueSoon})> pendingSummary() async {
    final d = _data((await ApiClient.instance.dio.get('$_base/pending-summary')).data);
    int n(String k) => (d[k] as num?)?.toInt() ?? 0;
    return (pending: n('pending'), overdue: n('overdue'), dueSoon: n('dueSoon'));
  }

  @override
  Future<Map<String, dynamic>> resubmit(String id, List<RawMaterialLine> lines) =>
      RawMaterialRequestService.instance.resubmit(id, lines: lines);

  @override
  Future<RawMaterialRequestRecord> eveningAccept(String id, Map<String, double> actualQuantities) async {
    final res = await ApiClient.instance.dio.post('$_base/$id/evening-accept', data: {
      'actualItems': [
        for (final e in actualQuantities.entries) {'material': e.key, 'quantiteReelle': e.value},
      ],
    });
    return RawMaterialRequestRecord.fromJson(_data(res.data));
  }

  @override
  Future<RawMaterialRequestRecord> eveningRefuse(String id, {required String comment}) async {
    final res = await ApiClient.instance.dio.post('$_base/$id/evening-refuse', data: {'comment': comment.trim()});
    return RawMaterialRequestRecord.fromJson(_data(res.data));
  }

  @override
  Future<RawMaterialRequestRecord> detail(String id) async =>
      RawMaterialRequestRecord.fromJson(_data((await ApiClient.instance.dio.get('$_base/$id')).data));

  @override
  Future<RawMaterialRequestRecord> changeStatus(String id, {required String status, String? comment, String? expectedStatus}) async {
    final res = await ApiClient.instance.dio.patch('$_base/$id/status', data: {
      'status': status,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      if (expectedStatus != null) 'expectedStatus': expectedStatus,
    });
    return RawMaterialRequestRecord.fromJson(_data(res.data));
  }

  @override
  Future<({Uint8List bytes, String fileName})> exportExcel(RawMaterialFilters filters) async {
    try {
      final res = await ApiClient.instance.dio.get(
        '$_base/export',
        queryParameters: filters.toQuery(paged: false),
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 120)),
      );
      final disposition = res.headers.value('content-disposition') ?? '';
      final name = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition)?.group(1) ?? 'matieres-premieres.xlsx';
      return (bytes: Uint8List.fromList(res.data as List<int>), fileName: name);
    } on DioException catch (e) {
      // Corps d'erreur JSON reçu en octets (responseType.bytes).
      final raw = e.response?.data;
      if (raw is List<int>) {
        try {
          final m = jsonDecode(utf8.decode(raw));
          if (m is Map && m['message'] != null) throw Exception(m['message'].toString());
        } on FormatException {
          // corps non JSON : erreur d'origine
        }
      }
      rethrow;
    }
  }
}
