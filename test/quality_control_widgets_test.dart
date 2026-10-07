// Module Contrôle Qualité — design system (VM) : statistiques réelles
// (fixture capturée sur l'API), badges de statut, cartes machines et table
// des contrôles rendues SANS débordement en bureau / tablette / mobile.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/quality_control/model/quality_control_model.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_widgets.dart';

import 'fixtures/quality_control_stats.dart';

QualityStats _stats() => QualityStats.fromJson(jsonDecode(kQualityControlStatsAll) as Map<String, dynamic>);

QualityControlModel _control(int i, String status) => QualityControlModel.fromJson({
      'id': 'id-$i',
      'reference': 'QC-2026-0000$i',
      'productionType': i.isEven ? 'PROMESH' : 'PROBAR',
      'productionRecordRef': 'promesh:x',
      'ficheNumero': 'PROMESH-2026-00088$i',
      'machine': '${i % 4 + 1}',
      'machineLabel': 'Machine ${i % 4 + 1}',
      'posteLabel': 'Matin',
      'controllerEmail': 'controle_qualite@cbi-tunisia.com',
      'status': status,
      'controlDate': '30/09/2026',
      'controlTime': '17:52:10',
      'counts': {'controlled': 12, 'nonConformes': status == 'NON_CONFORME' ? 2 : 0, 'total': 15},
    });

Future<void> _render(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: child))));
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull, reason: 'rendu à ${width}px');
}

void main() {
  group('statistiques (réponse réelle de l\'API)', () {
    test('lignes, machines (1 à 4, aucune inventée), compteurs et dernier contrôle', () {
      final s = _stats();
      expect(s.lines.map((l) => l.type), ['PROMESH', 'PROBAR']);
      for (final l in s.lines) {
        expect(l.machines.map((m) => m.machine), ['1', '2', '3', '4']);
      }
      expect(s.totals.total, s.totals.conforme + s.totals.nonConforme + s.totals.aVerifier);
      final promesh = s.line('promesh')!;
      expect(promesh.counts.total, promesh.machines.fold<int>(0, (n, m) => n + m.counts.total));
      final m1 = promesh.machine('1')!;
      expect(m1.lastControl!.ficheNumero, 'PROMESH-2026-000886');
      expect(m1.lastControl!.controlDate, '30/09/2026');
      expect(s.line('PROBAR')!.machine('3')!.lastControl, isNull);
      expect(s.machines, 8);
    });

    test('taux de conformité : uniquement sur les contrôles qualité validés, null sinon', () {
      expect(const QualityCounts(conforme: 3, nonConforme: 1, aVerifier: 10).conformityRate, 0.75);
      expect(const QualityCounts(aVerifier: 2).conformityRate, isNull);
    });

    test('formats d\'affichage', () {
      expect(qcFormatInt(1248), '1 248');
      expect(qcFormatInt(7), '7');
      expect(qcDateTime('30/09/2026', '17:52:10'), '30/09/2026 17:52');
      // Le compte du rôle est présenté par son nom, jamais par son identifiant technique.
      expect(qcControllerLabel('controle_qualite@cbi-tunisia.com'), 'Contrôle Qualité');
      expect(qcControllerLabel('autre.compte@cbi-tunisia.com'), 'autre.compte');
    });
  });

  group('badges de statut', () {
    testWidgets('libellés et couleurs', (tester) async {
      await _render(
        tester,
        900,
        const Wrap(children: [
          QcStatusBadge('CONFORME'),
          QcStatusBadge('NON_CONFORME'),
          QcStatusBadge('EN_ATTENTE'),
          QcStatusBadge('BROUILLON'),
          QcStatusBadge('VALIDE'),
        ]),
      );
      for (final label in ['Conforme', 'Non conforme', 'À vérifier', 'Brouillon', 'Validé']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(qualityStatusColor('CONFORME'), isNot(qualityStatusColor('NON_CONFORME')));
      expect(productionTypeColor('PROMESH'), isNot(productionTypeColor('PROBAR')));
    });
  });

  for (final width in [1440.0, 820.0, 390.0]) {
    group('rendu ${width.toInt()}px', () {
      testWidgets('cartes machines (stats réelles, chargement, indisponible)', (tester) async {
        final line = _stats().line('PROMESH')!;
        await _render(
          tester,
          width,
          qcGrid(columns: qcColumnsFor(240, max: 4), [
            for (final m in line.machines) QcMachineCard(type: 'PROMESH', machine: m.machine, stats: m, onOpen: () {}),
            QcMachineCard(type: 'PROBAR', machine: '1', onOpen: () {}),
            QcMachineCard(type: 'PROBAR', machine: '2', statsUnavailable: true, onOpen: () {}),
          ]),
        );
        expect(find.text('Machine 1'), findsNWidgets(2));
        expect(find.text('Ouvrir'), findsNWidgets(6));
        expect(find.text('30/09/2026 17:52'), findsOneWidget);
      });

      testWidgets('tuiles machines + KPI', (tester) async {
        final line = _stats().line('PROMESH')!;
        await _render(
          tester,
          width,
          Column(children: [
            qcGrid(columns: qcColumnsFor(190, max: 5), const [
              QcKpiTile(icon: Icons.fact_check_outlined, label: 'Total contrôles qualité', value: '1 248'),
              QcKpiTile(icon: Icons.check_circle_outline, label: 'Conformes', value: null),
              QcKpiTile(icon: Icons.cancel_outlined, label: 'Non conformes', value: '—', caption: 'indisponible'),
            ]),
            qcGrid(columns: qcColumnsFor(250, max: 2), gap: 8, [
              for (final m in line.machines) QcMachineTile(type: 'PROMESH', machine: m.machine, stats: m, onOpen: () {}),
            ]),
          ]),
        );
        expect(find.text('Total contrôles qualité'), findsOneWidget);
      });

      testWidgets('table des contrôles (standard et étendue)', (tester) async {
        final controls = [
          _control(0, 'CONFORME'),
          _control(1, 'NON_CONFORME'),
          _control(2, 'EN_ATTENTE'),
        ];
        await _render(
          tester,
          width,
          Column(children: [
            QcControlsTable(controls: controls),
            QcControlsTable(controls: controls, extended: true),
            const QcControlsTable(controls: [], emptyText: 'Aucun contrôle qualité'),
          ]),
        );
        expect(find.text('QC-2026-00000'), findsNWidgets(2));
        expect(find.text('Contrôle Qualité'), findsNWidgets(6));
        expect(find.text('controle_qualite'), findsNothing);
        expect(find.text('Aucun contrôle qualité'), findsOneWidget);
        expect(find.byTooltip('Voir'), findsNWidgets(6));
      });

      testWidgets('en-tête de page avec fil d\'Ariane et actions', (tester) async {
        await _render(
          tester,
          width,
          QcPageHeader(
            crumbs: const [('Contrôle Qualité', '/quality-control'), ('PROMESH', '/quality-control/promesh'), ('Machine 1', null)],
            title: 'PROMESH / Machine 1',
            subtitle: 'Sélectionnez la production à contrôler puis créez le contrôle.',
            onBack: () {},
            actions: [FilledButton(onPressed: () {}, child: const Text('Nouveau contrôle qualité'))],
          ),
        );
        expect(find.text('MACHINE 1'), findsOneWidget);
        expect(find.text('Nouveau contrôle qualité'), findsOneWidget);
      });
    });
  }
}
