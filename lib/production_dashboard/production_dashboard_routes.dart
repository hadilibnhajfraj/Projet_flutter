// lib/production_dashboard/production_dashboard_routes.dart
//
// Chemins utilisés par le Dashboard Production. Fichier sans dépendance :
// l'écran ne doit pas importer my_route.dart (qui charge toute l'application,
// y compris des écrans web uniquement — non testables hors navigateur).
// MyRoute reprend `dashboard` d'ici ; les autres valeurs sont celles des
// routes EXISTANTES de MyRoute (productionPromeshRoot, productionRecordsScreen…)
// — toute modification là-bas doit être reportée ici.

class ProdPaths {
  ProdPaths._();

  static const root = '/production';
  static const dashboard = '/production/dashboard';
  static const promesh = '/production/promesh';
  static const probar = '/production/probar';
  static const records = '/production/records';
  static const summary = '/production/summary';
  static const promeshSummary = '/production/promesh-summary';
  static const probarSummary = '/production/probar-summary';

  /// Demandes d'autorisation Production (MyRoute.productionComplianceScreen).
  static const productionRequests = '/production-compliance';

  /// Page d'une machine (fiches par poste) : `$promesh/machine/1`.
  static String machine(String type, String machine) => '${type == 'probar' ? probar : promesh}/machine/$machine';

  /// Fiche PROMESH existante (écran des modules de la fiche).
  static String promeshFiche(String machine, String poste, String id) => '$promesh/machine/$machine/poste/$poste/modules?ficheId=$id';

  /// Fiche PROBAR existante (écran de détail).
  static String probarFiche(String machine, String poste, String id) => '$probar/machine/$machine/poste/$poste/detail?id=$id';

  /// Modification d'une fiche existante : écrans de saisie EXISTANTS (grille
  /// des modules, fiche rechargée par son id), PROMESH comme PROBAR. `null`
  /// si l'id, la machine ou l'équipe manquent (la grille en a besoin).
  static String? ficheEdit({required String compositeId, required String type, String? machine, String? poste}) {
    final sep = compositeId.indexOf(':');
    final id = (sep >= 0 ? compositeId.substring(sep + 1) : compositeId).trim();
    final m = (machine ?? '').trim();
    final p = (poste ?? '').trim();
    if (id.isEmpty || m.isEmpty || p.isEmpty) return null;
    final enc = Uri.encodeQueryComponent(id);
    final seg = '/machine/${Uri.encodeComponent(m)}/poste/${Uri.encodeComponent(p)}/modules?ficheId=$enc';
    if (type == 'promesh') return '$promesh$seg';
    if (type == 'probar') return '$probar$seg';
    return null;
  }

  /// Fiche PROMESH existante en consultation (MyRoute.porPromeshDetailScreen).
  static String promeshDetail(String id) => '/por-promesh/detail?id=$id';

  /// Fiche originale d'une ligne de « Production records » / récapitulatifs :
  /// identifiant RÉEL de la fiche (id composite `promesh:<uuid>` /
  /// `probar:<uuid>`, jamais la date, la machine ou le rang de la ligne).
  /// `null` si l'identifiant est inexploitable.
  static String? ficheDetail({required String compositeId, required String type, String? machine, String? poste}) {
    final sep = compositeId.indexOf(':');
    final id = (sep >= 0 ? compositeId.substring(sep + 1) : compositeId).trim();
    if (id.isEmpty) return null;
    final enc = Uri.encodeQueryComponent(id);
    if (type == 'promesh') return promeshDetail(enc);
    if (type != 'probar') return null;
    // machine / poste : valeurs de la fiche (servent au bouton Retour de
    // l'écran PROBAR, qui charge la fiche par son id).
    String seg(String? v) => (v ?? '').trim().isEmpty ? '-' : Uri.encodeComponent(v!.trim());
    return probarFiche(seg(machine), seg(poste), enc);
  }
}
