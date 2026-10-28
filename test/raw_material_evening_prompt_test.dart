import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_evening_prompt.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_login_prompt.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_record.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_service.dart' show RawMaterialLine;
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_requests_screen.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_tracking_service.dart';

const _p2 = 'production_2@cbi-tunisia.com';

class _MemoryStore implements RawMaterialPromptStore {
  String? value;
  @override
  String? read() => value;
  @override
  Future<void> write(String sessionId) async => value = sessionId;
}

// Valeurs de la demande réelle DMP-2026-000001 (5 matières), validée par le responsable.
Map<String, dynamic> _validated() => {
      'id': 'r1',
      'requestNumber': 'DMP-2026-000001',
      'userId': 'dd746847-c5ad-42e9-a5ab-4a721a0e3839',
      'userEmail': 'production_1@cbi-tunisia.com',
      'poste': 'matin',
      'productionDate': '2026-10-26',
      'status': 'VALIDATED',
      'validatedAt': '2026-10-26T19:14:50.476Z',
      'validatedByEmail': 'responsable_logistique@cbi-tunisia.com',
      'createdAt': '2026-10-26T14:07:43.333Z',
      'items': [
        {'material': 'ISO', 'label': 'ISO', 'reference': 'ISO-26', 'lot': 'L-1', 'quantiteDisponible': 5, 'besoinProduction': 10, 'quantiteDemandee': 15, 'unite': 'KG'},
        {'material': 'RESINE', 'label': 'RESINE', 'reference': null, 'lot': null, 'quantiteDisponible': 10, 'besoinProduction': 25, 'quantiteDemandee': 15, 'unite': 'KG'},
        {'material': 'ACCELERATEUR', 'label': 'ACCELERATEUR', 'reference': null, 'lot': null, 'quantiteDisponible': 15, 'besoinProduction': 45, 'quantiteDemandee': 25, 'unite': 'KG'},
        {'material': 'GRAIN_PLASTIQUE', 'label': 'GRAIN PLASTIQUE', 'reference': null, 'lot': null, 'quantiteDisponible': 145, 'besoinProduction': 1000, 'quantiteDemandee': 855, 'unite': 'KG'},
        {'material': 'FIBRE', 'label': 'FIBRE', 'reference': null, 'lot': null, 'quantiteDisponible': 15, 'besoinProduction': 14, 'quantiteDemandee': 25, 'unite': 'KG'},
      ],
      'history': <Map<String, dynamic>>[
        {'fromStatus': null, 'toStatus': 'SUBMITTED', 'changedByEmail': 'production_1@cbi-tunisia.com', 'createdAt': '2026-10-26T14:07:43.333Z'},
        {'fromStatus': 'SUBMITTED', 'toStatus': 'VALIDATED', 'changedByEmail': 'responsable_logistique@cbi-tunisia.com', 'createdAt': '2026-10-26T19:14:50.479Z'},
      ],
    };

/// « Backend » en mémoire : mêmes règles que le serveur (statut VALIDATED
/// obligatoire, une seule prise en charge, motif de refus obligatoire).
class _Backend implements RawMaterialTrackingApi {
  final rows = <Map<String, dynamic>>[];
  final accepts = <(String, Map<String, double>)>[];
  final refusals = <(String, String)>[];
  final notifiedValidator = <String>[];
  Object? acceptError;
  int listCalls = 0;

  @override
  Future<({List<RawMaterialRequestRecord> items, int total})> list(RawMaterialFilters filters) async {
    listCalls++;
    final found = rows.where((r) => filters.status == null || r['status'] == filters.status).toList();
    return (items: [for (final r in found) RawMaterialRequestRecord.fromJson(r)], total: found.length);
  }

  @override
  Future<RawMaterialRequestRecord> detail(String id) async {
    final r = rows.firstWhere((r) => r['id'] == id);
    return RawMaterialRequestRecord.fromJson({...r, 'canEveningHandle': r['status'] == 'VALIDATED'});
  }

