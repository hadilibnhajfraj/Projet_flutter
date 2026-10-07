// Contrôle Qualité — fiche à ÉTAPES (prélèvements périodiques) (VM).
//
// Le VRAI écran QualityControlScreen et le VRAI service (Dio) sont utilisés ;
// seul le transport HTTP est remplacé par un faux backend en mémoire qui
// applique les mêmes règles que l'API (prélèvements indépendants, rang d'étape =
// dernier rang + 1, heure unique par fiche, prélèvement validé en lecture seule,
// lot / ordre de fabrication repris de la production). La persistance
// PostgreSQL est vérifiée côté backend (test/qualityControl.steps.test.js et
// qualityControl.readings.test.js).
//
// Scénario demandé : fiche PROMESH Machine 1 Matin, lot et OF repris de la
// production ; ÉTAPE 1 à 08:00 (20 / 180 / 12) ; « + Nouveau prélèvement » propose
// 11:00 → ÉTAPE 2 (mêmes paramètres, valeurs vides : 22 / 182 / 12.1) ;
// retour à l'étape 1 puis à l'étape 2 : rien n'est écrasé ; ÉTAPE 3 proposée
// puis saisie à 14:17.

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
import 'package:dash_master_toolkit/quality_control/view/quality_control_widgets.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_reading_form.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_reading_stepper.dart';
import 'package:dash_master_toolkit/quality_control/quality_control_i18n.dart' show QcI18n;

import 'fixtures/quality_control_config.dart';

class _Reading {
  final String id;
  final int sequence;
  String time;
  bool validated;
  String status;
  final Map<String, Map<String, String?>> values = {};
  _Reading(this.id, this.sequence, this.time, {this.validated = false, this.status = 'EN_COURS'});
}

/// Faux backend : une fiche `c1` et ses prélèvements (étapes).
class _FakeQcBackend implements HttpClientAdapter {
  final List<String> requests = [];
  final List<Map<String, dynamic>> readingPosts = [];
  final List<_Reading> readings = [];
  static final List<Map<String, dynamic>> _all = ((jsonDecode(kQualityControlConfig) as Map)['parameters'] as List).cast<Map<String, dynamic>>();
  // Contrôles d'un prélèvement / paramètres physiques de la fiche : deux niveaux.
  // Contrôles d'un prélèvement : ceux de la LIGNE de la fiche.
  List<Map<String, dynamic>> get params => _all.where((p) => p['scope'] == 'reading' && (p['lines'] as List).contains(_line)).toList();
  // Contrôle spécifique (treillis GFRP) : valeur / statut / remarque par paramètre.
  final Map<String, Map<String, String?>> specific = {};
  String productionType = 'PROMESH';
  String machine = '1';
  // Liste de paramètres de la fiche : celle de sa machine si elle en a une (PROMESH 4).
  String get _line => productionType == 'PROMESH' && machine == '4' ? 'PROMESH:4' : productionType;
  final Map<String, String?> physical = {};
  final List<Map<String, dynamic>> fichePuts = [];
  List<Map<String, dynamic>> get _ficheParams => _all.where((p) => p['scope'] == 'fiche' && (p['lines'] as List).contains(_line)).toList();
  List<Map<String, dynamic>> get physicalParams => _ficheParams.where((p) => p['section'] == 'physique').toList();
  List<Map<String, dynamic>> get specificParams => _ficheParams.where((p) => p['section'] != 'physique').toList();
  bool ficheValidated = false;
  String reference = 'QC-2026-00010';
  // Journal d'audit renvoyé par l'API (conservé côté serveur, jamais affiché).
  List<Map<String, dynamic>> history = [];
  // Lot / ordre de fabrication portés par la fiche de production (Matin).
  String? productionLot;
  String? productionOrder;
  int _seq = 0;

  _Reading add(String time, {Map<String, String> values = const {}, bool validated = false, String status = 'EN_COURS'}) {
    _seq++;
    final r = _Reading('r$_seq', _seq, time, validated: validated, status: status);
    for (final e in values.entries) {
      r.values[e.key] = {'value': e.value, 'status': 'CONFORME', 'remark': null};
    }
    readings.add(r);
    return r;
  }

  Map<String, dynamic> _readingJson(_Reading r, int step) {
    final items = [
      for (final p in params)
        {
          'parameterKey': p['key'],
          'parameterName': p['label'],
          'position': p['position'],
          'value': r.values[p['key']]?['value'],
          'status': r.values[p['key']]?['status'] ?? 'NON_CONTROLE',
          'remark': r.values[p['key']]?['remark'],
        },
    ];
    final controlled = items.where((i) => i['status'] != 'NON_CONTROLE').length;
    final nc = items.where((i) => i['status'] == 'NON_CONFORME').toList();
    return {
      'id': r.id,
      'step': step,
      'sequence': r.sequence,
      'readingTime': r.time,
      'status': r.status,
      'isValidated': r.validated,
      'validatedDate': r.validated ? '03/10/2026' : null,
      'validatedTime': r.validated ? '08:30:00' : null,
      'counts': {'controlled': controlled, 'nonConformes': nc.length, 'total': params.length},
      'nonConformParameters': [for (final i in nc) i['parameterName']],
      'items': items,
    };
  }

  Map<String, dynamic> control({String? readingId}) {
    // Ordre des étapes : le rang de création, jamais l'heure.
    final sorted = [...readings]..sort((a, b) => a.sequence.compareTo(b.sequence));
    final json = [for (var i = 0; i < sorted.length; i++) _readingJson(sorted[i], i + 1)];
    return {
      'id': 'c1',
      'reference': reference,
      'productionType': productionType,
      'machine': machine,
      'machineLabel': 'Machine $machine',
      'poste': 'matin',
      'posteLabel': 'Matin',
      'productionDate': '2026-10-03',
      'lot': productionLot,
      'manufacturingOrder': productionOrder,
      'lotAuto': productionLot != null,
      'manufacturingOrderAuto': productionOrder != null,
      'controllerEmail': 'controle_qualite@cbi-tunisia.com',
      'status': ficheValidated ? 'CONFORME' : 'EN_COURS',
      'isValidated': ficheValidated,
      // Heure d'OUVERTURE de la fiche — jamais celle d'un prélèvement.
      'controlDate': '03/10/2026',
      'controlTime': '20:10:56',
      'readingsCount': sorted.length,
      'lastReadingTime': sorted.isEmpty ? null : sorted.last.time,
      'suggestedNextReadingTime': sorted.isEmpty ? '08:00' : qcAddMinutes(sorted.last.time, 180),
      'readings': json,
      'counts': {'controlled': 0, 'nonConformes': 0, 'total': params.length * (sorted.isEmpty ? 1 : sorted.length)},
      'items': json.isEmpty ? [] : json.last['items'],
      'physicalParameters': [
        for (final p in physicalParams)
          {'parameterKey': p['key'], 'parameterName': p['label'], 'position': p['position'], 'value': physical[p['key']], 'status': 'NON_CONTROLE'},
      ],
      'specificParameters': [
        for (final p in specificParams)
          {
            'parameterKey': p['key'],
            'parameterName': p['label'],
            'position': p['position'],
            'section': p['section'],
            'value': specific[p['key']]?['value'],
            'status': specific[p['key']]?['status'] ?? 'NON_CONTROLE',
            'remark': specific[p['key']]?['remark'],
          },
      ],
      'history': history,
      if (readingId != null) 'readingId': readingId,
    };
  }

  void _apply(_Reading r, Map<String, dynamic> body) {
    if (body['readingTime'] != null) r.time = body['readingTime'] as String;
    for (final i in (body['items'] as List? ?? []).cast<Map>()) {
      String? text(Object? v) => (v == null || v.toString().trim().isEmpty) ? null : v.toString().trim();
      r.values[i['parameterKey'] as String] = {'value': text(i['value']), 'status': i['status'] as String?, 'remark': text(i['remark'])};
    }
  }

  void _validate(_Reading r) {
    r.validated = true;
    r.status = r.values.values.any((v) => v['status'] == 'NON_CONFORME') ? 'NON_CONFORME' : 'CONFORME';
  }

  ResponseBody _json(Object body, [int status = 200]) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  ResponseBody _ok(Object data, [int status = 200]) => _json({'success': true, 'data': data}, status);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = o.uri.path;
    requests.add('${o.method} ${path.substring(path.indexOf('/quality-control'))}');
    if (path.endsWith('/config')) return _ok(jsonDecode(kQualityControlConfig) as Object);
    if (path.endsWith('/production-match')) {
      return _ok({'matched': true, 'reason': null, 'lot': productionLot, 'manufacturingOrder': productionOrder});
    }
    final body = o.data is Map ? Map<String, dynamic>.from(o.data as Map) : <String, dynamic>{};

