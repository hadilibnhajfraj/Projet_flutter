// Formulaire Contrôle Qualité — Lot, Ordre de fabrication et recherche
// AUTOMATIQUE de la fiche de production (VM).
//
// Le VRAI écran QualityControlScreen et le VRAI service (Dio) sont utilisés ;
// seul le transport HTTP est remplacé par un faux backend en mémoire. La
// persistance PostgreSQL et l'association elle-même sont vérifiées côté
// backend (test/qualityControl.production.test.js).

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/quality_control/model/quality_control_model.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_screen.dart';

import 'fixtures/quality_control_config.dart';

const _noSheet = 'Aucune fiche de production correspondante trouvée. Le contrôle qualité peut néanmoins être enregistré.';

/// Faux backend : config, GET / PUT du contrôle, validation, et
/// GET /production-match (seule la fiche 2026-09-28 + soir « existe »).
class _FakeQcBackend implements HttpClientAdapter {
  final List<Map<String, dynamic>> puts = [];
  final List<Map<String, String>> matches = [];
  late Map<String, dynamic> control;
  // Lot / ordre de fabrication portés par la fiche de production trouvée.
  String? productionLot;
  String? productionOrder;

  _FakeQcBackend() {
    final config = jsonDecode(kQualityControlConfig) as Map<String, dynamic>;
    control = {
      'id': 'c1',
      'reference': 'QC-2026-00010',
      'productionType': 'PROMESH',
      // Association faite par le serveur : présente dans la réponse, jamais affichée.
      'productionRecordRef': 'promesh:11111111-1111-1111-1111-111111111111',
      'ficheNumero': 'PROMESH-2026-000886',
      'machine': '1',
      'machineLabel': 'Machine 1',
      'poste': null,
      'posteLabel': null,
      'productionDate': '2026-09-28',
      'lot': null,
      'manufacturingOrder': null,
      'controllerEmail': 'controle_qualite@cbi-tunisia.com',
      'status': 'EN_ATTENTE',
      'isValidated': false,
      'controlDate': '28/09/2026',
      'controlTime': '10:00:00',
      'counts': {'controlled': 0, 'nonConformes': 0, 'total': 15},
      'items': [
        for (final p in (config['parameters'] as List).cast<Map<String, dynamic>>())
          {'parameterKey': p['key'], 'parameterName': p['label'], 'position': p['position'], 'status': 'NON_CONTROLE'},
      ],
      'history': [],
    };
  }

