// Contrôle Qualité — fiches qualité par MACHINE, synchronisation (VM).
//
// VRAIS écrans + VRAI arbre de routes + VRAI service (Dio) ; seul le
// transport HTTP est remplacé par un faux backend en mémoire qui joue le
// rôle de PostgreSQL : ses statistiques sont TOUJOURS recalculées à partir
// de ses fiches (comme GET /quality-control/stats). Le filtrage SQL réel
// (machine, auteur controle_qualite) et les verrous sont vérifiés côté
// backend (qualityControl.module.test.js).
//
// Vérifie :
// - page Machine = fiches qualité de CETTE machine (Modifier / Consulter) ;
// - « Nouveau contrôle qualité » crée une fiche pour la machine de la page : AUCUNE
//   production (ni section, ni sélecteur, ni appel /production-records) ;
// - brouillon modifiable / supprimable ; validé (Conforme ou Non conforme)
//   en lecture seule ; dashboard et machine relus depuis l'API.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/quality_control/quality_control_routes.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_comparison_screen.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_history_screen.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_home_screen.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_line_screen.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_machine_screen.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_screen.dart';
import 'package:dash_master_toolkit/quality_control/quality_control_i18n.dart' show QcI18n;
import 'package:dash_master_toolkit/quality_control/view/quality_control_widgets.dart' show QcReferenceBadge;

import 'fixtures/quality_control_config.dart';

const _uuid886 = '00000000-0000-0000-0000-000000000886';
const _uuid890 = '00000000-0000-0000-0000-000000000890';

class _FakeDb implements HttpClientAdapter {
  final requests = <String>[];
  final posts = <Map<String, dynamic>>[];
  late final List<Map<String, dynamic>> params;
  late final List<Map<String, dynamic>> controls;
  int _seq = 3;

  _FakeDb() {
    params = (jsonDecode(kQualityControlConfig)['parameters'] as List).cast<Map<String, dynamic>>();
    controls = [
      _make('c886', 'QC-2026-00003', '1', 'EN_COURS', '01/09/2026', '12:52:00', validated: false, fiche: (_uuid886, 'PROMESH-2026-000886')),
      _make('c887', 'QC-2026-00002', '2', 'CONFORME', '30/09/2026', '17:20:39'),
      _make('c867', 'QC-2026-00001', '2', 'NON_CONFORME', '25/09/2026', '15:28:28'),
    ];
  }

  Map<String, dynamic> _make(String id, String reference, String machine, String status, String date, String time,
          {bool validated = true, (String, String)? fiche}) =>
      {
        'id': id,
        'reference': reference,
        'productionType': 'PROMESH',
        'productionRecordRef': fiche == null ? null : 'promesh:${fiche.$1}',
        'ficheNumero': fiche?.$2,
        'machine': machine,
        'machineLabel': 'Machine $machine',
        'poste': 'matin',
        'posteLabel': 'Matin',
        'productionDate': '2026-09-28',
        'controllerEmail': 'controle_qualite@cbi-tunisia.com',
        'status': status,
        'isValidated': validated,
        'controlDate': date,
        'controlTime': time,
        'validatedDate': validated ? date : null,
        'validatedTime': validated ? time : null,
        'counts': {'controlled': 1, 'nonConformes': 0, 'total': params.length},
        // Une fiche = un ou plusieurs PRÉLÈVEMENTS, chacun avec ses paramètres.
        'readingsCount': 1,
        'lastReadingTime': '08:00',
        'suggestedNextReadingTime': '11:00',
        'readings': [
          {
            'id': 'r-$id',
            'readingTime': '08:00',
            'status': validated ? status : 'EN_COURS',
            'isValidated': validated,
            'counts': {'controlled': 1, 'nonConformes': 0, 'total': params.length},
            'nonConformParameters': [],
            'items': [
              for (final p in params)
                {
                  'parameterKey': p['key'],
                  'parameterName': p['label'],
                  'position': p['position'],
                  'status': p['key'] == 'temperature_eau' ? 'CONFORME' : 'NON_CONTROLE',
                  if (p['key'] == 'temperature_eau') 'value': '8',
                },
            ],
          },
        ],
        'history': [],
      };

