// Écrans Production : message d'erreur de chargement explicite — le code HTTP,
// le code backend et la requête refusée restent toujours affichés.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/production_records/service/production_load_error.dart';

DioException _http(int status, Object? body, {String path = '/production-records/summary'}) {
  final options = RequestOptions(path: path, method: 'GET');
  return DioException(requestOptions: options, response: Response(requestOptions: options, statusCode: status, data: body), type: DioExceptionType.badResponse);
}

void main() {
  test('403 : code HTTP, code backend, requête et message du serveur', () {
    expect(productionLoadErrorText(_http(403, {'success': false, 'code': 'PERMISSION_DENIED', 'message': 'Forbidden'})),
        'HTTP 403 PERMISSION_DENIED – Accès refusé par le serveur (GET /production-records/summary) — Forbidden');
  });

  test('autres statuts : jamais masqués', () {
    expect(productionLoadErrorText(_http(401, {'message': 'Unauthorized'})), startsWith('HTTP 401 – Session expirée'));
    expect(productionLoadErrorText(_http(500, 'boom')), 'HTTP 500 – Erreur du serveur (GET /production-records/summary)');
    expect(productionLoadErrorText(_http(404, {'code': 'FICHE_NOT_FOUND'}, path: '/por-promesh/x')), 'HTTP 404 FICHE_NOT_FOUND – Ressource introuvable (GET /por-promesh/x)');
  });

  test('serveur injoignable et erreur non HTTP', () {
    final options = RequestOptions(path: '/por-promesh', method: 'GET');
    expect(productionLoadErrorText(DioException(requestOptions: options, type: DioExceptionType.connectionError, message: 'refused')), 'Serveur injoignable (GET /por-promesh) : refused.');
    expect(productionLoadErrorText(Exception('La date de début doit précéder la date de fin.')), 'La date de début doit précéder la date de fin.');
  });
}
