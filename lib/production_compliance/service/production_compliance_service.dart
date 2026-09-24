// lib/production_compliance/service/production_compliance_service.dart
//
// Client HTTP du contrôle de conformité PROD 1 / PROD 2
// (backend : /production-compliance/*). Toutes les règles sont appliquées
// côté backend ; ce service ne fait que les appeler et présenter les erreurs.

import 'package:dio/dio.dart' show DioException, Options;
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/providers/api_client.dart';

/// Erreur API avec message métier prêt à afficher (toString = message).
class ProductionApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  /// Corps JSON complet renvoyé par le backend (missingDate, requestedDate, production…).
  final Map<String, dynamic>? data;
  ProductionApiException(this.message, {this.code, this.statusCode, this.data});

  bool get isMissingPreviousSheet => code == 'PREVIOUS_PRODUCTION_MISSING';
  bool get isBackfillNotAuthorized => code == 'BACKFILL_NOT_AUTHORIZED';
  bool get needsAuthorization => isMissingPreviousSheet || isBackfillNotAuthorized;
  // Fiche archivée automatiquement (brouillon > 2h sans finalisation) —
  // voir production-draft-archive côté backend.
  bool get isArchived => code == 'SHEET_ARCHIVED';

  @override
  String toString() => message;
}

class ProductionComplianceService {
  static final ProductionComplianceService instance = ProductionComplianceService._();
  ProductionComplianceService._();

  static const _base = '/production-compliance';

  Future<Map<String, dynamic>> _map(Future<dynamic> Function() call) async {
    final res = await call();
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return (data as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Situation de l'utilisateur connecté (blocage, dates manquantes, rattrapages autorisés).
  Future<Map<String, dynamic>> me() =>
      _map(() => ApiClient.instance.dio.get('$_base/me', options: Options(receiveTimeout: const Duration(seconds: 20))));

  Future<List<Map<String, dynamic>>> list({
    String? from,
    String? to,
    String? production,
    String? userId,
    String? status,
  }) async {
    final res = await ApiClient.instance.dio.get(_base, queryParameters: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (production != null) 'production': production,
      if (userId != null) 'userId': userId,
      if (status != null) 'status': status,
    });
    return _list(res.data);
  }

  Future<Map<String, dynamic>> summary({String? date}) => _map(
        () => ApiClient.instance.dio.get('$_base/summary', queryParameters: {if (date != null) 'date': date}),
      );

  Future<Map<String, dynamic>> authorize({
    required String production,
    required String date,
    required String type,
    String? reason,
  }) =>
      _map(() => ApiClient.instance.dio.post('$_base/authorizations', data: {
            'production': production,
            'date': date,
            'type': type,
            if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
          }));

  // ── Demandes d'autorisation de régularisation ──

  /// Crée une demande couvrant TOUTES les dates actuellement manquantes (recalculées
  /// côté backend — jamais confiance dans une liste envoyée par le client). Statut
  /// PENDING : aucune autorisation n'est jamais accordée automatiquement.
  // requestedDate (date exacte du 403 reçu, ex. 21/09 passée) est transmise pour
  // qu'un blocage direct sur une date déjà pourvue en fiches reste régularisable —
  // le backend la revérifie toujours indépendamment, jamais de confiance aveugle.
  Future<Map<String, dynamic>> createRequest({required String reason, String? requestedDate}) async {
    final res = await ApiClient.instance.dio.post('$_base/requests', data: {
      'reason': reason.trim(),
      if (requestedDate != null) 'requestedDate': requestedDate,
    });
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : <String, dynamic>{};
    return {...data, '_alreadyPending': body['alreadyPending'] == true};
  }

  Future<List<Map<String, dynamic>>> myRequests() async => _list((await ApiClient.instance.dio.get('$_base/requests/mine')).data);

  Future<List<Map<String, dynamic>>> listRequests({String? status}) async => _list(
        (await ApiClient.instance.dio.get('$_base/requests', queryParameters: {if (status != null) 'status': status})).data,
      );

  /// Compteurs pour le tableau de bord (PENDING/APPROVED/REJECTED/USED/EXPIRED).
  Future<Map<String, dynamic>> requestStats() => _map(() => ApiClient.instance.dio.get('$_base/requests/stats'));

  Future<Map<String, dynamic>> approveRequest(String id, {String? note}) =>
      _map(() => ApiClient.instance.dio.post('$_base/requests/$id/approve', data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()}));

