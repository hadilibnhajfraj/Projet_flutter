// Tableau de bord industriel (VM).
//
// VRAI écran + VRAI service du dashboard (Dio) ; le transport HTTP est un faux
// backend qui renvoie une réponse au format exact de
// GET /production-records/dashboard (les agrégations SQL elles-mêmes sont
// vérifiées côté backend : test/productionDashboard.test.js). Les sources
// secondaires (demandes de matières premières, conformité) sont remplacées par
// un double qui renvoie des données, un refus ou une erreur. L'écran n'affiche
// que ce que les réponses contiennent — chaque test vérifie qu'il les suit.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_record.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_tracking_service.dart';
import 'package:dash_master_toolkit/production_dashboard/model/production_dashboard_model.dart';
import 'package:dash_master_toolkit/production_dashboard/service/industrial_dashboard_sources.dart';
import 'package:dash_master_toolkit/production_dashboard/view/production_dashboard_screen.dart';
import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/quality_control/quality_control_i18n.dart' show QcI18n;

const _rejectedId = 'promesh:44444444-4444-4444-4444-444444444444';

Map<String, dynamic> _machine(String m, int fiches, int validees, double qty, double waste, {String? last, String? statut}) => {
      'machine': m,
      'label': 'Machine $m',
      'fiches': fiches,
      'validees': validees,
      'brouillons': fiches - validees,
      'archivees': 0,
      'actives': fiches,
      'acceptees': 0,
      'enAttente': 0,
      'refusees': 0,
      'horsCircuit': fiches,
      'quantite': qty,
      'dechets': waste,
      'tauxDechets': qty > 0 ? (waste / qty * 10000).round() / 100 : null,
      'lastDate': last,
      'lastStatut': statut,
      'lastActivityAt': last == null ? null : '${last}T07:30:00Z',
      'active': fiches > 0,
    };

