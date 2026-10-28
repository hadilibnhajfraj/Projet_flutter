// Pages machine/poste PROMESH et PROBAR — système de design commun (VM).
//
// Les deux écrans (PosteDashboardScreen, ProbarPosteDashboardScreen)
// dépendent du routeur complet (dart:html) : ils sont vérifiés par
// l'analyseur ; leur PRÉSENTATION — en-tête, barre d'actions, alertes, KPI,
// graphiques, fiches récentes — est vérifiée ici, assemblée dans le même
// ordre et avec les mêmes données que les écrans, à plusieurs largeurs, en
// français et en anglais.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/view/poste_dashboard_layout.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

class _Calls {
  final taps = <String>[];
}

List<PosteFicheRow> _rows(String unit) => [
      PosteFicheRow(id: 'a', numero: 'PROMESH-2026-001708', date: '2026-09-23', poste: 'matin', machine: '1', producer: 'production_1@cbi-tunisia.com', quantity: 1250, unit: unit, isDraft: false, approvalStatus: 'REJECTED', rejectionComment: 'Épaisseur hors tolérance', rejectedAt: DateTime.utc(2026, 10, 27, 10, 17)),
      PosteFicheRow(id: 'b', numero: 'PROMESH-2026-001707', date: '2026-09-22', poste: 'matin', machine: '1', producer: 'production_1@cbi-tunisia.com', quantity: 900, unit: unit, isDraft: false, approvalStatus: 'APPROVED'),
      PosteFicheRow(id: 'c', numero: 'PROMESH-2026-001706', date: '2026-09-21', poste: 'nuit', machine: '1', producer: 'production_2@cbi-tunisia.com', quantity: 600, unit: unit, isDraft: false, approvalStatus: 'PENDING', nonConforme: true),
      PosteFicheRow(id: 'd', numero: 'PROMESH-2026-001705', date: '2026-09-20', poste: 'matin', machine: '1', operateur: 'Ali', quantity: null, unit: unit, isDraft: true),
      PosteFicheRow(id: 'e', numero: 'PROMESH-2026-000953', date: '2026-08-20', poste: 'matin', machine: '1', producer: 'production_1@cbi-tunisia.com', quantity: 33008, unit: unit, isDraft: false),
    ];

