// Dashboard Production (VM).
//
// VRAI écran + VRAI service (Dio) ; le transport HTTP est un faux backend qui
// renvoie une réponse au format exact de GET /production-records/dashboard
// (les agrégations SQL elles-mêmes sont vérifiées côté backend :
// test/productionDashboard.test.js). L'écran n'affiche que ce que la réponse
// contient — chaque test vérifie qu'il suit les données et la période.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/production_dashboard/model/production_dashboard_model.dart';
import 'package:dash_master_toolkit/production_dashboard/view/production_dashboard_screen.dart';
import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/quality_control/quality_control_i18n.dart' show QcI18n;

Map<String, dynamic> _machine(String m, int fiches, int validees, double qty, double waste, {String? last, String? statut}) => {
      'machine': m,
      'label': 'Machine $m',
      'fiches': fiches,
      'validees': validees,
      'brouillons': fiches - validees,
      'archivees': 0,
      'quantite': qty,
      'dechets': waste,
      'tauxDechets': qty > 0 ? (waste / qty * 10000).round() / 100 : null,
      'lastDate': last,
      'lastStatut': statut,
      'active': fiches > 0,
    };

/// Réponse au format de GET /production-records/dashboard.
Map<String, dynamic> _dashboard(Map<String, String> q, {bool empty = false, bool own = false}) {
  final period = q['period'] ?? 'month';
  // Une période plus courte renvoie moins de fiches : l'écran doit suivre.
  final scale = period == 'today' ? 0 : 1;
  final has = !empty && scale == 1;
  return {
    'period': {'key': period, 'start': q['startDate'] ?? '2026-01-01', 'end': q['endDate'] ?? '2026-10-05'},
    'scope': own ? 'own' : 'all',
    'promesh': {
      'type': 'promesh',
      'label': 'PROMESH',
      'unit': 'm²',
      'wasteUnit': 'kg',
      'fiches': has ? 29 : 0,
      'validees': has ? 23 : 0,
      'brouillons': has ? 1 : 0,
      'archivees': has ? 5 : 0,
      'quantite': has ? 51358.5 : 0,
      'dechets': has ? 750 : 0,
      'tauxDechets': has ? 1.46 : null,
      'tauxDechetsUnit': 'kg / 100 m²',
      'machines': has
          ? [
              _machine('1', 18, 14, 30008, 750, last: '2026-09-28', statut: 'validee'),
              _machine('2', 9, 8, 19850.5, 0, last: '2026-09-28', statut: 'brouillon'),
              _machine('3', 1, 0, 0, 0, last: '2026-09-16', statut: 'archivee'),
              _machine('4', 1, 1, 1500, 0, last: '2026-08-27', statut: 'validee'),
            ]
          : [for (final m in ['1', '2', '3', '4']) _machine(m, 0, 0, 0, 0)],
    },
    'probar': {
      'type': 'probar',
      'label': 'PROBAR',
      'unit': 'm',
      'wasteUnit': 'kg',
      'fiches': has ? 5 : 0,
      'validees': has ? 3 : 0,
      'brouillons': 0,
      'archivees': has ? 2 : 0,
      'quantite': has ? 3145 : 0,
      'dechets': has ? 100 : 0,
      'tauxDechets': has ? 3.18 : null,
      'tauxDechetsUnit': 'kg / 100 m',
      'machines': [
        _machine('1', has ? 3 : 0, has ? 2 : 0, has ? 3145 : 0, has ? 100 : 0, last: has ? '2026-08-28' : null, statut: has ? 'validee' : null),
        for (final m in ['2', '3', '4']) _machine(m, 0, 0, 0, 0),
      ],
    },
    'production': {'fiches': has ? 34 : 0, 'validees': has ? 26 : 0, 'brouillons': has ? 1 : 0, 'archivees': has ? 7 : 0, 'today': 2},
    'machines': {'actives': has ? 5 : 0, 'total': 8},
    'waste': {'promesh': has ? 750 : 0, 'probar': has ? 100 : 0, 'total': has ? 850 : 0, 'unit': 'kg'},
    'charts': {
      'daily': has
          ? [
              {'date': '2026-08-12', 'promesh': 7800, 'probar': 0, 'fichesPromesh': 2, 'fichesProbar': 0, 'dechetsPromesh': 750, 'dechetsProbar': 0},
              {'date': '2026-08-28', 'promesh': 1500, 'probar': 3145, 'fichesPromesh': 1, 'fichesProbar': 3, 'dechetsPromesh': 0, 'dechetsProbar': 100},
              {'date': '2026-09-28', 'promesh': 2500, 'probar': 0, 'fichesPromesh': 2, 'fichesProbar': 0, 'dechetsPromesh': 0, 'dechetsProbar': 0},
            ]
          : [],
    },
    'recent': has
        ? [
            {'id': 'promesh:11111111-1111-1111-1111-111111111111', 'type': 'promesh', 'ligne': 'PROMESH', 'numero': 'PROMESH-2026-000886', 'date': '2026-09-28', 'machine': '1', 'poste': 'matin', 'userEmail': 'production_1@cbi-tunisia.com', 'quantite': 1250, 'quantiteUnite': 'm²', 'dechets': 12, 'dechetsUnite': 'kg', 'statut': 'validee'},
            {'id': 'probar:22222222-2222-2222-2222-222222222222', 'type': 'probar', 'ligne': 'PROBAR', 'numero': 'PROBAR-2026-E9EAAE', 'date': '2026-09-24', 'machine': '1', 'poste': 'nuit', 'userEmail': 'production_2@cbi-tunisia.com', 'quantite': null, 'quantiteUnite': 'm', 'dechets': null, 'dechetsUnite': 'kg', 'statut': 'archivee'},
            {'id': 'promesh:33333333-3333-3333-3333-333333333333', 'type': 'promesh', 'ligne': 'PROMESH', 'numero': 'PROMESH-2026-000867', 'date': '2026-09-24', 'machine': '2', 'poste': 'nuit', 'userEmail': 'production_1@cbi-tunisia.com', 'quantite': 600, 'quantiteUnite': 'm²', 'dechets': null, 'dechetsUnite': 'kg', 'statut': 'brouillon'},
          ]
        : [],
  };
}

