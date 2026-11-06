// Tableau de bord Contrôle Qualité — Super Admin (VM).
//
// VRAI écran + VRAI service (Dio) ; le transport HTTP est un faux backend au
// format exact de GET /quality-control/admin/overview et /admin/controls
// (les chiffres eux-mêmes sont vérifiés contre PostgreSQL côté backend :
// test/qualityControl.adminDashboard.test.js). Chaque test vérifie que
// l'écran affiche ce que l'API renvoie et lui transmet les bons paramètres.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/quality_control/model/quality_control_admin.dart';
import 'package:dash_master_toolkit/quality_control/quality_control_i18n.dart' show QcI18n;
import 'package:dash_master_toolkit/quality_control/quality_control_routes.dart';
import 'package:dash_master_toolkit/quality_control/service/quality_control_service.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_superadmin_screen.dart';

const _total = 45;

Map<String, dynamic> _control(int i) {
  final validated = i % 3 != 0;
  return {
    'id': 'id-$i',
    'reference': 'QC-2026-${i.toString().padLeft(6, '0')}',
    'productionType': i.isEven ? 'PROMESH' : 'PROBAR',
    'machine': '${i % 3 + 1}',
    'machineLabel': 'Machine ${i % 3 + 1}',
    'controllerEmail': i % 5 == 0 ? 'autre_controleur@cbi-tunisia.com' : 'controle_qualite@cbi-tunisia.com',
    'status': validated ? (i % 2 == 0 ? 'CONFORME' : 'NON_CONFORME') : 'EN_COURS',
    'isValidated': validated,
    'controlDate': '05/11/2026',
    'controlTime': '09:30:00',
    'updatedAt': '2026-11-05T08:${(i % 60).toString().padLeft(2, '0')}:00.000Z',
    'readingsCount': 1,
    'readings': [],
    'counts': {'total': 15, 'controlled': 15, 'conformes': 15, 'nonConformes': 0},
    'nonConformParameters': [],
  };
}

const _overview = {
  'period': 'all',
  'totals': {'total': 45, 'validated': 30, 'pending': 15, 'conformes': 18, 'nonConformes': 12},
  'byProduct': [
    {'type': 'PROMESH', 'label': 'PROMESH', 'total': 23, 'validated': 15, 'pending': 8, 'conformes': 10, 'nonConformes': 5},
    {'type': 'PROBAR', 'label': 'PROBAR', 'total': 22, 'validated': 15, 'pending': 7, 'conformes': 8, 'nonConformes': 7},
  ],
};

class _FakeApi implements HttpClientAdapter {
  final requests = <Uri>[];
  int? failWith;
  // Backend sans ces routes (version déployée) : 404 HTML d'Express.
  bool routesMissing = false;
  bool unreachable = false;
  bool unexpected = false;
  bool empty = false;

