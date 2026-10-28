// Détail d'une fiche de production PROMESH / PROBAR — système de design
// commun (VM).
//
// Les écrans (PorPromeshDetailScreen, ProbarDetailScreen) dépendent du
// routeur complet (dart:html) : ils sont vérifiés par l'analyseur ; leur
// PRÉSENTATION est vérifiée ici, assemblée dans le même ordre et avec le même
// type de données que les écrans, à plusieurs largeurs, en français et en
// anglais.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/view/detail/fiche_detail_layout.dart';
import 'package:dash_master_toolkit/forms/industrial/view/poste_dashboard_layout.dart' show pdT;
import 'package:dash_master_toolkit/localization/app_localizations.dart';

class _Calls {
  final taps = <String>[];
}

Widget _page(_Calls calls, {required String line, bool locked = false, bool emptyQuality = false, String? approval = 'REJECTED', bool draft = false}) {
  final promesh = line == 'PROMESH';
  final color = promesh ? kPromeshColor : kProbarColor;
  final unit = promesh ? 'm²' : 'ml';
  final status = ficheStatus(isDraft: draft, approvalStatus: approval);
  void tap(String k) => calls.taps.add(k);
  return Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FicheDetailHeader(
          title: 'Fiche de production $line',
          color: color,
          badges: [
            if (locked) const FicheBadge(label: 'Verrouillée', color: kFicheLocked, icon: Icons.lock_rounded),
          ],
          onBack: () => tap('back'),
          actions: [
            FicheAction('edit', label: 'Modifier', icon: Icons.edit_outlined, color: Colors.blue, onTap: locked ? null : () => tap('edit'), disabledReason: 'Fiche verrouillée'),
            FicheAction('print', label: 'Imprimer', icon: Icons.print_outlined, color: Colors.black, onTap: () => tap('print')),
            FicheAction('pdf', label: 'Export PDF', icon: Icons.picture_as_pdf_outlined, color: Colors.purple, onTap: () => tap('pdf')),
            FicheAction('excel', label: 'Export Excel', icon: Icons.grid_on_rounded, color: Colors.green, onTap: () => tap('excel')),
            FicheAction('delete', label: 'Supprimer', icon: Icons.delete_outline_rounded, color: Colors.red, onTap: locked ? null : () => tap('delete'), disabledReason: 'Fiche verrouillée'),
          ],
        ),
        if (locked) const FicheLockBanner('Cette fiche est verrouillée : sa saisie est terminée, elle ne peut plus être modifiée ni supprimée.'),
        // Comme les écrans : numéro, statut, date, heure, machine, poste.
        Builder(builder: (context) => FicheSummaryBar(items: [
          FicheSummaryItem(Icons.confirmation_number_outlined, 'Numéro de fiche', promesh ? 'PROMESH-2026-001708' : 'PROBAR-2026-A01847', color: color),
          FicheSummaryItem(status.icon, 'Statut', pdT(context, status.label), color: status.color),
          const FicheSummaryItem(Icons.event_outlined, 'Date de production', '23/09/2026'),
          const FicheSummaryItem(Icons.schedule_outlined, 'Heure de production', '06:00 – 14:00'),
          const FicheSummaryItem(Icons.precision_manufacturing_outlined, 'Machine', 'Machine 1'),
          const FicheSummaryItem(Icons.wb_sunny_outlined, 'Poste', 'Matin'),
        ])),
        FicheRow(children: [
          FichePanel(
            panelKey: 'info',
            icon: Icons.info_outline_rounded,
            title: 'Informations générales',
            color: color,
            child: FicheInfoGrid(entries: [
              ('Numéro de fiche', promesh ? 'PROMESH-2026-001708' : 'PROBAR-2026-A01847'),
              ('Statut', status.label),
              ('Machine', 'Machine 1'),
              ('Poste', 'Matin'),
              ('Date de production', '23/09/2026'),
              ('Heure de production', '06:00 – 14:00'),
              ('Opérateur', 'Ali Ben Salah'),
              ('Date de création', '23/09/2026 06:10'),
              ('Dernière modification', '23/09/2026 13:55'),
              ('Validateur', 'responsable_production@cbi-tunisia.com'),
              ('Date de décision', '27/10/2026 11:17'),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FicheProductionPanel(color: color, label: 'Quantité produite', quantity: 1250, unit: unit, extras: promesh ? const [('Diamètre', '8 mm'), ('Taille de maille', '50 x 50 mm')] : const []),
            const SizedBox(height: 12),
            emptyQuality ? const FicheQualityPanel() : const FicheQualityPanel(globalConforme: true, conformes: 3, aVerifier: 1, nonConformes: 1),
          ]),
        ]),
        FicheDetailTabs(color: color, tabs: [
          FicheTab('parameters', label: 'Paramètres de production', icon: Icons.tune_rounded, builder: () => const FicheValueGrid(values: [('Air', '≥ 6 bar', Colors.green), ('Niveau Bain Eau', 'Bien', Colors.green), ('État Pistons', 'Sale', Colors.orange)])),
          FicheTab('quality', label: 'Contrôle qualité', icon: Icons.verified_user_outlined, count: 3, builder: () => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const FicheNote(label: 'Description', text: 'Épaisseur hors tolérance', color: Colors.red),
                FicheTable(
                  tableKey: 'measures',
                  columns: const [('Heure', 2), ('N° Plaque', 3), ('Maille', 2), ('Longueur', 2), ('Largeur', 2), ('Statut', 3)],
                  rows: [
                    for (final (h, st) in [('08:00', 'C'), ('11:00', 'NC'), ('14:00', null)])
                      [FicheTable.text(h, strong: true), FicheTable.text('P-12'), FicheTable.text('50x50'), FicheTable.text('2000'), FicheTable.text('1000'), ficheMeasureStatus(st)],
                  ],
                ),
              ])),
          FicheTab('materials', label: 'Matières premières', icon: Icons.inventory_2_outlined, count: promesh ? 2 : null, builder: () => FicheTable(
                tableKey: 'materials',
                columns: const [('Désignation article', 5), ('Métrage', 2), ('Observation', 5)],
                rows: promesh
                    ? [
                        [FicheTable.text('Fil galvanisé 2,5 mm', strong: true), FicheTable.text('120'), FicheTable.text('—')],
                        [FicheTable.text('Fil galvanisé 3 mm', strong: true), FicheTable.text('80'), FicheTable.text('Bobine entamée')],
                      ]
                    : const [],
                emptyMessage: 'La fiche PROBAR n\'enregistre pas de consommation de matières premières',
              )),
          FicheTab('documents', label: 'Documents', icon: Icons.attach_file_rounded, builder: () => const FicheEmpty('Aucun document joint')),
          FicheTab('history', label: 'Historique', icon: Icons.history_rounded, builder: () => const FicheHistoryTimeline(entries: [
                FicheHistoryEntry(icon: Icons.add_circle_outline_rounded, color: Colors.blue, title: 'Fiche créée', detail: 'production_1@cbi-tunisia.com', when: '23/09/2026 06:10'),
                FicheHistoryEntry(icon: Icons.block_rounded, color: Colors.red, title: 'Validation : Refusée', detail: 'responsable_production@cbi-tunisia.com · « Épaisseur hors tolérance »', when: '27/10/2026 11:17'),
              ])),
        ]),
      ]),
    ),
  );
}

