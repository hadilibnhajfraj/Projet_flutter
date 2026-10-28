import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_record.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_requests_screen.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_tracking_service.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_service.dart' show RawMaterialLine;

const _p1 = 'dd746847-c5ad-42e9-a5ab-4a721a0e3839';
const _transitions = {
  'PENDING_VALIDATION': ['VALIDATED', 'REJECTED'],
  'DRAFT': ['SUBMITTED'],
  'SUBMITTED': ['VALIDATED', 'REJECTED', 'IN_PROGRESS'],
  'VALIDATED': ['IN_PROGRESS', 'PROCESSED', 'REJECTED'],
  'IN_PROGRESS': ['PROCESSED', 'REJECTED'],
  'REJECTED': <String>[],
  'PROCESSED': <String>[],
};

Map<String, dynamic> _item(String material, String label, {String? ref, String? lot, num? dispo, num? besoin, num? demandee}) => {
      'material': material,
      'label': label,
      'reference': ref,
      'lot': lot,
      'quantiteDisponible': dispo,
      'besoinProduction': besoin,
      'quantiteDemandee': demandee,
      'unite': 'KG',
    };

/// « Backend » en mémoire : mêmes filtres et transitions que le serveur.
class _FakeApi implements RawMaterialTrackingApi {
  _FakeApi({this.manager = true});
  final bool manager;
  final listCalls = <RawMaterialFilters>[];
  final statusCalls = <(String, String, String?)>[];
  RawMaterialFilters? exported;
  Object? changeError;

  final rows = <Map<String, dynamic>>[
    {
      'id': 'a1',
      'requestNumber': 'DMP-2026-000001',
      'userId': _p1,
      'userEmail': 'production_1@cbi-tunisia.com',
      'poste': 'matin',
      'productionDate': '2026-10-26',
      'status': 'SUBMITTED',
      'createdAt': '2026-10-26T14:07:43.333Z',
      'items': [
        _item('ISO', 'ISO', ref: 'ISO-26', lot: 'L-1', dispo: 120, besoin: 300, demandee: 180),
        _item('RESINE', 'RESINE', dispo: 40, besoin: 90, demandee: 50.5),
        _item('FIBRE', 'FIBRE', ref: 'F-9', dispo: 0, besoin: 12, demandee: 12),
      ],
      'history': [
        {'fromStatus': null, 'toStatus': 'SUBMITTED', 'changedByEmail': 'production_1@cbi-tunisia.com', 'createdAt': '2026-10-26T14:07:43.333Z'},
      ],
    },
    {
      'id': 'a2',
      'requestNumber': 'DMP-2026-000002',
      'userId': _p1,
      'userEmail': 'production_1@cbi-tunisia.com',
      'poste': 'matin',
      'productionDate': '2026-10-27',
      'status': 'VALIDATED',
      'createdAt': '2026-10-27T06:30:00.000Z',
      'validatedAt': '2026-10-27T08:00:00.000Z',
      'validatedByEmail': 'responsable_logistique@cbi-tunisia.com',
      'items': [_item('GRAIN_PLASTIQUE', 'GRAIN PLASTIQUE', ref: 'GP-4', lot: 'L-77', dispo: 15, besoin: 40, demandee: 25)],
      'history': [
        {'fromStatus': null, 'toStatus': 'SUBMITTED', 'changedByEmail': 'production_1@cbi-tunisia.com', 'createdAt': '2026-10-27T06:30:00.000Z'},
        {'fromStatus': 'SUBMITTED', 'toStatus': 'VALIDATED', 'changedByEmail': 'responsable_logistique@cbi-tunisia.com', 'comment': 'Stock OK', 'createdAt': '2026-10-27T08:00:00.000Z'},
      ],
    },
  ];

  bool _match(Map<String, dynamic> r, RawMaterialFilters f) {
    final q = f.toQuery(paged: false);
    if (q['status'] != null && r['status'] != q['status']) return false;
    if (q['poste'] != null && r['poste'] != q['poste']) return false;
    if (q['userId'] != null && r['userId'] != q['userId']) return false;
    if (q['material'] != null && !(r['items'] as List).any((i) => i['material'] == q['material'])) return false;
    if (q['search'] != null && !(r['requestNumber'] as String).contains(q['search'] as String)) return false;
    if (q['from'] != null && (r['productionDate'] as String).compareTo(q['from'] as String) < 0) return false;
    if (q['to'] != null && (r['productionDate'] as String).compareTo(q['to'] as String) > 0) return false;
    return true;
  }