/// Réponse au format de GET /production-records/dashboard.
Map<String, dynamic> _dashboard(Map<String, String> q, {bool empty = false, bool own = false, bool noAlerts = false}) {
  final period = q['period'] ?? 'month';
  // Une période plus courte renvoie moins de fiches : l'écran doit suivre.
  final has = !empty && period != 'today';
  int n(int v) => has ? v : 0;
  return {
    'period': {'key': period, 'start': period == 'all' ? null : (q['startDate'] ?? '2026-01-01'), 'end': period == 'all' ? null : (q['endDate'] ?? '2026-10-05')},
    'scope': own ? 'own' : 'all',
    'promesh': {
      'type': 'promesh',
      'label': 'PROMESH',
      'unit': 'm²',
      'wasteUnit': 'kg',
      'fiches': n(29),
      'validees': n(23),
      'brouillons': n(1),
      'archivees': n(5),
      'actives': n(24),
      'acceptees': n(3),
      'enAttente': n(2),
      'refusees': n(1),
      'horsCircuit': n(18),
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
      'unit': 'ml',
      'wasteUnit': 'kg',
      'fiches': n(5),
      'validees': n(3),
      'brouillons': 0,
      'archivees': n(2),
      'actives': n(3),
      'acceptees': n(1),
      'enAttente': 0,
      'refusees': 0,
      'horsCircuit': n(2),
      'quantite': has ? 3145 : 0,
      'dechets': has ? 100 : 0,
      'tauxDechets': has ? 3.18 : null,
      'tauxDechetsUnit': 'kg / 100 ml',
      'machines': [
        _machine('1', n(3), n(2), has ? 3145 : 0, has ? 100 : 0, last: has ? '2026-08-28' : null, statut: has ? 'validee' : null),
        for (final m in ['2', '3', '4']) _machine(m, 0, 0, 0, 0),
      ],
    },
    'production': {'fiches': n(34), 'validees': n(26), 'brouillons': n(1), 'archivees': n(7), 'actives': n(27), 'acceptees': n(4), 'enAttente': n(2), 'refusees': n(1), 'horsCircuit': n(20), 'today': 2},
    'previous': period == 'all' ? null : {'start': '2025-03-06', 'end': '2025-12-31', 'promesh': 10, 'probar': 2, 'actives': 12},
    // Alertes : toutes dates — identiques quelle que soit la période.
    'alerts': noAlerts
        ? {'fichesEnAttente': 0, 'fichesRefusees': 0, 'promesh': {'enAttente': 0, 'refusees': 0}, 'probar': {'enAttente': 0, 'refusees': 0}, 'rejected': []}
        : {
            'fichesEnAttente': 2,
            'fichesRefusees': 1,
            'promesh': {'enAttente': 2, 'refusees': 1},
            'probar': {'enAttente': 0, 'refusees': 0},
            'rejected': [
              {
                'id': _rejectedId,
                'type': 'promesh',
                'numero': 'PROMESH-2026-001708',
                'machine': '1',
                'poste': 'matin',
                'date': '2026-09-23',
                'userEmail': 'production_1@cbi-tunisia.com',
                'comment': 'Épaisseur hors tolérance',
                'decidedByEmail': 'responsable_production@cbi-tunisia.com',
                'decidedAt': '2026-10-27T10:17:42.528Z',
              },
            ],
          },
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
            {'id': 'promesh:11111111-1111-1111-1111-111111111111', 'type': 'promesh', 'ligne': 'PROMESH', 'numero': 'PROMESH-2026-000886', 'date': '2026-09-28', 'machine': '1', 'poste': 'matin', 'userEmail': 'production_1@cbi-tunisia.com', 'quantite': 1250, 'quantiteUnite': 'm²', 'dechets': 12, 'dechetsUnite': 'kg', 'statut': 'validee', 'approval': {'status': 'APPROVED', 'decidedByEmail': 'responsable_logistique@cbi-tunisia.com'}},
            {'id': 'probar:22222222-2222-2222-2222-222222222222', 'type': 'probar', 'ligne': 'PROBAR', 'numero': 'PROBAR-2026-E9EAAE', 'date': '2026-09-24', 'machine': '1', 'poste': 'nuit', 'userEmail': 'production_2@cbi-tunisia.com', 'quantite': null, 'quantiteUnite': 'ml', 'dechets': null, 'dechetsUnite': 'kg', 'statut': 'archivee', 'approval': null},
            {'id': 'promesh:33333333-3333-3333-3333-333333333333', 'type': 'promesh', 'ligne': 'PROMESH', 'numero': 'PROMESH-2026-000867', 'date': '2026-09-24', 'machine': '2', 'poste': 'nuit', 'userEmail': 'production_1@cbi-tunisia.com', 'quantite': 600, 'quantiteUnite': 'm²', 'dechets': null, 'dechetsUnite': 'kg', 'statut': 'validee', 'approval': {'status': 'PENDING'}},
            {'id': _rejectedId, 'type': 'promesh', 'ligne': 'PROMESH', 'numero': 'PROMESH-2026-001708', 'date': '2026-09-23', 'machine': '1', 'poste': 'matin', 'userEmail': 'production_1@cbi-tunisia.com', 'quantite': 900, 'quantiteUnite': 'm²', 'dechets': null, 'dechetsUnite': 'kg', 'statut': 'validee', 'approval': {'status': 'REJECTED', 'comment': 'Épaisseur hors tolérance', 'decidedByEmail': 'responsable_production@cbi-tunisia.com', 'decidedAt': '2026-10-27T10:17:42.528Z'}},
          ]
        : [],
  };
}

class _FakeApi implements HttpClientAdapter {
  final requests = <Uri>[];
  bool empty = false;
  bool own = false;
  bool noAlerts = false;
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
    return ResponseBody.fromString(jsonEncode({'success': true, 'data': _dashboard(o.uri.queryParameters, empty: empty, own: own, noAlerts: noAlerts)}), 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}

  List<Uri> get dashboardCalls => requests.where((u) => u.path.endsWith('/production-records/dashboard')).toList();
}

