// lib/core/config/read_only_access.dart
//
// Compte back-office en CONSULTATION SEULE (rôle `backoffice_readonly`,
// ex. backoffice@cbi-tunisia.com) — mêmes règles que le backend
// (config/backofficeReadOnly.js, middleware/readOnlyRoleGuard.js), qui reste
// l'autorité : ici, uniquement l'affichage (actions masquées, profil) et un
// garde-fou local qui n'envoie jamais de requête d'écriture.
// Fichier sans dépendance : utilisable par ApiClient et AuthService.

const String kBackofficeReadOnlyRole = 'backoffice_readonly';

/// Libellé du profil affiché dans l'application.
const String kBackofficeReadOnlyLabel = 'Back-office — Consultation uniquement';

/// Seules écritures permises : l'authentification du compte lui-même.
const Set<String> kReadOnlyAllowedWrites = {
  '/auth/signin',
  '/auth/refresh',
  '/auth/logout',
  '/auth/forgot-password',
  '/auth/reset-password',
};

/// EXCEPTION — module Notes de calcul uniquement : Valider / Refuser une note
/// (même exception que le backend, config/backofficeReadOnly.js). Aucune autre
/// écriture, dans aucun module.
final List<RegExp> kReadOnlyAllowedWritePatterns = [RegExp(r'^/calculation-notes/\d+/(validate|reject)$')];

/// Compte en consultation seule : rôle dédié, ou drapeau `readOnly` renvoyé
/// par le backend à la connexion.
bool isReadOnlyAccount({String? role, bool? readOnlyFlag}) =>
    (role ?? '').toLowerCase().trim() == kBackofficeReadOnlyRole || readOnlyFlag == true;

/// Chemin normalisé (sans hôte ni paramètres, minuscules, barres obliques
/// simples, sans barre finale) — même normalisation que le backend.
String readOnlyNormalizePath(String pathOrUrl) {
  var p = Uri.tryParse(pathOrUrl)?.path ?? pathOrUrl;
  p = p.toLowerCase().replaceAll(RegExp(r'/{2,}'), '/');
  if (p.length > 1) p = p.replaceAll(RegExp(r'/+$'), '');
  return p.isEmpty ? '/' : p;
}

/// Requête interdite à un compte en consultation seule : toute écriture,
/// sauf l'authentification du compte et la décision sur une note de calcul.
bool readOnlyBlocksRequest(String method, String pathOrUrl) {
  final m = method.toUpperCase();
  if (m == 'GET' || m == 'HEAD' || m == 'OPTIONS') return false;
  final path = readOnlyNormalizePath(pathOrUrl);
  if (m == 'POST' && kReadOnlyAllowedWritePatterns.any((re) => re.hasMatch(path))) return false;
  return !kReadOnlyAllowedWrites.any((allowed) => path == allowed || path.endsWith(allowed));
}
