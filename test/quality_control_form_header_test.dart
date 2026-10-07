// Formulaire « Nouveau contrôle qualité » — en-tête modifiable (VM).
//
// Le VRAI écran QualityControlScreen et le VRAI service (Dio) sont utilisés ;
// seul le transport HTTP est remplacé par un faux backend en mémoire qui
// applique les champs comme l'API (la persistance PostgreSQL elle-même est
// vérifiée côté backend : test/qualityControl.module.test.js, scénario
// « en-tête »). On rejoue le scénario demandé :
//  1. contrôle PROMESH ouvert ; 2. Ouvert le = 30/09/2026, Heure = 08:15:00,
//  Date de production = 29/09/2026, Poste = Soir ; 3. brouillon ;
//  4-6. réouverture → valeurs exactes ; 7-8. Poste = Matin, Date de
//  production = 30/09/2026 ; 9-10. réouverture → nouvelles valeurs.

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

/// Faux backend : GET config / GET contrôle / PUT contrôle (champs d'en-tête
/// appliqués comme qualityControl.service#applyHeaderChanges).
class _FakeQcBackend implements HttpClientAdapter {
  final List<Map<String, dynamic>> puts = [];
  late Map<String, dynamic> control;

  _FakeQcBackend() {
    final config = jsonDecode(kQualityControlConfig) as Map<String, dynamic>;
    control = {
      'id': 'c1',
      'reference': 'QC-2026-00010',
      'productionType': 'PROMESH',
      'productionRecordRef': 'promesh:11111111-1111-1111-1111-111111111111',
      'ficheNumero': 'PROMESH-2026-000886',
      'machine': '1',
      'machineLabel': 'Machine 1',
      'poste': null,
      'posteLabel': null,
      'productionDate': '2026-09-28',
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

  static String _isoToDisplay(String iso) => '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    Object? data;
    if (options.method == 'GET' && path.endsWith('/quality-control/config')) {
      data = jsonDecode(kQualityControlConfig);
    } else if (path.endsWith('/quality-control/c1') && options.method == 'GET') {
      data = control;
    } else if (path.endsWith('/quality-control/c1') && options.method == 'PUT') {
      final body = Map<String, dynamic>.from(options.data as Map);
      puts.add(body);
      if (body['controlDate'] != null) control['controlDate'] = _isoToDisplay(body['controlDate'] as String);
      if (body['controlTime'] != null) control['controlTime'] = body['controlTime'];
      if (body['productionDate'] != null) control['productionDate'] = body['productionDate'];
      if (body['poste'] != null) {
        control['poste'] = body['poste'];
        control['posteLabel'] = body['poste'] == 'soir' ? 'Soir' : 'Matin';
      }
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
  // Clé différente = nouvel écran (comme quitter puis rouvrir la page).
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(home: QualityControlScreen(key: UniqueKey(), controlId: 'c1')));
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

Finder _fieldValue(String label, String value) =>
    find.descendant(of: find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first, matching: find.text(value));

Future<void> _pickDay(WidgetTester tester, String fieldLabel, String day) async {
  await tester.tap(find.text(fieldLabel).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(day).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Valider'));
  await tester.pumpAndSettle();
}

void main() {
  late _FakeQcBackend backend;

  setUpAll(() async {
    // Compte controle_qualite (saisie autorisée) — stockage local de test.
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('qc_form_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    GetStorage('GetStorage', dir.path, {'userRole': 'controle_qualite', 'userEmail': 'controle_qualite@cbi-tunisia.com'});
    await GetStorage.init();
  });

  setUp(() {
    backend = _FakeQcBackend();
    ApiClient.instance.dio.httpClientAdapter = backend;
  });

  testWidgets('scénario : saisie, brouillon, réouverture, modification, réouverture', (tester) async {
    tester.view.physicalSize = const Size(1440, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 1. Ouverture : valeurs chargées depuis l'API, sans cadenas.
    await _open(tester);
    expect(find.text('Contrôle qualité QC-2026-00010'), findsOneWidget); // fiche existante = mode ÉDITION
    expect(_fieldValue('Ouvert le', '28/09/2026'), findsOneWidget);
    expect(_fieldValue('Heure d\'ouverture', '10:00:00'), findsOneWidget);
    expect(_fieldValue('Date de production', '28/09/2026'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);

    // 2. Modifications via les sélecteurs Flutter.
    await _pickDay(tester, 'Ouvert le', '30');
    await tester.tap(find.text('Heure d\'ouverture'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined)); // saisie clavier
    await tester.pumpAndSettle();
    final timeFields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(timeFields.at(0), '08');
    await tester.enterText(timeFields.at(1), '15');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    await _pickDay(tester, 'Date de production', '29');
    await tester.tap(find.text('Sélectionner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soir').last);
    await tester.pumpAndSettle();
    expect(_fieldValue('Ouvert le', '30/09/2026'), findsOneWidget);
    expect(_fieldValue('Heure d\'ouverture', '08:15:00'), findsOneWidget);

    // 3. Brouillon : les 4 champs sont envoyés dans le PUT.
    await tester.tap(find.text('Enregistrer le prélèvement').first);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(backend.puts, hasLength(1));
    expect(backend.puts.single, containsPair('controlDate', '2026-09-30'));
    expect(backend.puts.single, containsPair('controlTime', '08:15:00'));
    expect(backend.puts.single, containsPair('productionDate', '2026-09-29'));
    expect(backend.puts.single, containsPair('poste', 'soir'));

    // 4-6. Quitter puis rouvrir : valeurs exactes.
    await _open(tester);
    expect(_fieldValue('Ouvert le', '30/09/2026'), findsOneWidget);
    expect(_fieldValue('Heure d\'ouverture', '08:15:00'), findsOneWidget);
    expect(_fieldValue('Date de production', '29/09/2026'), findsOneWidget);
    expect(find.text('Soir'), findsOneWidget);

    // 7-8. Poste = Matin, Date de production = 30/09/2026.
    await tester.tap(find.text('Soir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matin').last);
    await tester.pumpAndSettle();
    await _pickDay(tester, 'Date de production', '30');
    await tester.tap(find.text('Enregistrer le prélèvement').first);
    await _settle(tester);
    // Envoi PARTIEL : seuls les champs modifiés (aucune réinitialisation).
    expect(backend.puts, hasLength(2));
    expect(backend.puts.last, containsPair('poste', 'matin'));
    expect(backend.puts.last, containsPair('productionDate', '2026-09-30'));
    expect(backend.puts.last.containsKey('controlDate'), isFalse);
    expect(backend.puts.last.containsKey('controlTime'), isFalse);

    // 9-10. Réouverture : nouvelles valeurs conservées, les autres intactes.
    await _open(tester);
    expect(_fieldValue('Ouvert le', '30/09/2026'), findsOneWidget);
    expect(_fieldValue('Heure d\'ouverture', '08:15:00'), findsOneWidget);
    expect(_fieldValue('Date de production', '30/09/2026'), findsOneWidget);
    expect(find.text('Matin'), findsOneWidget);
  });

  testWidgets('édition sans changement : aucun champ d\'en-tête envoyé (aucune perte de données)', (tester) async {
    tester.view.physicalSize = const Size(1440, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    backend.control['poste'] = 'nuit'; // ancienne valeur copiée de la fiche
    backend.control['posteLabel'] = 'Nuit';
    await _open(tester);
    expect(find.textContaining('Valeur existante : Nuit'), findsOneWidget);
    await tester.tap(find.text('Enregistrer le prélèvement').first);
    await _settle(tester);
    // Rien n'a changé : aucune écriture n'est envoyée.
    expect(backend.puts, isEmpty);
    expect(backend.control['poste'], 'nuit');
  });

  group('QualityControlHeader (logique pure)', () {
    QualityControlModel model(Map<String, dynamic> over) => QualityControlModel.fromJson({
          'id': 'x',
          'productionType': 'PROMESH',
          'productionRecordRef': 'r',
          'controllerEmail': 'c',
          'status': 'EN_ATTENTE',
          'controlDate': '30/09/2026',
          'controlTime': '17:52:02',
          'productionDate': '2026-09-28',
          'poste': 'matin',
          ...over,
        });

    test('chargement depuis l\'API puis diff limité aux champs modifiés', () {
      final saved = QualityControlHeader.fromControl(model({}));
      expect(saved.controlDate, '2026-09-30');
      expect(saved.controlTime, '17:52:02');
      expect(saved.productionDate, '2026-09-28');
      expect(saved.diff(saved), isEmpty);
      final edited = saved.copyWith(controlTime: '08:15:00', poste: 'soir');
      expect(edited.diff(saved), {'controlTime': '08:15:00', 'poste': 'soir'});
    });

    test('validations : dates réelles, heure HH:mm:ss, poste Matin/Soir', () {
      expect(qcIsValidIsoDate('2026-02-30'), isFalse);
      expect(qcIsValidIsoDate('2026-09-30'), isTrue);
      expect(qcIsValidTime('24:00:00'), isFalse);
      expect(qcIsValidTime('08:15:00'), isTrue);
      expect(qcDisplayDateToIso('31/09/2026'), isNull);
      expect(qcIsoDateToDisplay('2026-09-29'), '29/09/2026');
      final bad = QualityControlHeader.fromControl(model({'productionDate': null, 'controlTime': ''}));
      expect(bad.errors(), hasLength(2));
      // Poste hérité ("nuit") : jamais envoyé ni écrasé tant que non choisi.
      final legacy = QualityControlHeader.fromControl(model({'poste': 'nuit'}));
      expect(legacy.hasLegacyPoste, isTrue);
      expect(legacy.diff(QualityControlHeader.fromControl(model({}))).containsKey('poste'), isFalse);
      expect(kQualityPostes.map((p) => p.$2), ['Matin', 'Soir']);
    });
  });
}