Widget _app(Widget home, Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: home,
    );

Future<void> _pump(WidgetTester tester, Widget page, {double width = 1440, Locale locale = const Locale('fr', 'FR')}) async {
  rootBundle.evict('assets/lang/${locale.languageCode}.json');
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 3000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(page, locale));
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Finder _in(String key, Finder f) => find.descendant(of: find.byKey(ValueKey(key)), matching: f);

void main() {
  test('statuts réels → badge unique : brouillon, soumise, en attente, acceptée, refusée', () {
    expect(ficheStatus(isDraft: true, approvalStatus: 'APPROVED').label, 'Brouillon');
    expect(ficheStatus(isDraft: false).label, 'Soumise');
    expect([for (final s in ['PENDING', 'APPROVED', 'REJECTED']) ficheStatus(isDraft: false, approvalStatus: s).label], ['En attente', 'Acceptée', 'Refusée']);
    expect(fdHours('06:00', null), '06:00');
    expect(fdHours(null, null), '—');
    expect(fdValue('  '), '—');
  });

  for (final line in ['PROMESH', 'PROBAR']) {
    for (final width in [1440.0, 800.0, 390.0]) {
      testWidgets('$line ${width.toInt()}px : en-tête, résumé, panneaux, onglets — sans débordement', (tester) async {
        final calls = _Calls();
        await _pump(tester, _page(calls, line: line), width: width);
        expect(tester.takeException(), isNull);

        expect(_in('fiche-header', find.text('Fiche de production $line')), findsOneWidget);
        // Résumé horizontal : numéro, statut, date, heure, machine, poste —
        // non répétés dans l'en-tête.
        for (final t in [line == 'PROMESH' ? 'PROMESH-2026-001708' : 'PROBAR-2026-A01847', 'Refusée', '06:00 – 14:00', 'Matin']) {
          expect(_in('fiche-summary', find.text(t)), findsOneWidget, reason: t);
          expect(_in('fiche-header', find.text(t)), findsNothing, reason: t);
        }
        // Retour aligné avec les actions (même hauteur ; même ligne sur grand écran).
        final back = tester.getRect(find.byKey(const ValueKey('fiche-back')));
        expect(back.height, tester.getRect(find.byKey(const ValueKey('fiche-action-print'))).height);
        await tester.tap(find.byKey(const ValueKey('fiche-back')));
        expect(calls.taps.removeLast(), 'back');
        // Grand écran : actions à droite, sur la ligne du titre ; sinon dessous.
        final title = tester.getRect(find.byKey(const ValueKey('fiche-title')));
        final print = tester.getRect(find.byKey(const ValueKey('fiche-action-print')));
        if (width >= 1000) {
          expect(print.left > title.right, isTrue);
          expect(print.top < title.bottom + 10, isTrue);
        } else {
          expect(print.top > title.bottom, isTrue);
        }
        for (final k in ['edit', 'print', 'pdf', 'excel', 'delete']) {
          await tester.ensureVisible(find.byKey(ValueKey('fiche-action-$k')));
          await tester.tap(find.byKey(ValueKey('fiche-action-$k')));
        }
        expect(calls.taps, ['edit', 'print', 'pdf', 'excel', 'delete']);

        // Production : quantité en grand, unité métier de la ligne.
        expect(find.byKey(const ValueKey('fiche-production-value')), findsOneWidget);
        expect(tester.widget<Text>(find.byKey(const ValueKey('fiche-production-unit'))).data, line == 'PROBAR' ? 'ml' : 'm²');
        if (line == 'PROBAR') expect(find.textContaining('m²'), findsNothing);

        // Informations générales : deux colonnes sur grand écran, une sinon.
        final num = tester.getRect(_in('fiche-panel-info', find.text('Numéro de fiche')));
        final status = tester.getRect(_in('fiche-panel-info', find.text('Statut')));
        if (width >= 1000) {
          expect((num.top - status.top).abs() < 2, isTrue, reason: 'deux colonnes');
        } else if (width < 600) {
          expect(status.top > num.top, isTrue, reason: 'une colonne');
        }

        // Qualité : conforme / à vérifier / non conforme.
        expect(_in('fiche-quality-ok', find.text('3')), findsOneWidget);
        expect(_in('fiche-quality-check', find.text('1')), findsOneWidget);
        expect(_in('fiche-quality-nok', find.text('1')), findsOneWidget);

        // Onglets : chacun affiche son contenu ; table ou état vide explicite.
        expect(find.byKey(const ValueKey('fiche-tab-content-parameters')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('fiche-tab-quality')));
        await tester.tap(find.byKey(const ValueKey('fiche-tab-quality')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('fiche-table-measures')), findsOneWidget);
        for (final c in ['HEURE', 'N° PLAQUE', 'MAILLE', 'LONGUEUR', 'LARGEUR', 'STATUT']) {
          expect(find.text(c), findsOneWidget, reason: c);
        }
        expect(_in('fiche-tab-content-quality', find.text('À vérifier')), findsOneWidget);
        expect(_in('fiche-tab-content-quality', find.text('Non conforme')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('fiche-tab-materials')));
        await tester.tap(find.byKey(const ValueKey('fiche-tab-materials')));
        await tester.pumpAndSettle();
        if (line == 'PROMESH') {
          expect(find.byKey(const ValueKey('fiche-table-materials')), findsOneWidget);
          expect(find.text('Fil galvanisé 3 mm'), findsOneWidget);
          expect(find.text('DÉSIGNATION ARTICLE'), findsOneWidget);
        } else {
          expect(find.text('La fiche PROBAR n\'enregistre pas de consommation de matières premières'), findsOneWidget);
        }
        await tester.ensureVisible(find.byKey(const ValueKey('fiche-tab-history')));
        await tester.tap(find.byKey(const ValueKey('fiche-tab-history')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('fiche-history')), findsOneWidget);
        expect(find.textContaining('Épaisseur hors tolérance'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('fiche verrouillée : bannière compacte, Modifier et Supprimer désactivés (motif en infobulle)', (tester) async {
    final calls = _Calls();
    await _pump(tester, _page(calls, line: 'PROMESH', locked: true, approval: null));
    expect(find.byKey(const ValueKey('fiche-locked')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('fiche-locked'))).height, lessThan(60));
    expect(_in('fiche-header', find.text('Verrouillée')), findsOneWidget);
    expect(_in('fiche-summary', find.text('Soumise')), findsOneWidget);
    for (final k in ['edit', 'delete']) {
      await tester.tap(find.byKey(ValueKey('fiche-action-$k')), warnIfMissed: false);
    }
    expect(calls.taps, isEmpty);
    expect(find.byWidgetPredicate((w) => w is Tooltip && w.message == 'Fiche verrouillée'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('fiche-action-pdf')));
    expect(calls.taps, ['pdf']); // les exports restent disponibles
  });

  testWidgets('aucune donnée qualité : état vide explicite, aucun faux résultat', (tester) async {
    await _pump(tester, _page(_Calls(), line: 'PROBAR', emptyQuality: true, draft: true));
    expect(find.byKey(const ValueKey('fiche-quality-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('fiche-quality-ok')), findsNothing);
    expect(_in('fiche-summary', find.text('Brouillon')), findsOneWidget);
  });

  testWidgets('English: no French left on the detail page', (tester) async {
    await _pump(tester, _page(_Calls(), line: 'PROBAR'), locale: const Locale('en', 'US'));
    expect(tester.takeException(), isNull);
    for (final t in ['PROBAR production sheet', 'Edit', 'Print', 'Export PDF', 'Delete', 'General Information', 'Production', 'Quality control', 'Production parameters', 'Raw materials', 'Documents', 'History', 'Rejected', 'To check', 'Quantity produced']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    for (final fr in ['Fiche de production PROBAR', 'Informations générales', 'Matières premières', 'Modifier']) {
      expect(find.text(fr), findsNothing, reason: fr);
    }
  });
}
