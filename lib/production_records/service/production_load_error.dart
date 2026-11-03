// lib/production_records/service/production_load_error.dart
//
// Message d'erreur de CHARGEMENT des écrans Production (listes, récapitulatifs,
// consultation, historique) : explicite et jamais masqué — code HTTP, code
// d'erreur du backend, requête refusée et message du serveur. Remplace le
// texte brut « DioException [bad response]… » sans rien en retirer d'utile.

import 'package:dio/dio.dart';

String productionLoadErrorText(Object error) {
  if (error is! DioException) return error.toString().replaceFirst('Exception: ', '');

  final req = '${error.requestOptions.method} ${error.requestOptions.path}';
  final res = error.response;
  if (res == null) {
    if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout) {
      return 'Délai dépassé : le serveur ne répond pas ($req).';
    }
    return 'Serveur injoignable ($req) : ${error.message ?? error.type.name}.';
  }

  final status = res.statusCode ?? 0;
  final body = res.data;
  final code = body is Map ? body['code']?.toString() : null;
  final serverMessage = body is Map ? (body['message'] ?? body['error'])?.toString() : null;
  final head = 'HTTP $status${code == null || code.isEmpty ? '' : ' $code'}';
  final meaning = switch (status) {
    401 => 'Session expirée ou non authentifiée',
    403 => 'Accès refusé par le serveur',
    404 => 'Ressource introuvable',
    >= 500 => 'Erreur du serveur',
    _ => 'Requête refusée',
  };
  final detail = serverMessage == null || serverMessage.isEmpty ? '' : ' — $serverMessage';
  return '$head – $meaning ($req)$detail';
}
