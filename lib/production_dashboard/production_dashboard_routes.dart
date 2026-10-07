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

  /// Fiche PROMESH existante (écran des modules de la fiche).
  static String promeshFiche(String machine, String poste, String id) => '$promesh/machine/$machine/poste/$poste/modules?ficheId=$id';

  /// Fiche PROBAR existante (écran de détail).
  static String probarFiche(String machine, String poste, String id) => '$probar/machine/$machine/poste/$poste/detail?id=$id';
}