RawMaterialRequestRecord _request(String id, String number, String status, {String? validator}) => RawMaterialRequestRecord.fromJson({
      'id': id,
      'requestNumber': number,
      'userEmail': 'production_1@cbi-tunisia.com',
      'poste': 'matin',
      'status': status,
      'createdAt': '2026-10-23T06:45:00Z',
      'validatedByEmail': validator,
      'items': [
        {'material': 'ISO', 'label': 'ISO', 'quantiteDemandee': 15, 'unite': 'KG'},
        {'material': 'GRAIN_PLASTIQUE', 'label': 'GRAIN PLASTIQUE', 'quantiteDemandee': 855, 'unite': 'KG'},
      ],
    });

/// Sources secondaires : données réelles simulées, refus ou erreur.
class _FakeSources implements IndustrialDashboardSources {
  DashboardSource<RawMaterialOverview> raw;
  DashboardSource<int?> missing;
  DashboardSource<int> requests;
  int calls = 0;

  _FakeSources({DashboardSource<RawMaterialOverview>? raw, this.missing = const DashboardSource.data(null), this.requests = const DashboardSource.forbidden()})
      : raw = raw ??
            DashboardSource.data(RawMaterialOverview(pending: 1, overdue: 0, isValidator: true, total: 2, latest: [
              _request('r-1', 'DMP-2026-000002', 'PENDING_VALIDATION'),
              _request('r-2', 'DMP-2026-000001', 'VALIDATED', validator: 'responsable_logistique@cbi-tunisia.com'),
            ]));

  @override
  Future<DashboardSource<RawMaterialOverview>> rawMaterials(IndustrialDashboardAccess access) async {
    calls++;
    return raw;
  }

  @override
  Future<DashboardSource<int?>> missingProductionSheets() async => missing;

  @override
  Future<DashboardSource<int>> pendingProductionRequests(IndustrialDashboardAccess access) async => requests;
}

