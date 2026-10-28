import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/app_shell_route/models/notification.dart';
import 'package:dash_master_toolkit/forms/industrial/model/industrial_record_model.dart';
import 'package:dash_master_toolkit/forms/por_promesh/model/por_promesh_model.dart';
import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_record.dart';
import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_screen.dart';
import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_service.dart';
import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_widgets.dart';

const _p1 = 'production_1@cbi-tunisia.com';
const _p2 = 'production_2@cbi-tunisia.com';
const _validator = 'responsable_logistique@cbi-tunisia.com';

Map<String, dynamic> _promesh() => {
      'ficheType': 'promesh',
      'ficheTypeLabel': 'PROMESH',
      'id': 'p-1',
      'numero': 'PROMESH-2026-001707',
      'status': 'PENDING',
      'version': 1,
      'submittedAt': '2026-10-26T07:05:00.000Z',
      'createdAt': '2026-10-26T07:05:00.000Z',
      'updatedAt': '2026-10-26T09:30:00.123Z',
      'creatorEmail': _p1,
      'machine': '1',
      'poste': 'matin',
      'posteLabel': 'Matin',
      'dateProduction': '2026-10-26',
      'operateur': 'Najeh',
      'saisieLabel': 'Saisie terminée',
      'production': {'label': 'Production', 'value': 320, 'unit': 'm²'},
      'dechets': [
        {'label': 'Total chute barres', 'value': 4},
        {'label': 'Total déchet graine', 'value': 1.5},
      ],
    };

Map<String, dynamic> _probar() => {
      'ficheType': 'probar',
      'ficheTypeLabel': 'PROBAR',
      'id': 'b-1',
      'numero': 'PROBAR-1A2B3C4D',
      'status': 'PENDING',
      'version': 1,
      'submittedAt': '2026-10-26T13:10:00.000Z',
      'createdAt': '2026-10-26T13:10:00.000Z',
      'updatedAt': '2026-10-26T13:40:00.000Z',
      'creatorEmail': _p2,
      'machine': '2',
      'poste': 'nuit',
      'posteLabel': 'Soir',
      'dateProduction': '2026-10-26',
      'saisieLabel': 'Saisie en cours',
      'production': {'label': 'Rendement (production)', 'value': 150, 'unit': null},
      'dechets': [
        {'label': 'Longueur déchet (15:00)', 'value': 0.4},
      ],
    };

/// « Backend » en mémoire : mêmes règles que le serveur (décision réservée
/// au responsable, une seule décision par soumission, motif obligatoire,
/// visibilité limitée aux fiches du créateur).
class _Backend implements FicheApprovalApi {
  _Backend(this.email);
  String email;
  final rows = <Map<String, dynamic>>[];
  final approvals = <(String, int, String?)>[];
  final rejections = <(String, String)>[];
  final resubmits = <String>[];
  Object? decisionError;
  final filtersSeen = <FicheApprovalFilters>[];

  bool get _isValidator => email == _validator;

  @override
  Future<FicheApprovalPermissions> permissions() async => FicheApprovalPermissions(
        canView: true,
        canViewAll: _isValidator,
        canDecide: _isValidator,
        isCreator: !_isValidator,
        creators: _isValidator ? const [_p1, _p2] : [email],
      );

  final summariesSeen = <FicheApprovalFilters?>[];
  Object? loadError;

  @override
  Future<FicheApprovalCounts> summary([FicheApprovalFilters? f]) async {
    summariesSeen.add(f);
    final scope = f == null
        ? const FicheApprovalFilters()
        : FicheApprovalFilters(status: 'all', from: f.from, to: f.to, creator: f.creator, type: f.type, machine: f.machine, poste: f.poste, search: f.search);
    final items = await _filtered(scope);
    int n(String s) => items.where((i) => i.status == s).length;
    return (pending: n('PENDING'), approved: n('APPROVED'), rejected: n('REJECTED'), processed: n('APPROVED') + n('REJECTED'));
  }

  Iterable<Map<String, dynamic>> get _visible => rows.where((r) => _isValidator || r['creatorEmail'] == email);

  @override
  Future<List<FicheApprovalItem>> list(FicheApprovalFilters f) async {
    if (loadError != null) throw loadError!;
    filtersSeen.add(f);
    return _filtered(f);
  }