  @override
  Future<RawMaterialRequestRecord> eveningAccept(String id, Map<String, double> actualQuantities) async {
    accepts.add((id, actualQuantities));
    if (acceptError != null) throw acceptError!;
    final r = rows.firstWhere((r) => r['id'] == id);
    if (r['status'] != 'VALIDATED') throw Exception('Cette demande a déjà été traitée.');
    r
      ..['status'] = 'EVENING_ACCEPTED'
      ..['actualItems'] = [for (final e in actualQuantities.entries) {'material': e.key, 'quantiteReelle': e.value}]
      ..['eveningHandledAt'] = '2026-10-26T20:00:00.000Z'
      ..['eveningHandledByEmail'] = _p2;
    (r['history'] as List).add({'fromStatus': 'VALIDATED', 'toStatus': 'EVENING_ACCEPTED', 'changedByEmail': _p2});
    return RawMaterialRequestRecord.fromJson(r);
  }

  @override
  Future<RawMaterialRequestRecord> eveningRefuse(String id, {required String comment}) async {
    if (comment.trim().isEmpty) throw Exception('Le motif du refus est obligatoire.');
    refusals.add((id, comment));
    final r = rows.firstWhere((r) => r['id'] == id);
    if (r['status'] != 'VALIDATED') throw Exception('Cette demande a déjà été traitée.');
    r
      ..['status'] = 'EVENING_REFUSED'
      ..['eveningRefusalComment'] = comment
      ..['eveningHandledByEmail'] = _p2;
    notifiedValidator.add(r['requestNumber'] as String); // notification du responsable (backend)
    return RawMaterialRequestRecord.fromJson(r);
  }

  @override
  Future<RawMaterialPermissions> permissions() async => const RawMaterialPermissions(canView: true, canEveningHandle: true);
  @override
  Future<({int pending, int overdue, int dueSoon})> pendingSummary() async => (pending: 0, overdue: 0, dueSoon: 0);
  @override
  Future<List<({String userId, String userEmail})>> requesters() async => const [];
  @override
  Future<RawMaterialRequestRecord> changeStatus(String id, {required String status, String? comment, String? expectedStatus}) async => throw UnimplementedError();
  @override
  Future<({Uint8List bytes, String fileName})> exportExcel(RawMaterialFilters filters) async => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> resubmit(String id, List<RawMaterialLine> lines) async => throw UnimplementedError();
}

class _Session {
  _Session(this.backend, {this.email = _p2});
  final _Backend backend;
  String email;
  String sessionId = 'session-1';
  final store = _MemoryStore();

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      home: Builder(builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) => RawMaterialEveningPrompt.maybeShow(
              context,
              loadSessionId: () async => sessionId,
              loadEmail: () async => email,
              api: backend,
              store: store,
            ));
        return const Scaffold(body: Text('Tableau de bord'));
      }),
    ));
    await tester.pumpAndSettle();
  }
}

final _title = find.text('Demande de matières premières validée — shift soir');
String _field(WidgetTester tester, String m) => tester.widget<TextFormField>(find.byKey(ValueKey('actual-input-$m'))).controller!.text;

Future<void> _fillActual(WidgetTester tester, Map<String, String> values) async {
  for (final e in values.entries) {
    await tester.enterText(find.byKey(ValueKey('actual-input-${e.key}')), e.value);
  }
}

const _all = {'ISO': '14,5', 'RESINE': '15', 'ACCELERATEUR': '0', 'GRAIN_PLASTIQUE': '840', 'FIBRE': '25'};