  ResponseBody _json(Object body, [int status = 200]) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(o.uri);
    final path = o.uri.path;
    if (unreachable) throw DioException.connectionError(requestOptions: o, reason: 'Connection refused');
    if (routesMissing) {
      return ResponseBody.fromString('<!DOCTYPE html><html><body><pre>Cannot GET $path</pre></body></html>', 404,
          headers: {Headers.contentTypeHeader: ['text/html; charset=utf-8']});
    }
    if (unexpected) return _json({'ok': true});
    if (failWith != null) return _json({'success': false, 'code': 'PERMISSION_DENIED', 'message': 'Forbidden'}, failWith!);
    if (path.endsWith('/quality-control/admin/overview')) {
      if (empty) {
        return _json({
          'success': true,
          'data': {
            'totals': {'total': 0, 'validated': 0, 'pending': 0, 'conformes': 0, 'nonConformes': 0},
            'byProduct': [],
          },
        });
      }
      return _json({'success': true, 'data': _overview});
    }
    if (path.endsWith('/quality-control/admin/controls') && empty) {
      return _json({'success': true, 'data': [], 'pagination': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 1}});
    }
    if (path.endsWith('/quality-control/admin/controls')) {
      final q = o.uri.queryParameters;
      final page = int.parse(q['page'] ?? '1');
      final limit = int.parse(q['limit'] ?? '20');
      final start = (page - 1) * limit;
      final items = [for (var i = start; i < (start + limit).clamp(0, _total); i++) _control(i)];
      return _json({
        'success': true,
        'data': items,
        'pagination': {'page': page, 'limit': limit, 'total': _total, 'totalPages': (_total / limit).ceil()},
      });
    }
    return _json({'success': true, 'data': {}});
  }

  @override
  void close({bool force = false}) {}

  Map<String, String> get lastList => requests.lastWhere((u) => u.path.endsWith('/admin/controls')).queryParameters;
  int get overviewCalls => requests.where((u) => u.path.endsWith('/admin/overview')).length;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _open(WidgetTester tester, {double width = 1440}) async {
  tester.view.physicalSize = Size(width, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: QcPaths.superAdmin,
    routes: [
      GoRoute(path: QcPaths.superAdmin, builder: (_, __) => const QualityControlSuperAdminScreen()),
      GoRoute(path: '/quality-control/control/:id', builder: (_, s) => Scaffold(body: Text('DÉTAIL ${s.pathParameters['id']}'))),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await _settle(tester);
}

Finder _inKey(String key, Finder f) => find.descendant(of: find.byKey(ValueKey(key)), matching: f);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await _settle(tester);
}

void main() {
  late _FakeApi api;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('qc_superadmin_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    GetStorage('GetStorage', dir.path, {'userRole': 'superadmin', 'userEmail': 'cbitunisia@cbi-tunisia.com'});
    await GetStorage.init();
  });

  setUp(() {
    api = _FakeApi();
    ApiClient.instance.dio.httpClientAdapter = api;
  });

  for (final width in [1440.0, 820.0, 390.0]) {
    testWidgets('${width.toInt()}px : indicateurs, répartition par produit, tableau global, pagination', (tester) async {
      await _open(tester, width: width);
      expect(tester.takeException(), isNull);

      expect(find.text('Tableau de bord Contrôle Qualité'), findsWidgets);
      // Indicateurs = valeurs de l'API.
      for (final (key, value) in [
        ('qc-admin-kpi-total', '45'),
        ('qc-admin-kpi-validated', '30'),
        ('qc-admin-kpi-pending', '15'),
        ('qc-admin-kpi-nonconformes', '12'),
        ('qc-admin-kpi-conformes', '18'),
      ]) {
        expect(_inKey(key, find.text(value)), findsOneWidget, reason: key);
      }
      expect(_inKey('qc-admin-product-PROMESH', find.text('23 fiches')), findsOneWidget);
      expect(_inKey('qc-admin-product-PROBAR', find.text('Non conformes : 7')), findsOneWidget);

      // Tableau : colonnes, 20 fiches (page 1), toutes les colonnes renseignées.
      for (final h in ['N° DE FICHE', 'PRODUIT', 'DATE DE CONTRÔLE', 'RESPONSABLE', 'RÉSULTAT', 'STATUT', 'DERNIÈRE MODIFICATION', 'ACTIONS']) {
        expect(find.text(h), findsOneWidget, reason: h);
      }
      expect(find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('qc-admin-row-')), findsNWidgets(20));
      expect(_inKey('qc-admin-row-id-1', find.text('QC-2026-000001')), findsOneWidget);
      expect(_inKey('qc-admin-row-id-1', find.text('Non conforme')), findsOneWidget);
      expect(_inKey('qc-admin-row-id-1', find.text('Validé')), findsOneWidget);
      expect(_inKey('qc-admin-row-id-0', find.text('Brouillon')), findsOneWidget);
      expect(_inKey('qc-admin-row-id-0', find.text('À vérifier')), findsOneWidget);
      expect(_inKey('qc-admin-row-id-5', find.text('autre_controleur')), findsOneWidget); // tout contrôleur
      expect(find.text('45 fiche(s)'), findsOneWidget);
      expect(find.text('Page 1 / 3'), findsOneWidget);

      // Requête par défaut : page 1, tri par date décroissante, aucun filtre.
      expect(api.lastList, {'page': '1', 'limit': '20', 'sort': 'date', 'order': 'desc'});

      await _tap(tester, find.byKey(const ValueKey('qc-admin-next')));
      expect(api.lastList['page'], '2');
      expect(find.text('Page 2 / 3'), findsOneWidget);
      expect(find.text('21–40 sur 45'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filtres : produit, statut, recherche par numéro, réinitialisation (retour page 1)', (tester) async {
    await _open(tester);
    await _tap(tester, find.byKey(const ValueKey('qc-admin-next')));
    expect(api.lastList['page'], '2');

    await _tap(tester, _inKey('qc-admin-filter-product', find.text('PROBAR')));
    expect(api.lastList, containsPair('productionType', 'PROBAR'));
    expect(api.lastList['page'], '1');

    await _tap(tester, _inKey('qc-admin-filter-status', find.text('Non conformes')));
    expect(api.lastList, allOf(containsPair('state', 'validated'), containsPair('status', 'NON_CONFORME'), containsPair('productionType', 'PROBAR')));
    await _tap(tester, _inKey('qc-admin-filter-status', find.text('En attente')));
    expect(api.lastList['state'], 'draft');
    expect(api.lastList.containsKey('status'), isFalse);
    await _tap(tester, _inKey('qc-admin-filter-status', find.text('Validées')));
    expect(api.lastList['state'], 'validated');

    await tester.enterText(find.byKey(const ValueKey('qc-admin-search')), 'QC-2026-000012');
    await tester.pump(const Duration(milliseconds: 400)); // délai de saisie
    await _settle(tester);
    expect(api.lastList['search'], 'QC-2026-000012');

    // Les filtres du tableau ne rechargent pas les indicateurs (période seule).
    expect(api.overviewCalls, 1);

    await _tap(tester, find.byKey(const ValueKey('qc-admin-reset')));
    expect(api.lastList, {'page': '1', 'limit': '20', 'sort': 'date', 'order': 'desc'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('carte produit : filtre le tableau, second appui = tous les produits', (tester) async {
    await _open(tester);
    await _tap(tester, find.byKey(const ValueKey('qc-admin-product-PROMESH')));
    expect(api.lastList['productionType'], 'PROMESH');
    await _tap(tester, find.byKey(const ValueKey('qc-admin-product-PROMESH')));
    expect(api.lastList.containsKey('productionType'), isFalse);
  });

  testWidgets('tri des colonnes par le serveur : asc puis desc, chaque colonne', (tester) async {
    await _open(tester);
    for (final key in [QcAdminSort.reference, QcAdminSort.product, QcAdminSort.controller, QcAdminSort.result, QcAdminSort.state]) {
      await _tap(tester, find.byKey(ValueKey('qc-admin-sort-$key')));
      expect([api.lastList['sort'], api.lastList['order']], [key, 'asc']);
      await _tap(tester, find.byKey(ValueKey('qc-admin-sort-$key')));
      expect([api.lastList['sort'], api.lastList['order']], [key, 'desc']);
    }
    // Dates : plus récentes d'abord au premier appui.
    await _tap(tester, find.byKey(const ValueKey('qc-admin-sort-updatedAt')));
    expect([api.lastList['sort'], api.lastList['order']], ['updatedAt', 'desc']);
    await _tap(tester, find.byKey(const ValueKey('qc-admin-sort-date')));
    expect([api.lastList['sort'], api.lastList['order']], ['date', 'desc']);
    await _tap(tester, find.byKey(const ValueKey('qc-admin-sort-date')));
    expect([api.lastList['sort'], api.lastList['order']], ['date', 'asc']);
  });

  testWidgets('consultation du détail : bouton « voir » et clic sur la ligne → fiche existante', (tester) async {
    await _open(tester);
    await _tap(tester, find.byKey(const ValueKey('qc-admin-open-id-3')));
    expect(find.text('DÉTAIL id-3'), findsOneWidget);

    await _open(tester);
    await _tap(tester, find.byKey(const ValueKey('qc-admin-row-id-7')));
    expect(find.text('DÉTAIL id-7'), findsOneWidget);
  });

  Finder rows() => find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('qc-admin-row-'));

  testWidgets('accès refusé par l\'API (403) : erreur affichée, aucun chiffre inventé', (tester) async {
    api.failWith = 403;
    await _open(tester);
    expect(find.text('Accès réservé au Super Administrateur (HTTP 403).'), findsNWidgets(2));
    expect(_inKey('qc-admin-kpi-total', find.text('45')), findsNothing);
    expect(rows(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backend sans les routes (404 HTML d\'Express) : erreur explicite, jamais « 0 fiche » ; Réessayer recharge', (tester) async {
    api.routesMissing = true;
    await _open(tester);
    expect(find.textContaining('HTTP 404 sur /quality-control/admin/overview'), findsOneWidget);
    expect(find.textContaining('HTTP 404 sur /quality-control/admin/controls'), findsOneWidget);
    expect(find.textContaining('la version déployée du backend ne contient pas encore cette fonctionnalité'), findsNWidgets(2));
    // Aucune présentation d'une erreur comme une absence de données.
    expect(find.text('0 fiche(s)'), findsNothing);
    expect(find.text('Aucune fiche sur cette période'), findsNothing);
    expect(find.text('Aucune fiche de contrôle qualité'), findsNothing);
    expect(find.text('Données indisponibles'), findsOneWidget);
    expect(find.text('Répartition indisponible : les indicateurs n\'ont pas pu être chargés.'), findsOneWidget);
    expect(find.textContaining('validateStatus'), findsNothing); // plus de message brut de Dio
    expect(find.byKey(const ValueKey('qc-admin-refresh')), findsOneWidget);

    // Backend corrigé : « Réessayer » recharge réellement depuis l'API.
    api.routesMissing = false;
    await _tap(tester, find.text('Réessayer').first);
    await _tap(tester, find.text('Réessayer').first);
    expect(find.textContaining('HTTP 404'), findsNothing);
    expect(_inKey('qc-admin-kpi-total', find.text('45')), findsOneWidget);
    expect(rows(), findsNWidgets(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('API injoignable / réponse non reconnue : message clair, aucune liste vide artificielle', (tester) async {
    api.unreachable = true;
    await _open(tester);
    expect(find.textContaining('API injoignable'), findsNWidgets(2));
    expect(find.text('0 fiche(s)'), findsNothing);

    api.unreachable = false;
    api.unexpected = true;
    await _tap(tester, find.byKey(const ValueKey('qc-admin-refresh')));
    expect(find.textContaining('Réponse inattendue du serveur pour /quality-control/admin/overview'), findsOneWidget);
    expect(find.textContaining('Réponse inattendue du serveur pour /quality-control/admin/controls'), findsOneWidget);
    expect(find.text('Aucune fiche de contrôle qualité'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('liste réellement vide (200) : état vide affiché, aucune erreur', (tester) async {
    api.empty = true;
    await _open(tester);
    expect(find.text('0 fiche(s)'), findsOneWidget);
    expect(find.text('Aucune fiche de contrôle qualité'), findsOneWidget);
    expect(find.text('Aucune fiche sur cette période'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('période : transmise aux indicateurs et à la liste (from / to)', () async {
    await QualityControlService.instance.fetchAdminOverview(from: '2026-10-01', to: '2026-10-31');
    expect(api.requests.last.queryParameters, {'from': '2026-10-01', 'to': '2026-10-31'});
    await QualityControlService.instance.fetchAdminControls(from: '2026-10-01', to: '2026-10-31');
    expect(api.lastList, allOf(containsPair('from', '2026-10-01'), containsPair('to', '2026-10-31')));
  });

  testWidgets('English — Quality Control dashboard: no French left', (tester) async {
    QcI18n.language.value = 'en';
    QcI18n.missing.clear();
    addTearDown(() {
      QcI18n.language.value = 'fr';
      QcI18n.missing.clear();
    });
    await _open(tester);
    for (final text in ['Quality Control dashboard', 'Breakdown by product', 'All quality control sheets', 'Validated sheets', 'Pending (drafts)', '23 sheets', 'Page 1 / 3']) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(QcI18n.frenchResidue(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
