// lib/production_records/fiche_edit_session.dart
//
// MODIFICATION d'une fiche de production EXISTANTE (PROBAR ou PROMESH) par le
// root admin (cbitunisia@cbi-tunisia.com — droit renvoyé par le backend,
// user.permissions.productionFicheAdmin, revérifié par chaque route).
//
// - [ficheLockBlocksWrite] : règle UNIQUE d'affichage de Modifier / Supprimer
//   sur une fiche verrouillée (validée), utilisée par toutes les listes et
//   fiches de détail — inchangée pour tous les autres comptes.
// - [FicheEditSession] : mode « modification » d'une fiche précise, ouvert
//   UNIQUEMENT par le bouton Modifier du root admin (jamais par une création :
//   « Nouvelle fiche » n'ouvre aucune session). La grille des modules s'en sert
//   pour relire la fiche en base, masquer « Terminer la saisie » (fiche déjà
//   validée) et revenir à la liste d'origine, qui se recharge.

import 'package:dash_master_toolkit/providers/auth_service.dart';

/// Vrai si le verrouillage interdit Modifier / Supprimer pour le compte
/// connecté : fiche verrouillée et compte autre que le root admin.
bool ficheLockBlocksWrite(bool isLocked) => isLocked && !AuthService().canManageAllProductionFiches;

class FicheEditSession {
  FicheEditSession._();

  // id réel de la fiche (UUID, jamais son numéro d'affichage) → route de retour.
  static final Map<String, String> _returnRoutes = {};

  /// Ouvre le mode modification de la fiche [ficheId] (id réel, sans préfixe
  /// « promesh: » / « probar: »). Sans effet hors root admin.
  static void start(String ficheId, {required String returnTo}) {
    final id = normalizeId(ficheId);
    if (id.isEmpty || !AuthService().canManageAllProductionFiches) return;
    _returnRoutes[id] = returnTo;
  }

  static bool isEditing(String ficheId) => _returnRoutes.containsKey(normalizeId(ficheId));

  static String? returnRouteFor(String ficheId) => _returnRoutes[normalizeId(ficheId)];

  /// Ferme le mode modification et renvoie la route de retour (liste d'origine).
  static String? end(String ficheId) => _returnRoutes.remove(normalizeId(ficheId));

  /// « promesh:<uuid> » / « probar:<uuid> » → « <uuid> ».
  static String normalizeId(String id) {
    final sep = id.indexOf(':');
    return (sep >= 0 ? id.substring(sep + 1) : id).trim();
  }
}