  @override
  Future<RawMaterialPermissions> permissions() async => RawMaterialPermissions(
        canView: true,
        fullVisibility: manager,
        canManageStatus: manager,
        canValidate: manager,
        transitions: manager ? _transitions : const {},
      );

  @override
  Future<({List<RawMaterialRequestRecord> items, int total})> list(RawMaterialFilters filters) async {
    listCalls.add(filters);
    final found = rows.where((r) => _match(r, filters)).toList()
      ..sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));
    final page = found.skip((filters.page - 1) * filters.pageSize).take(filters.pageSize);
    return (items: [for (final r in page) RawMaterialRequestRecord.fromJson({...r, 'history': null})], total: found.length);
  }

  @override
  Future<List<({String userId, String userEmail})>> requesters() async => [(userId: _p1, userEmail: 'production_1@cbi-tunisia.com')];

  @override
  Future<RawMaterialRequestRecord> detail(String id) async {
    final r = rows.firstWhere((r) => r['id'] == id);
    // Le demandeur (compte non gestionnaire) peut corriger sa demande rejetée.
    return RawMaterialRequestRecord.fromJson({...r, 'canResubmit': !manager && r['status'] == 'REJECTED'});
  }

  @override
  Future<RawMaterialRequestRecord> eveningAccept(String id, Map<String, double> actualQuantities) async => throw UnimplementedError();

  @override
  Future<RawMaterialRequestRecord> eveningRefuse(String id, {required String comment}) async => throw UnimplementedError();

  final resubmitCalls = <(String, List<RawMaterialLine>)>[];

  @override
  Future<Map<String, dynamic>> resubmit(String id, List<RawMaterialLine> lines) async {
    resubmitCalls.add((id, lines));
    final r = rows.firstWhere((r) => r['id'] == id);
    r
      ..['status'] = 'PENDING_VALIDATION'
      ..['rejectionComment'] = null
      ..['items'] = [for (final l in lines) {...l.toJson(), 'label': l.material, 'unite': 'KG'}];
    (r['history'] as List).add({'fromStatus': 'REJECTED', 'toStatus': 'PENDING_VALIDATION', 'changedByEmail': 'production_1@cbi-tunisia.com'});
    return {'id': id};
  }

  @override
  Future<({int pending, int overdue, int dueSoon})> pendingSummary() async {
    final pending = rows.where((r) => r['status'] == 'PENDING_VALIDATION');
    return (
      pending: pending.length,
      overdue: pending.where((r) => r['overdue'] == true).length,
      dueSoon: pending.where((r) => r['dueSoon'] == true).length,
    );
  }

  @override
  Future<RawMaterialRequestRecord> changeStatus(String id, {required String status, String? comment, String? expectedStatus}) async {
    statusCalls.add((id, status, comment));
    if (changeError != null) throw changeError!;
    final r = rows.firstWhere((r) => r['id'] == id);
    final from = r['status'] as String;
    if (!_transitions[from]!.contains(status)) throw Exception('transition interdite');
    r['status'] = status;
    if (status == 'REJECTED') {
      r
        ..['rejectionComment'] = (comment ?? '').trim().isEmpty ? null : comment!.trim()
        ..['rejectedAt'] = '2026-10-30T12:00:00.000Z'
        ..['rejectedByEmail'] = 'responsable_logistique@cbi-tunisia.com';
    }
    if (status == 'VALIDATED') r['validatedAt'] = '2026-10-30T12:00:00.000Z';
    r['overdue'] = false;
    r['dueSoon'] = false;
    (r['history'] as List).add({
      'fromStatus': from,
      'toStatus': status,
      'changedByEmail': 'responsable_logistique@cbi-tunisia.com',
      'comment': (comment ?? '').trim().isEmpty ? null : comment!.trim(),
      'createdAt': '2026-10-27T10:00:00.000Z',
    });
    return RawMaterialRequestRecord.fromJson(r);
  }

  @override
  Future<({Uint8List bytes, String fileName})> exportExcel(RawMaterialFilters filters) async {
    exported = filters;
    return (bytes: Uint8List.fromList([80, 75, 3, 4]), fileName: 'matieres-premieres-2026-10-27.xlsx');
  }
}

