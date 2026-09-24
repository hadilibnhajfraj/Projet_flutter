// lib/providers/production_unarchive_request_provider.dart
//
// État partagé des demandes de désarchivage PROMESH/PROBAR, pour :
//   - le badge [N] de "Administration > Demandes > Production — Unarchive
//     Requests" (compte UNIQUEMENT les PENDING) ;
//   - l'écran ProductionUnarchiveRequestsScreen (liste + Approve/Reject).
// Même mécanisme que ProductionComplianceRequestProvider (polling léger,
// aucun nouveau système). Jamais chargé pour un compte non autorisé — le
// sidebar ne l'instancie que si isComplianceManager.
import 'package:get/get.dart';

import 'package:dash_master_toolkit/production_compliance/service/production_draft_archive_service.dart';
import 'package:dash_master_toolkit/services/socket_service.dart';

class ProductionUnarchiveRequestProvider extends GetxController {
  static ProductionUnarchiveRequestProvider get to {
    if (!Get.isRegistered<ProductionUnarchiveRequestProvider>()) {
      Get.put(ProductionUnarchiveRequestProvider());
    }
    return Get.find<ProductionUnarchiveRequestProvider>();
  }

  final _svc = ProductionDraftArchiveService.instance;
  final _polling = PollingService();

  final requests = <Map<String, dynamic>>[].obs;
  final stats = <String, int>{}.obs;
  final loading = true.obs;

  int get pendingCount => stats['PENDING'] ?? requests.where((r) => r['status'] == 'PENDING').length;

  @override
  void onInit() {
    super.onInit();
    load();
    _polling.start(interval: const Duration(seconds: 20), onTick: () async { try { await load(); } catch (_) {} });
  }

  @override
  void onClose() {
    _polling.stop();
    super.onClose();
  }

  Future<void> load() async {
    loading.value = true;
    try {
      final results = await Future.wait([_svc.listRequests(), _svc.requestStats()]);
      requests.value = results[0] as List<Map<String, dynamic>>;
      final s = results[1] as Map<String, dynamic>;
      stats.value = {for (final e in s.entries) e.key: (e.value as num?)?.toInt() ?? 0};
    } catch (_) {
      // Compte non autorisé ou erreur réseau : le badge disparaît simplement.
    } finally {
      loading.value = false;
    }
  }

  Future<Map<String, dynamic>> approveRequest(String id, {String? note}) async {
    final res = await _svc.approveRequest(id, note: note);
    await load();
    return res;
  }

  Future<Map<String, dynamic>> rejectRequest(String id, {required String note}) async {
    final res = await _svc.rejectRequest(id, note: note);
    await load();
    return res;
  }
}