  List<Map<String, dynamic>> _readingItems(Map<String, dynamic> c) =>
      (((c['readings'] as List).first as Map)['items'] as List).cast<Map<String, dynamic>>();

  // Brouillon = À vérifier ; validé = son résultat (comme le backend).
  Map<String, int> _counts(Iterable<Map<String, dynamic>> rows) => {
        'total': rows.length,
        'conforme': rows.where((c) => c['isValidated'] == true && c['status'] == 'CONFORME').length,
        'nonConforme': rows.where((c) => c['isValidated'] == true && c['status'] == 'NON_CONFORME').length,
        'aVerifier': rows.where((c) => c['isValidated'] != true).length,
      };

  Map<String, dynamic> _stats() {
    List<Map<String, dynamic>> of(String type, [String? m]) =>
        controls.where((c) => c['productionType'] == type && (m == null || c['machine'] == m)).toList();
    Map<String, dynamic>? last(List<Map<String, dynamic>> rows) => rows.isEmpty
        ? null
        : {
            'id': rows.first['id'],
            'reference': rows.first['reference'],
            'status': rows.first['status'],
            'isValidated': rows.first['isValidated'],
            'ficheNumero': rows.first['ficheNumero'],
            'controlDate': rows.first['controlDate'],
            'controlTime': (rows.first['controlTime'] as String).substring(0, 5),
          };
    return {
      'period': 'all',
      'from': null,
      'totals': {..._counts(controls), 'machines': 8, 'machinesActives': {for (final c in controls) '${c['productionType']}:${c['machine']}'}.length},
      'lines': [
        for (final type in ['PROMESH', 'PROBAR'])
          {
            'type': type,
            'label': type,
            ..._counts(of(type)),
            'machines': [
              for (final m in ['1', '2', '3', '4']) {'machine': m, 'label': 'Machine $m', ..._counts(of(type, m)), 'lastControl': last(of(type, m))},
            ],
          },
      ],
    };
  }

