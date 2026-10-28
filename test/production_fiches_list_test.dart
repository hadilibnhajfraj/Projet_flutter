// « Fiches de production PROMESH / PROBAR » — écran de liste commun (VM).
//
// VRAI écran + double de l'API GET /production-records/fiches (les filtres,
// compteurs et la portée sont vérifiés côté backend :
// test/productionFiches.test.js). Vérifie que chaque filtre est réellement
// envoyé, combinable et réinitialisable ; que les cartes affichent les
// chiffres du backend ; que validation et verrouillage restent séparés ; que
// Modifier / Supprimer ne sont pas proposés sur une fiche verrouillée.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/production_records/model/production_fiche_list.dart';
import 'package:dash_master_toolkit/production_records/service/production_fiches_service.dart';
import 'package:dash_master_toolkit/production_records/view/production_fiches_list_screen.dart';

Map<String, dynamic> _row(String id, {String? approval, bool locked = true, String? statut = 'validee', double? q = 1250, String? comment, String owner = 'u-1', String? decidedBy}) => {
      'id': 'promesh:$id',
      'type': 'promesh',
      'numero': 'PROMESH-2026-00${id.padLeft(4, '0')}',
      'machine': '1',
      'poste': 'matin',
      'date': '2026-09-23',
      'createdAt': '2026-09-23T06:10:00Z',
      'operateur': 'aziz',
      'quantite': q,
      'quantiteUnite': 'm²',
      'statut': statut,
      'isLocked': locked,
      'approval': approval == null ? null : {'status': approval, 'rejectionComment': comment, 'decidedByEmail': decidedBy, 'decidedAt': decidedBy == null ? null : '2026-10-27T10:17:42.528Z'},
      'createdBy': owner,
      'creator': {'email': owner == 'u-1' ? 'production_1@cbi-tunisia.com' : 'production_2@cbi-tunisia.com'},
    };

class _FakeApi implements ProductionFichesApi {
  final queries = <Map<String, dynamic>>[];
  bool fail = false;
  bool empty = false;

  @override
  Future<FicheListPage> fetch(String type, FicheListFilters filters) async {
    queries.add(filters.toQuery(type));
    if (fail) throw Exception('Erreur 500 : serveur indisponible');
    final rows = empty
        ? <Map<String, dynamic>>[]
        : [
            _row('1708', approval: 'REJECTED', locked: false, comment: 'Épaisseur hors tolérance', decidedBy: 'responsable_production@cbi-tunisia.com'),
            _row('1707', approval: 'APPROVED', decidedBy: 'responsable_logistique@cbi-tunisia.com'),
            _row('1706', approval: 'PENDING'),
            _row('1705', locked: false, statut: 'brouillon', q: null),
            _row('953'),
            // Refusée, mais fiche d'un AUTRE producteur : ni correction ni suppression.
            _row('1709', approval: 'REJECTED', locked: false, comment: 'Maille hors tolérance', owner: 'u-2', decidedBy: 'responsable_logistique@cbi-tunisia.com'),
            // Valeurs inattendues du backend : jamais « Validée ».
            _row('1710', approval: 'ARCHIVED'),
            _row('1711', statut: 'SUBMITTED'),
          ];
    return FicheListPage.fromJson({
      'data': rows,
      'pagination': {'page': filters.page, 'limit': filters.limit, 'total': empty ? 0 : 45, 'totalPages': empty ? 1 : 3},
      'summary': empty ? {'total': 0, 'approved': 0, 'pending': 0, 'rejected': 0, 'none': 0} : {'total': 45, 'approved': 6, 'pending': 2, 'rejected': 2, 'none': 35},
    });
  }

  Map<String, dynamic> get last => queries.last;
}

class _Calls {
  final taps = <String>[];
}

