// Rubrique PRODUCTION du compte back-office : construite avec les MÊMES
// paramètres que sidebar_widget.dart à partir de la session réelle
// (AuthService), avec ou sans `granted` dans la réponse de connexion — les six
// entrées restent visibles et chacune ouvre un écran autorisé par les gardes de
// routes (my_route.dart → readOnlyProductionRouteAllowed).
//
// Test WEB (le menu importe MyRoute, donc des écrans web uniquement) :
//   flutter test --platform chrome test/backoffice_production_menu_test.dart
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

// sidebar_item_model.dart est une `part` de sidebar_widget.dart.
import 'package:dash_master_toolkit/app_shell_route/components/sidebar/sidebar_widget.dart';
import 'package:dash_master_toolkit/core/config/read_only_access.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

const _expected = {
  'Production PROBAR': '/production/probar/fiches',
  'Production PROMESH': '/por-promesh/list',
  'Récapitulatif de production PROBAR': '/production/probar-summary',
  'Récapitulatif de production PROMESH': '/production/promesh-summary',
  'Consultation des fiches de production': '/production/records',
  'Historique de production': '/por-promesh/historique',
};

/// Menus tels que sidebar_widget.dart les construit pour la session courante.
List<GroupedMenuModel> _menusForSession() {
  final auth = AuthService();
  final role = auth.normalizedRole;
  return buildGroupedMenus(
    isAdmin: role == 'admin' || role == 'superadmin' || role == 'superadmin2',
    isCommercial: auth.usesCommercialScreens,
    isAccueil: role == 'accueil',
    isLogistiqueAchat: role == 'responsable_logistique_achat',
    isFinance: role == 'finance_probar',
    isFinanceProduction: role == 'finance_production',
    isControleQualite: role == 'controle_qualite',
    canViewCommercialKpi: auth.canViewCommercialKpi,
    canViewPorPromesh: auth.canViewPorPromesh,
    canViewFinance: auth.canViewFinance,
    hideIndustrialDashboard: auth.hideIndustrialDashboard,
    hideHrAndRecuperables: role == 'user' || auth.usesCommercialScreens,
    isRootAdmin: auth.isRootAdmin,
    isComplianceManager: auth.isComplianceManager,
    isProductionWorkflowManager: auth.isProductionWorkflowManager,
    isProbarProjectManager: auth.isProbarProjectManager,
    canViewRawMaterialRequests: auth.canViewRawMaterialRequests,
    canValidateRawMaterialRequests: auth.isRawMaterialRequestManager,
    canViewFicheApprovals: auth.canViewFicheApprovals,
    isReadOnly: auth.isReadOnly,
  );
}

Map<String, String> _productionEntries(List<GroupedMenuModel> groups) {
  final g = groups.where((g) => g.name == 'PRODUCTION').toList();
  if (g.isEmpty) return const {};
  return {for (final m in g.single.menus) m.name: m.navigationPath ?? ''};
}

Future<void> _backofficeSession(GetStorage box, {List<String>? granted}) async {
  // Mêmes clés que AuthService._persistSession (réponse de /auth/signin).
  await box.write('isLoggedIn', true);
  await box.write('accessToken', 'jeton-de-test');
  await box.write('userRole', kBackofficeReadOnlyRole);
  await box.write('userEmail', 'backoffice@cbi-tunisia.com');
  await box.write('readOnly', true);
  await box.write('referenceEmail', 'info@probardistribution.com');
  if (granted == null) {
    await box.remove('grantedPermissions');
  } else {
    await box.write('grantedPermissions', granted);
  }
}

void main() {
  late GetStorage box;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await GetStorage.init();
    box = GetStorage();
  });

  for (final (label, granted) in [
    ('serveur à jour (granted: production.read_all)', <String>[kProductionReadAll]),
    ('serveur pas encore à jour (pas de granted)', null),
  ]) {
    test('back-office, $label : les 6 rubriques Production sont visibles et leurs écrans autorisés', () async {
      await _backofficeSession(box, granted: granted);
      final entries = _productionEntries(_menusForSession());
      expect(entries, _expected);
      for (final path in entries.values) {
        expect(readOnlyProductionRouteAllowed(path), isTrue, reason: path);
      }
      expect(AuthService().canConsultProductionReadOnly, isTrue);
    });
  }

  test('contacts commerciaux et KPI du back-office inchangés', () async {
    await _backofficeSession(box, granted: [kProductionReadAll]);
    final names = _menusForSession().expand((g) => g.menus).map((m) => m.name).toList();
    expect(AuthService().canViewCommercialKpi, isTrue);
    expect(AuthService().usesCommercialScreens, isTrue);
    expect(AuthService().normalizedRole, kBackofficeReadOnlyRole);
    expect(names.any((n) => n.toLowerCase().contains('contact')), isTrue, reason: names.join(', '));
  });

  test('autres rôles : aucune rubrique PRODUCTION de consultation ajoutée', () async {
    for (final role in ['commercial', 'admin', 'superadmin', 'responsable_logistique_achat', 'user']) {
      await box.write('userRole', role);
      await box.remove('readOnly');
      await box.remove('referenceEmail');
      await box.remove('grantedPermissions');
      expect([role, _productionEntries(_menusForSession())], [role, const <String, String>{}]);
    }
  });
}