class _FakeApi implements HttpClientAdapter {
  final requests = <Uri>[];
  bool empty = false;
  bool own = false;
  int? failWith;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(o.uri);
    final headers = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (failWith != null) {
      return ResponseBody.fromString(jsonEncode({'success': false, 'message': 'Accès refusé'}), failWith!, headers: headers);
    }
    return ResponseBody.fromString(jsonEncode({'success': true, 'data': _dashboard(o.uri.queryParameters, empty: empty, own: own)}), 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}

  List<Uri> get dashboardCalls => requests.where((u) => u.path.endsWith('/production-records/dashboard')).toList();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// L'écran dans un vrai GoRouter : les autres routes affichent leur chemin.
Future<void> _open(WidgetTester tester, {double width = 1440}) async {
  tester.view.physicalSize = Size(width, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/production/dashboard',
    routes: [
      GoRoute(path: '/production/dashboard', builder: (_, __) => const ProductionDashboardScreen()),
      GoRoute(path: '/:rest(.*)', builder: (_, state) => Scaffold(body: Text('ROUTE ${state.uri}'))),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await _settle(tester);
}

void main() {
  late _FakeApi api;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('prod_dash_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    GetStorage('GetStorage', dir.path, {'userRole': 'superadmin', 'userEmail': 'admin@cbi-tunisia.com'});
    await GetStorage.init();
  });

  setUp(() {
    api = _FakeApi();
    ApiClient.instance.dio.httpClientAdapter = api;
  });

  group('logique pure', () {
    test('formatage : milliers, décimales utiles, dates, statuts, postes', () {
      expect(prodFormatNumber(1250), '1 250');
      expect(prodFormatNumber(51358.5), '51 358,5');
      expect(prodFormatNumber(1.46), '1,46');
      expect(prodFormatNumber(0), '0');
      expect(prodFormatNumber(null), '—');
      expect(prodFormatNumber(double.nan), '—');
      expect(prodFormatQuantity(1250, 'm²'), '1 250 m²');
      expect(prodFormatQuantity(null, 'kg'), '—');
      expect(prodFormatDate('2026-09-28'), '28/09/2026');
      expect(prodFormatDate(null), '—');
      expect([prodStatusLabel('validee'), prodStatusLabel('archivee'), prodStatusLabel('brouillon'), prodStatusLabel(null)], ['Validée', 'Archivée', 'Brouillon', 'Brouillon']);
      expect([prodPosteLabel('matin'), prodPosteLabel('nuit'), prodPosteLabel(null)], ['Matin', 'Nuit', '—']);
      expect(prodUserLabel('production_1@cbi-tunisia.com'), 'production_1');
      expect(kProductionPeriods.map((p) => p.$2), ['Aujourd\'hui', 'Cette semaine', 'Ce mois', 'Cette année', 'Personnalisée']);
    });

    test('réponse API → modèle (lignes, machines, jours, dernières productions)', () {
      final d = ProductionDashboard.fromJson(_dashboard(const {'period': 'year'}));
      expect([d.promesh.fiches, d.promesh.validees, d.promesh.archivees, d.probar.fiches], [29, 23, 5, 5]);
      expect(d.promesh.quantite, 51358.5);
      expect(d.promesh.tauxDechetsUnit, 'kg / 100 m²');
      expect(d.promesh.machines.map((m) => m.machine), ['1', '2', '3', '4']);
      expect(d.promesh.machines[2].tauxDechets, isNull); // aucune production validée
      expect([d.machinesActives, d.machinesTotal, d.productionsToday, d.fiches], [5, 8, 2, 34]);
      expect(d.daily.map((x) => x.date), ['2026-08-12', '2026-08-28', '2026-09-28']);
      expect(d.recent.first.recordId, '11111111-1111-1111-1111-111111111111');
      expect(d.recent[1].quantite, isNull);
      expect(d.ownScope, isFalse);
      final empty = ProductionDashboard.fromJson(_dashboard(const {}, empty: true));
      expect([empty.fiches, empty.promesh.tauxDechets, empty.recent.length], [0, null, 0]);
    });
  });

  for (final width in [1440.0, 820.0, 390.0]) {
    testWidgets('${width.toInt()}px : KPI, cartes par machine, graphiques, dernières productions, accès rapides', (tester) async {
      await _open(tester, width: width);
      expect(tester.takeException(), isNull);

      // UN seul appel pour tout l'écran.
      expect(api.dashboardCalls, hasLength(1));
      expect(api.dashboardCalls.single.queryParameters['period'], 'year');

      expect(find.text('Dashboard Production'), findsOneWidget);
      expect(find.text('Actualiser'), findsOneWidget);

      // KPI : valeurs de l'API, unités réelles.
      for (final label in ['Fiches PROMESH', 'Fiches PROBAR', 'Machines actives', 'Productions aujourd\'hui']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final label in ['Productions validées', 'Quantité produite', 'Déchets', 'Taux de déchets']) {
        expect(find.text(label), findsNWidgets(2), reason: label); // PROMESH + PROBAR
      }
      expect(find.text('51 358,5'), findsWidgets);
      expect(find.text('3 145'), findsWidgets);
      expect(find.text('5 / 8'), findsOneWidget);
      expect(find.text('1,46'), findsWidgets);
      expect(find.text('kg / 100 m²'), findsWidgets); // ratio avec son unité, jamais un %
      expect(find.text('kg / 100 m'), findsWidgets);

      // Cartes PROMESH / PROBAR : quatre machines chacune.
      for (final type in ['promesh', 'probar']) {
        final card = find.byKey(ValueKey('prod-line-$type'));
        expect(card, findsOneWidget);
        for (final m in ['1', '2', '3', '4']) {
          expect(find.descendant(of: card, matching: find.byKey(ValueKey('prod-machine-$type-$m'))), findsOneWidget, reason: '$type M$m');
        }
      }
      final m1 = find.byKey(const ValueKey('prod-machine-promesh-1'));
      expect(find.descendant(of: m1, matching: find.text('30 008 m²')), findsOneWidget);
      expect(find.descendant(of: m1, matching: find.text('18 fiche(s)')), findsOneWidget);
      expect(find.descendant(of: m1, matching: find.text('750 kg')), findsOneWidget);
      expect(find.descendant(of: m1, matching: find.text('28/09/2026')), findsOneWidget);
      expect(find.descendant(of: m1, matching: find.text('Validée')), findsOneWidget);
      // Machine sans fiche : dit clairement, aucune valeur inventée.
      final idle = find.byKey(const ValueKey('prod-machine-probar-3'));
      expect(find.descendant(of: idle, matching: find.text('Aucune fiche sur la période')), findsOneWidget);
      expect(find.descendant(of: idle, matching: find.text('Aucune production')), findsOneWidget);

      // Graphiques : production par jour (une échelle par ligne), statuts, déchets.
      expect(find.byKey(const ValueKey('prod-chart-daily-promesh')), findsOneWidget);
      expect(find.byKey(const ValueKey('prod-chart-daily-probar')), findsOneWidget);
      expect(find.byKey(const ValueKey('prod-chart-status')), findsOneWidget);
      expect(find.byKey(const ValueKey('prod-chart-waste')), findsOneWidget);
      expect(find.byType(BarChart), findsNWidgets(3));
      expect(find.byType(LineChart), findsOneWidget);

      // Dernières productions : colonnes, valeurs, badges.
      for (final column in ['DATE', 'RÉFÉRENCE', 'LIGNE', 'MACHINE', 'POSTE', 'UTILISATEUR', 'QUANTITÉ', 'DÉCHETS', 'STATUT', 'ACTION']) {
        expect(find.text(column), findsWidgets, reason: column);
      }
      final row = find.byKey(const ValueKey('prod-recent-promesh:11111111-1111-1111-1111-111111111111'));
      for (final text in ['28/09/2026', 'PROMESH-2026-000886', 'Machine 1', 'Matin', 'production_1', '1 250 m²', '12 kg', 'Validée', 'Voir']) {
        expect(find.descendant(of: row, matching: find.text(text)), findsOneWidget, reason: text);
      }
      final archived = find.byKey(const ValueKey('prod-recent-probar:22222222-2222-2222-2222-222222222222'));
      expect(find.descendant(of: archived, matching: find.text('Archivée')), findsOneWidget);
      expect(find.descendant(of: archived, matching: find.text('—')), findsNWidgets(2)); // quantité et déchets absents
      expect(find.descendant(of: find.byKey(const ValueKey('prod-recent-promesh:33333333-3333-3333-3333-333333333333')), matching: find.text('Brouillon')), findsOneWidget);

      // Accès rapides.
      for (final id in ['new-promesh', 'new-probar', 'summary-promesh', 'summary-probar', 'records', 'summary']) {
        expect(find.byKey(ValueKey('prod-link-$id')), findsOneWidget, reason: id);
      }
      expect(find.textContaining('NaN'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filtre période : chaque choix recharge tout ; personnalisée attend les deux dates', (tester) async {
    await _open(tester);
    expect(find.text('34'), findsNothing); // total non affiché tel quel
    expect(find.text('29'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('prod-period-today')));
    await _settle(tester);
    expect(api.dashboardCalls.last.queryParameters['period'], 'today');
    // Aucune fiche aujourd'hui : zéros réels et états vides, aucun graphique.
    expect(find.text('29'), findsNothing);
    expect(find.text('N/A'), findsWidgets); // taux non calculable
    expect(find.byType(BarChart), findsNothing);
    expect(find.byType(LineChart), findsNothing);
    for (final text in ['Aucune production validée sur cette période', 'Aucune fiche sur cette période', 'Aucun déchet déclaré sur cette période', 'Aucune production sur cette période']) {
      expect(find.text(text), findsWidgets, reason: text);
    }

    for (final period in ['week', 'month', 'year']) {
      await tester.tap(find.byKey(ValueKey('prod-period-$period')));
      await _settle(tester);
      expect(api.dashboardCalls.last.queryParameters['period'], period);
    }
    expect(find.text('29'), findsWidgets);

    // Personnalisée : aucun appel tant que les dates ne sont pas choisies.
    final before = api.dashboardCalls.length;
    await tester.tap(find.byKey(const ValueKey('prod-period-custom')));
    await _settle(tester);
    expect(api.dashboardCalls, hasLength(before));
    expect(find.text('Choisissez une date de début et une date de fin.'), findsOneWidget);
    expect(find.byKey(const ValueKey('prod-date-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('prod-date-end')), findsOneWidget);
    for (final key in ['prod-date-start', 'prod-date-end']) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      await _settle(tester);
    }
    final custom = api.dashboardCalls.last.queryParameters;
    expect(custom['period'], 'custom');
    expect(custom['startDate'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(custom['endDate'], custom['startDate']);
    expect(api.dashboardCalls, hasLength(before + 1));

    // Actualiser : même période, nouvelle lecture.
    await tester.tap(find.byKey(const ValueKey('prod-refresh')));
    await _settle(tester);
    expect(api.dashboardCalls, hasLength(before + 2));
    expect(api.dashboardCalls.last.queryParameters['period'], 'custom');
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation : accès rapides et « Voir » ouvrent les écrans existants', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('prod-link-new-probar')));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /production/probar'), findsOneWidget);

    await _open(tester);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('prod-recent-promesh:11111111-1111-1111-1111-111111111111')), matching: find.text('Voir')));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /production/promesh/machine/1/poste/matin/modules?ficheId=11111111-1111-1111-1111-111111111111'), findsOneWidget);

    await _open(tester);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('prod-recent-probar:22222222-2222-2222-2222-222222222222')), matching: find.text('Voir')));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /production/probar/machine/1/poste/nuit/detail?id=22222222-2222-2222-2222-222222222222'), findsOneWidget);

    await _open(tester);
    await tester.tap(find.text('Toutes les fiches'));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /production/records'), findsOneWidget);
  });

  testWidgets('périmètre personnel signalé ; erreur de l\'API affichée, aucun chiffre inventé', (tester) async {
    api.own = true;
    await _open(tester);
    expect(find.text('Périmètre : vos propres fiches de production.'), findsOneWidget);

    api = _FakeApi()..failWith = 403;
    ApiClient.instance.dio.httpClientAdapter = api;
    await _open(tester);
    expect(find.textContaining('Accès refusé'), findsOneWidget);
    expect(find.text('Indicateurs'), findsNothing);
    expect(find.byType(BarChart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English — production dashboard: no French left', (tester) async {
    QcI18n.language.value = 'en';
    QcI18n.missing.clear();
    addTearDown(() {
      QcI18n.language.value = 'fr';
      QcI18n.missing.clear();
    });
    await _open(tester);
    for (final text in ['Production Dashboard', 'Refresh', 'Period', 'Indicators', 'PROMESH sheets', 'Quantity produced', 'Waste rate', 'Active machines', 'Production by machine', 'Production by day', 'Waste trend', 'Latest productions', 'Quick access', 'New PROMESH sheet', 'Validated', 'Archived', '18 sheet(s)']) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('Dernières productions'), findsNothing);
    expect(QcI18n.frenchResidue(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