void main() {
  setUp(RawMaterialEveningPrompt.resetForTest);

  testWidgets('2. connexion du shift soir : popup automatique avec la demande validée complète', (tester) async {
    final s = _Session(_Backend()..rows.add(_validated()));
    await s.open(tester);

    expect(_title, findsOneWidget);
    expect(find.byKey(const ValueKey('evening-card-DMP-2026-000001')), findsOneWidget);
    for (final t in ['DMP-2026-000001', '26/10/2026', 'Matin', 'production_1@cbi-tunisia.com', 'responsable_logistique@cbi-tunisia.com']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(find.text('Validée par'), findsOneWidget);
    expect(find.text('Date et heure de validation'), findsOneWidget);
    // Toutes les colonnes, dont « Quantité réelle (KG) » avant « Unité ».
    final table = find.byKey(const ValueKey('detail-items-table'));
    final headers = ['Matière', 'Référence', 'Lot', 'Quantité disponible', 'Besoin production', 'Quantité demandée', 'Quantité réelle (KG)', 'Unité'];
    double? x;
    for (final h in headers) {
      final f = find.descendant(of: table, matching: find.text(h));
      expect(f, findsOneWidget, reason: h);
      if (x != null) expect(tester.getTopLeft(f).dx, greaterThan(x), reason: h);
      x = tester.getTopLeft(f).dx;
    }
    // Valeurs validées telles qu'enregistrées (lecture seule), quantités réelles vides.
    for (final t in ['ISO-26', 'L-1', '145', '1000', '855']) {
      expect(find.descendant(of: table, matching: find.text(t)), findsOneWidget, reason: t);
    }
    for (final m in _all.keys) {
      expect(_field(tester, m), '', reason: m);
    }
    expect(find.descendant(of: table, matching: find.byType(EditableText)), findsNWidgets(5)); // seules les quantités réelles sont saisissables
  });

  testWidgets('aucune demande validée : pas de popup ; autres comptes : jamais', (tester) async {
    final empty = _Session(_Backend());
    await empty.open(tester);
    expect(_title, findsNothing);
    for (final email in ['production_1@cbi-tunisia.com', 'responsable_logistique@cbi-tunisia.com', 'admin@cbi-tunisia.com']) {
      final s = _Session(_Backend()..rows.add(_validated()), email: email)..sessionId = 'session-$email';
      await s.open(tester);
      expect(_title, findsNothing, reason: email);
      expect(s.backend.listCalls, 0, reason: email);
    }
  });

  testWidgets('quantités réelles : vides, négatives ou non numériques refusées avant tout envoi', (tester) async {
    final s = _Session(_Backend()..rows.add(_validated()));
    await s.open(tester);
    await tester.tap(find.byKey(const ValueKey('evening-accept')));
    await tester.pumpAndSettle();
    expect(find.text('Champ obligatoire'), findsNWidgets(5));
    expect(find.byKey(const ValueKey('evening-error')), findsOneWidget);
    expect(s.backend.accepts, isEmpty);
    // Le clavier n'accepte que chiffres, point et virgule : « -3 » devient « 3 » ; « 1,2,3 » est refusé.
    await _fillActual(tester, {..._all, 'ISO': '1,2,3'});
    await tester.tap(find.byKey(const ValueKey('evening-accept')));
    await tester.pumpAndSettle();
    expect(find.text('Nombre invalide (ex. 12,5)'), findsOneWidget);
    expect(s.backend.accepts, isEmpty);
  });

  testWidgets('3/4. Accepter : confirmation (n°, demandé / réel, message) puis enregistrement et succès', (tester) async {
    final s = _Session(_Backend()..rows.add(_validated()));
    await s.open(tester);
    await _fillActual(tester, _all);
    await tester.tap(find.byKey(const ValueKey('evening-accept')));
    await tester.pumpAndSettle();

    expect(find.text('Accepter la demande DMP-2026-000001'), findsOneWidget);
    expect(
        find.text('Cette demande de matières premières a été validée par le responsable logistique. '
            'Confirmez-vous sa prise en charge pour le shift soir ?'),
        findsOneWidget);
    final confirm = find.byKey(const ValueKey('evening-confirm-table'));
    expect(find.descendant(of: confirm, matching: find.text('855')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('confirm-actual-GRAIN_PLASTIQUE'))).data, '840');
    expect(tester.widget<Text>(find.byKey(const ValueKey('confirm-actual-ISO'))).data, '14,5');
    expect(tester.widget<Text>(find.byKey(const ValueKey('confirm-actual-ACCELERATEUR'))).data, '0');

    await tester.tap(find.byKey(const ValueKey('evening-confirm-accept')));
    await tester.pumpAndSettle();
    expect(s.backend.accepts.single.$2, {'ISO': 14.5, 'RESINE': 15.0, 'ACCELERATEUR': 0.0, 'GRAIN_PLASTIQUE': 840.0, 'FIBRE': 25.0});
    expect(find.text('Demande DMP-2026-000001 acceptée par le shift soir.'), findsOneWidget);
    expect(find.byKey(const ValueKey('evening-empty')), findsOneWidget);
    expect(s.backend.rows.single['status'], 'EVENING_ACCEPTED');
  });

  testWidgets('annuler la confirmation : rien n\'est enregistré, saisie conservée', (tester) async {
    final s = _Session(_Backend()..rows.add(_validated()));
    await s.open(tester);
    await _fillActual(tester, _all);
    await tester.tap(find.byKey(const ValueKey('evening-accept')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(s.backend.accepts, isEmpty);
    expect(_field(tester, 'GRAIN_PLASTIQUE'), '840');
  });

  testWidgets('échec du serveur : erreur explicite, saisie conservée, demande toujours à traiter', (tester) async {
    final s = _Session(_Backend()..rows.add(_validated())..acceptError = Exception('Cette demande a déjà été traitée (ou son statut vient de changer).'));
    await s.open(tester);
    await _fillActual(tester, _all);
    await tester.tap(find.byKey(const ValueKey('evening-accept')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('evening-confirm-accept')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('evening-error')), findsOneWidget);
    expect(find.textContaining('déjà été traitée'), findsOneWidget);
    expect(_field(tester, 'ISO'), '14,5');
    expect(find.byKey(const ValueKey('evening-card-DMP-2026-000001')), findsOneWidget);
  });

  testWidgets('5/6. Refuser : motif obligatoire, puis refus enregistré et responsable notifié', (tester) async {
    final s = _Session(_Backend()..rows.add(_validated()));
    await s.open(tester);
    await tester.tap(find.byKey(const ValueKey('evening-refuse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('evening-confirm-refuse')));
    await tester.pumpAndSettle();
    expect(find.text('Le motif du refus est obligatoire.'), findsOneWidget);
    expect(s.backend.refusals, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('evening-refuse-comment')), 'Stock ISO insuffisant ce soir');
    await tester.tap(find.byKey(const ValueKey('evening-confirm-refuse')));
    await tester.pumpAndSettle();
    expect(s.backend.refusals.single, ('r1', 'Stock ISO insuffisant ce soir'));
    expect(s.backend.notifiedValidator, ['DMP-2026-000001']);
    expect(find.text('Demande DMP-2026-000001 refusée par le shift soir.'), findsOneWidget);
    expect(s.backend.rows.single['status'], 'EVENING_REFUSED');
  });

  testWidgets('7/8. reconnexion : popup absente une fois traitée ; fiche détaillée : quantités réelles conservées, plus de prise en charge', (tester) async {
    final b = _Backend()..rows.add(_validated());
    final s = _Session(b);
    await s.open(tester);
    await _fillActual(tester, _all);
    await tester.tap(find.byKey(const ValueKey('evening-accept')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('evening-confirm-accept')));
    await tester.pumpAndSettle();

    s.sessionId = 'session-2'; // déconnexion / reconnexion
    await s.open(tester);
    expect(_title, findsNothing);

    // Fiche détaillée (page de suivi) : quantités réelles relues, aucun bouton de prise en charge.
    tester.view.physicalSize = const Size(1400, 1200);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RawMaterialRequestDetailDialog(requestId: 'r1', api: b, permissions: const RawMaterialPermissions(canView: true, canEveningHandle: true)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Acceptée par le shift soir'), findsWidgets);
    expect(tester.widget<Text>(find.byKey(const ValueKey('actual-GRAIN_PLASTIQUE'))).data, '840');
    expect(tester.widget<Text>(find.byKey(const ValueKey('actual-ISO'))).data, '14,5');
    expect(find.byKey(const ValueKey('evening-handle')), findsNothing);
    expect(find.text('Quantité réelle (KG)'), findsOneWidget);
  });

  testWidgets('fiche détaillée : « Prendre en charge (shift soir) » quand la popup a été fermée', (tester) async {
    final b = _Backend()..rows.add(_validated());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RawMaterialRequestDetailDialog(requestId: 'r1', api: b, permissions: const RawMaterialPermissions(canView: true, canEveningHandle: true)),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('evening-handle')));
    await tester.pumpAndSettle();
    expect(_title, findsOneWidget);
    await _fillActual(tester, _all);
    await tester.tap(find.byKey(const ValueKey('evening-accept')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('evening-confirm-accept')));
    await tester.pumpAndSettle();
    expect(b.accepts, hasLength(1));
    // Retour à la fiche : relue, statut et quantités réelles à jour.
    await tester.tap(find.descendant(of: find.byType(RawMaterialEveningDialog), matching: find.byTooltip('Fermer')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('detail-status')), matching: find.text('Acceptée par le shift soir')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('actual-FIBRE'))).data, '25');
  });
}
