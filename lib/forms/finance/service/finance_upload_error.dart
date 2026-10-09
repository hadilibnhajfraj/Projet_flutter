// lib/forms/finance/service/finance_upload_error.dart
//
// Message affiché à l'utilisateur quand un import Finance échoue (bons de
// livraison, bons de commande, factures) : celui du backend, qui nomme
// l'étape réellement en échec (fichier trop volumineux, lecture du PDF, base
// de données, stockage, document déjà importé…). Sans réponse exploitable
// (réseau, délai dépassé, refus du reverse proxy) : une phrase claire — jamais
// le texte brut de l'exception.

import 'package:dio/dio.dart';

String friendlyFinanceUploadError(Object error, String Function(String) translate) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String && (data['message'] as String).trim().isNotEmpty) {
      return data['message'] as String;
    }
    final status = error.response?.statusCode;
    // 413 sans corps JSON : refus du reverse proxy avant l'application.
    if (status == 413) return translate('Le fichier est trop volumineux pour être envoyé.');
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return translate('Le traitement du document prend trop de temps. Vérifiez dans la liste s\'il a été enregistré avant de réessayer.');
      case DioExceptionType.connectionError:
        return translate('Connexion au serveur impossible. Vérifiez votre réseau puis réessayez.');
      default:
        break;
    }
    if (status != null) return '${translate('Le serveur a renvoyé une erreur')} ($status).';
  }
  return translate('Une erreur inattendue a interrompu le traitement du document.');
}