  String? _text(Object? v) => (v == null || v.toString().trim().isEmpty) ? null : v.toString().trim();

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    Object? data;
    if (options.method == 'GET' && path.endsWith('/quality-control/config')) {
      data = jsonDecode(kQualityControlConfig);
    } else if (options.method == 'GET' && path.endsWith('/quality-control/production-match')) {
      final q = options.uri.queryParameters;
      matches.add(q);
      final found = q['productionDate'] == '2026-09-28' && q['poste'] == 'soir';
      data = {
        'matched': found,
        'reason': found ? null : 'NO_PRODUCTION_SHEET',
        'lot': found ? productionLot : null,
        'manufacturingOrder': found ? productionOrder : null,
      };
    } else if (path.endsWith('/quality-control/c1') && options.method == 'GET') {
      data = control;
    } else if (path.endsWith('/quality-control/c1') && options.method == 'PUT') {
      final body = Map<String, dynamic>.from(options.data as Map);
      puts.add(body);
      if (body['productionDate'] != null) control['productionDate'] = body['productionDate'];
      if (body['poste'] != null) control['poste'] = body['poste'];
      if (body.containsKey('lot')) control['lot'] = _text(body['lot']);
      if (body.containsKey('manufacturingOrder')) control['manufacturingOrder'] = _text(body['manufacturingOrder']);
      data = control;
    } else {
      return ResponseBody.fromString(jsonEncode({'success': false, 'message': 'not found'}), 404,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    return ResponseBody.fromString(jsonEncode({'success': true, 'data': data}), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(home: QualityControlScreen(key: UniqueKey(), controlId: 'c1')));
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

Future<void> _choosePoste(WidgetTester tester, String current, String next) async {
  await tester.tap(find.text(current));
  await tester.pumpAndSettle();
  await tester.tap(find.text(next).last);
  await tester.pumpAndSettle();
  await _settle(tester);
}

final _lot = find.byKey(const ValueKey('qc-lot'));
// Ordre de fabrication : jamais un champ de saisie — identification
// automatique de la fabrication, ou « Non renseigné ».
final _order = find.byKey(const ValueKey('qc-manufacturing-order-auto'));
final _orderEmpty = find.byKey(const ValueKey('qc-manufacturing-order-empty'));
final _notice = find.byKey(const ValueKey('qc-production-notice'));

String _value(WidgetTester tester, Finder field) => tester.widget<TextField>(field).controller!.text;

void _expectNoProductionSection() {
  for (final text in ['Production associée', 'Production contrôlée', 'Associer une production', 'Référence production', 'PROMESH-2026-000886']) {
    expect(find.textContaining(text), findsNothing, reason: text);
  }
}

void main() {
  late _FakeQcBackend backend;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('qc_lot_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    GetStorage('GetStorage', dir.path, {'userRole': 'controle_qualite', 'userEmail': 'controle_qualite@cbi-tunisia.com'});
    await GetStorage.init();
  });

  setUp(() {
    backend = _FakeQcBackend();
    ApiClient.instance.dio.httpClientAdapter = backend;
  });

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('lot et ordre de fabrication : vides par défaut, saisis, enregistrés, relus à la réouverture', (tester) async {
    bigView(tester);
    await _open(tester);

    // 01 Identification : ligne, machine, date, poste, contrôleur, lot, OF.
    expect(find.text('Identification'), findsOneWidget);
    for (final label in ['Ligne · Machine', 'Contrôleur qualité', 'Ouvert le', 'Heure d\'ouverture', 'Date de production', 'Poste', 'Lot de fabrication', 'Ordre de fabrication']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('controle_qualite@cbi-tunisia.com'), findsWidgets);
    // La production ne porte ni lot ni ordre de fabrication : saisie manuelle.
    expect(_value(tester, _lot), isEmpty); // aucune valeur fictive
    expect(_orderEmpty, findsOneWidget);
    expect(find.text('Non renseigné'), findsOneWidget);
    expect(find.byKey(const ValueKey('qc-manufacturing-order')), findsNothing); // aucune saisie
    expect(find.text('Non renseigné — saisie manuelle'), findsOneWidget); // lot seulement
    expect(find.text('Automatique'), findsNothing);
    _expectNoProductionSection();

    await tester.enterText(_lot, 'LOT-12345');
    await tester.pump();
    // La saisie du lot / de l'OF ne lance jamais la recherche de production.
    expect(backend.matches, isEmpty);

    await tester.tap(find.text('Enregistrer le prélèvement').first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(backend.puts.single, containsPair('lot', 'LOT-12345'));
    expect(backend.puts.single.containsKey('manufacturingOrder'), isFalse); // jamais envoyé
    expect(backend.puts.single.containsKey('productionRecordId'), isFalse);

    // Quitter puis rouvrir.
    await _open(tester);
    expect(_value(tester, _lot), 'LOT-12345');

    // Sans changement : rien n'est renvoyé. Lot vidé : '' envoyé, OF intact.
    await tester.tap(find.text('Enregistrer le prélèvement').first);
    await _settle(tester);
    expect(backend.puts, hasLength(1));
    await tester.enterText(_lot, '');
    await tester.tap(find.text('Enregistrer le prélèvement').first);
    await _settle(tester);
    expect(backend.puts.last, containsPair('lot', ''));
    expect(backend.puts.last.containsKey('manufacturingOrder'), isFalse);
    await _open(tester);
    expect(_value(tester, _lot), isEmpty);
  });

  testWidgets('PROBAR inchangé : sans fiche de production, le message non bloquant reste affiché', (tester) async {
    bigView(tester);
    backend.control['productionType'] = 'PROBAR';
    await _open(tester);
    await _choosePoste(tester, 'Sélectionner', 'Matin');
    expect(backend.matches.single['productionType'], 'PROBAR');
    expect(find.text(_noSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recherche automatique : lancée au choix du poste / de la date, message non bloquant, production jamais affichée', (tester) async {
    bigView(tester);
    await _open(tester);
    expect(backend.matches, isEmpty); // poste non renseigné : pas de recherche
    expect(_notice, findsNothing);

    // Poste = Soir → recherche PROMESH + machine 1 + date + soir : trouvée.
    await _choosePoste(tester, 'Sélectionner', 'Soir');
    expect(backend.matches.single, {'productionType': 'PROMESH', 'machine': '1', 'productionDate': '2026-09-28', 'poste': 'soir'});
    expect(_notice, findsNothing);
    _expectNoProductionSection();

    // Poste = Matin → nouvelle recherche, aucune fiche de production : pour
    // PROMESH (fiche qualité indépendante) aucun message, rien de bloqué.
    await _choosePoste(tester, 'Soir', 'Matin');
    expect(backend.matches, hasLength(2));
    expect(backend.matches.last['poste'], 'matin');
    expect(_notice, findsNothing);
    expect(find.text(_noSheet), findsNothing);

    await tester.tap(find.text('Enregistrer le prélèvement').first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(backend.puts.single, containsPair('poste', 'matin'));
    expect(find.text('Valider le contrôle qualité'), findsWidgets);

    // Date de production modifiée → recherche relancée avec la nouvelle date.
    final before = backend.matches.length;
    await tester.tap(find.text('Date de production').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('29').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(backend.matches.length, before + 1);
    expect(backend.matches.last, containsPair('productionDate', '2026-09-29'));
    _expectNoProductionSection();
  });

  testWidgets('lot et ordre de fabrication de la production : repris automatiquement, lecture seule, jamais envoyés', (tester) async {
    bigView(tester);
    backend
      ..productionLot = 'LOT-2026-001'
      ..productionOrder = 'FAB01 — 28/09/2026 — Ø12';
    await _open(tester);
    expect(_lot, findsOneWidget); // poste non choisi : pas encore de recherche

    // Date + poste (Soir) → la fiche de production est trouvée : lot et OF affichés.
    await _choosePoste(tester, 'Sélectionner', 'Soir');
    expect(find.byKey(const ValueKey('qc-lot-auto')), findsOneWidget);
    expect(find.byKey(const ValueKey('qc-manufacturing-order-auto')), findsOneWidget);
    expect(find.text('LOT-2026-001'), findsOneWidget);
    expect(find.text('FAB01 — 28/09/2026 — Ø12'), findsOneWidget);
    expect(find.text('Automatique'), findsNWidgets(2));
    // Lecture seule : plus aucun champ de saisie pour ces deux informations.
    expect(_lot, findsNothing);
    expect(_order, findsOneWidget);
    expect(_orderEmpty, findsNothing);
    expect(_notice, findsNothing);
    _expectNoProductionSection();

    await tester.tap(find.text('Enregistrer le prélèvement').first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(backend.puts.single, containsPair('poste', 'soir'));
    expect(backend.puts.single.containsKey('lot'), isFalse);
    expect(backend.puts.single.containsKey('manufacturingOrder'), isFalse);

    // Poste = Matin : aucune fiche de production → saisie manuelle, sans message (PROMESH).
    await _choosePoste(tester, 'Soir', 'Matin');
    expect(find.text(_noSheet), findsNothing);
    expect(find.text('Automatique'), findsNothing);
    expect(_orderEmpty, findsOneWidget);
    expect(_lot, findsOneWidget);
    expect(_value(tester, _lot), isEmpty);
  });

  testWidgets('fiche dont le lot vient de la production (valeur enregistrée) : affichée « Automatique » même validée', (tester) async {
    bigView(tester);
    backend.control
      ..['isValidated'] = true
      ..['status'] = 'CONFORME'
      ..['poste'] = 'matin'
      ..['lot'] = 'LOT-2026-001'
      ..['lotAuto'] = true
      ..['manufacturingOrder'] = null;
    await _open(tester);
    expect(find.byKey(const ValueKey('qc-lot-auto')), findsOneWidget);
    expect(find.text('LOT-2026-001'), findsOneWidget);
    expect(find.text('Automatique'), findsOneWidget);
    // Ordre de fabrication absent de la production : « Non renseigné ».
    expect(find.text('Non renseigné'), findsOneWidget);
    expect(backend.matches, isEmpty);
  });

  testWidgets('contrôle validé : lot, ordre de fabrication, poste et date en lecture seule', (tester) async {
    bigView(tester);
    backend.control
      ..['isValidated'] = true
      ..['status'] = 'CONFORME'
      ..['validatedDate'] = '28/09/2026'
      ..['validatedTime'] = '11:00:00'
      ..['poste'] = 'matin'
      ..['posteLabel'] = 'Matin'
      ..['lot'] = 'LOT-2026-103'
      ..['manufacturingOrder'] = 'OF-2026-00458';
    await _open(tester);

    expect(_value(tester, _lot), 'LOT-2026-103');
    expect(tester.widget<TextField>(_lot).readOnly, isTrue);
    // Fabrication enregistrée : affichée, sans champ de saisie.
    expect(find.text('OF-2026-00458'), findsOneWidget);
    expect(_order, findsOneWidget);
    await tester.enterText(_lot, 'AUTRE');
    expect(_value(tester, _lot), 'LOT-2026-103');
    expect(tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>)).onChanged, isNull);

    // Sélecteur de date inactif, aucune recherche, aucun message, aucun envoi.
    await tester.tap(find.text('Date de production').first);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(backend.matches, isEmpty);
    expect(_notice, findsNothing);
    expect(find.text('Enregistrer le prélèvement'), findsNothing);
    expect(backend.puts, isEmpty);
    _expectNoProductionSection();
  });

  group('logique pure', () {
    QualityControlModel model(Map<String, dynamic> over) => QualityControlModel.fromJson({
          'id': 'x',
          'productionType': 'PROMESH',
          'controllerEmail': 'c',
          'status': 'EN_ATTENTE',
          'controlDate': '03/10/2026',
          'controlTime': '19:54:24',
          'productionDate': '2026-10-03',
          'poste': 'matin',
          ...over,
        });

    test('en-tête : lot / ordre de fabrication chargés, diff limité aux champs modifiés', () {
      final empty = QualityControlHeader.fromControl(model({}));
      expect(empty.lot, isEmpty);
      expect(empty.manufacturingOrder, isEmpty);
      expect(empty.diff(empty), isEmpty);
      expect(empty.copyWith(lot: '  LOT-2026-103 ', manufacturingOrder: 'OF-2026-00458').diff(empty),
          {'lot': 'LOT-2026-103', 'manufacturingOrder': 'OF-2026-00458'});

      final saved = QualityControlHeader.fromControl(model({'lot': 'LOT-1', 'manufacturingOrder': 'OF-1'}));
      expect(saved.copyWith(lot: '').diff(saved), {'lot': ''});
      // Création : seules les valeurs saisies partent.
      expect(saved.diff(const QualityControlHeader()).keys, containsAll(['lot', 'manufacturingOrder', 'poste', 'productionDate']));
      expect(empty.diff(const QualityControlHeader()).containsKey('lot'), isFalse);
    });

    test('recherche : possible seulement avec une date valide et un poste Matin / Soir', () {
      expect(QualityControlHeader.fromControl(model({})).canMatchProduction, isTrue);
      expect(QualityControlHeader.fromControl(model({'poste': null})).canMatchProduction, isFalse);
      expect(QualityControlHeader.fromControl(model({'poste': 'nuit'})).canMatchProduction, isFalse);
      expect(QualityControlHeader.fromControl(model({'productionDate': null})).canMatchProduction, isFalse);
    });

    test('état de la recherche : message uniquement sans correspondance unique', () {
      expect(QcProductionMatch.fromJson({'matched': true, 'reason': null}).notice, isNull);
      expect(QcProductionMatch.fromJson({'matched': false, 'reason': 'NO_PRODUCTION_SHEET'}).notice, _noSheet);
      expect(QcProductionMatch.fromJson({'matched': false, 'reason': 'MULTIPLE_PRODUCTION_SHEETS'}).notice, contains('Plusieurs fiches de production'));
    });
  });
}
