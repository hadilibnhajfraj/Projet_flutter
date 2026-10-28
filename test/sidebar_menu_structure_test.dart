// Structure du Sidebar par rôle (buildTopMenus / buildGroupedMenus).
//
// Vérifie, pour chaque rôle : aucune destination en double, ordre des
// catégories du Superadmin, cloisonnement des espaces dédiés, existence de
// chaque route dans le GoRouter et présence des libellés en FR et EN.

//
// Lancer avec : flutter test --platform chrome test/sidebar_menu_structure_test.dart
// (les routes importent des écrans web — dart:html).

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/app_shell_route/components/sidebar/sidebar_widget.dart';
import 'package:dash_master_toolkit/route/my_route.dart';

class _Menu {
  _Menu(this.top, this.groups);
  final List<SidebarItemModel> top;
  final List<GroupedMenuModel> groups;

  List<String> get groupNames => groups.map((g) => g.name).toList();

  List<SidebarItemModel> get items => [...top, ...groups.expand((g) => g.menus)];

  /// Destinations réellement cliquables (tuile, ou chaque sous-menu).
  List<String> get targets => [
        for (final m in items)
          if (m.sidebarItemType == SidebarItemType.tile)
            m.navigationPath!
          else
            for (final s in m.submenus!)
              s.navigationPath!.startsWith('/')
                  ? s.navigationPath!
                  : '${m.navigationPath}/${s.navigationPath}',
      ];

  /// Tous les libellés traduits (groupes, tuiles, sous-menus).
  Set<String> get labels => {
        ...groupNames,
        for (final m in items) ...[m.name, ...?m.submenus?.map((s) => s.name)],
      };
}

_Menu _menu({
  bool isAdmin = false,
  bool isCommercial = false,
  bool isAccueil = false,
  bool isLogistiqueAchat = false,
  bool isFinance = false,
  bool isFinanceProduction = false,
  bool isControleQualite = false,
  bool canViewCommercialKpi = false,
  bool canViewPorPromesh = false,
  bool canViewFinance = false,
  bool hideIndustrialDashboard = false,
  bool hideHrAndRecuperables = false,
  bool isRestrictedAdmin = false,
  bool isRootAdmin = false,
  bool isComplianceManager = false,
  bool isProductionWorkflowManager = false,
}) =>
    _Menu(
      buildTopMenus(isLogistiqueAchat: isLogistiqueAchat, isFinanceProduction: isFinanceProduction),
      buildGroupedMenus(
        isAdmin: isAdmin,
        isCommercial: isCommercial,
        isAccueil: isAccueil,
        isLogistiqueAchat: isLogistiqueAchat,
        isFinance: isFinance,
        isFinanceProduction: isFinanceProduction,
        isControleQualite: isControleQualite,
        canViewCommercialKpi: canViewCommercialKpi,
        canViewPorPromesh: canViewPorPromesh,
        canViewFinance: canViewFinance,
        hideIndustrialDashboard: hideIndustrialDashboard,
        hideHrAndRecuperables: hideHrAndRecuperables,
        isRestrictedAdmin: isRestrictedAdmin,
        isRootAdmin: isRootAdmin,
        isComplianceManager: isComplianceManager,
        isProductionWorkflowManager: isProductionWorkflowManager,
      ),
    );

final _superadmin = _menu(
  isAdmin: true,
  canViewCommercialKpi: true,
  canViewPorPromesh: true,
  canViewFinance: true,
  isRootAdmin: true,
  isComplianceManager: true,
);

final Map<String, _Menu> _roles = {
  'superadmin': _superadmin,
  'admin (non root)': _menu(isAdmin: true, canViewCommercialKpi: true, canViewPorPromesh: true, canViewFinance: true),
  'admin restreint': _menu(isAdmin: true, canViewCommercialKpi: true, canViewPorPromesh: true, isRestrictedAdmin: true),
  'user': _menu(hideHrAndRecuperables: true),
  'commercial': _menu(isCommercial: true, canViewCommercialKpi: true, hideHrAndRecuperables: true),
  'accueil': _menu(isAccueil: true),
  'responsable_logistique_achat': _menu(isLogistiqueAchat: true, canViewPorPromesh: true, isProductionWorkflowManager: true),
  'finance_probar': _menu(isFinance: true, canViewFinance: true),
  'finance_production': _menu(isFinanceProduction: true, canViewPorPromesh: true, canViewFinance: true),
  'controle_qualite': _menu(isControleQualite: true),
};

