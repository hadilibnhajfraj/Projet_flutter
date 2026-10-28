// lib/forms/raw_material_request/raw_material_request_paths.dart
//
// Chemins de la demande de matières premières, sans dépendance vers
// my_route.dart (même principe que QcPaths) : MyRoute y fait référence.

abstract final class RawMaterialPaths {
  static const request = '/melange/demande-matieres-premieres';
  // Menu « Matières premières » : suivi des demandes (groupe PRODUCTION).
  static const tracking = '/production/matieres-premieres';
  // Responsable logistique achats : demandes sans décision à valider / rejeter.
  static const toValidate = '/production/matieres-premieres/a-valider';
}

/// `?module=melange&retour=<chemin>` ; sans module : demande générale.
String rawMaterialRequestPath({String? module, String? returnTo}) => Uri(
      path: RawMaterialPaths.request,
      queryParameters: {
        if (module != null) 'module': module,
        if (returnTo != null) 'retour': returnTo,
      },
    ).toString();
