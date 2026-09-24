// lib/providers/production_compliance_request_provider.dart
//
// État partagé des demandes de régularisation PROD 1 / PROD 2, pour :
//   - le badge [N] de "Administration > Demandes > Production — Demandes
//     d'autorisation" dans le sidebar (compte UNIQUEMENT les PENDING) ;
//   - l'écran ProductionComplianceScreen (liste + Approve/Reject).
// Même mécanisme de rafraîchissement que MaintenanceRequestProvider (l'un des
// mécanismes déjà en place dans l'app) : polling léger, pas de nouveau système.
// Le backend reste la seule autorité de sécurité (requireManager) — ce
// provider n'est jamais instancié/chargé pour un compte non autorisé (voir
// isComplianceManager, vérifié avant toute navigation vers cet écran).
import 'package:get/get.dart';

import 'package:dash_master_toolkit/production_compliance/service/production_compliance_service.dart';
import 'package:dash_master_toolkit/services/socket_service.dart';

class ProductionComplianceRequestProvider extends GetxController {
  static ProductionComplianceRequestProvider get to {
    if (!Get.isRegistered<ProductionComplianceRequestProvider>()) {
      Get.put(ProductionComplianceRequestProvider());
    }
    return Get.find<ProductionComplianceRequestProvider>();
  }

  final _svc = ProductionComplianceService.instance;
  final _polling = PollingService();

  final requests = <Map<String, dynamic>>[].obs;
  final stats = <String, int>{}.obs;
  final loading = true.obs;

  /// Compte AFFICHÉ SUR LE BADGE — uniquement PENDING (jamais APPROVED/
  /// REJECTED/EXPIRED/USED), recalculé côté serveur (requestStats) et par
  /// cohérence locale (requests.length) pour ne jamais désynchroniser badge
  /// et liste affichée.
  int get pendingCount => stats['PENDING'] ?? requests.where((r) => r['status'] == 'PENDING').length;

  @override
  void onInit() {
    super.onInit();
    load();
    _startPolling();
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
      // Refus (compte non autorisé) ou erreur réseau : le badge disparaît
      // simplement (pendingCount = 0 via stats vide) plutôt que de planter.
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

  void _startPolling() {
    _polling.start(
      interval: const Duration(seconds: 20),
      onTick: () async {
        try {
          await load();
        } catch (_) {}
      },
    );
  }
}