  Future<List<FicheApprovalItem>> _filtered(FicheApprovalFilters f) async {
    final q = f.toQuery();
    bool keep(Map<String, dynamic> r) =>
        (f.status == 'all' || r['status'] == f.status) &&
        (q['creator'] == null || r['creatorEmail'] == q['creator']) &&
        (q['type'] == null || r['ficheType'] == q['type']) &&
        (q['machine'] == null || r['machine'] == q['machine']) &&
        (q['poste'] == null || r['poste'] == q['poste']) &&
        (q['from'] == null || (r['dateProduction'] as String).compareTo(q['from'] as String) >= 0) &&
        (q['to'] == null || (r['dateProduction'] as String).compareTo(q['to'] as String) <= 0) &&
        (q['search'] == null ||
            [r['numero'], r['creatorEmail'], r['decidedByEmail']].any((v) => '${v ?? ''}'.toLowerCase().contains((q['search'] as String).toLowerCase())));
    return [for (final r in _visible) if (keep(r)) FicheApprovalItem.fromJson(r)];
  }

  @override
  Future<FicheApprovalItem> detail(String ficheType, String id) async {
    final r = _visible.firstWhere((r) => r['id'] == id);
    return FicheApprovalItem.fromJson({
      ...r,
      'details': {
        'sections': [
          {
            'title': 'Dimensions',
            'rows': [
              {'label': 'Diamètre maille 1', 'value': '5'},
            ],
          },
          {
            'title': 'Quantités produites',
            'rows': [
              {'label': 'Production (m²)', 'value': '320'},
            ],
          },
        ],
        'tables': [
          {
            'title': 'Contrôle qualité',
            'columns': ['Heure', 'Maille', 'Statut'],
            'rows': [
              ['08:00', '5', 'OK'],
            ],
          },
        ],
      },
      'history': [
        {'version': 1, 'fromStatus': null, 'toStatus': 'PENDING', 'changedByEmail': r['creatorEmail'], 'createdAt': r['createdAt']},
        if (r['status'] == 'REJECTED')
          {'version': r['version'], 'fromStatus': 'PENDING', 'toStatus': 'REJECTED', 'changedByEmail': _validator, 'comment': r['rejectionComment'], 'createdAt': r['rejectedAt']},
      ],
      'canDecide': _isValidator && r['status'] == 'PENDING',
      'canResubmit': !_isValidator && r['status'] == 'REJECTED',
    });
  }

  Map<String, dynamic> _decide(FicheApprovalItem item) {
    if (!_isValidator) throw Exception('Seul le responsable logistique peut valider ou refuser une fiche de production.');
    if (decisionError != null) throw decisionError!;
    final r = rows.firstWhere((r) => r['id'] == item.id);
    if (r['status'] != 'PENDING') throw Exception('Cette fiche a déjà été traitée.');
    return r;
  }

  @override
  Future<FicheApprovalItem> approve(FicheApprovalItem item) async {
    approvals.add((item.id, item.version, item.updatedAtRaw));
    final r = _decide(item);
    r
      ..['status'] = 'APPROVED'
      ..['decidedAt'] = '2026-10-26T15:00:00.000Z'
      ..['decidedByEmail'] = _validator;
    return FicheApprovalItem.fromJson(r);
  }

  @override
  Future<FicheApprovalItem> reject(FicheApprovalItem item, {required String comment}) async {
    rejections.add((item.id, comment));
    final r = _decide(item);
    if (comment.trim().isEmpty) throw Exception('Le motif du refus est obligatoire.');
    r
      ..['status'] = 'REJECTED'
      ..['decidedAt'] = '2026-10-26T15:05:00.000Z'
      ..['rejectedAt'] = '2026-10-26T15:05:00.000Z'
      ..['decidedByEmail'] = _validator
      ..['rejectionComment'] = comment.trim();
    return FicheApprovalItem.fromJson(r);
  }

  @override
  Future<FicheApprovalItem> resubmit(String ficheType, String id, {String? comment}) async {
    resubmits.add(id);
    final r = rows.firstWhere((r) => r['id'] == id && r['creatorEmail'] == email);
    if (r['status'] != 'REJECTED') throw Exception('Seule une fiche refusée peut être soumise de nouveau.');
    r
      ..['status'] = 'PENDING'
      ..['version'] = (r['version'] as int) + 1
      ..['decidedAt'] = null
      ..['decidedByEmail'] = null;
    return FicheApprovalItem.fromJson(r);
  }
}

