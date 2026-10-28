// lib/production_dashboard/service/industrial_dashboard_sources.dart
//
// Données du Tableau de bord industriel qui ne viennent PAS de
// GET /production-records/dashboard : demandes de matières premières, fiches
// de production manquantes et demandes d'autorisation Production. Chaque
// source appelle l'API EXISTANTE de son module (le backend reste seul juge des
// droits) ; une source refusée (403) ou indisponible est signalée comme telle
// — jamais remplacée par un zéro.

import 'package:dio/dio.dart' show DioException;

import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_record.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_tracking_service.dart';
import 'package:dash_master_toolkit/production_compliance/service/production_compliance_service.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

/// Résultat d'une source secondaire : donnée, non accessible au profil
/// (aucune requête envoyée ou 403), ou erreur d'API.
class DashboardSource<T> {
  final T? data;
  final bool forbidden;
  final String? error;

  const DashboardSource.data(T this.data)
      : forbidden = false,
        error = null;
  const DashboardSource.forbidden()
      : data = null,
        forbidden = true,
        error = null;
  const DashboardSource.error(String this.error)
      : data = null,
        forbidden = false;

  bool get hasData => data != null;
}

/// Droits d'affichage du tableau de bord — mêmes règles que le menu
/// (AuthService) ; le backend revérifie chaque appel.
class IndustrialDashboardAccess {
  final bool canViewRawMaterials;
  final bool isRawMaterialValidator;
  final bool canViewFicheApprovals;
  final bool isFicheApprovalValidator;
  final bool canManageProductionRequests;
  final bool canCreateFiches;

  const IndustrialDashboardAccess({
    this.canViewRawMaterials = false,
    this.isRawMaterialValidator = false,
    this.canViewFicheApprovals = false,
    this.isFicheApprovalValidator = false,
    this.canManageProductionRequests = false,
    this.canCreateFiches = true,
  });

  factory IndustrialDashboardAccess.fromAuth() {
    final a = AuthService();
    return IndustrialDashboardAccess(
      canViewRawMaterials: a.canViewRawMaterialRequests,
      isRawMaterialValidator: a.isRawMaterialRequestValidator,
      canViewFicheApprovals: a.canViewFicheApprovals,
      isFicheApprovalValidator: a.isFicheApprovalValidator,
      canManageProductionRequests: a.canManageProductionRequests,
    );
  }
}

/// Demandes de matières premières vues par le compte connecté.
class RawMaterialOverview {
  /// En attente de traitement : demandes à valider (validateur) ou demandes
  /// du compte en attente de validation (demandeur).
  final int pending;
  final int overdue; // validateur : en retard sur l'échéance
  final bool isValidator;
  final List<RawMaterialRequestRecord> latest;
  final int total;

  const RawMaterialOverview({required this.pending, this.overdue = 0, required this.isValidator, this.latest = const [], this.total = 0});
}

abstract class IndustrialDashboardSources {
  Future<DashboardSource<RawMaterialOverview>> rawMaterials(IndustrialDashboardAccess access);

  /// Fiches de production manquantes du compte connecté (comptes suivis par
  /// le contrôle de conformité) — null : compte non suivi.
  Future<DashboardSource<int?>> missingProductionSheets();

  /// Demandes d'autorisation Production en attente (responsables).
  Future<DashboardSource<int>> pendingProductionRequests(IndustrialDashboardAccess access);
}

String _message(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return 'Erreur ${e.response?.statusCode ?? 'réseau'}';
  }
  return e.toString().replaceFirst('Exception: ', '');
}

bool _isForbidden(Object e) => e is DioException && (e.response?.statusCode == 403 || e.response?.statusCode == 401);

class ApiIndustrialDashboardSources implements IndustrialDashboardSources {
  final RawMaterialTrackingApi rawApi;
  ApiIndustrialDashboardSources({RawMaterialTrackingApi? rawApi}) : rawApi = rawApi ?? RawMaterialTrackingService.instance;

  static const latestCount = 6;

  @override
  Future<DashboardSource<RawMaterialOverview>> rawMaterials(IndustrialDashboardAccess access) async {
    if (!access.canViewRawMaterials) return const DashboardSource.forbidden();
    try {
      final perms = await rawApi.permissions();
      if (!perms.canView) return const DashboardSource.forbidden();
      final latest = await rawApi.list(const RawMaterialFilters(pageSize: latestCount));
      if (access.isRawMaterialValidator && perms.canValidate) {
        final s = await rawApi.pendingSummary();
        return DashboardSource.data(RawMaterialOverview(pending: s.pending, overdue: s.overdue, isValidator: true, latest: latest.items, total: latest.total));
      }
      final mine = await rawApi.list(const RawMaterialFilters(status: 'PENDING_VALIDATION', pageSize: 1));
      return DashboardSource.data(RawMaterialOverview(pending: mine.total, isValidator: false, latest: latest.items, total: latest.total));
    } catch (e) {
      return _isForbidden(e) ? const DashboardSource.forbidden() : DashboardSource.error(_message(e));
    }
  }

  @override
  Future<DashboardSource<int?>> missingProductionSheets() async {
    try {
      final me = await ProductionComplianceService.instance.me();
      if (me['monitored'] != true) return const DashboardSource.data(null);
      final dates = me['missingDates'];
      return DashboardSource.data(dates is List ? dates.length : 0);
    } catch (e) {
      return _isForbidden(e) ? const DashboardSource.forbidden() : DashboardSource.error(_message(e));
    }
  }

  @override
  Future<DashboardSource<int>> pendingProductionRequests(IndustrialDashboardAccess access) async {
    if (!access.canManageProductionRequests) return const DashboardSource.forbidden();
    try {
      final stats = await ProductionComplianceService.instance.requestStats();
      return DashboardSource.data((stats['PENDING'] as num?)?.toInt() ?? 0);
    } catch (e) {
      return _isForbidden(e) ? const DashboardSource.forbidden() : DashboardSource.error(_message(e));
    }
  }
}
