import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_pending_prompt.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_login_prompt.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_record.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_service.dart' show RawMaterialLine;
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_tracking_service.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_to_validate_screen.dart';

const _validator = 'responsable_logistique@cbi-tunisia.com';

class _MemoryStore implements RawMaterialPromptStore {
  String? value;
  @override
  String? read() => value;
  @override
  Future<void> write(String sessionId) async => value = sessionId;
}

Map<String, dynamic> _req(String id, String number, {required String created, bool overdue = false, List<Map<String, dynamic>>? items}) => {
      'id': id,
      'requestNumber': number,
      'userId': 'dd746847-c5ad-42e9-a5ab-4a721a0e3839',
      'userEmail': 'production_1@cbi-tunisia.com',
      'poste': 'matin',
      'productionDate': '2026-10-30',
      'status': 'PENDING_VALIDATION',
      'deadlineAt': '2026-10-30T13:00:00.000Z',
      'overdue': overdue,
      'dueSoon': false,
      'createdAt': created,
      'items': items ??
          [
            {'material': 'ISO', 'label': 'ISO', 'reference': 'ISO-1', 'lot': 'L-1', 'quantiteDisponible': 10, 'besoinProduction': 30, 'quantiteDemandee': 20, 'unite': 'KG'},
          ],
      'history': <Map<String, dynamic>>[
        {'fromStatus': null, 'toStatus': 'PENDING_VALIDATION', 'changedByEmail': 'production_1@cbi-tunisia.com', 'createdAt': created},
      ],
    };

/// « Backend » en mémoire : seules les décisions explicites changent un statut.
class _Backend implements RawMaterialTrackingApi {
  final rows = <Map<String, dynamic>>[];
  final decisions = <(String, String, String?)>[];
  int summaryCalls = 0;
  int listCalls = 0;
  Object? decisionError;

  static const _awaiting = {'PENDING_VALIDATION', 'SUBMITTED'};
  Iterable<Map<String, dynamic>> get _pending => rows.where((r) => _awaiting.contains(r['status']));
  final listFilters = <RawMaterialFilters>[];

  @override
  Future<({int pending, int overdue, int dueSoon})> pendingSummary() async {
    summaryCalls++;
    return (pending: _pending.length, overdue: _pending.where((r) => r['overdue'] == true).length, dueSoon: 0);
  }

  @override
  Future<({List<RawMaterialRequestRecord> items, int total})> list(RawMaterialFilters filters) async {
    listCalls++;
    listFilters.add(filters);
    final found = rows
        .where((r) => filters.status == null || r['status'] == filters.status)
        .where((r) => !filters.toProcess || _awaiting.contains(r['status']))
        .toList();
    return (items: [for (final r in found) RawMaterialRequestRecord.fromJson(r)], total: found.length);
  }

  final expectedStatuses = <String?>[];

  @override
  Future<RawMaterialRequestRecord> changeStatus(String id, {required String status, String? comment, String? expectedStatus}) async {
    expectedStatuses.add(expectedStatus);
    decisions.add((id, status, comment));
    if (decisionError != null) throw decisionError!;
    final r = rows.firstWhere((r) => r['id'] == id);
    if (!_awaiting.contains(r['status'])) throw Exception('Passage impossible');
    if (status == 'REJECTED' && (comment ?? '').trim().isEmpty) throw Exception('Le motif du rejet est obligatoire.');
    final from = r['status'];
    r['status'] = status;
    (r['history'] as List).add({'fromStatus': from, 'toStatus': status, 'changedByEmail': _validator, 'comment': comment});
    return RawMaterialRequestRecord.fromJson(r);
  }

  @override
  Future<RawMaterialPermissions> permissions() async => const RawMaterialPermissions(
        canView: true,
        fullVisibility: true,
        canManageStatus: true,
        canValidate: true,
        transitions: {'PENDING_VALIDATION': ['VALIDATED', 'REJECTED']},
      );

  @override
  Future<RawMaterialRequestRecord> detail(String id) async => RawMaterialRequestRecord.fromJson(rows.firstWhere((r) => r['id'] == id));