  Future<Map<String, dynamic>> rejectRequest(String id, {String? note}) =>
      _map(() => ApiClient.instance.dio.post('$_base/requests/$id/reject', data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()}));

  Future<Map<String, dynamic>> revoke(String id) =>
      _map(() => ApiClient.instance.dio.post('$_base/authorizations/$id/revoke'));

  /// "Retry email" (Super Admin) — ne crée jamais une 2e demande/alerte, ne
  /// fait que retenter l'envoi de la MÊME ligne (retryCount/attempts incrémenté).
  Future<Map<String, dynamic>> retryRequestEmail(String id) => _map(() => ApiClient.instance.dio.post('$_base/requests/$id/retry-email'));

  Future<Map<String, dynamic>> retryAlertEmail(String id) => _map(() => ApiClient.instance.dio.post('$_base/alerts/$id/retry-email'));

  /// Diagnostic SMTP sécurisé (host/port/user masqué/from masqué/verify) —
  /// jamais de mot de passe, voir utils/mailer.maskEmail côté backend.
  Future<Map<String, dynamic>> smtpCheck() => _map(() => ApiClient.instance.dio.post('$_base/smtp-check'));

  static bool get _isFr => (GetStorage().read<String>('language_code') ?? 'fr') == 'fr';

  static String _fmtIso(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '');
    return d == null ? (iso?.toString() ?? '') : DateFormat('dd/MM/yyyy').format(d);
  }

  /// Message métier pour une erreur API — basé sur le `code` renvoyé par le
  /// backend (jamais seulement "DioException [bad response]").
  static String friendlyError(Object e, {required bool fr}) {
    if (e is ProductionApiException) return e.message;
    if (e is DioException) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map) {
        final code = data['code']?.toString();
        switch (code) {
          case 'PREVIOUS_PRODUCTION_MISSING':
            final dates = (data['missingDates'] as List?)?.map(_fmtIso).toList() ?? [_fmtIso(data['missingDate'])];
            return fr
                ? "${dates.length > 1 ? '${dates.length} fiches précédentes sont manquantes' : 'Fiche du ${dates.first} manquante'} : ${dates.join(', ')}.\nDemandez une autorisation de régularisation."
                : "${dates.length > 1 ? '${dates.length} previous sheets are missing' : 'The sheet of ${dates.first} is missing'}: ${dates.join(', ')}.\nRequest a regularization authorization.";
          case 'BACKFILL_NOT_AUTHORIZED':
            final d = _fmtIso(data['requestedDate'] ?? data['missingDate']);
            return fr
                ? "Cette date est antérieure ($d).\nUne autorisation de rattrapage est nécessaire."
                : "This date is in the past ($d).\nA backfill authorization is required.";
          case 'PERMISSION_DENIED':
            return fr ? "Vous n'avez pas l'autorisation d'effectuer cette action." : 'You are not allowed to perform this action.';
          case 'SHEET_LOCKED':
            return fr ? 'Cette fiche est validée définitivement : elle ne peut plus être modifiée.' : 'This sheet is permanently validated and can no longer be edited.';
          case 'SHEET_ARCHIVED':
            return fr ? 'Cette fiche est archivée. Une demande de désarchivage est nécessaire pour la modifier.' : 'This sheet is archived. Request its unarchiving to edit it.';
          case 'NOT_OWNER':
            return fr ? "Cette fiche a été créée par un autre utilisateur : vous n'y avez pas accès." : 'This sheet was created by another user: you do not have access.';
          case 'COMPLIANCE_CHECK_FAILED':
            return fr ? 'Le contrôle de conformité de production a échoué. Veuillez réessayer.' : 'The production compliance check failed. Please retry.';
        }
        final m = fr ? (data['messageFr'] ?? data['message']) : (data['messageEn'] ?? data['message'] ?? data['messageFr']);
        if (m != null && m.toString().isNotEmpty) return m.toString();
        if (status == 403) return fr ? "Vous n'avez pas l'autorisation d'effectuer cette action." : 'You are not allowed to perform this action.';
      }
      if (status != null) return 'HTTP $status';
      return e.message ?? 'Network error';
    }
    return e.toString();
  }

  /// Convertit un refus 403 / 503 du backend en exception lisible (message métier) ;
  /// toute autre erreur est renvoyée inchangée.
  static Object translateError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      if ((status == 403 || status == 503) && data is Map) {
        return ProductionApiException(
          friendlyError(e, fr: _isFr),
          code: data['code']?.toString(),
          statusCode: status,
          data: Map<String, dynamic>.from(data),
        );
      }
    }
    return e;
  }

  /// Vrai si l'erreur est un refus métier (conformité / verrouillage / permissions).
  static bool isComplianceBlock(Object e) {
    if (e is ProductionApiException) return true;
    if (e is DioException && e.response?.statusCode == 403) {
      final data = e.response?.data;
      return data is Map && (data['code'] == 'PREVIOUS_PRODUCTION_MISSING' || data['code'] == 'BACKFILL_NOT_AUTHORIZED');
    }
    return false;
  }
}
