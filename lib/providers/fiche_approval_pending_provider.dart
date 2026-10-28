// lib/providers/fiche_approval_pending_provider.dart
//
// Nombre de fiches de production « En attente de validation », pour le
// badge [N] du menu « Validation des fiches de production » du responsable
// logistique. Même mécanisme que RawMaterialPendingProvider (polling
// léger) ; jamais chargé pour un autre compte — le sidebar ne l'instancie
// que si AuthService.isFicheApprovalValidator.
import 'package:get/get.dart';

import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_service.dart';
import 'package:dash_master_toolkit/services/socket_service.dart';

class FicheApprovalPendingProvider extends GetxController {
  static FicheApprovalPendingProvider get to {
    if (!Get.isRegistered<FicheApprovalPendingProvider>()) {
      Get.put(FicheApprovalPendingProvider());
    }
    return Get.find<FicheApprovalPendingProvider>();
  }

  final _polling = PollingService();

  final pendingCount = 0.obs;

  void _onRemoteUpdate(dynamic _) => load();

  @override
  void onInit() {
    super.onInit();
    SocketService.instance.on('production-fiche-approval:updated', _onRemoteUpdate);
    load();
    _polling.start(interval: const Duration(seconds: 30), onTick: () async { try { await load(); } catch (_) {} });
  }

  @override
  void onClose() {
    SocketService.instance.off('production-fiche-approval:updated', _onRemoteUpdate);
    _polling.stop();
    super.onClose();
  }

  Future<void> load() async {
    try {
      pendingCount.value = (await FicheApprovalService.instance.summary()).pending;
    } catch (_) {
      // Erreur réseau : le badge garde sa dernière valeur connue.
    }
  }
}