    final m = RegExp(r'/quality-control/c1/readings(?:/(r\d+))?(/validate)?$').firstMatch(path);
    if (m != null) {
      if (ficheValidated) return _json({'success': false, 'code': 'CONTROL_LOCKED', 'message': 'Lecture seule'}, 403);
      if (m[1] == null) {
        // NOUVEAU prélèvement : étape suivante ; une heure n'existe qu'une fois.
        readingPosts.add(Map<String, dynamic>.of(body));
        final time = body['readingTime'] as String;
        final dup = readings.where((r) => r.time == time);
        if (dup.isNotEmpty) {
          return _json({'success': false, 'code': 'READING_TIME_EXISTS', 'existingReadingId': dup.first.id, 'message': 'Un prélèvement existe déjà pour $time.'}, 409);
        }
        final r = add(time);
        _apply(r, body..remove('readingTime'));
        if (body['validate'] == true) _validate(r);
        return _ok(control(readingId: r.id), 201);
      }
      final r = readings.firstWhere((x) => x.id == m[1]);
      if (r.validated) return _json({'success': false, 'code': 'READING_LOCKED', 'message': 'Prélèvement validé'}, 403);
      if (o.method == 'DELETE') {
        readings.remove(r);
        return _ok(control());
      }
      _apply(r, body);
      if (m[2] != null) _validate(r);
      return _ok(control(readingId: r.id));
    }
    if (path.endsWith('/quality-control/c1/validate')) {
      for (final r in readings.where((r) => !r.validated)) {
        _validate(r);
      }
      ficheValidated = true;
      return _ok(control());
    }
    if (path.endsWith('/quality-control/c1')) {
      if (o.method == 'PUT') {
        // Niveau FICHE : paramètres physiques (aucun prélèvement touché).
        fichePuts.add(Map<String, dynamic>.of(body));
        for (final i in (body['physical'] as List? ?? []).cast<Map>()) {
          String? text(Object? v) => (v == null || v.toString().trim().isEmpty) ? null : v.toString().trim();
          final key = i['parameterKey'] as String;
          if (key.startsWith('treillis_')) {
            specific[key] = {'value': text(i['value']), 'status': i['status'] as String?, 'remark': text(i['remark'])};
          } else {
            physical[key] = text(i['value']);
          }
        }
      }
      return _ok(control());
    }
    return _json({'success': false, 'message': 'not found'}, 404);
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

Future<void> _open(WidgetTester tester, {Size size = const Size(1440, 9000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(home: QualityControlScreen(key: UniqueKey(), controlId: 'c1')));
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

final _timeField = find.byKey(const ValueKey('qc-reading-time'));
final _newButton = find.byKey(const ValueKey('qc-new-reading'));
final _prev = find.byKey(const ValueKey('qc-prev-reading'));
final _next = find.byKey(const ValueKey('qc-next-reading'));

// Les trois paramètres du scénario : vitesse de tirage, température de la
// filière, diamètre de la barre.
const _keys = ['temperature_machine', 'temperature_eau', 'pression_air_comprime'];
const _labels = ['TEMPÉRATURE DE MACHINE', 'TEMPÉRATURE D\'EAU', 'PRESSION D\'AIR COMPRIMÉ'];
Finder _field(String key) => find.byKey(ValueKey('qc-value-$key'));

List<String> _values(WidgetTester tester) => [for (final k in _keys) tester.widget<TextField>(_field(k)).controller!.text];

Finder _row(String readingId) => find.byKey(ValueKey('qc-reading-$readingId'));

/// Valeur affichée dans une tuile (libellé au-dessus de la valeur).
Finder _tile(String label, String value) =>
    find.descendant(of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first, matching: find.text(value));

/// Sélecteur d'heure Flutter : accepte l'heure proposée, ou en saisit une
/// autre (mode clavier).
Future<void> _confirmTime(WidgetTester tester, {String? hh, String? mm}) async {
  expect(find.byType(TimePickerDialog), findsOneWidget);
  if (hh != null) {
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), hh);
    await tester.enterText(fields.at(1), mm!);
  }
  await tester.tap(find.text('Valider'));
  await tester.pumpAndSettle();
}

/// Saisit les trois valeurs du scénario et les déclare conformes.
Future<void> _fill(WidgetTester tester, List<String> values) async {
  for (var i = 0; i < _keys.length; i++) {
    await tester.enterText(_field(_keys[i]), values[i]);
    final card = find.ancestor(of: find.text(_labels[i]), matching: find.byType(Column)).first;
    await tester.tap(find.descendant(of: card, matching: find.text('Conforme')));
    await tester.pump();
  }
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Enregistrer le prélèvement').first);
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

Future<void> _newReading(WidgetTester tester, {String? hh, String? mm}) async {
  await tester.tap(_newButton);
  await tester.pumpAndSettle();
  await _confirmTime(tester, hh: hh, mm: mm);
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

List<String?> _stored(_FakeQcBackend backend, int index) => [for (final k in _keys) backend.readings[index].values[k]?['value']];

void main() {
  late _FakeQcBackend backend;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('qc_readings_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    GetStorage('GetStorage', dir.path, {'userRole': 'controle_qualite', 'userEmail': 'controle_qualite@cbi-tunisia.com'});
    await GetStorage.init();
  });

  setUp(() {
    backend = _FakeQcBackend();
    ApiClient.instance.dio.httpClientAdapter = backend;
  });

  testWidgets('TEST COMPLET — lot et OF automatiques ; étape 1 (08:00), étape 2 (11:00 proposé), étape 3 (14:17) : aucune valeur écrasée', (tester) async {
    backend
      ..productionLot = 'LOT-2026-001'
      ..productionOrder = 'FAB01 — 03/10/2026 — Ø12';
    await _open(tester);

    // Structure : 01 Identification, 02 Prélèvements (Contrôle Machine), Contrôle Produit, 04 Synthèse.
    for (final (number, title) in const [('01', 'Identification'), ('02', 'Prélèvements de contrôle'), ('04', 'Synthèse')]) {
      expect(find.descendant(of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first, matching: find.text(number)), findsOneWidget, reason: title);
    }
    for (final label in ['Contrôle Machine', 'Contrôle Produit']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final text in ['Production associée', 'Production contrôlée', 'Associer une production']) {
      expect(find.textContaining(text), findsNothing, reason: text);
    }

    // Identification : lot et OF repris de la production, lecture seule.
    expect(find.text('PROMESH · Machine 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('qc-lot-auto')), findsOneWidget);
    expect(find.text('LOT-2026-001'), findsOneWidget);
    expect(find.text('FAB01 — 03/10/2026 — Ø12'), findsOneWidget); // fabrication identifiée automatiquement
    expect(find.byKey(const ValueKey('qc-manufacturing-order')), findsNothing); // jamais saisie
    expect(find.text('Automatique'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('qc-lot')), findsNothing);

    // ÉTAPE 1 — 08:00 (non enregistrée) : 20 / 180 / 12.
    expect(find.byKey(const ValueKey('qc-reading-new')), findsOneWidget);
    expect(find.text('ÉTAPE 1'), findsOneWidget);
    expect(_tile('Heure du prélèvement', '08:00'), findsOneWidget);
    expect(_tile('Heure d\'ouverture', '20:10:56'), findsOneWidget); // heure de la fiche, distincte
    expect(tester.widget<InkWell>(_newButton).onTap, isNull); // étape 1 d'abord
    await _fill(tester, ['20', '180', '12']);
    await _save(tester);
    expect(backend.readingPosts.single['readingTime'], '08:00');
    expect((backend.readingPosts.single['items'] as List).map((i) => '${i['parameterKey']}=${i['value']}'),
        ['temperature_machine=20', 'temperature_eau=180', 'pression_air_comprime=12']);
    expect(backend.readingPosts.single.containsKey('lot'), isFalse);
    expect(find.text('3/8 contrôlés'), findsOneWidget);
    expect(find.text('Étape 1 / 1'), findsOneWidget);

    // + Nouveau prélèvement : 11:00 proposé dans le sélecteur, accepté → ÉTAPE 2.
    expect(find.text('proposé : 11:00'), findsOneWidget);
    await _newReading(tester);
    expect(backend.readingPosts.last, {'readingTime': '11:00', 'items': []});
    expect(find.byType(QualityControlScreen), findsOneWidget); // même écran
    expect(find.byType(QualityReadingForm), findsOneWidget); // UN seul formulaire
    expect(find.text('ÉTAPE 2'), findsOneWidget);
    expect(find.text('Étape 2 / 2'), findsOneWidget);
    expect(_tile('Heure du prélèvement', '11:00'), findsOneWidget);
    // Mêmes paramètres, valeurs vides : rien n'est recopié de l'étape 1.
    for (final label in _labels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(_values(tester), ['', '', '']);
    // La valeur précédente est seulement proposée.
    expect(find.text('Précédent (08:00) : 20 °C'), findsOneWidget);
    expect(find.byKey(const ValueKey('qc-reuse-temperature_machine')), findsOneWidget);

    await _fill(tester, ['22', '182', '12.1']);

    // Retour à l'ÉTAPE 1 : la saisie de l'étape 2 est enregistrée, puis 20 / 180 / 12.
    await tester.tap(_prev);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(backend.requests, contains('PUT /quality-control/c1/readings/r2'));
    expect(find.text('Étape 1 / 2'), findsOneWidget);
    expect(_values(tester), ['20', '180', '12']);
    // Retour à l'ÉTAPE 2 : 22 / 182 / 12.1.
    await tester.tap(_next);
    await _settle(tester);
    expect(_values(tester), ['22', '182', '12.1']);
    expect(_stored(backend, 0), ['20', '180', '12']);
    expect(_stored(backend, 1), ['22', '182', '12.1']);

    // Heure réelle de l'étape 2 : 11:05.
    await tester.tap(_timeField);
    await tester.pumpAndSettle();
    await _confirmTime(tester, hh: '11', mm: '05');
    expect(_tile('Heure du prélèvement', '11:05'), findsOneWidget);

    // TEST 3ᵉ PRÉLÈVEMENT — heure proposée modifiée en 14:17 → ÉTAPE 3.
    await _newReading(tester, hh: '14', mm: '17');
    expect(backend.readings.map((r) => '${r.sequence}:${r.time}'), ['1:08:00', '2:11:05', '3:14:17']);
    expect(find.text('Étape 3 / 3'), findsOneWidget);
    expect(_values(tester), ['', '', '']);
    for (final step in ['ÉTAPE 1', 'ÉTAPE 2', 'ÉTAPE 3']) {
      expect(find.text(step), findsOneWidget, reason: step);
    }
    // Stepper : navigation seule — une carte compacte par prélèvement, aucun paramètre physique.
    final stepper = find.byType(QualityReadingStepper);
    for (final time in ['08:00', '11:05', '14:17']) {
      expect(find.descendant(of: stepper, matching: find.text(time)), findsOneWidget, reason: time);
    }
    for (final label in _labels) {
      expect(find.descendant(of: stepper, matching: find.text(label)), findsNothing, reason: label);
    }
    expect(find.descendant(of: stepper, matching: find.byType(TextField)), findsNothing);
    // Les contrôles affichés sont ceux du prélèvement actuel (étape 3), et de lui seul.
    expect(find.text('CONTRÔLES DU PRÉLÈVEMENT 3 — 14:17'), findsOneWidget);
    expect(find.text('Prélèvement actuel — étape 3'), findsOneWidget);

    // « Reprendre » : action volontaire, valeur seule (le statut reste à choisir).
    expect(find.text('Précédent (11:05) : 22 °C'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qc-reuse-temperature_machine')));
    await tester.pump();
    expect(_values(tester), ['22', '', '']);
    await _save(tester);
    expect(backend.readings[2].values['temperature_machine'], containsPair('status', 'NON_CONTROLE'));

    // Aucun prélèvement existant modifié par les créations ; étape 1 jamais réécrite.
    expect(backend.requests.where((r) => r.contains('/readings/r1')), isEmpty);
    expect(_stored(backend, 0), ['20', '180', '12']);
    expect(_stored(backend, 1), ['22', '182', '12.1']);
    expect(_tile('Heure d\'ouverture', '20:10:56'), findsOneWidget);

    // 04 Synthèse : 1 fiche, 3 prélèvements, paramètres contrôlés de tous les prélèvements.
    for (final (label, value) in const [('Fiche QC', '1'), ('Prélèvements', '3'), ('Paramètres contrôlés', '6'), ('Non-conformités', '0')]) {
      expect(find.descendant(of: find.ancestor(of: find.text(label), matching: find.byType(QcKpiTile)), matching: find.text(value)), findsOneWidget, reason: label);
    }
    expect(find.text('dernier : 14:17'), findsOneWidget);
  });

  testWidgets('heure déjà utilisée : « Un prélèvement existe déjà pour 08:00. » → ouvrir le prélèvement existant, aucun doublon', (tester) async {
    backend.add('08:00', values: {'temperature_machine': '20'});
    await _open(tester);
    await _newReading(tester, hh: '08', mm: '00');
    expect(find.text('Un prélèvement existe déjà pour 08:00.'), findsOneWidget);
    expect(find.text('Choisir une autre heure'), findsOneWidget);
    await tester.tap(find.text('Ouvrir le prélèvement existant'));
    await _settle(tester);

    expect(_tile('Heure du prélèvement', '08:00'), findsOneWidget);
    expect(_values(tester).first, '20');
    expect(backend.readingPosts, isEmpty);
    expect(backend.readings, hasLength(1));
  });

  testWidgets('prélèvement validé : lecture seule ; prélèvement brouillon : modifiable, validé seul ; fiche validée : plus de prélèvement', (tester) async {
    backend.add('08:00', values: {'temperature_machine': '20'}, validated: true, status: 'CONFORME');
    backend.add('11:05', values: {'temperature_machine': '22'});
    await _open(tester);
    final speed = _field('temperature_machine');

    // Ouverture : dernier prélèvement brouillon (étape 2), modifiable.
    expect(find.text('Étape 2 / 2'), findsOneWidget);
    expect(tester.widget<TextField>(speed).enabled, isTrue);
    expect(find.text('Valider le prélèvement'), findsOneWidget);

    // Clic sur l'étape 1 dans la timeline : le brouillon en cours est enregistré.
    await tester.enterText(speed, '23');
    await tester.pump();
    await tester.tap(_row('r1'));
    await _settle(tester);
    expect(backend.readings[1].values['temperature_machine']!['value'], '23');

    // Étape 1 validée : aucune saisie possible.
    expect(_tile('Heure du prélèvement', '08:00'), findsOneWidget);
    expect(tester.widget<TextField>(speed).controller!.text, '20');
    expect(tester.widget<TextField>(speed).enabled, isFalse);
    expect(find.text('Valider le prélèvement'), findsNothing);
    expect(find.text('Supprimer le prélèvement'), findsNothing);
    expect(find.byKey(const ValueKey('qc-reuse-temperature_machine')), findsNothing);
    await tester.tap(_timeField);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsNothing);
    // La fiche reste ouverte : nouveaux prélèvements possibles.
    expect(tester.widget<InkWell>(_newButton).onTap, isNotNull);

    // Étape 2 : valider CE prélèvement seulement.
    await tester.tap(_next);
    await _settle(tester);
    expect(tester.widget<TextField>(speed).controller!.text, '23');
    await tester.tap(find.text('Valider le prélèvement'));
    await tester.pumpAndSettle();
    expect(find.text('Valider le prélèvement de 11:05'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Valider le prélèvement').last);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(backend.requests, contains('POST /quality-control/c1/readings/r2/validate'));
    expect(backend.readings.every((r) => r.validated), isTrue);
    expect(backend.ficheValidated, isFalse);
    expect(tester.widget<TextField>(speed).enabled, isFalse);

    // Valider le contrôle qualité : fiche clôturée, plus aucun prélèvement ajoutable.
    await tester.tap(find.text('Valider le contrôle qualité'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await _settle(tester);
    expect(backend.ficheValidated, isTrue);
    expect(find.textContaining('Contrôle qualité validé — Lecture seule'), findsWidgets);
    expect(_newButton, findsNothing);
    for (final label in ['Enregistrer le prélèvement', 'Valider le prélèvement', 'Valider le contrôle qualité']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    // Les étapes restent consultables.
    expect(find.text('ÉTAPE 1'), findsOneWidget);
    expect(find.text('ÉTAPE 2'), findsOneWidget);
  });

  testWidgets('mise en page : stepper HORIZONTAL au-dessus du prélèvement actif, défilement sur écran étroit', (tester) async {
    backend
      ..add('08:00', validated: true, status: 'CONFORME')
      ..add('11:00', validated: true, status: 'CONFORME')
      ..add('14:00');
    final stepper = find.byType(QualityReadingStepper);
    final form = find.byType(QualityReadingForm);

    await _open(tester, size: const Size(1440, 3000));
    // Étapes côte à côte, sur une même ligne, suivies de « + Nouveau prélèvement ».
    final rects = [for (final id in ['r1', 'r2', 'r3']) tester.getRect(_row(id))];
    expect(rects[0].right, lessThan(rects[1].left));
    expect(rects[1].right, lessThan(rects[2].left));
    expect(rects.map((r) => r.top).toSet(), hasLength(1));
    expect(tester.getRect(_newButton).left, greaterThan(rects[2].right));
    expect((tester.getRect(_newButton).center.dy - rects[2].center.dy).abs(), lessThan(2));
    // Le prélèvement actif et ses paramètres sont SOUS le stepper.
    expect(tester.getBottomLeft(stepper).dy, lessThan(tester.getTopLeft(form).dy));
    expect(tester.getBottomLeft(stepper).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('qc-parameters-heading'))).dy));
    // Une seule étape active : l'étape 3 (dernier brouillon).
    expect(find.text('Prélèvement actuel — étape 3'), findsOneWidget);
    expect(find.text('Étape 3 / 3'), findsOneWidget);

    // Tablette / téléphone : le stepper défile horizontalement, sans débordement.
    for (final size in const [Size(800, 7000), Size(390, 9000)]) {
      await _open(tester, size: size);
      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.descendant(of: stepper, matching: find.byType(SingleChildScrollView)), findsOneWidget);
      expect(tester.getRect(_row('r1')).top, tester.getRect(_row('r2')).top);
      expect(find.text('Enregistrer le prélèvement'), findsOneWidget);
    }
  });

  testWidgets('TEST OBLIGATOIRE PROBAR — FAB automatique, prélèvements horizontaux, 7 paramètres du contrôle produit affichés UNE fois et enregistrés à part', (tester) async {
    backend
      ..productionType = 'PROBAR'
      ..productionLot = 'LOT-01'
      ..productionOrder = 'FAB01 — 28/08/2026 — Ø12'
      ..add('08:00', values: {'variateur_frequence_tirage': '20'}, validated: true, status: 'CONFORME')
      ..add('11:00', values: {'variateur_frequence_tirage': '22'}, validated: true, status: 'CONFORME')
      ..add('14:00', values: {'variateur_frequence_tirage': '24'});
    await _open(tester);
    const labels = [
      'DIAMÈTRE NOMINAL',
      'DIAMÈTRE RÉEL',
      'SECTION TRANSVERSALE',
      'LONGUEUR',
      'POIDS EN g',
      'DÉFAUTS SUPERFICIELS',
    ];
    final stepper = find.byType(QualityReadingStepper);
    final section = find.byKey(const ValueKey('qc-physical-section'));
    final current = find.byKey(const ValueKey('qc-current-reading'));
    final actions = find.byKey(const ValueKey('qc-reading-actions'));
    Finder phys(String key) => find.byKey(ValueKey('qc-physical-$key'));

    // Identification : fabrication et lot automatiques, visibles aussi dans le bandeau fixe.
    expect(find.text('FAB01 — 28/08/2026 — Ø12'), findsOneWidget);
    expect(find.text('LOT-01'), findsOneWidget);
    final bar = find.byKey(const ValueKey('qc-identity-bar'));
    expect(find.descendant(of: bar, matching: find.text('Fabrication : FAB01 — 28/08/2026 — Ø12')), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text('Lot : LOT-01')), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.byType(QcReferenceBadge)), findsOneWidget); // étiquette de la fiche
    expect(find.ancestor(of: bar, matching: find.byType(ListView)), findsNothing); // hors de la zone qui défile

    // Stepper horizontal : ① 08:00 ✓, ② 11:00 ✓, ③ 14:00 actif — aucun paramètre physique dedans.
    final rects = [for (final id in ['r1', 'r2', 'r3']) tester.getRect(_row(id))];
    expect(rects[0].right, lessThan(rects[1].left));
    expect(rects[1].right, lessThan(rects[2].left));
    expect(rects.map((r) => r.top).toSet(), hasLength(1));
    for (final label in labels) {
      expect(find.descendant(of: stepper, matching: find.text(label)), findsNothing, reason: label);
    }
    expect(find.descendant(of: stepper, matching: find.byType(TextField)), findsNothing);

    // Ordre de la page : prélèvements → prélèvement actuel → actions du prélèvement → paramètres physiques.
    expect(find.text('Paramètres physiques PROBAR'), findsNothing);
    expect(find.descendant(of: section, matching: find.text('Contrôle produit')), findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('Contrôle dimensionnel et qualité du produit — indépendant des prélèvements')), findsOneWidget);
    expect(find.descendant(of: find.ancestor(of: find.text('Contrôle produit'), matching: find.byType(Row)).first, matching: find.text('03')), findsNothing); // plus de numéro à gauche du bloc
    expect(tester.getBottomLeft(stepper).dy, lessThan(tester.getTopLeft(current).dy));
    expect(tester.getBottomLeft(current).dy, lessThan(tester.getTopLeft(actions).dy));
    expect(tester.getBottomLeft(actions).dy, lessThanOrEqualTo(tester.getTopLeft(section).dy));
    expect(find.descendant(of: actions, matching: find.text('Valider le prélèvement')), findsOneWidget);
    expect(find.descendant(of: actions, matching: find.text('Enregistrer le prélèvement')), findsOneWidget);

    // Les 7 paramètres du contrôle produit PROBAR, dans l'ordre demandé : tous
    // présents, UNE seule fois, hors du prélèvement.
    expect(tester.widgetList<Text>(find.descendant(of: section, matching: find.byType(Text))).map((t) => t.data).where((t) => [...labels, 'QUALITÉ DE COUPE'].contains(t)).toList(), [...labels, 'QUALITÉ DE COUPE']);
    for (final label in [...labels, 'QUALITÉ DE COUPE']) {
      expect(find.descendant(of: section, matching: find.text(label)), findsOneWidget, reason: label);
      expect(find.text(label), findsOneWidget, reason: '$label (une seule fois)');
    }
    expect(find.text('Refroidissement / coupe'), findsNothing); // plus de section séparée
    // Paramètres retirés : absents.
    for (final label in ['VITESSE DE COUPE', 'LONGUEUR DE COUPE', 'HAUTEUR / PROFONDEUR DES NERVURES OU ENROULEMENT', 'RÉGULARITÉ DU REVÊTEMENT', ...['OVALISATION', 'RECTITUDE', 'VITESSE DE REFROIDISSEMENT', 'CEINTURE DE TIRAGE', 'PAS DU PROFIL DE SURFACE', 'MASSE LINÉIQUE']]) {
      expect(find.text(label), findsNothing, reason: label);
    }
    // 5 champs de saisie + 2 choix (défauts superficiels : OK / NOK ; qualité de coupe : Bon / Pas bon), aucune sélection par défaut.
    expect(find.descendant(of: section, matching: find.byType(TextField)), findsNWidgets(5));
    // Défauts superficiels : uniquement OK / NOK — aucun champ « Valeur ».
    final defauts = find.byKey(const ValueKey('qc-physical-phys_defauts_superficiels_controle'));
    expect(find.descendant(of: section, matching: defauts), findsOneWidget);
    expect(find.descendant(of: defauts, matching: find.byType(TextField)), findsNothing);
    expect(find.descendant(of: defauts, matching: find.text('OK')), findsOneWidget);
    expect(find.descendant(of: defauts, matching: find.text('NOK')), findsOneWidget);
    expect(find.descendant(of: defauts, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsNothing);
    expect(find.byKey(const ValueKey('qc-physical-phys_pas_profil_surface_controle')), findsNothing);
    final coupe = find.byKey(const ValueKey('qc-physical-phys_qualite_coupe'));
    expect(find.descendant(of: section, matching: coupe), findsOneWidget);
    expect(find.descendant(of: coupe, matching: find.byType(TextField)), findsNothing);
    expect(find.descendant(of: coupe, matching: find.text('Bon')), findsOneWidget);
    expect(find.descendant(of: coupe, matching: find.text('Pas bon')), findsOneWidget);
    expect(find.descendant(of: coupe, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsNothing);
    expect(find.descendant(of: coupe, matching: find.byIcon(Icons.radio_button_unchecked_rounded)), findsNWidgets(2));
    expect(tester.widget<TextField>(phys('phys_masse_lineique')).decoration!.suffixText, isNull);
    expect(find.descendant(of: find.byType(QualityReadingForm), matching: find.text('DIAMÈTRE NOMINAL')), findsNothing);
    expect(find.text('0 / 7 renseigné(s)'), findsOneWidget);

    // Saisie d'un contrôle du prélèvement (non enregistrée) puis des paramètres physiques.
    await tester.enterText(_field('viscosite_resine'), '182');
    await tester.enterText(phys('phys_diametre_nominal'), '12');
    await tester.enterText(phys('phys_diametre_reel'), '12.1');
    // Qualité de coupe : un seul choix à la fois ; un second appui efface.
    final bon = find.byKey(const ValueKey('qc-physical-phys_qualite_coupe-BON'));
    final pasBon = find.byKey(const ValueKey('qc-physical-phys_qualite_coupe-PAS_BON'));
    await tester.tap(pasBon);
    await tester.pump();
    expect(find.descendant(of: pasBon, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget);
    await tester.tap(bon);
    await tester.pump();
    expect(find.descendant(of: bon, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget);
    expect(find.descendant(of: pasBon, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsNothing);
    await tester.tap(bon);
    await tester.pump();
    expect(find.descendant(of: coupe, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsNothing); // aucune sélection
    await tester.tap(bon);
    await tester.enterText(phys('phys_masse_lineique'), '152.4');
    // Défauts superficiels : OK / NOK, un seul choix à la fois.
    final defautsOk = find.byKey(const ValueKey('qc-physical-phys_defauts_superficiels_controle-OK'));
    final defautsNok = find.byKey(const ValueKey('qc-physical-phys_defauts_superficiels_controle-NOK'));
    await tester.tap(defautsNok);
    await tester.pump();
    expect(find.descendant(of: defautsNok, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget);
    await tester.tap(defautsOk);
    await tester.pump();
    expect(find.descendant(of: defautsOk, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget);
    expect(find.descendant(of: defautsNok, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsNothing);
    expect(find.text('5 / 7 renseigné(s)'), findsOneWidget); // compteur recalculé à la saisie
    await tester.tap(find.byKey(const ValueKey('qc-save-physical')));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // « Enregistrer » des paramètres physiques : niveau fiche SEUL — aucun prélèvement envoyé.
    expect(backend.fichePuts.single, {
      'physical': [
        {'parameterKey': 'phys_diametre_nominal', 'value': '12'},
        {'parameterKey': 'phys_diametre_reel', 'value': '12.1'},
        {'parameterKey': 'phys_masse_lineique', 'value': '152.4'},
        {'parameterKey': 'phys_defauts_superficiels_controle', 'value': 'OK'},
        {'parameterKey': 'phys_qualite_coupe', 'value': 'BON'},
      ],
    });
    expect(backend.requests.where((r) => r.contains('/readings')), isEmpty);
    expect(backend.physical, {'phys_diametre_nominal': '12', 'phys_diametre_reel': '12.1', 'phys_qualite_coupe': 'BON', 'phys_masse_lineique': '152.4', 'phys_defauts_superficiels_controle': 'OK'});
    expect(find.text('5 / 7 renseigné(s)'), findsOneWidget);
    // La saisie en cours du prélèvement n'a été ni envoyée ni perdue.
    expect(tester.widget<TextField>(_field('viscosite_resine')).controller!.text, '182');
    expect(backend.readings[2].values.containsKey('viscosite_resine'), isFalse);

    // Changer de prélèvement : les paramètres physiques ne changent pas ; les prélèvements restent indépendants.
    await tester.tap(_row('r1'));
    await _settle(tester);
    expect(find.text('Prélèvement actuel — étape 1'), findsOneWidget);
    expect(tester.widget<TextField>(_field('variateur_frequence_tirage')).controller!.text, '20');
    expect(tester.widget<TextField>(phys('phys_diametre_nominal')).controller!.text, '12');
    expect(tester.widget<TextField>(phys('phys_diametre_reel')).controller!.text, '12.1');
    expect(tester.widget<TextField>(phys('phys_masse_lineique')).controller!.text, '152.4');
    // Choix restaurés après rechargement.
    expect(find.descendant(of: find.byKey(const ValueKey('qc-physical-phys_defauts_superficiels_controle-OK')), matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('qc-physical-phys_qualite_coupe-BON')), matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget);
    expect(find.descendant(of: section, matching: find.byType(TextField)), findsNWidgets(5));
    // Prélèvement 1 validé : lecture seule, mais les paramètres physiques restent saisissables.
    expect(find.descendant(of: actions, matching: find.text('Valider le prélèvement')), findsNothing);
    expect(tester.widget<TextField>(phys('phys_longueur')).readOnly, isFalse);
    expect(backend.readings.map((r) => r.values['variateur_frequence_tirage']!['value']), ['20', '22', '24']);
    expect(backend.readings[2].values['viscosite_resine']!['value'], '182'); // brouillon enregistré en quittant l'étape 3

    // Fiche validée : paramètres physiques en lecture seule.
    await tester.tap(find.text('Valider le contrôle qualité'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await _settle(tester);
    expect(backend.ficheValidated, isTrue);
    expect(tester.widget<TextField>(phys('phys_diametre_nominal')).readOnly, isTrue);
    expect(tester.widget<TextField>(phys('phys_diametre_nominal')).controller!.text, '12');
    expect(find.byKey(const ValueKey('qc-save-physical')), findsNothing);
  });

  testWidgets('PROMESH — deux sections séparées : Contrôle Machine (prélèvement) et Contrôle Produit (fiche, saisi une fois)', (tester) async {
    backend
      ..add('08:00', values: {'temperature_machine': '8'}, validated: true, status: 'CONFORME')
      ..add('12:00', values: {'temperature_machine': '8.2'});
    await _open(tester, size: const Size(1440, 12000));
    final form = find.byType(QualityReadingForm);
    final machine = find.byKey(const ValueKey('qc-reading-section-controle_machine'));
    final product = find.byKey(const ValueKey('qc-physical-section'));
    Finder phys(String key) => find.byKey(ValueKey('qc-physical-$key'));

    // ✓ CONTRÔLE MACHINE : une seule section du prélèvement, sans lettre, un compteur.
    const machineLabels = [
      'TEMPÉRATURE DE MACHINE',
      'TEMPÉRATURE D\'EAU',
      'PRESSION D\'AIR COMPRIMÉ',
      'FUITE D\'EAU',
      'FUITE D\'AIR COMPRIMÉ',
      'ÉTAT DISQUE DE COUPE',
      'NIVEAU BAIN DE GRAINES',
      'VITESSE D\'IMPRESSION',
    ];
    expect(machine, findsOneWidget);
    expect(find.descendant(of: form, matching: find.byType(QcSection)), findsNWidgets(2)); // contrôle machine + résultat
    expect(find.descendant(of: machine, matching: find.text('Contrôle Machine')), findsOneWidget);
    expect(find.descendant(of: machine, matching: find.text('Paramètres liés au prélèvement')), findsOneWidget);
    for (final label in machineLabels) {
      expect(find.descendant(of: machine, matching: find.text(label)), findsOneWidget, reason: label);
      expect(find.text(label), findsOneWidget, reason: '$label (une seule fois)');
    }
    for (final key in ['temperature_machine', 'temperature_eau', 'pression_air_comprime', 'vitesse_impression']) {
      expect(_field(key), findsOneWidget, reason: key);
    }
    // Vitesse d'impression : contrôle MACHINE, saisie libre (placeholder « Valeur »), sans unité.
    expect(find.descendant(of: machine, matching: _field('vitesse_impression')), findsOneWidget);
    expect(tester.widget<TextField>(_field('vitesse_impression')).decoration!.hintText, 'Valeur');
    expect(tester.widget<TextField>(_field('vitesse_impression')).decoration!.suffixText, isNull);
    expect(find.textContaining('contrôlé(s)', findRichText: true), findsOneWidget);
    expect(find.textContaining('/ 8 contrôlé(s)', findRichText: true), findsOneWidget);
    for (final category in ['Paramètres du prélèvement', 'Paramètres de ligne', 'Chauffage / imprégnation', 'Polymérisation', 'Refroidissement / coupe', 'Barre', 'A']) {
      expect(find.text(category), findsNothing, reason: category);
    }

    // ✓ CONTRÔLE PRODUIT : section séparée, de niveau fiche — les 7 caractéristiques
    // du produit, dans l'ordre, jamais dans le prélèvement.
    const productLabels = [
      'DIAMÈTRE RÉEL',
      'NOMBRE DE BARRES EN LONGUEUR',
      'NOMBRE DE BARRES EN LARGEUR',
      'DIMENSIONS DE MAILLE',
      'DIMENSIONS CÔTÉ 1 LONG',
      'DIMENSIONS CÔTÉ 2 LONG',
      'ÉTAT D\'IMPRESSION',
    ];
    expect(product, findsOneWidget);
    expect(find.descendant(of: product, matching: find.text('Contrôle Produit')), findsOneWidget);
    expect(find.descendant(of: product, matching: find.text('Caractéristiques du produit — saisies une seule fois pour la fiche, communes à tous les prélèvements')), findsOneWidget);
    expect(tester.widgetList<Text>(find.descendant(of: product, matching: find.byType(Text))).map((t) => t.data).where(productLabels.contains).toList(), productLabels);
    for (final label in productLabels) {
      expect(find.descendant(of: form, matching: find.text(label)), findsNothing, reason: label);
      expect(find.text(label), findsOneWidget, reason: '$label (une seule fois)');
    }
    expect(tester.getBottomLeft(machine).dy, lessThan(tester.getTopLeft(product).dy)); // machine, puis produit
    // 6 champs de saisie + 1 choix (état d'impression : Conforme / Non conforme).
    expect(find.descendant(of: product, matching: find.byType(TextField)), findsNWidgets(6));
    expect(tester.widget<TextField>(phys('dimensions_maille')).decoration!.hintText, 'ex. 20 × 20 mm');
    expect(tester.widget<TextField>(phys('dimensions_cote_2_long')).decoration!.suffixText, 'mm');
    // Diamètre réel : saisie libre (placeholder « Valeur »), une fois pour la fiche.
    expect(tester.widget<TextField>(phys('promesh_diametre_reel')).decoration!.hintText, 'Valeur');
    expect(tester.widget<TextField>(phys('promesh_diametre_reel')).decoration!.suffixText, isNull);
    expect(phys('vitesse_impression'), findsNothing); // plus dans le Contrôle Produit
    final impression = phys('etat_impression');
    expect(find.descendant(of: impression, matching: find.byType(TextField)), findsNothing);
    expect(find.descendant(of: impression, matching: find.text('Conforme')), findsOneWidget);
    expect(find.descendant(of: impression, matching: find.text('Non conforme')), findsOneWidget);
    expect(find.descendant(of: impression, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsNothing);
    expect(find.text('0 / 7 renseigné(s)'), findsOneWidget);
    expect(find.byKey(const ValueKey('qc-treillis-section')), findsNothing);
    expect(find.descendant(of: find.ancestor(of: find.text('Synthèse'), matching: find.byType(Row)).first, matching: find.text('04')), findsOneWidget);

    // ✓ Paramètres des versions précédentes : absents.
    for (final label in [
      'DIAMÈTRE DE BAR',
      'DIAMÈTRE DE LA BARRE',
      'VITESSE DE TIRAGE',
      'VITESSE D\'ALIMENTATION DES FIBRES',
      'ALIGNEMENT DES FIBRES',
      'TENSION DES ROVINGS',
      'NOMBRE DE ROVINGS',
      'TEMPÉRATURE DE LA FILIÈRE',
      'VISCOSITÉ DE LA RÉSINE',
      'TEMPS DE GEL',
      'DEGRÉ DE POLYMÉRISATION',
      'VITESSE DE REFROIDISSEMENT',
      'LARGEUR',
      'LONGUEUR',
      'MAILLE LONGITUDINALE',
      'MAILLE TRANSVERSALE',
      'POIDS PAR M²',
      'RECTITUDE / PLANÉITÉ',
      'TOLÉRANCE DIMENSIONNELLE',
      'ESPACEMENT DES FILS',
      'DIAMÈTRE NOMINAL',
      'OVALISATION',
      'QUALITÉ DE COUPE',
      'ÉTAT DU DISQUE DE COUPE',
      'Paramètres physiques PROMESH',
      'Paramètres spécifiques PROMESH',
      'Caractéristiques du treillis',
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }

    // ✓ Contrôle Produit : saisi une fois, enregistré au niveau de la fiche — aucun prélèvement envoyé.
    await tester.enterText(phys('promesh_diametre_reel'), '6,1');
    await tester.enterText(phys('nombre_bar_longueur'), '15');
    await tester.enterText(phys('dimensions_maille'), '20 × 20 mm');
    await tester.tap(find.byKey(const ValueKey('qc-physical-etat_impression-Non conforme')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('qc-physical-etat_impression-Conforme')));
    await tester.pump();
    expect(find.descendant(of: impression, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget);
    expect(find.text('4 / 7 renseigné(s)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qc-save-physical')));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(backend.fichePuts.single, {
      'physical': [
        {'parameterKey': 'promesh_diametre_reel', 'value': '6,1'},
        {'parameterKey': 'nombre_bar_longueur', 'value': '15'},
        {'parameterKey': 'dimensions_maille', 'value': '20 × 20 mm'},
        {'parameterKey': 'etat_impression', 'value': 'Conforme'},
      ],
    });
    expect(backend.requests.where((r) => r.contains('/readings')), isEmpty);
    // ✓ Vitesse d'impression : saisie dans le prélèvement affiché (12:00), propre à ce prélèvement.
    await tester.enterText(_field('vitesse_impression'), '35');
    await tester.pump();

    // ✓ Prélèvements indépendants (contrôle machine) ; le Contrôle Produit reste
    // commun : mêmes valeurs quel que soit le prélèvement affiché.
    expect(tester.widget<TextField>(_field('temperature_machine')).controller!.text, '8.2');
    await tester.tap(_row('r1'));
    await _settle(tester);
    expect(tester.widget<TextField>(_field('temperature_machine')).controller!.text, '8');
    for (final label in machineLabels) {
      expect(find.descendant(of: find.byType(QualityReadingForm), matching: find.text(label)), findsOneWidget, reason: '$label (prélèvement 1)');
    }
    expect(tester.widget<TextField>(phys('nombre_bar_longueur')).controller!.text, '15');
    expect(tester.widget<TextField>(phys('promesh_diametre_reel')).controller!.text, '6,1');
    // Vitesse d'impression : enregistrée avec le prélèvement 2 seulement ; vide pour le prélèvement 1.
    expect(tester.widget<TextField>(_field('vitesse_impression')).controller!.text, '');
    expect(backend.readings[1].values['vitesse_impression']!['value'], '35');
    expect(backend.readings[0].values.containsKey('vitesse_impression'), isFalse);
    expect(backend.physical.containsKey('vitesse_impression'), isFalse);
    expect(find.descendant(of: find.byKey(const ValueKey('qc-physical-etat_impression-Conforme')), matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget);
    expect(find.text('4 / 7 renseigné(s)'), findsOneWidget);
    expect(backend.readings.map((r) => r.values['temperature_machine']!['value']), ['8', '8.2']);
    expect(backend.readings.every((r) => !r.values.containsKey('nombre_bar_longueur')), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PROMESH 4 — Contrôle Machine (zones de température, viscosité bain 1 / bain 2 en °) et Contrôle Produit propres à la machine', (tester) async {
    backend
      ..machine = '4'
      ..add('08:00',
          values: {'promesh4_temperature_machine_1_zone_1': '182', 'promesh4_temperature_machine_1_zone_2': '186', 'promesh4_viscosite_bain_1': '45', 'promesh4_viscosite_bain_2': '47'},
          validated: true,
          status: 'CONFORME')
      ..add('11:00');
    await _open(tester, size: const Size(1440, 12000));
    final form = find.byType(QualityReadingForm);
    final section = find.byKey(const ValueKey('qc-reading-section-controle_promesh_4'));
    final product = find.byKey(const ValueKey('qc-physical-section'));
    Finder phys(String key) => find.byKey(ValueKey('qc-physical-$key'));
    Finder group(String name) => find.byKey(ValueKey('qc-param-group-$name'));
    const keys = [
      'promesh4_temperature_machine_1_zone_1',
      'promesh4_temperature_machine_1_zone_2',
      'promesh4_temperature_machine_2_zone_1',
      'promesh4_temperature_machine_2_zone_2',
      'temperature_eau',
      'promesh4_nombre_bobines',
      'promesh4_vitesse_tirage',
      'promesh4_viscosite_bain_1',
      'promesh4_viscosite_bain_2',
    ];

    // ✓ CONTRÔLE MACHINE : une seule section, sans lettre, un seul compteur.
    expect(section, findsOneWidget);
    expect(find.descendant(of: form, matching: find.byType(QcSection)), findsNWidgets(2)); // contrôle machine + résultat
    expect(find.descendant(of: section, matching: find.text('Contrôle Machine')), findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('Paramètres spécifiques de la machine')), findsOneWidget);
    expect(find.textContaining('0 / 9 contrôlé(s)', findRichText: true), findsOneWidget);
    for (final label in ['TEMPÉRATURE D\'EAU', 'NOMBRE DE BOBINES', 'VITESSE DE TIRAGE']) {
      expect(find.descendant(of: section, matching: find.text(label)), findsOneWidget, reason: label);
    }
    // ✓ Température machine 1 et 2 : un sous-titre, deux zones distinctes en °C.
    for (final m in ['1', '2']) {
      final g = group('TEMPÉRATURE MACHINE $m');
      expect(find.descendant(of: g, matching: find.text('TEMPÉRATURE MACHINE $m')), findsOneWidget);
      final z1 = _field('promesh4_temperature_machine_${m}_zone_1');
      final z2 = _field('promesh4_temperature_machine_${m}_zone_2');
      expect(tester.getTopLeft(z1).dy, greaterThan(tester.getBottomLeft(g).dy));
      expect(tester.getTopLeft(z1).dy, tester.getTopLeft(z2).dy); // côte à côte
      expect(tester.getTopLeft(z1).dx, lessThan(tester.getTopLeft(z2).dx));
      expect(tester.widget<TextField>(z1).decoration!.suffixText, '°C');
      expect(tester.widget<TextField>(z2).decoration!.suffixText, '°C');
    }
    expect(find.descendant(of: section, matching: find.text('ZONE 1')), findsNWidgets(2));
    expect(find.descendant(of: section, matching: find.text('ZONE 2')), findsNWidgets(2));
    // ✓ Viscosité de la résine : un sous-titre, deux bains, en degrés (°).
    final viscosite = group('VISCOSITÉ DE LA RÉSINE');
    expect(find.descendant(of: viscosite, matching: find.text('VISCOSITÉ DE LA RÉSINE')), findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('BAIN 1')), findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('BAIN 2')), findsOneWidget);
    expect(tester.getTopLeft(_field('promesh4_viscosite_bain_1')).dy, tester.getTopLeft(_field('promesh4_viscosite_bain_2')).dy);
    expect(tester.widget<TextField>(_field('promesh4_viscosite_bain_1')).decoration!.suffixText, '°');
    expect(tester.widget<TextField>(_field('promesh4_viscosite_bain_2')).decoration!.suffixText, '°');
    expect(tester.widget<TextField>(_field('temperature_eau')).decoration!.suffixText, '°C');
    expect(tester.widget<TextField>(_field('promesh4_nombre_bobines')).decoration!.suffixText, isNull);
    expect(tester.widget<TextField>(_field('promesh4_vitesse_tirage')).decoration!.suffixText, isNull); // aucune unité inventée
    // ✓ Ordre vertical : machine 1, machine 2, champs simples, viscosité.
    final tops = [
      for (final k in ['promesh4_temperature_machine_1_zone_1', 'promesh4_temperature_machine_2_zone_1', 'temperature_eau', 'promesh4_viscosite_bain_1']) tester.getTopLeft(_field(k)).dy,
    ];
    expect(tops, [...tops]..sort());
    expect(tops.toSet(), hasLength(4));
    // ✓ De vrais champs éditables, vides pour un nouveau prélèvement.
    for (final key in keys) {
      final field = tester.widget<TextField>(_field(key));
      expect(field.enabled, isNot(false), reason: key);
      expect(field.controller!.text, '', reason: key);
    }
    expect(find.descendant(of: form, matching: find.byType(TextField)), findsNWidgets(9));

    // ✓ CONTRÔLE PRODUIT : section séparée, sous le contrôle machine — 6 paramètres dans l'ordre.
    const productLabels = [
      'DIAMÈTRE RÉEL',
      'DIMENSIONS CÔTÉ 1 LONGUEUR',
      'NOMBRE DE BARRES EN LONGUEUR',
      'DIMENSIONS DE MAILLE',
      'NOMBRE DE BARRES EN LARGEUR',
      'DIMENSIONS CÔTÉ 2 LONGUEUR',
    ];
    expect(product, findsOneWidget);
    expect(find.descendant(of: product, matching: find.text('Contrôle Produit')), findsOneWidget);
    expect(tester.getBottomLeft(section).dy, lessThan(tester.getTopLeft(product).dy));
    expect(tester.widgetList<Text>(find.descendant(of: product, matching: find.byType(Text))).map((t) => t.data).where(productLabels.contains).toList(), productLabels);
    for (final label in productLabels) {
      expect(find.descendant(of: form, matching: find.text(label)), findsNothing, reason: label);
      expect(find.text(label), findsOneWidget, reason: '$label (une seule fois)');
    }
    // 6 champs de saisie ; « État d'impression » retiré de PROMESH 4 : ni libellé, ni choix.
    expect(find.descendant(of: product, matching: find.byType(TextField)), findsNWidgets(6));
    expect(tester.widget<TextField>(phys('dimensions_maille')).decoration!.hintText, 'ex. 20 × 20 mm');
    expect(find.text('ÉTAT D\'IMPRESSION'), findsNothing);
    expect(phys('etat_impression'), findsNothing);
    expect(find.descendant(of: product, matching: find.text('Conforme')), findsNothing);
    expect(find.descendant(of: product, matching: find.text('Non conforme')), findsNothing);
    expect(find.descendant(of: product, matching: find.byIcon(Icons.radio_button_unchecked_rounded)), findsNothing);
    expect(find.text('0 / 6 renseigné(s)'), findsOneWidget);
    for (final key in ['promesh_diametre_reel', 'dimensions_cote_1_long', 'nombre_bar_longueur', 'dimensions_maille', 'nombre_bar_largeur', 'dimensions_cote_2_long']) {
      expect(tester.widget<TextField>(phys(key)).controller!.text, '', reason: key);
    }

    // ✓ Paramètres des autres machines PROMESH : absents.
    for (final label in [
      'Contrôle PROMESH 4',
      'TEMPÉRATURE DE MACHINE',
      'PRESSION D\'AIR COMPRIMÉ',
      'FUITE D\'EAU',
      'FUITE D\'AIR COMPRIMÉ',
      'ÉTAT DISQUE DE COUPE',
      'NIVEAU BAIN DE GRAINES',
      'DIMENSIONS CÔTÉ 1 LONG',
      'DIMENSIONS CÔTÉ 2 LONG',
      'VITESSE D\'IMPRESSION',
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.byKey(const ValueKey('qc-reading-section-controle_machine')), findsNothing);

    // ✓ Contrôle Produit : saisie puis « Enregistrer » → niveau fiche seul.
    await tester.enterText(phys('promesh_diametre_reel'), 'Ø 6,1');
    await tester.enterText(phys('dimensions_cote_1_long'), '2400');
    await tester.enterText(phys('nombre_bar_longueur'), '15');
    await tester.enterText(phys('dimensions_maille'), '20 × 20 mm');
    await tester.pump();
    expect(find.text('4 / 6 renseigné(s)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qc-save-physical')));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(backend.fichePuts.single, {
      'physical': [
        {'parameterKey': 'promesh_diametre_reel', 'value': 'Ø 6,1'},
        {'parameterKey': 'dimensions_cote_1_long', 'value': '2400'},
        {'parameterKey': 'nombre_bar_longueur', 'value': '15'},
        {'parameterKey': 'dimensions_maille', 'value': '20 × 20 mm'},
      ],
    });
    expect(backend.requests.where((r) => r.contains('/readings')), isEmpty);

    // ✓ Contrôle Machine : saisie du prélèvement 2 — chaque zone et chaque bain a sa valeur.
    const input = {
      'promesh4_temperature_machine_1_zone_1': '184',
      'promesh4_temperature_machine_1_zone_2': '188',
      'promesh4_temperature_machine_2_zone_1': '191',
      'promesh4_temperature_machine_2_zone_2': '195',
      'temperature_eau': '18',
      'promesh4_nombre_bobines': '24',
      'promesh4_vitesse_tirage': '3.5',
      'promesh4_viscosite_bain_1': '46',
      'promesh4_viscosite_bain_2': '48',
    };
    for (final e in input.entries) {
      await tester.enterText(_field(e.key), e.value);
    }
    await tester.pump();

    // ✓ Édition d'un prélèvement existant : valeurs relues depuis la base, jamais écrasées.
    await tester.tap(_row('r1'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(tester.widget<TextField>(_field('promesh4_temperature_machine_1_zone_1')).controller!.text, '182');
    expect(tester.widget<TextField>(_field('promesh4_temperature_machine_1_zone_2')).controller!.text, '186');
    expect(tester.widget<TextField>(_field('promesh4_temperature_machine_2_zone_1')).controller!.text, '');
    expect(tester.widget<TextField>(_field('promesh4_viscosite_bain_1')).controller!.text, '45');
    expect(tester.widget<TextField>(_field('promesh4_viscosite_bain_2')).controller!.text, '47');
    // Le prélèvement quitté (11:00) a été enregistré avec ses propres valeurs, une par champ.
    expect({for (final k in keys) k: backend.readings[1].values[k]?['value']}, input);
    expect(backend.readings[0].values['promesh4_viscosite_bain_1']!['value'], '45'); // prélèvement 1 intact
    // Le Contrôle Produit est commun aux prélèvements : valeurs enregistrées toujours affichées.
    expect(tester.widget<TextField>(phys('promesh_diametre_reel')).controller!.text, 'Ø 6,1');
    expect(tester.widget<TextField>(phys('dimensions_maille')).controller!.text, '20 × 20 mm');
    expect(find.text('4 / 6 renseigné(s)'), findsOneWidget);
    // Retour au prélèvement 2 : ses valeurs sont rechargées depuis la base.
    await tester.tap(_row('r2'));
    await _settle(tester);
    for (final e in input.entries) {
      expect(tester.widget<TextField>(_field(e.key)).controller!.text, e.value, reason: e.key);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('TEST 2 — PROBAR : contrôles de barre et paramètres physiques PROBAR ; ni treillis GFRP ni paramètre de maille', (tester) async {
    backend
      ..productionType = 'PROBAR'
      ..add('08:00');
    await _open(tester, size: const Size(1440, 12000));
    // ✓ Structure PROBAR : une seule section « Contrôle qualité de la machine » — ligne (5),
    // chauffage / imprégnation (6), puis Refroidissement / coupe et Machine (inchangés).
    final form = find.byType(QualityReadingForm);
    for (final label in [...['VARIATEUR EN FRÉQUENCE DE TIRAGE', 'VARIATEUR EN FRÉQUENCE DE BOBINAGE', 'VITESSE DE BARRE (m/min)', 'NOMBRE DE BOBINES', 'ALIGNEMENT DES FIBRES'], ...['TEMPÉRATURE ZONE 1', 'TEMPÉRATURE ZONE 2', 'TEMPÉRATURE ZONE 3', 'PRESSION D\'AIR', 'VISCOSITÉ DE LA RÉSINE', 'RATIO RÉSINE / DURCISSEUR / CATALYSEUR']]) {
      expect(find.descendant(of: form, matching: find.text(label)), findsOneWidget, reason: label);
    }
    // ✓ Sections Polymérisation et Barre absentes ; contrôles retirés absents.
    expect(find.text('Barre'), findsNothing);
    expect(find.text('Polymérisation'), findsNothing);
    for (final label in ['NIVEAU BAIN DE GRAINES', 'VITESSE DE TIRAGE', 'TENSION DES ROVINGS', 'NOMBRE DE BAR EN LONGUEUR', 'TEMPÉRATURE DE LA FILIÈRE', 'TEMPS DE GEL', 'NOMBRE DE BAR EN LONGUEUR', 'VITESSE DE POLYMÉRISATION', 'DIAMÈTRE DE LA BARRE', 'ÉTAT DE SURFACE', 'QUANTITÉ ET RÉGULARITÉ DU REVÊTEMENT', 'TOLÉRANCE DIMENSIONNELLE', 'ESPACEMENT DES FILS', 'VITESSE DE TIRAGE DE BOBINAGE', 'VITESSE D\'ALIMENTATION DES FIBRES', 'VITESSE DE BOBINAGE (m/min)', 'TEMPÉRATURE DES DIFFÉRENTES ZONES DE CHAUFFAGE', 'PRESSION / CONDITIONS D\'IMPRÉGNATION']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    // ✓ Champs de saisie des nouveaux contrôles, avec statut à trois choix.
    for (final key in ['variateur_frequence_tirage', 'variateur_frequence_bobinage', 'nombre_bobines', 'vitesse_barre', 'temperature_zone_1', 'temperature_zone_2', 'temperature_zone_3', 'pression_air']) {
      expect(_field(key), findsOneWidget, reason: key);
    }
    // ✓ Trois zones : trois champs indépendants, une valeur par zone.
    await tester.enterText(_field('temperature_zone_1'), '180');
    await tester.enterText(_field('temperature_zone_2'), '195');
    await tester.enterText(_field('temperature_zone_3'), '210');
    await tester.pump();
    expect(['temperature_zone_1', 'temperature_zone_2', 'temperature_zone_3'].map((k) => tester.widget<TextField>(_field(k)).controller!.text), ['180', '195', '210']);
    for (final key in ['temperature_zone_1', 'temperature_zone_2', 'temperature_zone_3']) {
      await tester.enterText(_field(key), '');
    }
    await tester.pump();
    // ✓ Compteurs par catégorie, calculés sur les paramètres actifs.
    // ✓ UNE section principale « Contrôle qualité de la machine » : titre, sous-titre,
    // sous-catégories visuelles, et UN compteur global (plus de A / B / C).
    final machineQuality = find.byKey(const ValueKey('qc-machine-quality-section'));
    expect(machineQuality, findsOneWidget);
    expect(find.descendant(of: form, matching: find.byType(QcSection)), findsNWidgets(2)); // qualité de la machine + résultat
    expect(find.descendant(of: machineQuality, matching: find.text('Contrôle qualité de la machine')), findsOneWidget);
    expect(find.descendant(of: machineQuality, matching: find.text('Contrôle des paramètres de fonctionnement et de réglage de la machine')), findsOneWidget);
    for (final sub in ['PARAMÈTRES DE LIGNE', 'CHAUFFAGE / IMPRÉGNATION', 'MACHINE']) {
      expect(find.descendant(of: machineQuality, matching: find.text(sub)), findsOneWidget, reason: sub);
    }
    for (final old in ['Paramètres de ligne', 'Chauffage / imprégnation', 'A', 'B', 'C']) {
      expect(find.descendant(of: form, matching: find.text(old)), findsNothing, reason: old);
    }
    expect(find.descendant(of: machineQuality, matching: find.byKey(const ValueKey('qc-value-variateur_frequence_tirage'))), findsOneWidget);
    expect(find.descendant(of: machineQuality, matching: find.byKey(const ValueKey('qc-value-temperature_eau'))), findsOneWidget);
    expect(find.textContaining('contrôlé(s)', findRichText: true), findsOneWidget);
    expect(find.textContaining('0 / 15 contrôlé(s)', findRichText: true), findsOneWidget);
    // ✓ Retirés de PROBAR : état d'impression, pression d'air comprimé, température de machine, ovalisation.
    for (final label in ['ÉTAT D\'IMPRESSION', 'PRESSION D\'AIR COMPRIMÉ', 'TEMPÉRATURE DE MACHINE', 'OVALISATION']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    // ✓ Ratio : contrôle binaire — aucun champ « Valeur », aucun « Non contrôlé ».
    const ratio = 'ratio_resine_durcisseur_catalyseur';
    final ratioOk = find.byKey(const ValueKey('qc-conformity-$ratio-CONFORME'));
    final ratioNc = find.byKey(const ValueKey('qc-conformity-$ratio-NON_CONFORME'));
    expect(_field(ratio), findsNothing);
    expect(find.descendant(of: ratioOk, matching: find.text('Conforme')), findsOneWidget);
    expect(find.descendant(of: ratioNc, matching: find.text('Non conforme')), findsOneWidget);
    expect(find.descendant(of: form, matching: find.text('Non contrôlé')), findsNWidgets(14)); // 15 contrôles, sauf le ratio
    expect(find.descendant(of: ratioOk, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsNothing);
    // ✓ Conforme → compté ; Non conforme → non-conformité ; compteurs recalculés.
    await tester.tap(ratioOk);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.descendant(of: ratioOk, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget);
    expect(find.textContaining('1 / 15 contrôlé(s)', findRichText: true), findsOneWidget);
    await tester.tap(ratioNc);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.descendant(of: ratioOk, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsNothing);
    expect(find.descendant(of: ratioNc, matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget);
    expect(find.textContaining('1 / 15 contrôlé(s)  ·  1 NC', findRichText: true), findsOneWidget);
    await tester.tap(ratioNc); // second appui : choix retiré
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('0 / 15 contrôlé(s)', findRichText: true), findsOneWidget);
    await tester.enterText(_field('nombre_bobines'), '24');
    await tester.enterText(_field('vitesse_barre'), '3.5');
    await tester.pump();
    expect(tester.widget<TextField>(_field('nombre_bobines')).controller!.text, '24');
    expect(find.text('Contrôle produit'), findsOneWidget);
    // ✓ Coupe : plus de section dans le prélèvement — contrôle produit de la fiche.
    expect(find.text('Refroidissement / coupe'), findsNothing);
    for (final label in ['OVALISATION', 'RECTITUDE', 'VITESSE DE REFROIDISSEMENT', 'CEINTURE DE TIRAGE', 'PAS DU PROFIL DE SURFACE', 'MASSE LINÉIQUE']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    for (final label in ['QUALITÉ DE COUPE', 'DÉFAUTS SUPERFICIELS', 'POIDS EN g']) {
      expect(find.descendant(of: form, matching: find.text(label)), findsNothing, reason: label);
      expect(find.descendant(of: find.byKey(const ValueKey('qc-physical-section')), matching: find.text(label)), findsOneWidget, reason: label);
    }
    for (final label in ['VITESSE DE COUPE', 'LONGUEUR DE COUPE', 'HAUTEUR / PROFONDEUR DES NERVURES OU ENROULEMENT', 'RÉGULARITÉ DU REVÊTEMENT']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.descendant(of: find.byKey(const ValueKey('qc-physical-section')), matching: find.byType(TextField)), findsNWidgets(5));
    expect(find.text('0 / 7 renseigné(s)'), findsOneWidget);
    // ✓ Compteur recalculé : 25 contrôles par prélèvement PROBAR.
    expect(find.text('0/28 contrôlés'), findsNothing);
    expect(find.text('0/25 contrôlés'), findsNothing);
    expect(find.textContaining('/15 contrôlés'), findsOneWidget);
    // ✓ Section Treillis GFRP absente, aucun paramètre de maille.
    expect(find.byKey(const ValueKey('qc-treillis-section')), findsNothing);
    expect(find.textContaining('TREILLIS', findRichText: true), findsNothing);
    for (final label in ['Paramètres spécifiques PROMESH', 'GÉOMÉTRIE', 'ASSEMBLAGE', 'MÉCANIQUE', 'MAILLE LONGITUDINALE', 'DIMENSIONS DE MAILLE', 'NOMBRE DE BARRES EN LONGUEUR']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    // Sans treillis, la synthèse est la section 04.
    expect(find.descendant(of: find.ancestor(of: find.text('Synthèse'), matching: find.byType(Row)).first, matching: find.text('04')), findsOneWidget);
  });

  testWidgets('fil d\'Ariane : chaque chevron à DROITE de l\'élément qu\'il suit, y compris sur écran étroit', (tester) async {
    backend.add('08:00');
    const labels = ['CONTRÔLE QUALITÉ', 'PROMESH', 'MACHINE 1', 'QC-2026-00010'];
    for (final size in const [Size(1440, 2000), Size(390, 2000)]) {
      await _open(tester, size: size);
      final crumbs = find.ancestor(of: find.text(labels.first), matching: find.byType(Wrap)).first;
      final chevrons = find.descendant(of: crumbs, matching: find.byIcon(Icons.chevron_right_rounded));
      expect(chevrons, findsNWidgets(labels.length - 1), reason: '$size');
      for (var i = 0; i < labels.length - 1; i++) {
        final label = tester.getRect(find.descendant(of: crumbs, matching: find.text(labels[i])));
        final chevron = tester.getRect(chevrons.at(i));
        // Même ligne que l'élément précédent, juste à sa droite.
        expect(chevron.left, greaterThanOrEqualTo(label.right), reason: '${labels[i]} $size');
        expect((chevron.center.dy - label.center.dy).abs(), lessThan(6), reason: '${labels[i]} $size');
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('QualityReadingStepper : cartes compactes numérotées, étape active, étape validée cochée, nouveau prélèvement', (tester) async {
    backend
      ..add('08:00', values: {'temperature_machine': '20'}, validated: true, status: 'CONFORME')
      ..add('11:05', values: {'temperature_machine': '22'});
    final control = QualityControlModel.fromJson(backend.control());
    final opened = <String>[];
    var created = 0;
    tester.view.physicalSize = const Size(420, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QualityReadingStepper(
          readings: control.readings,
          selectedId: 'r2',
          color: productionTypeColor('PROMESH'),
          onOpen: (r) => opened.add(r.id),
          onNew: () => created++,
          newHint: 'proposé : 14:05',
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('ÉTAPE 1'), findsOneWidget);
    expect(find.text('ÉTAPE 2'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('11:05'), findsOneWidget);
    expect(find.text('1/8 contrôlés'), findsNWidgets(2));
    expect(find.text('Conforme'), findsOneWidget); // étape 1 validée
    expect(find.text('Brouillon'), findsOneWidget); // étape 2
    expect(find.descendant(of: _row('r1'), matching: find.byIcon(Icons.check_circle_rounded)), findsWidgets); // terminée
    expect(find.descendant(of: _row('r2'), matching: find.byIcon(Icons.radio_button_checked_rounded)), findsOneWidget); // active
    expect(find.text('Nouveau prélèvement'), findsOneWidget);
    expect(find.text('proposé : 14:05'), findsOneWidget);
    // Aucun paramètre physique dans le stepper.
    expect(find.text('TEMPÉRATURE DE MACHINE'), findsNothing);
    expect(find.text('20'), findsNothing);
    // Étapes côte à côte (horizontal).
    expect(tester.getRect(_row('r1')).right, lessThan(tester.getRect(_row('r2')).left));
    expect(tester.getRect(_row('r1')).top, tester.getRect(_row('r2')).top);

    await tester.tap(_row('r1'));
    await tester.tap(_row('r2')); // étape déjà active : aucune action
    await tester.ensureVisible(_newButton);
    await tester.tap(_newButton);
    expect(opened, ['r1']);
    expect(created, 1);
  });

  testWidgets('historique : une fiche = un contrôle, « 3 prélèvements » et dernier prélèvement affichés', (tester) async {
    backend
      ..add('08:00')
      ..add('11:07')
      ..add('14:15');
    final control = QualityControlModel.fromJson(backend.control());
    expect(control.readingsCount, 3);
    expect(control.lastReadingTime, '14:15');
    expect(control.suggestedNextReadingTime, '17:15');
    expect(control.readings.map((r) => '${r.step}:${r.readingTime}'), ['1:08:00', '2:11:07', '3:14:15']);
    expect(control.controlTime, '20:10:56');

    tester.view.physicalSize = const Size(1400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: QcControlsTable(controls: [control], extended: true))));
    for (final header in ['PRÉLÈVEMENTS', 'DERNIER PRÉLÈVEMENT', 'POSTE', 'RÉSULTAT', 'CONTRÔLEUR QUALITÉ']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('3 prélèvements'), findsOneWidget);
    expect(find.text('14:15'), findsOneWidget);
    expect(find.text('QC-2026-00010'), findsOneWidget); // une seule ligne pour la fiche
    expect(tester.takeException(), isNull);
  });

  testWidgets('étiquette de référence à la couleur de la ligne ; traçabilité jamais affichée (audit conservé côté serveur)', (tester) async {
    for (final (type, reference) in const [('PROMESH', 'QC-PROMESH-000125'), ('PROBAR', 'QC-PROBAR-000087')]) {
      backend = _FakeQcBackend()
        ..productionType = type
        ..reference = reference
        ..history = [
          {'action': 'UPDATE', 'readingTime': '08:00', 'parameterName': 'TEMPÉRATURE DE MACHINE', 'field': 'value', 'oldValue': '20', 'newValue': '21', 'userEmail': 'controle_qualite@cbi-tunisia.com', 'changedDate': '03/10/2026', 'changedTime': '08:10:00'},
          {'action': 'VALIDATE', 'field': 'status', 'newValue': 'CONFORME', 'userEmail': 'controle_qualite@cbi-tunisia.com', 'changedDate': '03/10/2026', 'changedTime': '09:00:00'},
        ]
        ..add('08:00', validated: true, status: 'CONFORME');
      ApiClient.instance.dio.httpClientAdapter = backend;
      await _open(tester, size: const Size(1440, 12000));

      // Étiquette en tête de fiche + dans le bandeau fixe, couleur de la ligne.
      final badge = find.byKey(const ValueKey('qc-reference-badge'));
      expect(find.descendant(of: badge, matching: find.text(reference)), findsOneWidget, reason: type);
      expect(find.byType(QcReferenceBadge), findsNWidgets(2), reason: type);
      final text = tester.widget<Text>(find.descendant(of: badge, matching: find.text(reference)));
      expect(text.style!.color, productionTypeColor(type), reason: type);
      expect(productionTypeColor('PROMESH'), isNot(productionTypeColor('PROBAR')));
      expect(find.text('Contrôle qualité $reference'), findsOneWidget);

      // Traçabilité : absente de la fiche, quel que soit le journal reçu.
      for (final label in ['Traçabilité', 'Validation de la fiche', 'Modification', 'Changement de statut', 'Aucun événement']) {
        expect(find.textContaining(label), findsNothing, reason: '$type · $label');
      }
      expect(find.textContaining('événement(s)'), findsNothing);
      expect(find.text('20 → 21'), findsNothing);
      // Le reste de la fiche est intact.
      expect(find.text('Synthèse'), findsOneWidget);
      // PROMESH : aucune section de niveau fiche ; PROBAR : ses paramètres physiques.
      expect(find.text('Contrôle produit'), type == 'PROBAR' ? findsOneWidget : findsNothing);
      expect(find.text('Paramètres physiques PROBAR'), findsNothing);
      expect(find.text('Paramètres spécifiques PROMESH'), findsNothing);
      expect(find.byKey(const ValueKey('qc-treillis-section')), findsNothing);
    }
  });

  testWidgets('English — PROMESH and PROBAR sheets fully translated, no French left', (tester) async {
    QcI18n.language.value = 'en';
    QcI18n.missing.clear();
    addTearDown(() {
      QcI18n.language.value = 'fr';
      QcI18n.missing.clear();
    });
    for (final type in ['PROMESH', 'PROBAR']) {
      backend = _FakeQcBackend()
        ..productionType = type
        ..reference = 'QC-$type-000125'
        ..productionLot = 'LOT-01'
        ..productionOrder = 'FAB01 — 28/08/2026 — Ø12'
        // Contrôle commun aux deux lignes.
        ..add('08:00', values: {'temperature_eau': '20'}, validated: true, status: 'CONFORME')
        ..add('11:00', values: {'temperature_eau': '22'});
      ApiClient.instance.dio.httpClientAdapter = backend;
      await _open(tester, size: const Size(1440, 12000));

      for (final text in [
        'Quality control QC-$type-000125',
        'Identification',
        'Production date',
        'Shift',
        'Manufacturing lot',
        'Manufacturing order',
        'Quality Inspector',
        'Control Samples',
        'Current Sample — step 2',
        'Sample time',
        'Save Sample',
        'Validate Sample',
        'Validate Quality Control',
        if (type == 'PROBAR') ...['Product Control', 'Dimensional and product quality control — independent of the samples', 'WEIGHT IN g', 'SURFACE DEFECTS'],
        'Summary',
        if (type == 'PROMESH') ...['MACHINE TEMPERATURE', 'WATER TEMPERATURE'] else ...[
          'Machine Quality Control',
          'Control of the machine operating and setting parameters',
          'LINE PARAMETERS',
          'HEATING / IMPREGNATION',
          'MACHINE',
          'PULLING FREQUENCY DRIVE',
          'WINDING FREQUENCY DRIVE',
          'NUMBER OF SPOOLS',
          'BAR SPEED (m/min)',
          'ZONE 1 TEMPERATURE',
          'ZONE 2 TEMPERATURE',
          'ZONE 3 TEMPERATURE',
          'AIR PRESSURE',
          'RESIN / HARDENER / CATALYST RATIO',
          'Non-compliant',
        ],
        'New sample',
        'STEP 1',
        'Draft',
        'Compliant',
        'Automatic',
      ]) {
        expect(find.text(text), findsWidgets, reason: '$type · $text');
      }
      expect(find.text('Not checked'), findsWidgets);
      expect(find.text('Shift: Morning'), findsOneWidget);
      if (type == 'PROMESH') {
        for (final text in ['Machine Control', 'Parameters linked to the sample', 'Product Control', 'NUMBER OF BARS LENGTHWISE', 'NUMBER OF BARS WIDTHWISE', 'MESH DIMENSIONS', 'SIDE 2 LENGTH DIMENSIONS', 'PRINTING SPEED', 'PRINT CONDITION', 'CUTTING DISC CONDITION']) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
        expect(find.text('Bar'), findsNothing);
      } else {
        expect(find.text('Bar'), findsNothing);
        expect(find.text('PULLING SPEED'), findsNothing);
        for (final text in ['NOMINAL DIAMETER', 'CUT QUALITY', 'Good', 'Not good', 'WEIGHT IN g', 'SURFACE DEFECTS']) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
        expect(find.text('PROMESH Specific Parameters'), findsNothing);
      }
      for (final french in ['Prélèvements de contrôle', 'Enregistrer le prélèvement', 'Valider le prélèvement', 'Paramètres physiques $type', 'Contrôle produit', 'Brouillon', 'Conforme', 'Non contrôlé', 'Synthèse', 'TEMPÉRATURE DE MACHINE']) {
        expect(find.text(french), findsNothing, reason: '$type · $french');
      }
      // Dialogue de validation du prélèvement.
      await tester.tap(find.text('Validate Sample'));
      await tester.pumpAndSettle();
      expect(find.text('Validate the sample of 11:00'), findsOneWidget);
      expect(find.textContaining('The sample will no longer be editable'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
    expect(QcI18n.frenchResidue(), isEmpty);
  });
}