  ResponseBody _json(Object body, [int status = 200]) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = o.uri.path;
    requests.add('${o.method} $path');
    final q = o.uri.queryParameters;
    if (path.endsWith('/quality-control/config')) return _json({'success': true, 'data': jsonDecode(kQualityControlConfig)});
    if (path.endsWith('/quality-control/stats')) return _json({'success': true, 'data': _stats()});
    if (path.endsWith('/production-records')) {
      // Fiches de production de la machine demandée (association optionnelle).
      return _json({
        'success': true,
        'data': [
          if (q['machineId'] == '1')
            {'id': 'promesh:$_uuid890', 'type': 'promesh', 'numero': 'PROMESH-2026-000890', 'machine': '1', 'poste': 'matin', 'date': '2026-09-29', 'statut': 'validee'},
        ],
        'pagination': {'page': 1, 'limit': 50, 'total': 1, 'totalPages': 1},
      });
    }
    if (path.endsWith('/quality-control') && o.method == 'GET') {
      final rows = controls
          .where((c) => (q['productionType'] == null || c['productionType'] == q['productionType']) && (q['machine'] == null || c['machine'] == q['machine']))
          .toList();
      return _json({'success': true, 'data': rows, 'pagination': {'page': 1, 'limit': 20, 'total': rows.length, 'totalPages': 1}});
    }
    if (path.endsWith('/quality-control') && o.method == 'POST') {
      final body = Map<String, dynamic>.from(o.data as Map);
      posts.add(body);
      final reading = body['reading'] is Map ? Map<String, dynamic>.from(body['reading'] as Map) : <String, dynamic>{};
      final items = (reading['items'] as List? ?? []).cast<Map>();
      final anyNc = items.any((i) => i['status'] == 'NON_CONFORME');
      final validate = body['validate'] == true;
      final status = validate ? (anyNc ? 'NON_CONFORME' : (body['status'] ?? 'CONFORME')) : 'EN_COURS';
      final ref = body['productionRecordId'] as String?;
      _seq++;
      final c = _make('c${900 + _seq}', 'QC-2026-${_seq.toString().padLeft(5, '0')}', body['machine'] as String, status as String, '01/10/2026', '10:35:00',
          validated: validate, fiche: ref == null ? null : (ref.split(':').last, 'PROMESH-2026-000${ref.substring(ref.length - 3)}'));
      // Premier prélèvement de la fiche : heure saisie + paramètres envoyés.
      final first = (c['readings'] as List).first as Map;
      first['readingTime'] = reading['readingTime'] ?? '08:00';
      c['lastReadingTime'] = first['readingTime'];
      for (final item in _readingItems(c)) {
        item['status'] = 'NON_CONTROLE';
        item.remove('value');
      }
      for (final i in items) {
        final item = _readingItems(c).firstWhere((x) => x['parameterKey'] == i['parameterKey']);
        item['status'] = i['status'];
        item['value'] = (i['value'] as String?)?.isEmpty == true ? null : i['value'];
      }
      // En-tête saisi (comme l'API) : poste / date de production.
      c['poste'] = body['poste'];
      c['posteLabel'] = body['poste'] == 'soir' ? 'Soir' : (body['poste'] == 'matin' ? 'Matin' : null);
      if (body['productionDate'] != null) c['productionDate'] = body['productionDate'];
      controls.insert(0, c);
      return _json({'success': true, 'data': c}, 201);
    }
    final match = RegExp(r'/quality-control/(c\d+)(/validate)?$').firstMatch(path);
    if (match != null) {
      final c = controls.firstWhere((x) => x['id'] == match[1]);
      if (o.method == 'GET') return _json({'success': true, 'data': c});
      // Fiche VALIDÉE : lecture seule (403), comme le backend.
      if (c['isValidated'] == true) return _json({'success': false, 'code': 'CONTROL_LOCKED', 'message': 'Lecture seule'}, 403);
      if (o.method == 'DELETE') {
        controls.remove(c);
        return _json({'success': true, 'data': {'id': c['id']}});
      }
      final body = Map<String, dynamic>.from(o.data as Map);
      if (match[2] != null) {
        c['status'] = body['status'] ?? 'CONFORME';
        c['isValidated'] = true;
        c['validatedDate'] = '01/10/2026';
        c['validatedTime'] = '10:40:00';
        // Les prélèvements brouillons sont validés avec la fiche.
        for (final r in (c['readings'] as List).cast<Map>()) {
          r['isValidated'] = true;
          r['status'] = c['status'];
        }
      }
      return _json({'success': true, 'data': c});
    }
    return _json({'success': false, 'message': 'not found'}, 404);
  }

  @override
  void close({bool force = false}) {}
}

GoRouter _router() => GoRouter(
      initialLocation: QcPaths.root,
      routes: [
        buildQualityControlRoute(
          canView: () => true,
          deniedRedirect: '/',
          screens: QcRouteScreens(
            home: () => const QualityControlHomeScreen(),
            history: (q) => QualityControlHistoryScreen(initialQuery: q),
            comparison: () => const QualityControlComparisonScreen(),
            line: (t) => QualityControlLineScreen(type: t),
            machine: (t, m) => QualityControlMachineScreen(type: t, machine: m),
            form: (id) => QualityControlScreen(controlId: id),
            newForm: (t, m) => QualityControlScreen.create(productionType: t, machine: m),
          ),
        ),
      ],
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Chiffre affiché sous/à côté d'un libellé (1re occurrence).
void _expectFigure(String label, String value) {
  final column = find.ancestor(of: find.text(label).first, matching: find.byType(Column)).first;
  expect(find.descendant(of: column, matching: find.text(value)), findsOneWidget, reason: '$label = $value');
}

Future<GoRouter> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = _router();
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await _settle(tester);
  return router;
}