Future<Map<String, dynamic>> _lang(String code) async =>
    jsonDecode(await rootBundle.loadString('assets/lang/$code.json')) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Superadmin', () {
    test('catégories dans l\'ordre demandé', () {
      expect(_superadmin.top, isEmpty);
      expect(_superadmin.groupNames.take(6), [
        'TABLEAU DE BORD',
        'PROJECT MANAGEMENT',
        'PRODUCTION',
        'MÉLANGE',
        'FINANCE',
        'CONTRÔLE QUALITÉ',
      ]);
      expect(_superadmin.groupNames, isNot(contains('SUPER ADMIN')));
      expect(_superadmin.groupNames, isNot(contains('MY PROJECTS')));
      expect(_superadmin.groupNames.toSet().length, _superadmin.groupNames.length);
    });

    test('contenu des catégories principales', () {
      List<String> names(String group) =>
          _superadmin.groups.firstWhere((g) => g.name == group).menus.map((m) => m.name).toList();

      expect(names('TABLEAU DE BORD'), [
        'KPI Projets CRM',
        'KPI Commercial Contacts',
        'Tableau de bord industriel',
      ]);
      expect(names('PRODUCTION'), [
        'PROMESH',
        'Récapitulatif de production PROMESH',
        'PROBAR',
        'Récapitulatif de production PROBAR',
      ]);
      expect(names('FINANCE'), [
        'Tableau de bord Finance',
        'Inflow of Raw Materials',
        'Bons de livraison',
        'Expéditions facturées',
        'Factures payées',
      ]);
      expect(names('CONTRÔLE QUALITÉ'),
          ['Contrôle Qualité', 'PROMESH', 'PROBAR', 'Historique', 'Comparaison qualité']);
    });

    test('production et contrôle qualité ne partagent aucune route', () {
      List<String> targetsOf(String group) =>
          _Menu(const [], [_superadmin.groups.firstWhere((g) => g.name == group)]).targets;
      expect(targetsOf('PRODUCTION').every((p) => p.startsWith('${MyRoute.productionRoot}/')), isTrue);
      expect(targetsOf('CONTRÔLE QUALITÉ').every((p) => p.startsWith(MyRoute.qualityControlRoot)), isTrue);
    });
  });

  group('Tous les rôles', () {
    for (final entry in _roles.entries) {
      test('${entry.key} : aucune destination en double', () {
        final targets = entry.value.targets;
        final dupes = targets.where((t) => targets.indexOf(t) != targets.lastIndexOf(t)).toSet();
        expect(dupes, isEmpty);
      });
    }

    test('chaque destination existe dans le GoRouter', () {
      final config = MyRoute.router.configuration;
      final all = _roles.values.expand((m) => m.targets).toSet();
      for (final path in all) {
        expect(config.findMatch(Uri.parse(path)).isNotEmpty, isTrue, reason: path);
      }
    });

    test('chaque libellé est traduit en FR et EN', () async {
      final en = await _lang('en');
      final fr = await _lang('fr');
      final labels = _roles.values.expand((m) => m.labels).toSet();
      expect(labels.where((l) => !en.containsKey(l)), isEmpty, reason: 'en.json');
      expect(labels.where((l) => !fr.containsKey(l)), isEmpty, reason: 'fr.json');
    });
  });

  group('Permissions', () {
    test('espaces dédiés cloisonnés', () {
      expect(_roles['controle_qualite']!.groupNames, ['CONTRÔLE QUALITÉ']);
      expect(_roles['controle_qualite']!.top, isEmpty);
      expect(_roles['finance_probar']!.groupNames, ['FINANCE']);
      expect(_roles['finance_production']!.groupNames, ['PRODUCTION', 'MÉLANGE', 'MAINTENANCE', 'FINANCE']);
      expect(_roles['finance_production']!.top.single.navigationPath, MyRoute.porPromeshDashboardScreen);
      expect(_roles['responsable_logistique_achat']!.groupNames,
          ['PRODUCTION', 'MÉLANGE', 'MAINTENANCE', 'RH', 'RÉCUPÉRABLES', 'ADMINISTRATION']);
      expect(_roles['accueil']!.groupNames, ['ACCUEIL']);
    });

    test('« Tableau de bord général » retiré du menu pour tous les rôles', () {
      for (final m in _roles.values) {
        expect(m.targets, isNot(contains(MyRoute.superAdminDashboardScreen)));
      }
    });

    test('admin restreint : ni industriel, ni finance, ni qualité, ni tableau de bord général', () {
      final m = _roles['admin restreint']!;
      for (final g in ['PRODUCTION', 'MÉLANGE', 'MAINTENANCE', 'FINANCE', 'CONTRÔLE QUALITÉ', 'RH']) {
        expect(m.groupNames, isNot(contains(g)));
      }
      expect(m.targets, isNot(contains(MyRoute.superAdminDashboardScreen)));
      expect(m.targets, isNot(contains(MyRoute.productionDashboardScreen)));
    });

    test('user : un seul "Mes Projets", pas de menus admin', () {
      final m = _roles['user']!;
      expect(m.items.where((i) => i.name == 'Mes Projets').length, 1);
      expect(m.targets, isNot(contains(MyRoute.superAdminDashboardScreen)));
      expect(m.groupNames, isNot(contains('USER MANAGEMENT')));
      expect(m.groupNames, isNot(contains('CONTRÔLE QUALITÉ')));
    });

    test('commercial : KPI Contacts commerciaux une seule fois', () {
      final m = _roles['commercial']!;
      expect(m.targets.where((t) => t == MyRoute.commercialContactsKpiUsers).length, 1);
      expect(m.targets, isNot(contains(MyRoute.dashboardSalesAdmin)));
    });
  });
}
