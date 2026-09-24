// lib/production_compliance/service/production_draft_archive_service.dart
//
// Client HTTP de l'archivage automatique des brouillons PROMESH/PROBAR (2h
// sans finalisation, backend : /production-draft-archive/*) et des demandes
// de désarchivage. Toutes les règles sont appliquées côté backend — ce
// service ne fait que les appeler et présenter les erreurs.

import 'package:dio/dio.dart' show DioException;

import 'package:dash_master_toolkit/providers/api_client.dart';
import 'production_compliance_service.dart' show ProductionApiException;

class ProductionDraftArchiveService {
  static final ProductionDraftArchiveService instance = ProductionDraftArchiveService._();
  ProductionDraftArchiveService._();

  static const _base = '/production-draft-archive';

  Map<String, dynamic> _data(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return (data as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Demande de désarchivage d'une fiche ARCHIVÉE dont l'utilisateur est
  /// propriétaire — motif obligatoire, jamais de doublon (le backend réutilise
  /// la demande PENDING existante le cas échéant).
  Future<Map<String, dynamic>> createRequest({required String ficheType, required String ficheId, required String reason}) async {
    final res = await ApiClient.instance.dio.post('$_base/requests', data: {
      'ficheType': ficheType,
      'ficheId': ficheId,
      'reason': reason.trim(),
    });
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : <String, dynamic>{};
    return {...data, '_alreadyPending': body['alreadyPending'] == true};
  }

  Future<List<Map<String, dynamic>>> myRequests() async => _list((await ApiClient.instance.dio.get('$_base/requests/mine')).data);

  Future<List<Map<String, dynamic>>> listRequests({String? status}) async =>
      _list((await ApiClient.instance.dio.get('$_base/requests', queryParameters: {if (status != null) 'status': status})).data);

  Future<Map<String, dynamic>> requestStats() => ApiClient.instance.dio.get('$_base/requests/stats').then((r) => _data(r.data));

  Future<Map<String, dynamic>> approveRequest(String id, {String? note}) => ApiClient.instance.dio
      .post('$_base/requests/$id/approve', data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()})
      .then((r) => _data(r.data));

  Future<Map<String, dynamic>> rejectRequest(String id, {required String note}) =>
      ApiClient.instance.dio.post('$_base/requests/$id/reject', data: {'note': note.trim()}).then((r) => _data(r.data));

  /// §12 — liste DIRECTE des fiches ACTUELLEMENT archivées (≠ demandes de
  /// désarchivage : une fiche archivée peut n'avoir aucune demande en cours,
  /// ce qui est normal). Responsables uniquement.
  Future<List<Map<String, dynamic>>> listArchivedSheets({String? ficheType}) async =>
      _list((await ApiClient.instance.dio.get('$_base/archived-sheets', queryParameters: {if (ficheType != null) 'ficheType': ficheType})).data);

  /// Message métier pour une erreur API (mêmes codes que le backend :
  /// SHEET_ARCHIVED, NOT_OWNER, NOT_ARCHIVED, REASON_REQUIRED, NOT_A_MANAGER…).
  static String friendlyError(Object e, {required bool fr}) {
    if (e is ProductionApiException) return e.message;
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final code = data['code']?.toString();
        switch (code) {
          case 'SHEET_ARCHIVED':
            return fr ? "Cette fiche est archivée. Demandez son désarchivage pour la modifier." : 'This sheet is archived. Request its unarchiving to edit it.';
          case 'NOT_ARCHIVED':
            return fr ? "Cette fiche n'est pas archivée." : 'This sheet is not archived.';
          case 'REASON_REQUIRED':
            return fr ? 'Le motif est obligatoire.' : 'A reason is required.';
          case 'NOT_A_MANAGER':
            return fr ? "Vous n'avez pas l'autorisation d'effectuer cette action." : 'You are not allowed to perform this action.';
          case 'NOT_OWNER':
            return fr ? "Cette fiche a été créée par un autre utilisateur." : 'This sheet was created by another user.';
        }
        final m = data['message'];
        if (m != null && m.toString().isNotEmpty) return m.toString();
      }
      return e.message ?? (fr ? 'Erreur réseau' : 'Network error');
    }
    return e.toString();
  }
}
