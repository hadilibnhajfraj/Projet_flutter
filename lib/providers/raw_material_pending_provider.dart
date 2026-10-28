// lib/providers/raw_material_pending_provider.dart
//
// Nombre de demandes de matières premières « En attente de validation »,
// pour le badge [N] du menu « Matières premières » du responsable
// logistique achats. Même mécanisme que ProductionUnarchiveRequestProvider
// (polling léger, compteur relu depuis le backend). Jamais chargé pour un
// autre compte — le sidebar ne l'instancie que si
// AuthService.isRawMaterialRequestValidator.
import 'package:get/get.dart';

import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_tracking_service.dart';
import 'package:dash_master_toolkit/services/socket_service.dart';

class RawMaterialPendingProvider extends GetxController {
  static RawMaterialPendingProvider get to {
    if (!Get.isRegistered<RawMaterialPendingProvider>()) {
      Get.put(RawMaterialPendingProvider());
    }
    return Get.find<RawMaterialPendingProvider>();
  }

  final _polling = PollingService();

  final pendingCount = 0.obs;
  final overdueCount = 0.obs;

  void _onRemoteUpdate(dynamic _) => load();

  @override
  void onInit() {
    super.onInit();
    SocketService.instance.on('raw-material-request:updated', _onRemoteUpdate);
    load();
    _polling.start(interval: const Duration(seconds: 30), onTick: () async { try { await load(); } catch (_) {} });
  }

  @override
  void onClose() {
    SocketService.instance.off('raw-material-request:updated', _onRemoteUpdate);
    _polling.stop();
    super.onClose();
  }

  Future<void> load() async {
    try {
      final s = await RawMaterialTrackingService.instance.pendingSummary();
      pendingCount.value = s.pending;
      overdueCount.value = s.overdue;
    } catch (_) {
      // Erreur réseau : le badge garde sa dernière valeur connue.
    }
  }
}