  @override
  Future<List<({String userId, String userEmail})>> requesters() async => const [];

  @override
  Future<({Uint8List bytes, String fileName})> exportExcel(RawMaterialFilters filters) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> resubmit(String id, List<RawMaterialLine> lines) async => throw UnimplementedError();

  @override
  Future<RawMaterialRequestRecord> eveningAccept(String id, Map<String, double> actualQuantities) async => throw UnimplementedError();

  @override
  Future<RawMaterialRequestRecord> eveningRefuse(String id, {required String comment}) async => throw UnimplementedError();
}

class _Session {
  _Session(this.backend, {this.email = _validator});
  final _Backend backend;
  String email;
  String sessionId = 'session-1';
  final store = _MemoryStore();
  final counts = <int>[];

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1100);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      home: Builder(builder: (context) {
        // Comme AppShell : après la première image, session et navigation prêtes.
        WidgetsBinding.instance.addPostFrameCallback((_) => RawMaterialPendingPrompt.maybeShow(
              context,
              loadSessionId: () async => sessionId,
              loadEmail: () async => email,
              api: backend,
              store: store,
              onCountChanged: counts.add,
            ));
        return const Scaffold(body: Text('Tableau de bord'));
      }),
    ));
    await tester.pumpAndSettle();
  }
}

final _title = find.text('Demande(s) de matières premières en attente');
String _count(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('pending-count')), matching: find.byType(Text))).data!;

_Backend _twoPending() => _Backend()
  ..rows.addAll([
    _req('b', 'DMP-2026-000003', created: '2026-10-30T08:00:00.000Z'),
    _req('a', 'DMP-2026-000002', created: '2026-10-30T07:00:00.000Z', overdue: true, items: [
      {'material': 'ISO', 'label': 'ISO', 'reference': 'ISO-7', 'lot': 'L-7', 'quantiteDisponible': 5, 'besoinProduction': 10, 'quantiteDemandee': 15, 'unite': 'KG'},
      {'material': 'GRAIN_PLASTIQUE', 'label': 'GRAIN PLASTIQUE', 'reference': null, 'lot': null, 'quantiteDisponible': 145, 'besoinProduction': 1000, 'quantiteDemandee': 855, 'unite': 'KG'},
    ]),
  ]);