Widget _screen(_FakeApi api, _Calls calls, {Locale locale = const Locale('fr', 'FR')}) {
  final router = GoRouter(
    initialLocation: '/por-promesh/list',
    routes: [
      GoRoute(
        path: '/por-promesh/list',
        builder: (_, __) => ProductionFichesListScreen(
          type: 'promesh',
          lineLabel: 'PROMESH',
          color: kPromeshColor,
          unit: 'm²',
          breadcrumbs: const [('Production', '/production/dashboard'), ('PROMESH', '/production/promesh'), ('Fiches de production', null)],
          newFicheRoute: '/production/promesh',
          viewRoute: (r) => '/por-promesh/detail?id=${r.recordId}',
          onReport: (r) async => calls.taps.add('report-${r.recordId}'),
          // Compte de production u-1 (rôle limité à ses propres fiches).
          canWrite: (r) => ficheCanWrite(r, role: 'responsable_logistique_achat', userId: 'u-1'),
          actions: [
            FicheListAction('edit', label: 'Modifier', icon: Icons.edit_outlined, color: Colors.blue, requiresWrite: true, handler: (r) => r.isLocked ? null : (r) async => calls.taps.add('edit-${r.recordId}')),
            FicheListAction('delete', label: 'Supprimer', icon: Icons.delete_outline, color: Colors.red, reloadAfter: true, requiresWrite: true, handler: (r) => r.isLocked ? null : (r) async => calls.taps.add('delete-${r.recordId}')),
          ],
          api: api,
          realtime: false,
        ),
      ),
      GoRoute(path: '/:rest(.*)', builder: (_, state) => Scaffold(body: Text('ROUTE ${state.uri}'))),
    ],
  );
  return MaterialApp.router(
    locale: locale,
    supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
    localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    routerConfig: router,
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

Future<void> _open(WidgetTester tester, _FakeApi api, _Calls calls, {double width = 1440, Locale locale = const Locale('fr', 'FR')}) async {
  rootBundle.evict('assets/lang/${locale.languageCode}.json');
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 2600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_screen(api, calls, locale: locale));
  await _settle(tester);
}

Future<void> _choose(WidgetTester tester, String field, String option) async {
  await tester.tap(find.byKey(ValueKey('fiches-filter-$field')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(option).last);
  await tester.pumpAndSettle();
  await _settle(tester);
}

Finder _in(String key, Finder f) => find.descendant(of: find.byKey(ValueKey(key)), matching: f);

void main() {
  // Stockage local initialisé avant le premier rendu (fournisseur de langue).
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('fiches_list_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    await GetStorage.init();
  });

  test('modèle : taux de validation = validées / soumises ; aucun taux sans fiche soumise', () {
    expect(const FicheListSummary(total: 45, approved: 6, pending: 2, rejected: 2, none: 35).validationRate, 60);
    expect(const FicheListSummary(total: 3, none: 3).validationRate, isNull);
    expect(const FicheListFilters(period: 'custom').toQuery('probar'), {'type': 'probar', 'period': 'custom', 'sort': 'date_desc', 'page': 1, 'limit': 20});
    final r = FicheListRow.fromJson(_row('1705', statut: 'brouillon', q: null));
    expect([r.quantite, r.isDraft, r.recordId], [null, true, '1705']); // quantité absente ≠ 0
  });

  test('mapping explicite des statuts : chaque valeur backend, valeurs inattendues jamais « Validée »', () {
    String label(Map<String, dynamic> j) => ficheListValidation(FicheListRow.fromJson(j)).label;
    expect(label(_row('a', approval: 'APPROVED')), 'Validée');
    expect(label(_row('b', approval: 'PENDING')), 'En attente');
    expect(label(_row('c', approval: 'REJECTED')), 'Refusée');
    expect(label(_row('d', statut: 'brouillon')), 'Brouillon');
    expect(label(_row('e')), 'Hors circuit'); // saisie terminée, hors circuit de validation
    expect(label(_row('f', approval: 'ARCHIVED')), 'Statut inconnu');
    expect(label(_row('g', statut: 'SUBMITTED')), 'Statut inconnu');
    expect(label(_row('h', statut: null)), 'Statut inconnu');
    expect(FicheListRow.fromJson(_row('i', statut: 'SUBMITTED')).isDraft, isFalse);
    // Une fiche refusée n'est jamais « validée », même si sa saisie est terminée.
    expect(label(_row('j', approval: 'REJECTED', statut: 'validee')), 'Refusée');
  });

  test('droits d\'écriture = règle du backend (assertOwnership)', () {
    final mine = FicheListRow.fromJson(_row('1', owner: 'u-1'));
    final other = FicheListRow.fromJson(_row('2', owner: 'u-2'));
    expect(ficheCanWrite(mine, role: 'responsable_logistique_achat', userId: 'u-1'), isTrue);
    expect(ficheCanWrite(other, role: 'responsable_logistique_achat', userId: 'u-1'), isFalse);
    expect(ficheCanWrite(other, role: 'superadmin', userId: 'u-1'), isTrue);
    expect(ficheCanWrite(mine, role: 'responsable_logistique_achat', userId: null), isFalse);
  });

  for (final width in [1440.0, 820.0, 390.0]) {
    testWidgets('${width.toInt()}px : en-tête, statistiques, filtres, liste, pagination — sans débordement', (tester) async {
      final api = _FakeApi();
      final calls = _Calls();
      await _open(tester, api, calls, width: width);
      expect(tester.takeException(), isNull);
      expect(api.queries, hasLength(1));
      expect(api.last, {'type': 'promesh', 'sort': 'date_desc', 'page': 1, 'limit': 20});

      expect(find.text('Fiches de production PROMESH'), findsOneWidget);
      expect(_in('fiches-breadcrumbs', find.text('PROMESH')), findsOneWidget);
      for (final (k, v) in [('total', '45'), ('approved', '6'), ('pending', '2'), ('rejected', '2'), ('rate', '60 %')]) {
        expect(_in('poste-kpi-$k', find.text(v)), findsOneWidget, reason: k);
      }
      expect(_in('poste-kpi-total', find.text('dont 35 hors circuit')), findsOneWidget);
      expect(_in('poste-kpi-rate', find.text('sur 10 fiche(s) soumise(s)')), findsOneWidget);
      expect(find.text('45 fiche(s)'), findsOneWidget);

      // Validation et verrouillage : deux badges indépendants.
      expect(_in('fiche-row-promesh:1708', find.text('Refusée')), findsOneWidget);
      expect(_in('fiche-row-promesh:1708', find.text('Verrouillée')), findsNothing);
      expect(_in('fiche-row-promesh:1707', find.text('Validée')), findsOneWidget);
      expect(_in('fiche-row-promesh:1707', find.text('Verrouillée')), findsOneWidget);
      expect(_in('fiche-row-promesh:1706', find.text('En attente')), findsOneWidget);
      expect(_in('fiche-row-promesh:1705', find.text('Brouillon')), findsOneWidget);
      expect(_in('fiche-row-promesh:953', find.text('Hors circuit')), findsOneWidget);
      expect(_in('fiche-row-promesh:953', find.text('Verrouillée')), findsOneWidget);
      // Valeurs inattendues : « Statut inconnu », jamais « Validée ».
      for (final id in ['1710', '1711']) {
        expect(_in('fiche-row-promesh:$id', find.text('Statut inconnu')), findsOneWidget, reason: id);
        expect(_in('fiche-row-promesh:$id', find.text('Validée')), findsNothing, reason: id);
      }
      // Producteur, validateur, motif du refus : données réelles affichées.
      expect(_in('fiche-row-promesh:1707', find.textContaining('production_1')), findsWidgets);
      expect(_in('fiche-row-promesh:1707', find.textContaining('responsable_logistique')), findsWidgets);
      expect(_in('fiche-rejection-promesh:1708', find.textContaining('Épaisseur hors tolérance')), findsOneWidget);
      expect(_in('fiche-rejection-promesh:1708', find.textContaining('responsable_production')), findsOneWidget);
      // Correction proposée seulement au créateur de la fiche refusée.
      expect(find.byKey(const ValueKey('fiche-correct-promesh:1708')), findsOneWidget);
      expect(find.byKey(const ValueKey('fiche-correct-promesh:1709')), findsNothing);
      expect(find.byKey(const ValueKey('fiche-menu-promesh:1709')), findsNothing);
      expect(find.byKey(const ValueKey('fiche-rejection-promesh:1707')), findsNothing);
      // Quantité avec unité ; absente → « — », jamais 0.
      expect(_in('fiche-row-promesh:1707', find.textContaining('1 250 m²')), findsOneWidget);
      expect(_in('fiche-row-promesh:1705', find.textContaining('0 m²')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filtres réels et combinables : période, machine, poste, statut, tri, recherche ; réinitialiser', (tester) async {
    final api = _FakeApi();
    await _open(tester, api, _Calls());
    await _choose(tester, 'period', 'Ce mois');
    expect(api.last['period'], 'month');
    await _choose(tester, 'machine', 'Machine 2');
    await _choose(tester, 'poste', 'Soir');
    await _choose(tester, 'status', 'Refusée');
    await _choose(tester, 'sort', 'Quantité décroissante');
    await tester.enterText(find.byKey(const ValueKey('fiches-search')), 'PROMESH-2026-001708');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(api.last, {'type': 'promesh', 'period': 'month', 'machine': '2', 'poste': 'nuit', 'approval': 'REJECTED', 'search': 'PROMESH-2026-001708', 'sort': 'quantite_desc', 'page': 1, 'limit': 20});
    // Résultats filtrés comparés au total sans filtre.
    expect(find.text('45 résultat(s) sur 45 fiche(s)'), findsOneWidget);

    final before = api.queries.length;
    await tester.tap(find.byKey(const ValueKey('fiches-reset')));
    await _settle(tester);
    expect(api.queries.length, before + 1);
    expect(api.last, {'type': 'promesh', 'sort': 'quantite_desc', 'page': 1, 'limit': 20});
    expect(tester.widget<TextField>(find.byKey(const ValueKey('fiches-search'))).controller!.text, isEmpty);

    // Période personnalisée : aucun appel avant les deux dates.
    final n = api.queries.length;
    await _choose(tester, 'period', 'Personnalisée');
    expect(api.queries.length, n);
    expect(find.text('Choisissez une date de début et une date de fin.'), findsOneWidget);
    for (final k in ['start', 'end']) {
      await tester.tap(find.byKey(ValueKey('fiches-date-$k')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await _settle(tester);
    }
    expect(api.last['period'], 'custom');
    expect(api.last['startDate'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(api.last['endDate'], api.last['startDate']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagination : page suivante, taille de page (retour page 1)', (tester) async {
    final api = _FakeApi();
    await _open(tester, api, _Calls());
    await tester.ensureVisible(find.byKey(const ValueKey('poste-page-next')));
    await tester.tap(find.byKey(const ValueKey('poste-page-next')));
    await _settle(tester);
    expect(api.last['page'], 2);
    await tester.ensureVisible(find.text('20').last);
    await tester.tap(find.text('20').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('50').last);
    await tester.pumpAndSettle();
    await _settle(tester);
    expect([api.last['limit'], api.last['page']], [50, 1]);
  });

  testWidgets('actions : Voir, Rapport ; Modifier / Supprimer absents si verrouillée ; suppression relit la liste', (tester) async {
    final api = _FakeApi();
    final calls = _Calls();
    await _open(tester, api, calls);
    await tester.tap(find.byKey(const ValueKey('fiche-report-promesh:1707')));
    await _settle(tester);
    expect(calls.taps, ['report-1707']);

    // Fiche verrouillée : aucun menu (ni Modifier ni Supprimer).
    expect(find.byKey(const ValueKey('fiche-menu-promesh:1707')), findsNothing);
    // Fiche refusée (déverrouillée) : Modifier et Supprimer proposés.
    await tester.tap(find.byKey(const ValueKey('fiche-menu-promesh:1708')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fiche-action-edit-promesh:1708')), findsOneWidget);
    final before = api.queries.length;
    await tester.tap(find.byKey(const ValueKey('fiche-action-delete-promesh:1708')));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(calls.taps.last, 'delete-1708');
    expect(api.queries.length, before + 1); // liste relue

    await tester.tap(find.byKey(const ValueKey('fiche-correct-promesh:1708')));
    await _settle(tester);
    expect(calls.taps.last, 'edit-1708');

    await tester.tap(find.byKey(const ValueKey('fiche-view-promesh:1708')));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /por-promesh/detail?id=1708'), findsOneWidget);
  });

  testWidgets('« + Nouvelle fiche » ouvre le parcours de création existant', (tester) async {
    await _open(tester, _FakeApi(), _Calls());
    await tester.tap(find.byKey(const ValueKey('fiches-new')));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /production/promesh'), findsOneWidget);
  });

  testWidgets('erreur API : message compréhensible et réessai ; aucune fiche : état vide', (tester) async {
    final api = _FakeApi()..fail = true;
    await _open(tester, api, _Calls());
    expect(_in('fiches-error', find.textContaining('serveur indisponible')), findsOneWidget);
    expect(_in('poste-kpi-total', find.text('—')), findsOneWidget); // jamais un zéro inventé
    api.fail = false;
    api.empty = true;
    await tester.tap(find.text('Réessayer'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('fiches-empty')), findsOneWidget);
    expect(find.text('Aucune fiche de production pour le moment'), findsOneWidget);
    expect(_in('poste-kpi-rate', find.text('—')), findsOneWidget);
  });

  testWidgets('English: no French left', (tester) async {
    await _open(tester, _FakeApi(), _Calls(), locale: const Locale('en', 'US'));
    for (final t in ['PROMESH production sheets', 'Total records', 'Validated sheets', 'Validation Rate', 'Rejected', 'Validated', 'Locked', 'Reset', '45 sheet(s)']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(find.byTooltip('Report'), findsWidgets); // « Rapport » en icône dans le tableau
    for (final fr in ['Fiches de production PROMESH', 'Taux de validation', 'Verrouillée']) {
      expect(find.text(fr), findsNothing, reason: fr);
    }
  });
}
