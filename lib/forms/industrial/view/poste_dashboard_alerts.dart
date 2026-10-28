// lib/forms/industrial/view/poste_dashboard_alerts.dart
//
// Données réelles du panneau « Alertes et actions requises » des pages
// machine/poste PROMESH et PROBAR — uniquement des API EXISTANTES, appelées
// seulement pour les rôles qui y ont accès (le backend revérifie) :
// - fiches refusées / en attente : GET /production-fiche-approvals/summary
//   filtré par ligne, machine et poste (toutes dates) ;
// - demandes de matières premières non traitées : sources du tableau de bord
//   industriel (pending-summary pour le validateur, ses demandes pour le
//   demandeur).
// Une source refusée ou en erreur ne produit AUCUNE alerte (jamais un nombre
// inventé).

import 'package:flutter/foundation.dart';

import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_record.dart';
import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_service.dart';
import 'package:dash_master_toolkit/production_dashboard/service/industrial_dashboard_sources.dart';

class PosteAlertData {
  final int? rejected;
  final int? pending;
  final RawMaterialOverview? raw;
  const PosteAlertData({this.rejected, this.pending, this.raw});
}

Future<PosteAlertData> loadPosteAlertData({
  required String type, // promesh | probar
  required String machine,
  required String poste,
  IndustrialDashboardAccess? access,
  FicheApprovalApi? approvals,
  IndustrialDashboardSources? sources,
}) async {
  final a = access ?? IndustrialDashboardAccess.fromAuth();
  Future<FicheApprovalCounts?> counts() async {
    if (!a.canViewFicheApprovals) return null;
    try {
      return await (approvals ?? FicheApprovalService.instance).summary(FicheApprovalFilters(type: type, machine: machine, poste: poste));
    } catch (e) {
      debugPrint('[PosteAlerts] validation des fiches indisponible : $e');
      return null;
    }
  }

  final results = await Future.wait<Object?>([
    counts(),
    (sources ?? ApiIndustrialDashboardSources()).rawMaterials(a),
  ]);
  final c = results[0] as FicheApprovalCounts?;
  final raw = results[1] as DashboardSource<RawMaterialOverview>;
  return PosteAlertData(rejected: c?.rejected, pending: c?.pending, raw: raw.data);
}