void main() {
  setUp(RawMaterialPendingPrompt.resetForTest);

  testWidgets('connexion sans demande en attente : aucune popup (vérifié auprès du backend)', (tester) async {
    final s = _Session(_Backend());
    await s.open(tester);
    expect(_title, findsNothing);
    expect(s.backend.summaryCalls, 1);
    expect(s.counts, [0]);
  });

  testWidgets('connexion avec 2 demandes : popup, compteur, détail complet de chaque matière, navigation', (tester) async {
    final s = _Session(_twoPending());
    await s.open(tester);

    expect(_title, findsOneWidget);
    expect(find.textContaining('nécessitent votre traitement'), findsOneWidget);
    expect(_count(tester), '2 en attente');
    // La plus urgente (échéance / soumission la plus ancienne) d'abord.
    expect(find.byKey(const ValueKey('pending-card-DMP-2026-000002')), findsOneWidget);
    expect(find.text('Demande 1 / 2'), findsOneWidget);
    for (final t in ['N° demande', 'Date et heure de soumission', 'Demandeur', 'Date de production', 'Poste', 'Validation requise avant']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('production_1@cbi-tunisia.com'), findsOneWidget);
    expect(find.text('30/10/2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-overdue-DMP-2026-000002')), findsOneWidget);
    // Chaque matière avec ses propres valeurs (aucun total).
    final table = find.byKey(const ValueKey('detail-items-table'));
    for (final t in ['ISO', 'ISO-7', 'L-7', '5', '10', '15', 'GRAIN PLASTIQUE', '145', '1000', '855']) {
      expect(find.descendant(of: table, matching: find.text(t)), findsOneWidget, reason: t);
    }
    expect(find.descendant(of: table, matching: find.text('KG')), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('pending-next')));
    await tester.pumpAndSettle();
    expect(find.text('Demande 2 / 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-card-DMP-2026-000003')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pending-prev')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pending-card-DMP-2026-000002')), findsOneWidget);

    for (final k in ['pending-details', 'pending-validate', 'pending-reject']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
  });

  testWidgets('Valider la demande : confirmation, décision enregistrée, compteur actualisé, demande retirée', (tester) async {
    final s = _Session(_twoPending());
    await s.open(tester);

    await tester.tap(find.byKey(const ValueKey('pending-validate')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confirmer la validation de la demande DMP-2026-000002'), findsOneWidget);
    // Annuler la confirmation : rien n'est enregistré.
    await tester.tap(find.text('Annuler').last);
    await tester.pumpAndSettle();
    expect(s.backend.decisions, isEmpty);

    await tester.tap(find.byKey(const ValueKey('pending-validate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-validate')));
    await tester.pumpAndSettle();

    expect(s.backend.decisions.single, ('a', 'VALIDATED', null));
    expect(find.byKey(const ValueKey('pending-success')), findsOneWidget);
    expect(find.text('Demande DMP-2026-000002 validée.'), findsOneWidget);
    expect(_count(tester), '1 en attente');
    expect(find.byKey(const ValueKey('pending-card-DMP-2026-000002')), findsNothing);
    expect(find.byKey(const ValueKey('pending-card-DMP-2026-000003')), findsOneWidget);
    expect(s.counts.last, 1);
  });

  testWidgets('Rejeter la demande : motif obligatoire, puis décision enregistrée avec le motif', (tester) async {
    final s = _Session(_twoPending());
    await s.open(tester);

    await tester.tap(find.byKey(const ValueKey('pending-reject')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-reject')));
    await tester.pumpAndSettle();
    expect(find.text('Le motif du rejet est obligatoire.'), findsOneWidget);
    expect(s.backend.decisions, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('reject-comment')), 'Quantité GRAIN PLASTIQUE à revoir');
    await tester.tap(find.byKey(const ValueKey('confirm-reject')));
    await tester.pumpAndSettle();

    expect(s.backend.decisions.single, ('a', 'REJECTED', 'Quantité GRAIN PLASTIQUE à revoir'));
    expect(find.text('Demande DMP-2026-000002 rejetée.'), findsOneWidget);
    expect(_count(tester), '1 en attente');
  });

  testWidgets('responsable_production : popup à la connexion, demande complète, Accepter avec confirmation', (tester) async {
    final s = _Session(_twoPending(), email: 'responsable_production@cbi-tunisia.com');
    await s.open(tester);

    expect(_title, findsOneWidget);
    expect(_count(tester), '2 en attente');
    // Lignes complètes : disponible, besoin, demandé.
    for (final v in ['GRAIN PLASTIQUE', '145', '1000', '855']) {
      expect(find.text(v), findsWidgets, reason: v);
    }
    await tester.tap(find.byKey(const ValueKey('pending-validate')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confirmer la validation de la demande DMP-2026-000002'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-validate')));
    await tester.pumpAndSettle();

    expect(s.backend.decisions.single, ('a', 'VALIDATED', null));
    // Décision prise sur le statut affiché : refusée par le backend si l'autre
    // responsable a décidé entre-temps.
    expect(s.backend.expectedStatuses.single, 'PENDING_VALIDATION');
    expect(find.text('Demande DMP-2026-000002 validée.'), findsOneWidget);
    expect(_count(tester), '1 en attente');
  });

  testWidgets('responsable_production : Refuser avec motif obligatoire', (tester) async {
    final s = _Session(_twoPending(), email: 'responsable_production@cbi-tunisia.com');
    await s.open(tester);
    await tester.tap(find.byKey(const ValueKey('pending-reject')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-reject')));
    await tester.pumpAndSettle();
    expect(find.text('Le motif du rejet est obligatoire.'), findsOneWidget);
    expect(s.backend.decisions, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('reject-comment')), 'Stock FIBRE suffisant');
    await tester.tap(find.byKey(const ValueKey('confirm-reject')));
    await tester.pumpAndSettle();
    expect(s.backend.decisions.single, ('a', 'REJECTED', 'Stock FIBRE suffisant'));
    expect(find.text('Demande DMP-2026-000002 rejetée.'), findsOneWidget);
  });

  testWidgets('toutes traitées : message de fin, compteur à 0', (tester) async {
    final s = _Session(_Backend()..rows.add(_req('a', 'DMP-2026-000002', created: '2026-10-30T07:00:00.000Z')));
    await s.open(tester);
    await tester.tap(find.byKey(const ValueKey('pending-validate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-validate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pending-empty')), findsOneWidget);
    expect(_count(tester), '0 en attente');
    expect(s.counts.last, 0);
  });

  testWidgets("échec de la décision : erreur explicite, la demande reste à traiter", (tester) async {
    final s = _Session(_twoPending())..backend.decisionError = Exception('Le statut de cette demande vient d\'être modifié.');
    await s.open(tester);
    await tester.tap(find.byKey(const ValueKey('pending-validate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-validate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pending-error')), findsOneWidget);
    expect(find.textContaining("vient d'être modifié"), findsOneWidget);
    expect(_count(tester), '2 en attente');
    expect(find.byKey(const ValueKey('pending-card-DMP-2026-000002')), findsOneWidget);
  });

  testWidgets('fermée sans décision : rien n\'est validé ; même session : pas de 2e popup ; reconnexion : popup de nouveau', (tester) async {
    final s = _Session(_twoPending());
    await s.open(tester);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(_title, findsNothing);
    expect(s.backend.decisions, isEmpty);
    expect(s.backend.rows.every((r) => r['status'] == 'PENDING_VALIDATION'), isTrue);
    expect(s.counts.last, 2); // le badge du menu garde le compteur

    await s.open(tester); // navigation / actualisation dans la même session
    expect(_title, findsNothing);

    s.sessionId = 'session-2'; // déconnexion puis reconnexion
    await s.open(tester);
    expect(_title, findsOneWidget);
    expect(_count(tester), '2 en attente');
  });

  testWidgets('Consulter les détails : fiche complète avec historique', (tester) async {
    final s = _Session(_twoPending());
    await s.open(tester);
    await tester.tap(find.byKey(const ValueKey('pending-details')));
    await tester.pumpAndSettle();
    expect(find.text('Demande DMP-2026-000002'), findsOneWidget);
    expect(find.text('Historique des statuts'), findsOneWidget);
  });

  testWidgets('autres comptes (production_1, superadmin…) : jamais cette popup, aucun appel', (tester) async {
    for (final email in ['production_1@cbi-tunisia.com', 'production_2@cbi-tunisia.com', 'admin@cbi-tunisia.com', 'cbitunisia@cbi-tunisia.com']) {
      final s = _Session(_twoPending(), email: email)..sessionId = 'session-$email';
      await s.open(tester);
      expect(_title, findsNothing, reason: email);
      expect(s.backend.summaryCalls, 0, reason: email);
    }
  });

  testWidgets('email en majuscules / espaces : reconnu', (tester) async {
    final s = _Session(_twoPending(), email: '  Responsable_Logistique@CBI-Tunisia.com ');
    await s.open(tester);
    expect(_title, findsOneWidget);
  });

  // Cause du défaut corrigé : la seule demande réelle (DMP-2026-000001) est
  // « Soumise » (créée avant la validation obligatoire) et était exclue.
  Map<String, dynamic> legacySubmitted() => {
        ..._req('legacy', 'DMP-2026-000001', created: '2026-10-26T14:07:43.333Z', items: [
          {'material': 'ISO', 'label': 'ISO', 'reference': null, 'lot': null, 'quantiteDisponible': 5, 'besoinProduction': 10, 'quantiteDemandee': 15, 'unite': 'KG'},
          {'material': 'GRAIN_PLASTIQUE', 'label': 'GRAIN PLASTIQUE', 'reference': null, 'lot': null, 'quantiteDisponible': 145, 'besoinProduction': 1000, 'quantiteDemandee': 855, 'unite': 'KG'},
        ]),
        'status': 'SUBMITTED',
        'deadlineAt': null,
        'requestDate': '2026-10-26',
        'productionDate': '2026-10-26',
      };

  testWidgets('demande « Soumise » (antérieure à la validation) : popup à la connexion et validation possible', (tester) async {
    final s = _Session(_Backend()..rows.add(legacySubmitted()));
    await s.open(tester);
    expect(_title, findsOneWidget);
    expect(_count(tester), '1 en attente');
    expect(s.backend.listFilters.last.toProcess, isTrue);
    expect(find.byKey(const ValueKey('pending-card-DMP-2026-000001')), findsOneWidget);
    expect(find.text('Soumise'), findsOneWidget);
    final table = find.byKey(const ValueKey('detail-items-table'));
    for (final t in ['ISO', '5', '10', '15', 'GRAIN PLASTIQUE', '145', '1000', '855']) {
      expect(find.descendant(of: table, matching: find.text(t)), findsOneWidget, reason: t);
    }

    await tester.tap(find.byKey(const ValueKey('pending-validate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-validate')));
    await tester.pumpAndSettle();
    expect(s.backend.decisions.single, ('legacy', 'VALIDATED', null));
    expect(find.byKey(const ValueKey('pending-empty')), findsOneWidget);
    expect(s.counts.last, 0);
  });

  Future<void> openPage(WidgetTester tester, _Backend b, List<int> counts) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 2000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: RawMaterialToValidateScreen(api: b, onCountChanged: counts.add)));
    await tester.pumpAndSettle();
  }

  testWidgets('page « Demandes à valider » : toutes les demandes sans décision, sans popup', (tester) async {
    final b = _twoPending()..rows.add(legacySubmitted());
    final counts = <int>[];
    await openPage(tester, b, counts);

    expect(find.text('Demandes à valider'), findsOneWidget);
    expect(_count(tester), '3 en attente');
    for (final n in ['DMP-2026-000001', 'DMP-2026-000002', 'DMP-2026-000003']) {
      expect(find.byKey(ValueKey('pending-card-$n')), findsOneWidget, reason: n);
      expect(find.byKey(ValueKey('pending-validate-$n')), findsOneWidget, reason: n);
    }
    // Les demandes du vendredi (avec échéance) d'abord, puis la demande sans échéance.
    double y(String n) => tester.getTopLeft(find.byKey(ValueKey('pending-card-$n'))).dy;
    expect(y('DMP-2026-000002'), lessThan(y('DMP-2026-000003')));
    expect(y('DMP-2026-000003'), lessThan(y('DMP-2026-000001')));
    expect(counts.last, 3);
  });

  testWidgets('page : rejet motivé d\'une demande précise, liste et compteur relus', (tester) async {
    final b = _twoPending()..rows.add(legacySubmitted());
    final counts = <int>[];
    await openPage(tester, b, counts);

    await tester.tap(find.byKey(const ValueKey('pending-reject-DMP-2026-000003')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('reject-comment')), 'Lot à préciser');
    await tester.tap(find.byKey(const ValueKey('confirm-reject')));
    await tester.pumpAndSettle();

    expect(b.decisions.single, ('b', 'REJECTED', 'Lot à préciser'));
    expect(find.text('Demande DMP-2026-000003 rejetée.'), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-card-DMP-2026-000003')), findsNothing);
    expect(_count(tester), '2 en attente');
    expect(counts.last, 2);
  });

  testWidgets('page vide : message clair, actualisation depuis le backend', (tester) async {
    final b = _Backend();
    await openPage(tester, b, <int>[]);
    expect(find.text('Aucune demande à valider pour le moment.'), findsOneWidget);
    final before = b.listCalls;
    b.rows.add(_req('a', 'DMP-2026-000002', created: '2026-10-30T07:00:00.000Z'));
    await tester.tap(find.byKey(const ValueKey('pending-refresh')));
    await tester.pumpAndSettle();
    expect(b.listCalls, before + 1);
    expect(find.byKey(const ValueKey('pending-card-DMP-2026-000002')), findsOneWidget);
  });
}