/// Page assemblée comme les écrans (même ordre, mêmes composants).
Widget _page(_Calls calls, {required String line, List<PosteAlert>? alerts, List<PosteFicheRow>? rows, bool loading = false, String? error, bool creating = false, Widget? chart}) {
  final color = line == 'PROBAR' ? kProbarColor : kPromeshColor;
  final unit = line == 'PROBAR' ? 'ml' : 'm²';
  return Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PosteHeader(lineLabel: line, color: color, machine: '1', poste: 'matin', now: DateTime(2026, 10, 28, 9, 5), operatorName: 'Production 1', onBack: () => calls.taps.add('back')),
        PosteActionBar(
          color: color,
          primary: PosteAction('new', label: creating ? 'Préparation…' : 'Nouvelle fiche', icon: Icons.add_rounded, busy: creating, onTap: creating ? null : () => calls.taps.add('new')),
          secondary: [
            PosteAction('list', label: 'Fiches du poste', icon: Icons.list_alt_rounded, onTap: () => calls.taps.add('list')),
            PosteAction('history', label: 'Historique', icon: Icons.history_rounded, onTap: () => calls.taps.add('history')),
            PosteAction('refresh', label: 'Actualiser', icon: Icons.refresh_rounded, onTap: () => calls.taps.add('refresh')),
          ],
        ),
        PosteAlertsPanel(
          alerts: alerts ??
              [
                PosteAlert('pending', severity: PosteSeverity.warning, icon: Icons.hourglass_top_rounded, title: 'Fiches en attente de validation', count: 2, description: 'À accepter ou refuser.', actionLabel: 'Voir', onTap: () => calls.taps.add('alert-pending')),
                PosteAlert('rejected', severity: PosteSeverity.critical, icon: Icons.block_rounded, title: 'Fiches refusées', count: 1, description: 'Refusées par le responsable : motif consultable, correction et nouvelle soumission requises.', actionLabel: 'Voir', onTap: () => calls.taps.add('alert-rejected')),
                PosteAlert('missing', severity: PosteSeverity.critical, icon: Icons.event_busy_rounded, title: 'Fiches précédentes manquantes', count: 23, description: 'Dates sans fiche : une autorisation peut être nécessaire pour régulariser.', actionLabel: 'Voir les dates', onTap: () => calls.taps.add('alert-missing')),
              ],
        ),
        PosteKpiGrid(loading: loading, items: [
          PosteKpi('created', icon: Icons.description_outlined, label: 'Fiches créées', value: '5', color: color),
          PosteKpi('validated', icon: Icons.check_circle_outline_rounded, label: 'Fiches validées', value: '4', color: kPosteAccepted),
          PosteKpi('drafts', icon: Icons.edit_note_rounded, label: 'En brouillon', value: '1', color: kPosteNeutral),
          PosteKpi('production', icon: Icons.straighten_rounded, label: 'Production totale', value: '35 758 $unit', color: color),
          PosteKpi('nonconformities', icon: Icons.warning_amber_rounded, label: 'Non-conformités', value: '1', color: kPosteRejected),
          if (line == 'PROMESH') PosteKpi('operators', icon: Icons.engineering_outlined, label: 'Opérateurs présents', value: '3', color: kPersonnelColor),
        ]),
        PosteChartsRow(panels: [
          PosteChartPanel(panelKey: 'hourly', title: 'Production par heure', subtitle: unit, icon: Icons.bar_chart_outlined, color: color, chart: null, emptyMessage: 'Non disponible : la production PROBAR n\'est pas enregistrée par heure'),
          PosteChartPanel(panelKey: 'conformity', title: 'Conformité', icon: Icons.pie_chart_outline_rounded, color: kPosteAccepted, chart: chart, emptyMessage: 'Aucun contrôle de conformité sur cette période'),
          PosteChartPanel(
            panelKey: 'trend',
            title: 'Production des 7 derniers jours',
            subtitle: '$unit / jour',
            icon: Icons.show_chart_rounded,
            color: color,
            chart: BarChart(BarChartData(barGroups: [BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 1250, color: color)])])),
          ),
        ]),
        PosteFichesSection(
          color: color,
          total: (rows ?? _rows(unit)).length,
          rows: rows ?? _rows(unit),
          loading: loading,
          error: error,
          onRetry: () => calls.taps.add('retry'),
          onViewAll: () => calls.taps.add('all'),
          actions: (r) => [PosteRowAction(actionKey: 'poste-fiche-view-${r.id}', tooltip: 'Voir', icon: Icons.visibility_outlined, color: Colors.grey, onTap: () => calls.taps.add('view-${r.id}'))],
          filters: PosteFiltersBar(hint: 'Rechercher par opérateur, date, machine…', onSearch: (_) {}, filters: [
            PosteFilterDropdown<String>(label: 'Date', value: 'today', items: const [('today', "Aujourd'hui"), ('week', 'Cette semaine')], onChanged: (_) {}),
          ]),
          pagination: PostePagination(page: 1, totalPages: 3, pageSize: 10, pageSizes: const [10, 20], onPageSize: (_) {}, onNext: () => calls.taps.add('next')),
        ),
      ]),
    ),
  );
}

Widget _app(Widget home, {Locale locale = const Locale('fr', 'FR')}) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

Future<List<String>> _pump(WidgetTester tester, Widget page, {double width = 1440, Locale locale = const Locale('fr', 'FR')}) async {
  rootBundle.evict('assets/lang/${locale.languageCode}.json');
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 3200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(page, locale: locale));
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  // Indicateurs de chargement animés (voulus) : pas de pumpAndSettle.
  await tester.pump(const Duration(milliseconds: 300));
  final e = tester.takeException();
  return [if (e != null) '$e'];
}

Finder _in(String key, Finder f) => find.descendant(of: find.byKey(ValueKey(key)), matching: f);