Future<void> _open(WidgetTester tester, _Backend api, {ValueChanged<int>? onPending, String? initialFiche, Duration? refresh}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 1100);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    home: FicheApprovalScreen(api: api, onPendingChanged: onPending, initialFiche: initialFiche, refreshInterval: refresh),
  ));
  await tester.pumpAndSettle();
}

Finder _card(String id) => find.byKey(ValueKey('fiche-card-$id'));
Finder _historyReason(String id) => find.byKey(ValueKey('history-reason-$id'));
String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;
String _tabCount(WidgetTester tester, String tab) => _text(tester, '$tab-count');
String _kpi(WidgetTester tester, String kpi) => _text(tester, 'kpi-$kpi-value');

Future<void> _history(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('view-history')));
  await tester.pumpAndSettle();
}

/// Choisit une valeur dans un filtre déroulant de l'historique.
Future<void> _pick(WidgetTester tester, String filterKey, String label) async {
  await tester.tap(find.byKey(ValueKey(filterKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('responsable : les fiches des deux postes sont visibles dès leur création, avec leurs informations', (tester) async {
    final api = _Backend(_validator)..rows.addAll([_promesh(), _probar()]);
    int? pending;
    await _open(tester, api, onPending: (n) => pending = n);

    expect(find.text('Validation des fiches de production'), findsOneWidget);
    expect(_tabCount(tester, 'view-pending'), '2');
    expect(_card('p-1'), findsOneWidget);
    expect(_card('b-1'), findsOneWidget);
    expect(pending, 2);
    String texts(Finder f) => tester.widgetList<Text>(f).map((t) => t.data ?? t.textSpan?.toPlainText() ?? '').join(' | ');
    final p = texts(find.descendant(of: _card('p-1'), matching: find.byType(Text)));
    for (final s in ['PROMESH-2026-001707', _p1, 'Poste Matin', 'Machine 1', 'Production : 320 m²', 'Total chute barres : 4', 'Total déchet graine : 1.5', 'En attente', 'Saisie terminée']) {
      expect(p, contains(s));
    }
    final b = texts(find.descendant(of: _card('b-1'), matching: find.byType(Text)));
    for (final s in ['PROBAR-1A2B3C4D', _p2, 'Poste Soir', 'Rendement (production) : 150', 'Longueur déchet (15:00) : 0.4']) {
      expect(b, contains(s));
    }
    // Jamais « Validée » avant la décision.
    expect(find.descendant(of: _card('p-1'), matching: find.text('Validée')), findsNothing);
  });

  testWidgets('Accepter : confirmation, puis retrait des fiches en attente, conservée dans l\'historique avec validateur et date', (tester) async {
    final api = _Backend(_validator)..rows.addAll([_promesh(), _probar()]);
    final counts = <int>[];
    await _open(tester, api, onPending: counts.add);

    await tester.tap(find.byKey(const ValueKey('fiche-approve-p-1')));
    await tester.pumpAndSettle();
    expect(find.text('Accepter la fiche PROMESH-2026-001707 ?'), findsOneWidget);
    // Annuler : rien n'est envoyé.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(api.approvals, isEmpty);

    await tester.tap(find.byKey(const ValueKey('fiche-approve-p-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-approve')));
    await tester.pumpAndSettle();

    // La décision porte sur la soumission et la version affichées.
    expect(api.approvals.single, ('p-1', 1, '2026-10-26T09:30:00.123Z'));
    expect(find.text('Fiche PROMESH-2026-001707 validée avec succès.'), findsOneWidget);
    // Compteur actualisé, fiche retirée des fiches en attente.
    expect(_tabCount(tester, 'view-pending'), '1');
    expect(counts.last, 1);
    expect(_card('p-1'), findsNothing);
    expect(_card('b-1'), findsOneWidget);

    // Historique : toujours présente, « Validée », validateur et date de décision.
    await _history(tester);
    expect(_historyReason('p-1'), findsOneWidget);
    final table = find.byKey(const ValueKey('history-table'));
    expect(find.descendant(of: table, matching: find.text('Acceptée')), findsOneWidget);
    expect(find.descendant(of: table, matching: find.text(_validator)), findsOneWidget);
    expect(find.descendant(of: table, matching: find.textContaining('26/10/2026')), findsWidgets);
  });

  testWidgets('Refuser sans motif : bloqué ; avec motif : « Refusée », motif et validateur dans l\'historique', (tester) async {
    final api = _Backend(_validator)..rows.add(_probar());
    await _open(tester, api);

    await tester.tap(find.byKey(const ValueKey('fiche-reject-b-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('fiche-reject-comment')), '   ');
    await tester.tap(find.byKey(const ValueKey('confirm-fiche-reject')));
    await tester.pumpAndSettle();
    expect(find.text('Le motif du refus est obligatoire.'), findsOneWidget);
    expect(api.rejections, isEmpty);
    expect(api.rows.single['status'], 'PENDING');

    await tester.enterText(find.byKey(const ValueKey('fiche-reject-comment')), 'Diamètre non conforme');
    await tester.tap(find.byKey(const ValueKey('confirm-fiche-reject')));
    await tester.pumpAndSettle();
    expect(api.rejections.single, ('b-1', 'Diamètre non conforme'));
    expect(find.text('Fiche PROBAR-1A2B3C4D refusée. Le motif a été transmis à son créateur.'), findsOneWidget);
    expect(_card('b-1'), findsNothing);
    expect(_tabCount(tester, 'view-pending'), '0');

    await _history(tester);
    expect(tester.widget<Text>(_historyReason('b-1')).data, 'Diamètre non conforme');
    expect(find.descendant(of: find.byKey(const ValueKey('history-table')), matching: find.text('Refusée')), findsOneWidget);
  });

  testWidgets('échec de l\'API : aucune fausse confirmation, la fiche reste en attente', (tester) async {
    final api = _Backend(_validator)
      ..rows.add(_promesh())
      ..decisionError = Exception('Serveur injoignable. Vérifiez votre connexion puis réessayez.');
    await _open(tester, api);

    await tester.tap(find.byKey(const ValueKey('fiche-approve-p-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-approve')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fiche-banner-success')), findsNothing);
    expect(find.byKey(const ValueKey('fiche-banner-error')), findsOneWidget);
    expect(find.textContaining('La validation a échoué : la fiche reste en attente.'), findsOneWidget);
    expect(find.textContaining('validée avec succès'), findsNothing);
    expect(_card('p-1'), findsOneWidget);
    expect(find.descendant(of: _card('p-1'), matching: find.text('En attente')), findsOneWidget);
    expect(api.rows.single['status'], 'PENDING');
  });

  testWidgets('détail complet : informations, sections, tableaux, historique et actions', (tester) async {
    final api = _Backend(_validator)..rows.add(_promesh());
    await _open(tester, api);

    await tester.tap(find.byKey(const ValueKey('fiche-open-p-1')));
    await tester.pumpAndSettle();
    final dialog = find.byKey(const ValueKey('fiche-detail-dialog'));
    expect(dialog, findsOneWidget);
    for (final s in ['Dimensions', 'Quantités produites', 'Contrôle qualité', 'Historique de validation']) {
      expect(find.descendant(of: dialog, matching: find.text(s)), findsOneWidget);
    }
    expect(find.descendant(of: dialog, matching: find.text('Fiche en attente de validation par le responsable logistique.')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail-approve')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-approve')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-success')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-approve')), findsNothing); // plus de décision possible
    expect(find.descendant(of: dialog, matching: find.text('Fiche validée par le responsable logistique.')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fiche-detail-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fiche-banner-success')), findsOneWidget);
    expect(_card('p-1'), findsNothing);
  });

  testWidgets('historique : filtres période, producteur, type, machine, poste et statut transmis et appliqués', (tester) async {
    final approved = _promesh()
      ..['status'] = 'APPROVED'
      ..['decidedAt'] = '2026-10-26T15:00:00.000Z'
      ..['decidedByEmail'] = _validator;
    final rejected = _probar()
      ..['status'] = 'REJECTED'
      ..['rejectionComment'] = 'Diamètre non conforme'
      ..['rejectedAt'] = '2026-10-26T15:05:00.000Z'
      ..['decidedAt'] = '2026-10-26T15:05:00.000Z'
      ..['decidedByEmail'] = _validator;
    final older = _promesh()
      ..['id'] = 'p-0'
      ..['numero'] = 'PROMESH-2026-001500'
      ..['dateProduction'] = '2026-10-20';
    final api = _Backend(_validator)..rows.addAll([approved, rejected, older]);
    await _open(tester, api);
    await _history(tester);
    expect(_historyReason('p-1'), findsOneWidget);
    expect(_historyReason('b-1'), findsOneWidget);
    expect(_historyReason('p-0'), findsOneWidget); // en attente : présente aussi dans l'historique

    await _pick(tester, 'filter-type', 'PROBAR');
    expect(_historyReason('p-1'), findsNothing);
    expect(_historyReason('b-1'), findsOneWidget);
    await _pick(tester, 'filter-type', 'PROMESH et PROBAR');

    await _pick(tester, 'filter-creator', _p1);
    expect(_historyReason('b-1'), findsNothing);
    expect(_historyReason('p-1'), findsOneWidget);
    await _pick(tester, 'filter-creator', 'Tous les producteurs');

    await _pick(tester, 'filter-poste', 'Soir');
    expect(_historyReason('p-1'), findsNothing);
    expect(_historyReason('b-1'), findsOneWidget);
    await _pick(tester, 'filter-poste', 'Matin et Soir');

    await _pick(tester, 'filter-machine', 'Machine 2');
    expect(_historyReason('b-1'), findsOneWidget);
    expect(_historyReason('p-1'), findsNothing);
    await _pick(tester, 'filter-machine', 'Toutes les machines');

    await _pick(tester, 'filter-status', 'Refusée');
    expect(_historyReason('b-1'), findsOneWidget);
    expect(_historyReason('p-1'), findsNothing);
    await _pick(tester, 'filter-status', 'Tous les statuts');

    // Période : choisie dans le sélecteur de dates → transmise au backend.
    await tester.tap(find.byKey(const ValueKey('filter-period')));
    await tester.pumpAndSettle();
    final picker = find.byType(DateRangePickerDialog);
    expect(picker, findsOneWidget);
    await tester.tap(find.byTooltip('Switch to input').evaluate().isNotEmpty ? find.byTooltip('Switch to input') : find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final fields = find.descendant(of: picker, matching: find.byType(TextField));
    await tester.enterText(fields.at(0), '10/26/2026');
    await tester.enterText(fields.at(1), '10/26/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final last = api.filtersSeen.last.toQuery();
    expect((last['from'], last['to']), ('2026-10-26', '2026-10-26'));
    expect(_historyReason('p-0'), findsNothing); // production du 20/10
    expect(_historyReason('p-1'), findsOneWidget);
  });

  testWidgets('notification : la fiche s\'ouvre directement (lien promesh:<id>)', (tester) async {
    final api = _Backend(_validator)..rows.addAll([_promesh(), _probar()]);
    await _open(tester, api, initialFiche: 'probar:b-1');
    final dialog = find.byKey(const ValueKey('fiche-detail-dialog'));
    expect(dialog, findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('PROBAR — PROBAR-1A2B3C4D')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-approve')), findsOneWidget);
  });

  testWidgets('actualisation automatique : décision prise ailleurs visible sans recharger la page', (tester) async {
    final api = _Backend(_validator)..rows.addAll([_promesh(), _probar()]);
    await _open(tester, api, refresh: const Duration(seconds: 30));
    expect(_tabCount(tester, 'view-pending'), '2');
    api.rows.first['status'] = 'APPROVED'; // décidée depuis une autre session
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(_tabCount(tester, 'view-pending'), '1');
    expect(_card('p-1'), findsNothing);
  });

  testWidgets('production_2 : ses fiches seulement, motif exact du refus, pas de bouton de décision, nouvelle soumission', (tester) async {
    final rejected = _probar()
      ..['status'] = 'REJECTED'
      ..['rejectionComment'] = 'Diamètre non conforme'
      ..['rejectedAt'] = '2026-10-26T15:05:00.000Z'
      ..['decidedAt'] = '2026-10-26T15:05:00.000Z'
      ..['decidedByEmail'] = _validator;
    final api = _Backend(_p2)..rows.addAll([_promesh(), rejected]);
    await _open(tester, api);

    expect(find.text('Validation des fiches de production'), findsOneWidget);
    expect(_tabCount(tester, 'view-pending'), '0');
    await _history(tester);
    expect(_historyReason('p-1'), findsNothing); // fiche de production_1
    expect(tester.widget<Text>(_historyReason('b-1')).data, 'Diamètre non conforme');
    expect(find.byKey(const ValueKey('filter-creator')), findsNothing);
    expect(find.byKey(const ValueKey('fiche-approve-b-1')), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('history-open-b-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-open-b-1')));
    await tester.pumpAndSettle();
    expect(
      find.text('Fiche refusée par le responsable logistique. Motif : Diamètre non conforme. Veuillez corriger la fiche.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('detail-approve')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('fiche-resubmit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-resubmit')));
    await tester.pumpAndSettle();
    expect(api.resubmits, ['b-1']);
    expect(api.rows.last['status'], 'PENDING');
    expect(api.rows.last['version'], 2);
    expect(find.byKey(const ValueKey('fiche-resubmit')), findsNothing);
    // Le motif du refus précédent n'est jamais effacé.
    expect(api.rows.last['rejectionComment'], 'Diamètre non conforme');
  });

  testWidgets('reconnexion : statuts et motifs relus depuis le backend', (tester) async {
    final api = _Backend(_validator)..rows.addAll([_promesh(), _probar()]);
    await _open(tester, api);
    await tester.tap(find.byKey(const ValueKey('fiche-reject-b-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('fiche-reject-comment')), 'Production à recompter');
    await tester.tap(find.byKey(const ValueKey('confirm-fiche-reject')));
    await tester.pumpAndSettle();

    // Nouvelle session production_2 : même « base ».
    api.email = _p2;
    await _open(tester, api);
    await _history(tester);
    expect(tester.widget<Text>(_historyReason('b-1')).data, 'Production à recompter');
    expect(find.descendant(of: find.byKey(const ValueKey('history-table')), matching: find.text('Refusée')), findsOneWidget);
  });

  test('notification : lien direct vers la fiche, absent pour les autres notifications', () {
    final n = NotificationData.fromJson({
      'id': 'n1',
      'title': 'Nouvelle fiche de production à valider',
      'message': 'Fiche : PROMESH-2026-001707',
      'type': 'PRODUCTION_FICHE_PENDING',
      'productionFicheType': 'promesh',
      'productionFicheId': 'p-1',
      'productionFicheVersion': 1,
    });
    expect(n.productionFicheLink, '/production/validation-fiches?fiche=promesh:p-1');
    expect(n.target, ('/production/validation-fiches?fiche=promesh:p-1', 'Voir la fiche'));
    expect(NotificationData.fromJson({'id': 'n2', 'type': 'raw_material_request'}).productionFicheLink, isNull);
    expect(NotificationData.fromJson({'id': 'n3', 'type': 'project'}).target, isNull);
  });

  test('notification de demande de matières premières : lien direct vers la demande', () {
    final n = NotificationData.fromJson({
      'id': 'n4',
      'type': 'raw_material_request',
      'title': 'Demande de matières premières à valider',
      'message': 'DMP-2026-000002 — Producteur : production_1@cbi-tunisia.com',
      'rawMaterialRequestId': 'r-42',
    });
    expect(n.rawMaterialRequestLink, '/production/matieres-premieres?id=r-42');
    expect(n.target, ('/production/matieres-premieres?id=r-42', 'Voir la demande'));
  });


  testWidgets('cartes KPI : compteurs du backend, mêmes filtres que la liste, actualisés après une décision', (tester) async {
    final approved = _promesh()
      ..['id'] = 'p-9'
      ..['numero'] = 'PROMESH-2026-001709'
      ..['status'] = 'APPROVED'
      ..['decidedAt'] = '2026-10-26T15:00:00.000Z'
      ..['decidedByEmail'] = _validator;
    final api = _Backend(_validator)..rows.addAll([_promesh(), _probar(), approved]);
    await _open(tester, api);
    expect(find.text('Suivi et traçabilité des décisions de validation'), findsOneWidget);
    expect((_kpi(tester, 'processed'), _kpi(tester, 'pending'), _kpi(tester, 'approved'), _kpi(tester, 'rejected')), ('1', '2', '1', '0'));

    // Filtre type PROBAR : compteurs restreints de la même façon.
    await _pick(tester, 'filter-type', 'PROBAR');
    expect((_kpi(tester, 'processed'), _kpi(tester, 'pending'), _kpi(tester, 'approved')), ('0', '1', '0'));
    expect(api.summariesSeen.last!.toSummaryQuery(), {'type': 'probar'});
    await _pick(tester, 'filter-type', 'PROMESH et PROBAR');

    // Refus : compteurs et onglet relus depuis le backend.
    await tester.tap(find.byKey(const ValueKey('fiche-reject-b-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('fiche-reject-comment')), 'Diamètre non conforme');
    await tester.tap(find.byKey(const ValueKey('confirm-fiche-reject')));
    await tester.pumpAndSettle();
    expect((_kpi(tester, 'processed'), _kpi(tester, 'pending'), _kpi(tester, 'rejected')), ('2', '1', '1'));
    expect(_tabCount(tester, 'view-pending'), '1');
  });

  testWidgets('historique : badges et règles d\'affichage (en attente : tirets ; acceptée : validateur ; refusée : motif)', (tester) async {
    final approvedAfterRefusal = _promesh()
      ..['status'] = 'APPROVED'
      ..['version'] = 2
      ..['decidedAt'] = '2026-10-26T16:00:00.000Z'
      ..['decidedByEmail'] = _validator
      ..['rejectionComment'] = 'Ancien motif' // refus d'une soumission précédente
      ..['rejectedAt'] = '2026-10-26T12:00:00.000Z';
    final rejected = _probar()
      ..['status'] = 'REJECTED'
      ..['rejectionComment'] = 'Diamètre non conforme'
      ..['rejectedAt'] = '2026-10-26T15:05:00.000Z'
      ..['decidedAt'] = '2026-10-26T15:05:00.000Z'
      ..['decidedByEmail'] = _validator;
    final pending = _promesh()
      ..['id'] = 'p-0'
      ..['numero'] = 'PROMESH-2026-001500';
    final api = _Backend(_validator)..rows.addAll([approvedAfterRefusal, rejected, pending]);
    await _open(tester, api);
    await _history(tester);

    String badge(String id) => tester
        .widget<Text>(find.descendant(of: find.byKey(ValueKey('history-status-$id')), matching: find.byType(Text)))
        .data!;
    expect(badge('p-1'), 'Acceptée');
    expect(badge('b-1'), 'Refusée');
    expect(badge('p-0'), 'En attente');
    expect(find.descendant(of: find.byKey(const ValueKey('history-status-p-1')), matching: find.byIcon(Icons.check_circle_rounded)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('history-status-b-1')), matching: find.byIcon(Icons.cancel_rounded)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('history-status-p-0')), matching: find.byIcon(Icons.schedule_rounded)), findsOneWidget);

    expect((_text(tester, 'history-validator-p-1'), _text(tester, 'history-reason-p-1')), (_validator, '—'));
    expect(_text(tester, 'history-date-p-1'), isNot('—'));
    expect((_text(tester, 'history-validator-b-1'), _text(tester, 'history-reason-b-1')), (_validator, 'Diamètre non conforme'));
    expect((_text(tester, 'history-validator-p-0'), _text(tester, 'history-date-p-0'), _text(tester, 'history-reason-p-0')), ('—', '—', '—'));
    // Aucune action de décision dans l'historique.
    expect(find.byKey(const ValueKey('fiche-approve-p-0')), findsNothing);
    expect(find.byTooltip('Voir le détail'), findsNWidgets(3));
  });

  test('statut inconnu : jamais présenté comme une décision', () {
    expect(kFicheDecisionLabels, {'PENDING': 'En attente', 'APPROVED': 'Acceptée', 'REJECTED': 'Refusée'});
  });

  testWidgets('badge d\'un statut inconnu : « Statut inconnu », icône neutre', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FicheApprovalBadge(status: 'ARCHIVED', decisionWording: true))));
    expect(find.text('Statut inconnu'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    expect(find.text('Acceptée'), findsNothing);
    expect(find.text('Refusée'), findsNothing);
  });

  testWidgets('recherche (producteur, validateur) et « Réinitialiser les filtres »', (tester) async {
    final rejected = _probar()
      ..['status'] = 'REJECTED'
      ..['rejectionComment'] = 'x'
      ..['decidedAt'] = '2026-10-26T15:05:00.000Z'
      ..['decidedByEmail'] = _validator;
    final api = _Backend(_validator)..rows.addAll([_promesh(), rejected]);
    await _open(tester, api);
    await _history(tester);
    final reset = find.byKey(const ValueKey('filter-reset'));
    expect(tester.widget<TextButton>(reset).onPressed, isNull); // aucun filtre

    await tester.enterText(find.byKey(const ValueKey('fiche-search')), 'responsable_logistique');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(_historyReason('b-1'), findsOneWidget);
    expect(_historyReason('p-1'), findsNothing);
    expect(api.filtersSeen.last.toQuery()['search'], 'responsable_logistique');

    await _pick(tester, 'filter-poste', 'Soir');
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(api.filtersSeen.last.toQuery(), {'status': 'all'});
    expect(_historyReason('p-1'), findsOneWidget);
    expect(_historyReason('b-1'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('fiche-search'))).controller!.text, '');
  });

  for (final (label, size) in [('mobile 390×800', const Size(390, 800)), ('tablette 800×900', const Size(800, 900))]) {
    testWidgets('$label : historique en cartes, filtres sur plusieurs lignes, aucun débordement', (tester) async {
      final rejected = _probar()
        ..['status'] = 'REJECTED'
        ..['rejectionComment'] = 'Diamètre non conforme'
        ..['decidedAt'] = '2026-10-26T15:05:00.000Z'
        ..['decidedByEmail'] = _validator;
      final api = _Backend(_validator)..rows.addAll([_promesh(), rejected]);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: FicheApprovalScreen(api: api, refreshInterval: null)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull); // aucun débordement
      expect(find.byKey(const ValueKey('fiche-card-p-1')), findsOneWidget);
      await _history(tester);
      expect(find.byKey(const ValueKey('history-cards')), findsOneWidget);
      expect(find.byKey(const ValueKey('history-table')), findsNothing);
      expect(find.byKey(const ValueKey('history-card-b-1')), findsOneWidget);
      expect(find.textContaining('Motif du refus : Diamètre non conforme', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('erreur de chargement : message et « Réessayer » ; liste vide : message dédié', (tester) async {
    final api = _Backend(_validator)..loadError = Exception('Serveur injoignable.');
    await _open(tester, api);
    expect(find.byKey(const ValueKey('fiche-error')), findsOneWidget);
    expect(find.textContaining('Serveur injoignable.'), findsOneWidget);
    api.loadError = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fiche-empty')), findsOneWidget);
    expect(find.text('Aucune fiche en attente de validation.'), findsOneWidget);
  });

  group('fiches existantes', () {
    test('PROMESH : bloc approval lu ; fiche refusée déverrouillée pour correction ; hors circuit inchangée', () {
      final base = {'id': 'x', 'status': 'VALIDE', 'isLocked': true};
      final legacy = PorPromeshModel.fromJson(base);
      expect(legacy.approval, isNull);
      expect(legacy.isLocked, isTrue);

      final pending = PorPromeshModel.fromJson({...base, 'approval': {'status': 'PENDING', 'version': 1}});
      expect(pending.approval!.isPending, isTrue);
      expect(pending.isLocked, isTrue);

      final rejected = PorPromeshModel.fromJson({
        ...base,
        'approval': {'status': 'REJECTED', 'version': 1, 'rejectionComment': 'Motif', 'rejectedAt': '2026-10-26T15:05:00Z'},
      });
      expect(rejected.isLocked, isFalse);
      expect(rejected.approval!.rejectionComment, 'Motif');
      expect(rejected.status, 'submitted');
    });

    test('PROBAR : bloc approval lu, absent pour les fiches historiques', () {
      expect(IndustrialRecordModel.fromJson({'module': 'probar', 'statut': 'validee'}).approval, isNull);
      final m = IndustrialRecordModel.fromJson({'module': 'probar', 'statut': 'validee', 'approval': {'status': 'APPROVED', 'decidedByEmail': _validator}});
      expect(m.approval!.isApproved, isTrue);
      expect(m.approval!.decidedByEmail, _validator);
    });
  });

  testWidgets('message de refus affiché au créateur, avec la date de décision', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FicheApprovalNotice(
          approval: FicheApproval(
            status: 'REJECTED',
            rejectionComment: 'Diamètre non conforme',
            rejectedAt: DateTime(2026, 10, 26, 16, 5),
            decidedAt: DateTime(2026, 10, 26, 16, 5),
            decidedByEmail: _validator,
          ),
        ),
      ),
    ));
    expect(find.text('Fiche refusée par le responsable logistique. Motif : Diamètre non conforme. Veuillez corriger la fiche.'), findsOneWidget);
    expect(find.text('Décision du 26/10/2026 16:05 — $_validator'), findsOneWidget);
  });
}