const _manager = IndustrialDashboardAccess(
  canViewRawMaterials: true,
  isRawMaterialValidator: true,
  canViewFicheApprovals: true,
  isFicheApprovalValidator: true,
  canManageProductionRequests: true,
);
const _producer = IndustrialDashboardAccess(canViewRawMaterials: true, canViewFicheApprovals: true);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// L'écran dans un vrai GoRouter : les autres routes affichent leur chemin.
Future<void> _open(WidgetTester tester, {double width = 1440, _FakeSources? sources, IndustrialDashboardAccess access = _manager}) async {
  tester.view.physicalSize = Size(width, 12000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = sources ?? _FakeSources();
  final router = GoRouter(
    initialLocation: '/production/dashboard',
    routes: [
      GoRoute(path: '/production/dashboard', builder: (_, __) => ProductionDashboardScreen(sources: s, access: access, realtime: false)),
      GoRoute(path: '/:rest(.*)', builder: (_, state) => Scaffold(body: Text('ROUTE ${state.uri}'))),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await _settle(tester);
}

Finder _in(String key, Finder f) => find.descendant(of: find.byKey(ValueKey(key)), matching: f);

class _FakeRawApi implements RawMaterialTrackingApi {
  final Map<String, dynamic> perms;
  final Object? error;
  final queries = <Map<String, dynamic>>[];
  _FakeRawApi(this.perms, {this.error});

  @override
  Future<RawMaterialPermissions> permissions() async {
    if (error != null) throw error!;
    return RawMaterialPermissions.fromJson(perms);
  }

  @override
  Future<({List<RawMaterialRequestRecord> items, int total})> list(RawMaterialFilters filters) async {
    queries.add(filters.toQuery());
    if (filters.status == 'PENDING_VALIDATION') return (items: [_request('r-1', 'DMP-1', 'PENDING_VALIDATION')], total: 3);
    return (items: [_request('r-1', 'DMP-1', 'PENDING_VALIDATION')], total: 9);
  }

  @override
  Future<({int pending, int overdue, int dueSoon})> pendingSummary() async => (pending: 4, overdue: 1, dueSoon: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
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
    test('formatage : milliers, décimales utiles, dates, statuts, postes, périodes', () {
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
      expect(kProductionPeriods.map((p) => p.$1), ['today', 'week', 'month', 'year', 'all', 'custom']);
    });

    test('réponse API → modèle (lignes, validation, période précédente, alertes, dernières fiches)', () {
      final d = ProductionDashboard.fromJson(_dashboard(const {'period': 'year'}));
      expect([d.promesh.fiches, d.promesh.validees, d.promesh.archivees, d.probar.fiches], [29, 23, 5, 5]);
      expect([d.promesh.actives, d.probar.actives, d.approval.actives], [24, 3, 27]);
      expect([d.approval.acceptees, d.approval.enAttente, d.approval.refusees, d.approval.horsCircuit], [4, 2, 1, 20]);
      expect(d.promesh.quantite, 51358.5);
      expect(d.promesh.machines.map((m) => m.machine), ['1', '2', '3', '4']);
      expect(d.promesh.machines[2].tauxDechets, isNull); // aucune production validée
      expect(d.promesh.machines.first.lastActivityAt, isNotNull);
      expect([d.machinesActives, d.machinesTotal, d.productionsToday, d.fiches, d.archivees], [5, 8, 2, 34, 7]);
      expect(d.previous!.actives, 12);
      expect(d.alerts.fichesRefusees, 1);
      expect(d.alerts.rejected.single.approval.comment, 'Épaisseur hors tolérance');
      expect(d.alerts.rejected.single.recordId, '44444444-4444-4444-4444-444444444444');
      expect(d.recent.map((r) => r.approval?.status), ['APPROVED', null, 'PENDING', 'REJECTED']);
      expect(d.recent.last.approval!.comment, 'Épaisseur hors tolérance');
      expect(d.ownScope, isFalse);
      // « Toutes périodes » : aucune période précédente, jamais inventée.
      expect(ProductionDashboard.fromJson(_dashboard(const {'period': 'all'})).previous, isNull);
      final empty = ProductionDashboard.fromJson(_dashboard(const {}, empty: true));
      expect([empty.fiches, empty.promesh.tauxDechets, empty.recent.length, empty.approval.actives], [0, null, 0, 0]);
    });
  });

  group('sources secondaires (API existantes, droits du backend)', () {
    const permsValidator = {'canView': true, 'fullVisibility': true, 'canManageStatus': true, 'canValidate': true};
    const permsRequester = {'canView': true, 'fullVisibility': false, 'canManageStatus': false, 'canValidate': false};

    test('validateur : demandes à valider et en retard (pending-summary) + dernières demandes', () async {
      final raw = _FakeRawApi(permsValidator);
      final r = await ApiIndustrialDashboardSources(rawApi: raw).rawMaterials(_manager);
      expect([r.data!.pending, r.data!.overdue, r.data!.isValidator, r.data!.latest.length, r.data!.total], [4, 1, true, 1, 9]);
      expect(raw.queries.single['pageSize'], ApiIndustrialDashboardSources.latestCount);
    });

    test('demandeur : SES demandes en attente de validation (jamais celles des autres)', () async {
      final raw = _FakeRawApi(permsRequester);
      final r = await ApiIndustrialDashboardSources(rawApi: raw).rawMaterials(_producer);
      expect([r.data!.pending, r.data!.isValidator], [3, false]);
      expect(raw.queries.last['status'], 'PENDING_VALIDATION');
    });

    test('profil sans accès : aucune requête ; refus 403 et erreur réseau signalés, jamais un zéro', () async {
      final none = _FakeRawApi(permsValidator);
      final hidden = await ApiIndustrialDashboardSources(rawApi: none).rawMaterials(const IndustrialDashboardAccess());
      expect([hidden.forbidden, hidden.data, none.queries], [true, null, isEmpty]);

      DioException fail(int? status) => DioException(
            requestOptions: RequestOptions(path: '/raw-material-requests/permissions'),
            response: status == null ? null : Response(requestOptions: RequestOptions(), statusCode: status, data: {'message': 'Refusé'}),
          );
      final denied = await ApiIndustrialDashboardSources(rawApi: _FakeRawApi(permsValidator, error: fail(403))).rawMaterials(_manager);
      expect(denied.forbidden, isTrue);
      final down = await ApiIndustrialDashboardSources(rawApi: _FakeRawApi(permsValidator, error: fail(null))).rawMaterials(_manager);
      expect([down.forbidden, down.data, down.error], [false, null, 'Erreur réseau']);
      final noView = await ApiIndustrialDashboardSources(rawApi: _FakeRawApi({...permsValidator, 'canView': false})).rawMaterials(_manager);
      expect(noView.forbidden, isTrue);
    });
  });

  for (final width in [1440.0, 820.0, 390.0]) {
    testWidgets('${width.toInt()}px : en-tête, alertes, KPI, graphiques, machines, tableaux, accès rapides', (tester) async {
      await _open(tester, width: width);
      expect(tester.takeException(), isNull);

      // UN seul appel pour les fiches (période par défaut : année).
      expect(api.dashboardCalls, hasLength(1));
      expect(api.dashboardCalls.single.queryParameters['period'], 'year');

      expect(find.text('Tableau de bord industriel'), findsOneWidget);
      expect(find.text('Vue globale de la production PROMESH/PROBAR et suivi des activités'), findsOneWidget);
      expect(find.text('Actualiser'), findsOneWidget);
      expect(find.text('01/01/2026 → 05/10/2026'), findsOneWidget);
      expect(find.text('Aujourd\'hui : 2 fiche(s)'), findsOneWidget);

      // Alertes, triées par priorité : refus (critique) avant les attentes.
      final alerts = ['prod-alert-rejected', 'prod-alert-raw-pending', 'prod-alert-pending', 'prod-alert-requests'];
      for (final k in alerts.take(3)) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      expect(find.byKey(const ValueKey('prod-alert-requests')), findsNothing); // source refusée : aucune fausse alerte
      expect(tester.getTopLeft(find.byKey(const ValueKey('prod-alert-rejected'))).dy, lessThanOrEqualTo(tester.getTopLeft(find.byKey(const ValueKey('prod-alert-pending'))).dy));
      expect(_in('prod-alert-rejected', find.text('Fiches refusées à corriger')), findsOneWidget);
      expect(_in('prod-alert-pending', find.text('2')), findsOneWidget);

      // KPI : fiches non archivées, parts réelles, évolution calculée.
      expect(_in('prod-kpi-total', find.text('27')), findsOneWidget);
      expect(_in('prod-kpi-total', find.text('+125 % vs période précédente (12)')), findsOneWidget);
      expect(_in('prod-kpi-promesh', find.text('24')), findsOneWidget);
      expect(_in('prod-kpi-promesh', find.text('88,9 % du total')), findsOneWidget);
      expect(_in('prod-kpi-probar', find.text('3')), findsOneWidget);
      expect(_in('prod-kpi-probar', find.text('11,1 % du total')), findsOneWidget);
      expect(_in('prod-kpi-raw', find.text('1')), findsOneWidget);
      expect(_in('prod-kpi-raw', find.text('En attente de validation')), findsOneWidget);

      // Production par type : anneau, total au centre, archivées signalées.
      expect(find.byKey(const ValueKey('prod-chart-type')), findsOneWidget);
      expect(_in('prod-type', find.text('27')), findsOneWidget);
      expect(_in('prod-type', find.text('7 fiche(s) archivée(s) non comptée(s)')), findsOneWidget);

      // Statuts : nombre, pourcentage, barre ; hors circuit jamais compté accepté.
      expect(_in('prod-approval-accepted', find.text('4')), findsOneWidget);
      expect(_in('prod-approval-pending', find.text('2')), findsOneWidget);
      expect(_in('prod-approval-rejected', find.text('1')), findsOneWidget);
      expect(_in('prod-approval-rejected', find.text('3,7 %')), findsOneWidget);
      expect(_in('prod-approval-outside', find.text('20')), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));

      // Machines : toutes, activité (jamais « inactive »), lien vers les fiches.
      for (final type in ['promesh', 'probar']) {
        for (final m in ['1', '2', '3', '4']) {
          expect(find.byKey(ValueKey('prod-machine-$type-$m')), findsOneWidget, reason: '$type M$m');
        }
      }
      expect(_in('prod-machine-promesh-1', find.text('30 008 m²')), findsOneWidget);
      expect(_in('prod-machine-probar-3', find.text('Aucune fiche sur la période')), findsOneWidget);
      expect(find.textContaining('Inactive'), findsNothing);
      expect(find.textContaining('Aucun état de machine'), findsOneWidget);

      // Graphiques : production par jour (une échelle par unité), déchets.
      expect(find.byKey(const ValueKey('prod-chart-daily-promesh')), findsOneWidget);
      expect(find.byKey(const ValueKey('prod-chart-daily-probar')), findsOneWidget);
      expect(find.byKey(const ValueKey('prod-chart-waste')), findsOneWidget);
      expect(find.byType(BarChart), findsNWidgets(2));
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);

      // Dernières fiches : numéro, producteur, statut de validation, actions selon les droits.
      final row = 'prod-recent-promesh:11111111-1111-1111-1111-111111111111';
      for (final text in ['PROMESH-2026-000886', 'Machine 1', 'production_1', '28/09/2026', 'Acceptée', 'Voir']) {
        expect(_in(row, find.textContaining(text)), findsOneWidget, reason: text);
      }
      expect(_in('prod-recent-probar:22222222-2222-2222-2222-222222222222', find.text('Hors circuit')), findsOneWidget);
      expect(_in('prod-recent-probar:22222222-2222-2222-2222-222222222222', find.text('Archivée')), findsOneWidget);
      expect(_in('prod-recent-$_rejectedId', find.text('Refusée')), findsOneWidget);
      expect(find.byKey(const ValueKey('prod-recent-reason-$_rejectedId')), findsOneWidget);
      expect(find.byKey(const ValueKey('prod-recent-decide-promesh:33333333-3333-3333-3333-333333333333')), findsOneWidget);

      // Demandes de matières premières : détail des matières, validateur.
      expect(_in('prod-raw-r-1', find.text('DMP-2026-000002')), findsOneWidget);
      expect(_in('prod-raw-r-1', find.text('ISO : 15 KG · GRAIN PLASTIQUE : 855 KG')), findsOneWidget);
      expect(find.byKey(const ValueKey('prod-raw-process-r-1')), findsOneWidget); // validateur : « Traiter »
      expect(find.byKey(const ValueKey('prod-raw-open-r-2')), findsOneWidget);

      // Quantités (unités séparées) et accès rapides conservés.
      expect(find.text('kg / 100 m²'), findsOneWidget);
      expect(find.text('kg / 100 ml'), findsOneWidget);
      for (final id in ['new-promesh', 'new-probar', 'summary-promesh', 'summary-probar', 'records', 'summary']) {
        expect(find.byKey(ValueKey('prod-link-$id')), findsOneWidget, reason: id);
      }
      expect(find.textContaining('NaN'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('motif du refus : depuis l\'alerte, le statut et la ligne ; accès à la validation', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('prod-alert-rejected')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('prod-rejected-dialog')), findsOneWidget);
    for (final text in ['PROMESH-2026-001708', 'Épaisseur hors tolérance', '1 fiche(s) refusée(s), toutes dates — les plus récentes']) {
      expect(_in('prod-rejected-dialog', find.text(text)), findsOneWidget, reason: text);
    }
    expect(_in('prod-rejected-dialog', find.textContaining('responsable_production@cbi-tunisia.com')), findsOneWidget);
    await tester.tap(find.text('Voir dans Validation des fiches'));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /production/validation-fiches?fiche=$_rejectedId'), findsOneWidget);

    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('prod-recent-reason-$_rejectedId')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('prod-reason-dialog')), findsOneWidget);
    expect(_in('prod-reason-dialog', find.text('Épaisseur hors tolérance')), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('prod-approval-rejected')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('prod-rejected-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('droits : un producteur ne voit ni « Traiter » ni accès aux décisions ; sans accès matières = « non accessible »', (tester) async {
    await _open(tester, access: _producer, sources: _FakeSources(raw: DashboardSource.data(RawMaterialOverview(pending: 1, isValidator: false, latest: [_request('r-1', 'DMP-2026-000002', 'PENDING_VALIDATION')]))));
    expect(find.byKey(const ValueKey('prod-recent-decide-promesh:33333333-3333-3333-3333-333333333333')), findsNothing);
    expect(find.byKey(const ValueKey('prod-raw-process-r-1')), findsNothing);
    expect(find.byKey(const ValueKey('prod-raw-open-r-1')), findsOneWidget);
    expect(_in('prod-kpi-raw', find.text('Vos demandes en attente de validation')), findsOneWidget);
    expect(_in('prod-alert-pending', find.text('En attente de la décision du responsable.')), findsOneWidget);

    // Compte sans accès aux demandes (backend : 403) : section masquée, KPI explicite.
    await _open(tester, access: const IndustrialDashboardAccess(), sources: _FakeSources(raw: const DashboardSource.forbidden()));
    expect(find.byKey(const ValueKey('prod-raw')), findsNothing);
    expect(_in('prod-kpi-raw', find.text('—')), findsOneWidget);
    expect(_in('prod-kpi-raw', find.text('Non accessible avec votre profil')), findsOneWidget);
    expect(find.byKey(const ValueKey('prod-alert-raw-pending')), findsNothing);
    // Pas de lien vers la validation pour qui n'y a pas accès.
    expect(_in('prod-alert-pending', find.text('Traiter')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('API secondaire en erreur : signalée « indisponible », aucun zéro inventé ; autres alertes réelles', (tester) async {
    await _open(
      tester,
      sources: _FakeSources(raw: const DashboardSource.error('Erreur 500'), missing: const DashboardSource.data(3), requests: const DashboardSource.data(2)),
    );
    expect(_in('prod-kpi-raw', find.text('—')), findsOneWidget);
    expect(_in('prod-kpi-raw', find.text('Données indisponibles')), findsOneWidget);
    expect(find.byKey(const ValueKey('prod-alert-error-raw')), findsOneWidget);
    expect(_in('prod-raw', find.textContaining('Erreur 500')), findsOneWidget);
    expect(_in('prod-alert-missing', find.text('3')), findsOneWidget);
    expect(_in('prod-alert-requests', find.text('2')), findsOneWidget);
    // Critiques (refus, fiches manquantes) avant les attentes, erreurs en dernier.
    double y(String k) => tester.getTopLeft(find.byKey(ValueKey(k))).dy;
    expect(y('prod-alert-missing') <= y('prod-alert-requests'), isTrue);
    expect(y('prod-alert-requests') <= y('prod-alert-error-raw'), isTrue);

    await tester.tap(find.byKey(const ValueKey('prod-alert-requests')));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /production-compliance'), findsOneWidget);
  });

  testWidgets('aucun problème : état explicite ; aucune demande : état vide', (tester) async {
    api.noAlerts = true;
    await _open(tester, sources: _FakeSources(raw: const DashboardSource.data(RawMaterialOverview(pending: 0, isValidator: true))));
    expect(find.byKey(const ValueKey('prod-alerts-none')), findsOneWidget);
    expect(find.text('Aucune demande de matières premières pour le moment'), findsOneWidget);
    expect(_in('prod-kpi-raw', find.text('0')), findsOneWidget);
  });

  testWidgets('filtre période : chaque choix recharge tout ; alertes inchangées ; personnalisée attend les deux dates', (tester) async {
    final sources = _FakeSources();
    await _open(tester, sources: sources);
    expect(_in('prod-kpi-total', find.text('27')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('prod-period-today')));
    await _settle(tester);
    expect(api.dashboardCalls.last.queryParameters['period'], 'today');
    // Aucune fiche aujourd'hui : zéros réels et états vides, aucun graphique.
    expect(_in('prod-kpi-total', find.text('0')), findsOneWidget);
    expect(_in('prod-kpi-total', find.text('-125 % vs période précédente (12)')), findsNothing);
    expect(find.byType(BarChart), findsNothing);
    expect(find.byType(PieChart), findsNothing);
    for (final text in ['Aucune production validée sur cette période', 'Aucune fiche sur cette période', 'Aucun déchet déclaré sur cette période']) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    // Les alertes portent sur toutes les dates : toujours présentes.
    expect(find.byKey(const ValueKey('prod-alert-rejected')), findsOneWidget);

    // Toutes périodes : aucune comparaison inventée.
    await tester.tap(find.byKey(const ValueKey('prod-period-all')));
    await _settle(tester);
    expect(api.dashboardCalls.last.queryParameters['period'], 'all');
    expect(_in('prod-kpi-total', find.text('Toutes périodes')), findsOneWidget);

    for (final period in ['week', 'month', 'year']) {
      await tester.tap(find.byKey(ValueKey('prod-period-$period')));
      await _settle(tester);
      expect(api.dashboardCalls.last.queryParameters['period'], period);
    }

    // Personnalisée : aucun appel tant que les dates ne sont pas choisies.
    final before = api.dashboardCalls.length;
    await tester.tap(find.byKey(const ValueKey('prod-period-custom')));
    await _settle(tester);
    expect(api.dashboardCalls, hasLength(before));
    expect(find.text('Choisissez une date de début et une date de fin.'), findsOneWidget);
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

    // Actualiser : même période, nouvelle lecture de TOUTES les sources.
    final rawCalls = sources.calls;
    await tester.tap(find.byKey(const ValueKey('prod-refresh')));
    await _settle(tester);
    expect(api.dashboardCalls, hasLength(before + 2));
    expect(api.dashboardCalls.last.queryParameters['period'], 'custom');
    expect(sources.calls, rawCalls + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation : écrans existants (fiche, machine, demandes, validation, listes)', (tester) async {
    Future<void> go(Finder f, String route) async {
      await _open(tester);
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
      expect(find.text('ROUTE $route'), findsOneWidget, reason: route);
    }

    await go(find.byKey(const ValueKey('prod-link-new-probar')), '/production/probar');
    await go(find.byKey(const ValueKey('prod-recent-open-promesh:11111111-1111-1111-1111-111111111111')), '/production/promesh/machine/1/poste/matin/modules?ficheId=11111111-1111-1111-1111-111111111111');
    await go(find.byKey(const ValueKey('prod-recent-open-probar:22222222-2222-2222-2222-222222222222')), '/production/probar/machine/1/poste/nuit/detail?id=22222222-2222-2222-2222-222222222222');
    await go(find.byKey(const ValueKey('prod-recent-decide-promesh:33333333-3333-3333-3333-333333333333')), '/production/validation-fiches?fiche=promesh:33333333-3333-3333-3333-333333333333');
    await go(find.byKey(const ValueKey('prod-recent-all')), '/production/records');
    await go(find.byKey(const ValueKey('prod-machine-link-probar-1')), '/production/probar/machine/1');
    await go(find.byKey(const ValueKey('prod-raw-process-r-1')), '/production/matieres-premieres?id=r-1');
    await go(find.byKey(const ValueKey('prod-alert-raw-pending')), '/production/matieres-premieres/a-valider');
    await go(find.byKey(const ValueKey('prod-alert-pending')), '/production/validation-fiches');
  });

  testWidgets('périmètre personnel signalé ; erreur de l\'API affichée, aucun chiffre inventé', (tester) async {
    api.own = true;
    await _open(tester);
    expect(find.text('Périmètre : vos propres fiches de production.'), findsOneWidget);

    api = _FakeApi()..failWith = 403;
    ApiClient.instance.dio.httpClientAdapter = api;
    await _open(tester);
    expect(find.textContaining('Accès refusé'), findsOneWidget);
    expect(find.byKey(const ValueKey('prod-kpi-total')), findsNothing);
    expect(find.byType(BarChart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English — industrial dashboard: no French left', (tester) async {
    QcI18n.language.value = 'en';
    QcI18n.missing.clear();
    addTearDown(() {
      QcI18n.language.value = 'fr';
      QcI18n.missing.clear();
    });
    await _open(tester);
    for (final text in [
      'Industrial dashboard',
      'Refresh',
      'Period',
      'Alerts and detected issues',
      'Rejected sheets to correct',
      'Total sheets',
      'PROMESH sheets',
      'Raw material requests',
      'Production by type',
      'Sheet statuses',
      'Outside the approval process',
      'Machine status',
      'Latest production sheets',
      'Latest raw material requests',
      'Production by day',
      'Waste trend',
      'Quick access',
      'Accepted',
      '+125 % vs previous period (12)',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('Dernières fiches de production'), findsNothing);
    expect(QcI18n.frenchResidue(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