void main() {
  test('grille KPI : 6 par rangée sur grand écran, 3 sur tablette, 2 puis 1 sur petit écran', () {
    expect([posteKpiColumns(1440, 6), posteKpiColumns(1000, 6), posteKpiColumns(600, 6), posteKpiColumns(340, 6), posteKpiColumns(280, 6)], [6, 3, 2, 2, 1]);
    expect(posteKpiColumns(1440, 5), 5); // PROBAR : 5 cartes, jamais de case vide
  });

  test('libellés de poste : valeur backend « nuit » affichée « Soir »', () {
    expect([pdPosteLabel('matin'), pdPosteLabel('nuit'), pdPosteLabel(null)], ['Matin', 'Soir', '—']);
    expect(pdQuantity(null, 'ml'), '—');
    expect(pdDate('2026-09-23'), '23/09/2026');
  });

  for (final line in ['PROMESH', 'PROBAR']) {
    for (final width in [1440.0, 1000.0, 390.0]) {
      testWidgets('$line ${width.toInt()}px : ordre, en-tête, actions, alertes, KPI, graphiques, fiches — sans débordement', (tester) async {
        final calls = _Calls();
        final errors = await _pump(tester, _page(calls, line: line), width: width);
        expect(errors, isEmpty, reason: errors.join('\n'));

        // En-tête : la machine est l'élément principal ; poste, date, heure, opérateur.
        expect(_in('poste-header', find.text(line)), findsOneWidget);
        expect(_in('poste-header', find.text('Machine 1')), findsOneWidget);
        expect(_in('poste-header', find.text('Poste Matin')), findsOneWidget);
        expect(_in('poste-header', find.text('28/10/2026')), findsOneWidget);
        expect(_in('poste-header', find.text('09:05')), findsOneWidget);
        expect(_in('poste-header', find.text('Production 1')), findsOneWidget);
        final title = tester.widget<Text>(_in('poste-header', find.text('Machine 1')));
        expect(title.style!.fontSize, greaterThan(20));

        // Ordre : en-tête → actions → alertes → KPI → graphiques → fiches.
        double y(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
        final order = ['poste-header', 'poste-action-new', 'poste-alerts', 'poste-kpi-created', 'poste-chart-trend', 'poste-fiches'];
        for (var i = 1; i < order.length; i++) {
          expect(y(order[i - 1]) < y(order[i]), isTrue, reason: '${order[i - 1]} avant ${order[i]}');
        }

        // Actions : principale + secondaires alignées.
        for (final k in ['new', 'list', 'history', 'refresh']) {
          await tester.ensureVisible(find.byKey(ValueKey('poste-action-$k')));
          await tester.tap(find.byKey(ValueKey('poste-action-$k')));
        }
        expect(calls.taps, ['new', 'list', 'history', 'refresh']);

        // Alertes triées : critiques (refus, manquantes) avant les attentes.
        expect(y('poste-alert-rejected') <= y('poste-alert-pending'), isTrue);
        expect(y('poste-alert-missing') <= y('poste-alert-pending'), isTrue);
        expect(_in('poste-alert-missing', find.text('23')), findsOneWidget);

        // KPI compacts : hauteur limitée, unité de la ligne (ml pour PROBAR).
        expect(tester.getSize(find.byKey(const ValueKey('poste-kpi-created'))).height, lessThan(80));
        expect(find.text(line == 'PROBAR' ? '35 758 ml' : '35 758 m²'), findsOneWidget);
        if (line == 'PROBAR') expect(find.textContaining('m²'), findsNothing);
        expect(find.byKey(const ValueKey('poste-kpi-operators')), line == 'PROMESH' ? findsOneWidget : findsNothing);

        // Graphiques : aucune donnée → état vide, jamais de courbe inventée.
        expect(find.byKey(const ValueKey('poste-chart-hourly-empty')), findsOneWidget);
        expect(find.byKey(const ValueKey('poste-chart-conformity-empty')), findsOneWidget);
        expect(find.byType(BarChart), findsOneWidget);

        // Fiches : statuts cohérents, motif du refus, actions.
        expect(_in('poste-fiche-a', find.text('Refusée')), findsOneWidget);
        expect(_in('poste-fiche-b', find.text('Acceptée')), findsOneWidget);
        expect(_in('poste-fiche-c', find.text('En attente')), findsOneWidget);
        expect(_in('poste-fiche-c', find.text('Non conforme')), findsOneWidget);
        expect(_in('poste-fiche-d', find.text('Brouillon')), findsOneWidget);
        expect(_in('poste-fiche-e', find.text('Terminée')), findsOneWidget);
        expect(find.byKey(const ValueKey('poste-fiche-reason-a')), findsOneWidget);
        expect(_in('poste-fiche-reason-a', find.textContaining('Épaisseur hors tolérance')), findsOneWidget);
        expect(find.byKey(const ValueKey('poste-fiche-reason-b')), findsNothing);
        if (width >= 1000) {
          for (final c in ['NUMÉRO DE FICHE', 'DATE DE PRODUCTION', 'POSTE', 'MACHINE', 'PRODUCTEUR', 'QUANTITÉ PRODUITE', 'STATUT', 'ACTIONS']) {
            expect(find.text(c), findsOneWidget, reason: c);
          }
          expect(_in('poste-fiche-e', find.text('production_1')), findsOneWidget);
          expect(_in('poste-fiche-c', find.text('Soir')), findsOneWidget);
        }
        await tester.ensureVisible(find.byKey(const ValueKey('poste-fiche-view-a')));
        await tester.tap(find.byKey(const ValueKey('poste-fiche-view-a')));
        await tester.ensureVisible(find.byKey(const ValueKey('poste-view-all')));
        await tester.tap(find.byKey(const ValueKey('poste-view-all')));
        await tester.ensureVisible(find.byKey(const ValueKey('poste-page-next')));
        await tester.tap(find.byKey(const ValueKey('poste-page-next')));
        expect(calls.taps.sublist(4), ['view-a', 'all', 'next']);
        expect(errors, isEmpty, reason: errors.join('\n'));
      });
    }
  }

  testWidgets('aucune alerte : message positif ; création en cours : bouton désactivé', (tester) async {
    final calls = _Calls();
    await _pump(tester, _page(calls, line: 'PROMESH', alerts: const [], creating: true));
    expect(find.byKey(const ValueKey('poste-alerts-none')), findsOneWidget);
    expect(find.text('Aucun problème nécessitant une intervention'), findsOneWidget);
    expect(find.text('Préparation…'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('poste-action-new')));
    expect(calls.taps, isEmpty);
  });

  testWidgets('chargement, erreur API (avec réessai) et liste vide', (tester) async {
    final calls = _Calls();
    await _pump(tester, _page(calls, line: 'PROBAR', loading: true));
    expect(find.byKey(const ValueKey('poste-kpi-created')), findsNothing); // squelettes, aucun chiffre
    await _pump(tester, _page(calls, line: 'PROBAR', error: 'Erreur 500'));
    expect(_in('poste-fiches-error', find.textContaining('Erreur 500')), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(calls.taps, ['retry']);
    await _pump(tester, _page(calls, line: 'PROBAR', rows: const []));
    expect(find.byKey(const ValueKey('poste-fiches-empty')), findsOneWidget);
  });

  testWidgets('English: no French left on the machine page', (tester) async {
    final calls = _Calls();
    final errors = await _pump(tester, _page(calls, line: 'PROBAR'), locale: const Locale('en', 'US'));
    expect(errors, isEmpty);
    for (final t in ['New Record', 'Shift sheets', 'History', 'Refresh', 'Alerts and required actions', 'Refused sheets', 'Missing previous sheets', 'Sheets created', 'Total production', 'Production per hour', 'Recent sheets (5)', 'View all sheets', 'Rejected', 'Accepted', 'Pending', 'Draft', 'Completed', 'Shift Morning', 'RECORD NUMBER']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    for (final fr in ['Nouvelle fiche', 'Fiches récentes (5)', 'Refusée', 'Brouillon', 'Production totale']) {
      expect(find.text(fr), findsNothing, reason: fr);
    }
  });
}