String _uri(GoRouter r) => r.routerDelegate.currentConfiguration.uri.toString();

void main() {
  late _FakeDb db;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('qc_sync_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    GetStorage('GetStorage', dir.path, {'userRole': 'controle_qualite', 'userEmail': 'controle_qualite@cbi-tunisia.com'});
    await GetStorage.init();
  });

  setUp(() {
    db = _FakeDb();
    ApiClient.instance.dio.httpClientAdapter = db;
  });

  testWidgets('page Machine = fiches de CETTE machine ; brouillon → Valider → VALIDÉ lecture seule, synchronisé', (tester) async {
    final router = await _pump(tester);
    _expectFigure('Total contrôles qualité', '3');
    _expectFigure('Conformes', '1');
    _expectFigure('Non conformes', '1');

    // Machine 1 : uniquement sa fiche QC-2026-00003 (brouillon) ; aucune
    // sélection de production imposée.
    router.go(QcPaths.machine('PROMESH', '1'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('QC-2026-00003'), findsWidgets);
    expect(find.text('QC-2026-00002'), findsNothing); // fiche de la machine 2
    expect(find.text('Productions disponibles'), findsNothing);
    expect(find.text('Sélectionner'), findsNothing);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Brouillon'), findsWidgets);

    // Ouvrir le brouillon : édition, aucune création.
    await tester.tap(find.text('Modifier'));
    await _settle(tester);
    expect(_uri(router), QcPaths.control('c886'));
    expect(db.posts, isEmpty);
    expect(find.text('Contrôle qualité QC-2026-00003'), findsOneWidget);
    expect(find.text('Enregistrer le prélèvement'), findsWidgets);
    expect(find.text('Supprimer'), findsWidgets);

    // Résultat CONFORME (proposé par défaut) → Valider le contrôle qualité.
    expect(find.text('08:00'), findsWidgets); // prélèvement existant de la fiche
    await tester.tap(find.text('Valider le contrôle qualité').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(db.requests, contains('POST /quality-control/c886/validate'));
    expect(find.textContaining('Contrôle qualité validé — Lecture seule'), findsWidgets);
    for (final label in ['Enregistrer le prélèvement', 'Valider le contrôle qualité', 'Supprimer']) {
      expect(find.text(label), findsNothing, reason: label);
    }

    router.go(QcPaths.root);
    await _settle(tester);
    _expectFigure('Conformes', '2');
    router.go(QcPaths.machine('PROMESH', '1'));
    await _settle(tester);
    expect(find.text('Consulter'), findsOneWidget);
  });

  testWidgets('« Nouveau contrôle qualité » depuis Machine 1 : fiche de la machine SANS production, NON CONFORME validée, absente de Machine 2', (tester) async {
    final router = await _pump(tester);
    router.go(QcPaths.machine('PROMESH', '1'));
    await _settle(tester);
    await tester.tap(find.text('Nouveau contrôle qualité'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(_uri(router), QcPaths.newControl('PROMESH', '1'));
    expect(find.text('Nouveau contrôle qualité'), findsOneWidget);
    expect(db.posts, isEmpty); // rien en base avant l'enregistrement

    final card = find.ancestor(of: find.text('TEMPÉRATURE D\'EAU'), matching: find.byType(Column)).first;
    await tester.enterText(find.descendant(of: card, matching: find.byType(TextField)).first, '9.4');
    await tester.tap(find.descendant(of: card, matching: find.text('Non conforme')));
    await tester.pump();
    await tester.tap(find.text('Valider le contrôle qualité').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // UN POST : ligne + machine de la page, aucune production, validation NON CONFORME.
    expect(db.posts, hasLength(1));
    final body = db.posts.single;
    expect(body['productionType'], 'PROMESH');
    expect(body['machine'], '1');
    expect(body.containsKey('productionRecordId'), isFalse);
    expect(body['validate'], isTrue);
    expect(body['status'], 'NON_CONFORME');
    // Les paramètres saisis partent dans le PREMIER prélèvement de la fiche.
    final reading = Map<String, dynamic>.from(body['reading'] as Map);
    expect(reading['readingTime'], matches(r'^\d{2}:\d{2}$'));
    expect(reading['items'], [
      {'parameterKey': 'temperature_eau', 'value': '9.4', 'status': 'NON_CONFORME', 'remark': ''},
    ]);
    expect(body.containsKey('items'), isFalse);
    final created = db.controls.first;
    expect(_uri(router), QcPaths.control(created['id'] as String));
    expect(find.textContaining('Contrôle qualité validé — Lecture seule'), findsWidgets);

    router.go(QcPaths.machine('PROMESH', '1'));
    await _settle(tester);
    expect(find.text(created['reference'] as String), findsWidgets);
    router.go(QcPaths.machine('PROMESH', '2'));
    await _settle(tester);
    expect(find.text(created['reference'] as String), findsNothing);
  });

  testWidgets('TESTS 1-4 — nouvelle fiche SANS aucune production : brouillon enregistré, rouvert, modifié', (tester) async {
    final router = await _pump(tester);
    router.go(QcPaths.machine('PROMESH', '1'));
    await _settle(tester);
    await tester.tap(find.text('Nouveau contrôle qualité'));
    await _settle(tester);
    expect(_uri(router), QcPaths.newControl('PROMESH', '1'));

    // TEST 1 — aucune trace de production dans le formulaire.
    for (final label in ['Production contrôlée', 'Production contrôlée (optionnelle)', 'Production associée', 'Associer une production', 'Voir la fiche']) {
      expect(find.textContaining(label), findsNothing, reason: label);
    }
    expect(find.byIcon(Icons.add_link_rounded), findsNothing);
    expect(find.text('PROMESH · Machine 1'), findsOneWidget); // machine fixée par la page
    expect(find.text('controle_qualite@cbi-tunisia.com'), findsOneWidget); // contrôleur
    expect(find.text('Date de production'), findsWidgets); // information du contrôle, sans fiche
    // Sections numérotées sans trou : 01 Informations générales, 02 Prélèvements
    // de contrôle ; PROMESH : une seule catégorie « Contrôle Machine », sans lettre.
    expect(find.text('01'), findsOneWidget);
    expect(find.descendant(of: find.ancestor(of: find.text('Prélèvements de contrôle'), matching: find.byType(Row)).first, matching: find.text('02')),
        findsOneWidget);
    expect(find.text('Contrôle Machine'), findsOneWidget);
    expect(find.text('Contrôle Produit'), findsOneWidget);
    expect(find.text('A'), findsNothing);

    // TEST 2 — brouillon enregistré sans production.
    await tester.tap(find.text('Sélectionner')); // Poste
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soir').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer le prélèvement').first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    final body = db.posts.single;
    expect(body, containsPair('productionType', 'PROMESH'));
    expect(body, containsPair('machine', '1'));
    expect(body, containsPair('poste', 'soir'));
    expect(body.containsKey('productionRecordId'), isFalse);
    expect(body.containsKey('validate'), isFalse);
    expect(db.requests.where((r) => r.contains('/production-records')), isEmpty); // jamais de production
    final id = db.controls.first['id'] as String;

    // TEST 3 — fermer puis rouvrir : données présentes, brouillon modifiable.
    router.go(QcPaths.machine('PROMESH', '1'));
    await _settle(tester);
    router.go(QcPaths.control(id));
    await _settle(tester);
    expect(find.text('Soir'), findsOneWidget);
    expect(find.text('Enregistrer le prélèvement'), findsWidgets);
    expect(find.textContaining('Production associée'), findsNothing);

    // TEST 4 — modification du brouillon (PUT, sans production).
    await tester.tap(find.text('Soir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matin').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer le prélèvement').first);
    await _settle(tester);
    expect(db.requests, contains('PUT /quality-control/$id'));
    expect(db.posts, hasLength(1)); // modification = PUT, jamais un nouveau POST
  });

  testWidgets('TESTS 7-8 — isolation : Machine 2 sans les fiches de Machine 1, PROBAR sans les fiches PROMESH', (tester) async {
    final router = await _pump(tester);
    router.go(QcPaths.machine('PROMESH', '2'));
    await _settle(tester);
    expect(find.text('QC-2026-00003'), findsNothing); // fiche Machine 1
    expect(find.text('QC-2026-00002'), findsWidgets);
    router.go(QcPaths.machine('PROBAR', '1'));
    await _settle(tester);
    for (final ref in ['QC-2026-00001', 'QC-2026-00002', 'QC-2026-00003']) {
      expect(find.text(ref), findsNothing, reason: ref);
    }
    expect(find.textContaining('Aucune fiche qualité pour cette machine'), findsOneWidget);
  });

  testWidgets('suppression d\'un BROUILLON : DELETE, retour à la machine, fiche retirée', (tester) async {
    final router = await _pump(tester);
    router.go(QcPaths.control('c886'));
    await _settle(tester);
    await tester.tap(find.text('Supprimer').first);
    await tester.pumpAndSettle();
    expect(find.text('Supprimer le brouillon'), findsOneWidget);
    await tester.tap(find.text('Supprimer').last);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(db.requests, contains('DELETE /quality-control/c886'));
    expect(_uri(router), QcPaths.machine('PROMESH', '1'));
    expect(find.text('QC-2026-00003'), findsNothing);
    expect(find.textContaining('Aucune fiche qualité pour cette machine'), findsOneWidget);
  });

  testWidgets('fiche VALIDÉE ouverte directement : lecture seule, aucune action', (tester) async {
    final router = await _pump(tester);
    router.go(QcPaths.control('c867'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Contrôle qualité validé — Lecture seule'), findsWidgets);
    for (final label in ['Enregistrer le prélèvement', 'Valider le contrôle qualité', 'Supprimer']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    final poste = tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>));
    expect(poste.onChanged, isNull);
  });

  testWidgets('English — dashboard, line, machine, history and sheet: no French left', (tester) async {
    QcI18n.language.value = 'en';
    QcI18n.missing.clear();
    addTearDown(() {
      QcI18n.language.value = 'fr';
      QcI18n.missing.clear();
    });
    final router = await _pump(tester);
    expect(find.text('Quality Control'), findsWidgets);
    expect(find.text('General statistics'), findsOneWidget);
    expect(find.text('Total quality controls'), findsOneWidget);
    expect(find.text('Samples'), findsWidgets);
    expect(find.text('Statistiques générales'), findsNothing);

    router.go(QcPaths.line('PROMESH'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Quality controls'), findsWidgets);

    router.go(QcPaths.machine('PROMESH', '1'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('New Quality Control'), findsWidgets);
    expect(find.text('Quality sheets'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Nouveau contrôle qualité'), findsNothing);

    router.go(QcPaths.machine('PROBAR', '1'));
    await _settle(tester);
    expect(find.textContaining('No quality sheet for this machine'), findsOneWidget);

    router.go(QcPaths.history);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Quality control history'), findsOneWidget);
    expect(find.text('QUALITY INSPECTOR'), findsOneWidget);
    expect(find.text('Quality Control'), findsWidgets); // compte du rôle, jamais « controle_qualite »
    expect(find.text('controle_qualite'), findsNothing);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Historique des contrôles qualité'), findsNothing);

    router.go(QcPaths.control('c886'));
    await _settle(tester);
    expect(find.text('Control Samples'), findsOneWidget);
    expect(find.text('Save Sample'), findsOneWidget);

    router.go(QcPaths.control('c867'));
    await _settle(tester);
    expect(find.textContaining('Quality control validated — Read only'), findsWidgets);

    router.go(QcPaths.newControl('PROBAR', '2'));
    await _settle(tester);
    expect(find.text('New Quality Control'), findsWidgets);
    expect(find.byType(QcReferenceBadge), findsNothing); // pas de référence avant l'enregistrement

    expect(QcI18n.frenchResidue(), isEmpty);
  });
}
