// Finance — message affiché quand un import échoue : celui du backend quand il
// existe (fichier trop volumineux, lecture du PDF, base, doublon…), sinon une
// phrase claire. Jamais le texte brut de l'exception.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/finance/service/finance_upload_error.dart';

DioException _http(int status, Object? data) {
  final options = RequestOptions(path: '/finance/shipments');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: data),
  );
}

String _t(String key) => key;

void main() {
  test('message du backend affiché tel quel : 413 trop volumineux, 422 PDF illisible, 500 base, 409 doublon', () {
    const cases = {
      413: 'Le fichier dépasse la taille maximale autorisée de 25 Mo.',
      422: 'Impossible de lire le PDF. Vérifiez que le fichier est valide.',
      500: 'Document reçu, mais l\'enregistrement en base a échoué.',
      409: 'Le document a déjà été importé (Bon de Livraison n° BL-123).',
    };
    cases.forEach((status, message) {
      expect(friendlyFinanceUploadError(_http(status, {'success': false, 'message': message}), _t), message, reason: '$status');
    });
  });

  test('sans message exploitable : phrase claire, jamais « DioException »', () {
    // 413 renvoyé par le reverse proxy (page HTML, pas de JSON).
    expect(friendlyFinanceUploadError(_http(413, '<html>413 Request Entity Too Large</html>'), _t), 'Le fichier est trop volumineux pour être envoyé.');
    expect(friendlyFinanceUploadError(_http(502, null), _t), 'Le serveur a renvoyé une erreur (502).');
    final options = RequestOptions(path: '/finance/shipments');
    expect(friendlyFinanceUploadError(DioException(requestOptions: options, type: DioExceptionType.connectionError), _t), 'Connexion au serveur impossible. Vérifiez votre réseau puis réessayez.');
    expect(friendlyFinanceUploadError(DioException(requestOptions: options, type: DioExceptionType.receiveTimeout), _t), contains('prend trop de temps'));
    expect(friendlyFinanceUploadError(StateError('interne'), _t), 'Une erreur inattendue a interrompu le traitement du document.');
    for (final e in [_http(413, null), _http(500, {'message': ''}), StateError('x')]) {
      expect(friendlyFinanceUploadError(e, _t), isNot(contains('Exception')));
    }
  });
}