Future<void> _pump(WidgetTester tester, _FakeApi api, {List<(Uint8List, String, String)>? saved, String? initialRequestId}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(2200, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: RawMaterialRequestsScreen(
      api: api,
      saveFile: (bytes, name, mime) async => saved?.add((bytes, name, mime)),
      initialRequestId: initialRequestId,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String filterKey, String option) async {
  await tester.tap(find.byKey(ValueKey('filter-$filterKey')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  String cell(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  testWidgets('tableau : une ligne par matière, toutes les colonnes, informations de la demande répétées', (tester) async {
    final api = _FakeApi();
    await _pump(tester, api);

    for (final h in [
      'N° demande', 'Date et heure de la demande', 'Demandeur', 'Poste', 'Date de production', 'Matière première',
      'Référence', 'Lot', 'Quantité disponible (KG)', 'Besoin de production (KG)', 'Quantité demandée (KG)', 'Unité',
      'Statut', 'Date et heure de validation',
    ]) {
      final table = find.byKey(const ValueKey('raw-material-requests-table'));
      expect(find.descendant(of: table, matching: find.text(h)), findsOneWidget, reason: h);
    }
    // 3 matières + 1 matière = 4 lignes ; numéro, poste et statut répétés sur chaque ligne.
    expect(find.text('DMP-2026-000001'), findsNWidgets(3));
    expect(find.text('DMP-2026-000002'), findsOneWidget);
    expect(find.text('Matin'), findsNWidgets(4));
    expect(find.text('Soumise'), findsNWidgets(3));
    expect(find.text('KG'), findsNWidgets(4));
    // Plus récente en premier ; lignes d'une demande dans l'ordre enregistré.
    expect(tester.getTopLeft(find.byKey(const ValueKey('row-DMP-2026-000002'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('row-DMP-2026-000001'))).dy));
    double y(String m) => tester.getTopLeft(find.byKey(ValueKey('material-DMP-2026-000001-$m'))).dy;
    expect(y('ISO'), lessThan(y('RESINE')));
    expect(y('RESINE'), lessThan(y('FIBRE')));

    // Aucune agrégation.
    expect(find.textContaining('Σ'), findsNothing);
    expect(find.textContaining(RegExp(r'^\d+ matières')), findsNothing);
    expect(find.byKey(const ValueKey('expand-DMP-2026-000001')), findsNothing);
  });

  testWidgets('valeurs individuelles telles qu\'enregistrées ; « — » seulement si rien n\'est enregistré', (tester) async {
    await _pump(tester, _FakeApi());
    const id = 'DMP-2026-000001';
    expect([for (final f in ['material', 'reference', 'lot', 'dispo', 'besoin', 'demandee', 'unite']) cell(tester, '$f-$id-ISO')],
        ['ISO', 'ISO-26', 'L-1', '120', '300', '180', 'KG']);
    expect([for (final f in ['material', 'reference', 'lot', 'dispo', 'besoin', 'demandee', 'unite']) cell(tester, '$f-$id-RESINE')],
        ['RESINE', '—', '—', '40', '90', '50,5', 'KG']);
    // 0 enregistré reste 0 (jamais « — »).
    expect([for (final f in ['material', 'reference', 'lot', 'dispo', 'besoin', 'demandee', 'unite']) cell(tester, '$f-$id-FIBRE')],
        ['FIBRE', 'F-9', '—', '0', '12', '12', 'KG']);
  });

  testWidgets('demande réelle à 5 matières : 5 lignes avec leurs propres valeurs', (tester) async {
    // Valeurs de DMP-2026-000001 en base locale (26/10/2026).
    final api = _FakeApi();
    api.rows[0]['items'] = [
      _item('ISO', 'ISO', dispo: 5, besoin: 10, demandee: 15),
      _item('RESINE', 'RESINE', dispo: 10, besoin: 25, demandee: 15),
      _item('ACCELERATEUR', 'ACCELERATEUR', dispo: 15, besoin: 45, demandee: 25),
      _item('GRAIN_PLASTIQUE', 'GRAIN PLASTIQUE', dispo: 145, besoin: 1000, demandee: 855),
      _item('FIBRE', 'FIBRE', dispo: 15, besoin: 14, demandee: 25),
    ];
    await _pump(tester, api);
    const id = 'DMP-2026-000001';
    expect(find.text(id), findsNWidgets(5));
    final expected = {
      'ISO': ['5', '10', '15'],
      'RESINE': ['10', '25', '15'],
      'ACCELERATEUR': ['15', '45', '25'],
      'GRAIN_PLASTIQUE': ['145', '1000', '855'],
      'FIBRE': ['15', '14', '25'],
    };
    for (final e in expected.entries) {
      expect([for (final f in ['dispo', 'besoin', 'demandee']) cell(tester, '$f-$id-${e.key}')], e.value, reason: e.key);
      expect(cell(tester, 'unite-$id-${e.key}'), 'KG');
      expect(cell(tester, 'reference-$id-${e.key}'), '—');
    }
    expect(find.textContaining('Σ'), findsNothing);
  });

  testWidgets('bouton de la demande : fiche complète avec toutes ses matières', (tester) async {
    await _pump(tester, _FakeApi());
    // Un seul bouton par demande, sur sa première ligne.
    expect(find.byKey(const ValueKey('detail-DMP-2026-000001')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('detail-DMP-2026-000001')));
    await tester.pumpAndSettle();
    final items = find.byKey(const ValueKey('detail-items-table'));
    for (final t in ['ISO', 'RESINE', 'FIBRE', 'ISO-26', 'L-1', 'F-9', '120', '300', '180', '50,5', '90', '0']) {
      expect(find.descendant(of: items, matching: find.text(t)), findsWidgets, reason: t);
    }
    expect(find.descendant(of: items, matching: find.text('KG')), findsNWidgets(3));
  });

  testWidgets('filtres statut, poste, matière, utilisateur et recherche envoyés au backend', (tester) async {
    final api = _FakeApi();
    await _pump(tester, api);

    await _pick(tester, 'status', 'Validée');
    expect(api.listCalls.last.status, 'VALIDATED');
    expect(find.byKey(const ValueKey('row-DMP-2026-000001')), findsNothing);
    expect(find.byKey(const ValueKey('row-DMP-2026-000002')), findsOneWidget);

    await _pick(tester, 'status', 'Tous');
    expect(api.listCalls.last.status, isNull);

    await _pick(tester, 'material', 'FIBRE');
    expect(api.listCalls.last.material, 'FIBRE');
    expect(find.byKey(const ValueKey('row-DMP-2026-000001')), findsOneWidget);
    expect(find.byKey(const ValueKey('row-DMP-2026-000002')), findsNothing);
    // Filtre matière : uniquement la ligne FIBRE de la demande, avec ses valeurs.
    expect(find.byKey(const ValueKey('material-DMP-2026-000001-FIBRE')), findsOneWidget);
    expect(find.byKey(const ValueKey('material-DMP-2026-000001-ISO')), findsNothing);
    expect(find.byKey(const ValueKey('material-DMP-2026-000001-RESINE')), findsNothing);
    expect(cell(tester, 'demandee-DMP-2026-000001-FIBRE'), '12');

    await _pick(tester, 'poste', 'Soir');
    expect(api.listCalls.last.poste, 'nuit');
    expect(find.text('Aucune demande ne correspond aux filtres.'), findsOneWidget);

    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(api.listCalls.last.isEmpty, isTrue);

    await _pick(tester, 'userId', 'production_1@cbi-tunisia.com');
    expect(api.listCalls.last.userId, _p1);

    await tester.enterText(find.byKey(const ValueKey('filter-search')), '000002');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(api.listCalls.last.search, '000002');
    expect(find.byKey(const ValueKey('row-DMP-2026-000002')), findsOneWidget);
    expect(find.byKey(const ValueKey('row-DMP-2026-000001')), findsNothing);
  });

  testWidgets('filtre période : dates choisies envoyées au format AAAA-MM-JJ', (tester) async {
    final api = _FakeApi();
    await _pump(tester, api);
    await tester.tap(find.byKey(const ValueKey('filter-from')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined)); // saisie au clavier
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '10/27/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(api.listCalls.last.toQuery()['from'], '2026-10-27');
    expect(find.byKey(const ValueKey('row-DMP-2026-000002')), findsOneWidget);
    expect(find.byKey(const ValueKey('row-DMP-2026-000001')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('filter-from-clear')));
    await tester.pumpAndSettle();
    expect(api.listCalls.last.from, isNull);
  });

  testWidgets('demandeur (non gestionnaire) : pas de filtre utilisateur ni d\'action de statut', (tester) async {
    final api = _FakeApi(manager: false);
    await _pump(tester, api);
    expect(find.byKey(const ValueKey('filter-userId')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('detail-DMP-2026-000001')));
    await tester.pumpAndSettle();
    expect(find.text('Historique des statuts'), findsOneWidget);
    expect(find.text('Changer le statut'), findsNothing);
    expect(find.byKey(const ValueKey('to-VALIDATED')), findsNothing);
  });

  testWidgets('notification : la demande indiquée par le lien (?id=) s\'ouvre directement', (tester) async {
    await _pump(tester, _FakeApi(), initialRequestId: 'a2');
    expect(find.text('Demande DMP-2026-000002'), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-items-table')), findsOneWidget);
  });

  testWidgets('fiche détaillée : matières, informations et historique', (tester) async {
    await _pump(tester, _FakeApi());
    await tester.tap(find.byKey(const ValueKey('detail-DMP-2026-000002')));
    await tester.pumpAndSettle();

    expect(find.text('Demande DMP-2026-000002'), findsOneWidget);
    final items = find.byKey(const ValueKey('detail-items-table'));
    for (final t in ['GRAIN PLASTIQUE', 'GP-4', 'L-77', '15', '40', '25', 'KG']) {
      expect(find.descendant(of: items, matching: find.text(t)), findsOneWidget, reason: t);
    }
    expect(find.textContaining('responsable_logistique@cbi-tunisia.com'), findsWidgets);
    expect(find.byKey(const ValueKey('history-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-1')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('history-0')), matching: find.text('Création')), findsOneWidget);
    expect(find.text('« Stock OK »'), findsOneWidget);
    // Validée : transitions suivantes proposées au gestionnaire.
    expect(find.byKey(const ValueKey('to-IN_PROGRESS')), findsOneWidget);
    expect(find.byKey(const ValueKey('to-PROCESSED')), findsOneWidget);
    expect(find.byKey(const ValueKey('to-REJECTED')), findsOneWidget);
    expect(find.byKey(const ValueKey('to-SUBMITTED')), findsNothing);
  });

  testWidgets('gestionnaire : changement de statut avec commentaire, historisé, liste rechargée', (tester) async {
    final api = _FakeApi();
    await _pump(tester, api);
    await tester.tap(find.byKey(const ValueKey('detail-DMP-2026-000001')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('status-comment')), 'Stock vérifié');
    await tester.tap(find.byKey(const ValueKey('to-VALIDATED')));
    await tester.pumpAndSettle();

    expect(api.statusCalls.single, ('a1', 'VALIDATED', 'Stock vérifié'));
    final status = find.byKey(const ValueKey('detail-status'));
    expect(find.descendant(of: status, matching: find.text('Validée')), findsOneWidget);
    final last = find.byKey(const ValueKey('history-1'));
    expect(find.descendant(of: last, matching: find.text('Soumise')), findsOneWidget);
    expect(find.descendant(of: last, matching: find.text('Validée')), findsOneWidget);
    expect(find.text('« Stock vérifié »'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('status-comment'))).controller!.text, '');

    final callsBefore = api.listCalls.length;
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(api.listCalls.length, callsBefore + 1);
    // Statut répété sur chaque ligne : 3 lignes de DMP-…001 + 1 ligne de DMP-…002.
    expect(find.text('Validée'), findsNWidgets(4));
  });

  testWidgets('échec du changement de statut : erreur affichée, statut inchangé, commentaire conservé', (tester) async {
    final api = _FakeApi()..changeError = Exception('Le statut de cette demande vient d\'être modifié.');
    await _pump(tester, api);
    await tester.tap(find.byKey(const ValueKey('detail-DMP-2026-000001')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('status-comment')), 'À vérifier');
    await tester.tap(find.byKey(const ValueKey('to-REJECTED')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('status-error')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('detail-status')), matching: find.text('Soumise')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('status-comment'))).controller!.text, 'À vérifier');
    expect(find.byKey(const ValueKey('history-1')), findsNothing);
  });

  testWidgets('export Excel : filtres en cours transmis, fichier enregistré', (tester) async {
    final api = _FakeApi();
    final saved = <(Uint8List, String, String)>[];
    await _pump(tester, api, saved: saved);
    await _pick(tester, 'status', 'Soumise');
    await tester.tap(find.byKey(const ValueKey('raw-material-export')));
    await tester.pumpAndSettle();

    expect(api.exported?.status, 'SUBMITTED');
    expect(saved.single.$2, 'matieres-premieres-2026-10-27.xlsx');
    expect(saved.single.$3, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  });

  test('filtres : paramètres envoyés au backend', () {
    final f = RawMaterialFilters(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
      userId: _p1,
      poste: 'matin',
      material: 'ISO',
      status: 'SUBMITTED',
      search: ' 0001 ',
      page: 2,
    );
    expect(f.toQuery(), {
      'from': '2026-10-01',
      'to': '2026-10-31',
      'userId': _p1,
      'poste': 'matin',
      'material': 'ISO',
      'status': 'SUBMITTED',
      'search': '0001',
      'page': 2,
      'pageSize': 20,
    });
    expect(f.toQuery(paged: false).containsKey('page'), isFalse);
    expect(f.copyWith(clear: {'material', 'from'}).toQuery().containsKey('material'), isFalse);
  });

  // Demande du vendredi en attente de validation (échéance 14 h = 13 h UTC).
  Map<String, dynamic> pendingRow({bool overdue = false, bool dueSoon = false, String status = 'PENDING_VALIDATION'}) => {
        'id': 'a3',
        'requestNumber': 'DMP-2026-000003',
        'userId': _p1,
        'userEmail': 'production_1@cbi-tunisia.com',
        'poste': 'matin',
        'productionDate': '2026-10-30',
        'status': status,
        'deadlineAt': '2026-10-30T13:00:00.000Z',
        'overdue': overdue,
        'dueSoon': dueSoon,
        'createdAt': '2026-10-30T07:00:00.000Z',
        'items': [_item('ISO', 'ISO', ref: 'ISO-30', lot: 'L-30', dispo: 50, besoin: 120, demandee: 70)],
        'history': [
          {'fromStatus': null, 'toStatus': 'PENDING_VALIDATION', 'changedByEmail': 'production_1@cbi-tunisia.com', 'createdAt': '2026-10-30T07:00:00.000Z'},
        ],
      };

  testWidgets('demande en retard : « En attente de validation » + « En retard », bandeau du responsable', (tester) async {
    final api = _FakeApi()..rows.add(pendingRow(overdue: true));
    await _pump(tester, api);

    final table = find.byKey(const ValueKey('raw-material-requests-table'));
    expect(find.descendant(of: table, matching: find.text('En attente de validation')), findsOneWidget);
    expect(find.byKey(const ValueKey('overdue-DMP-2026-000003')), findsOneWidget);
    final banner = find.byKey(const ValueKey('pending-banner'));
    expect(find.descendant(of: banner, matching: find.textContaining('1 demande en attente de validation')), findsOneWidget);
    expect(find.descendant(of: banner, matching: find.textContaining('1 en retard')), findsOneWidget);

    await tester.tap(find.descendant(of: banner, matching: find.text('Afficher')));
    await tester.pumpAndSettle();
    expect(api.listCalls.last.status, 'PENDING_VALIDATION');
    expect(find.byKey(const ValueKey('row-DMP-2026-000003')), findsOneWidget);
    expect(find.byKey(const ValueKey('row-DMP-2026-000001')), findsNothing);
  });

  testWidgets('échéance proche : indicateur dédié', (tester) async {
    await _pump(tester, _FakeApi()..rows.add(pendingRow(dueSoon: true)));
    expect(find.byKey(const ValueKey('due-soon-DMP-2026-000003')), findsOneWidget);
    expect(find.byKey(const ValueKey('overdue-DMP-2026-000003')), findsNothing);
  });

  testWidgets('responsable : « Valider » une demande en attente — statut et historique mis à jour', (tester) async {
    final api = _FakeApi()..rows.add(pendingRow());
    await _pump(tester, api);
    await tester.tap(find.byKey(const ValueKey('detail-DMP-2026-000003')));
    await tester.pumpAndSettle();

    // Détail complet : matière, référence, lot, quantités ; échéance affichée.
    final items = find.byKey(const ValueKey('detail-items-table'));
    for (final t in ['ISO', 'ISO-30', 'L-30', '50', '120', '70', 'KG']) {
      expect(find.descendant(of: items, matching: find.text(t)), findsOneWidget, reason: t);
    }
    expect(find.text('Validation requise avant'), findsOneWidget);
    expect(find.text('Validation de la demande'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('to-VALIDATED')), matching: find.text('Valider')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('to-REJECTED')), matching: find.text('Rejeter')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('to-VALIDATED')));
    await tester.pumpAndSettle();
    expect(api.statusCalls.single.$1, 'a3');
    expect(api.statusCalls.single.$2, 'VALIDATED');
    expect(find.descendant(of: find.byKey(const ValueKey('detail-status')), matching: find.text('Validée')), findsOneWidget);
    expect(find.byKey(const ValueKey('to-VALIDATED')), findsNothing);
  });

  testWidgets('responsable : « Rejeter » avec motif — motif conservé et affiché', (tester) async {
    final api = _FakeApi()..rows.add(pendingRow());
    await _pump(tester, api);
    await tester.tap(find.byKey(const ValueKey('detail-DMP-2026-000003')));
    await tester.pumpAndSettle();
    expect(find.text('Commentaire (obligatoire en cas de rejet)'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('status-comment')), 'Quantité ISO trop élevée');
    await tester.tap(find.byKey(const ValueKey('to-REJECTED')));
    await tester.pumpAndSettle();

    expect(api.statusCalls.single, ('a3', 'REJECTED', 'Quantité ISO trop élevée'));
    expect(find.descendant(of: find.byKey(const ValueKey('detail-status')), matching: find.text('Rejetée')), findsOneWidget);
    expect(find.byKey(const ValueKey('rejection-comment')), findsOneWidget);
    expect(find.text('Motif du rejet : « Quantité ISO trop élevée »'), findsOneWidget);
    expect(find.text('Date et heure du rejet'), findsOneWidget);
  });

  testWidgets('demandeur : jamais de bouton Valider ; demande rejetée corrigée et soumise de nouveau', (tester) async {
    final api = _FakeApi(manager: false)
      ..rows.add(pendingRow(status: 'REJECTED')..['rejectionComment'] = 'Quantité ISO trop élevée');
    await _pump(tester, api);
    await tester.tap(find.byKey(const ValueKey('detail-DMP-2026-000003')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('to-VALIDATED')), findsNothing);
    expect(find.text('Motif du rejet : « Quantité ISO trop élevée »'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('resubmit')));
    await tester.pumpAndSettle();
    // Formulaire rechargé avec les valeurs rejetées, motif rappelé.
    expect(find.text('Demande rejetée par le responsable logistique achats'), findsOneWidget);
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('demandee-ISO'))).controller!.text, '70');
    await tester.enterText(find.byKey(const ValueKey('demandee-ISO')), '40');
    await tester.ensureVisible(find.byKey(const ValueKey('raw-material-submit')));
    await tester.tap(find.byKey(const ValueKey('raw-material-submit')));
    await tester.pumpAndSettle();

    expect(api.resubmitCalls.single.$1, 'a3');
    expect(api.resubmitCalls.single.$2.single.quantiteDemandee, 40);
    // La même demande repasse « En attente de validation » ; l'historique garde le rejet.
    expect(find.descendant(of: find.byKey(const ValueKey('detail-status')), matching: find.text('En attente de validation')), findsOneWidget);
    expect(find.byKey(const ValueKey('resubmit')), findsNothing);
    expect(find.byKey(const ValueKey('history-1')), findsOneWidget);
  });

  testWidgets('fiche détaillée : rejet sans motif bloqué avant tout appel', (tester) async {
    final api = _FakeApi()..rows.add(pendingRow());
    await _pump(tester, api);
    await tester.tap(find.byKey(const ValueKey('detail-DMP-2026-000003')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('to-REJECTED')));
    await tester.pumpAndSettle();
    expect(find.text('Le motif du rejet est obligatoire.'), findsOneWidget);
    expect(api.statusCalls, isEmpty);
    expect(find.descendant(of: find.byKey(const ValueKey('detail-status')), matching: find.text('En attente de validation')), findsOneWidget);
  });
}
