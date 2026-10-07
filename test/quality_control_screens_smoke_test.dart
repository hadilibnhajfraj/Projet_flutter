// Module Contrôle Qualité — écrans complets montés dans le VRAI arbre de
// routes (VM). En test, le réseau est indisponible (HTTP 400 de flutter_test) :
// les écrans doivent rester stables, sans débordement, et n'afficher AUCUN
// chiffre inventé (valeurs neutres "—" + bandeaux d'erreur avec Réessayer).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/quality_control/model/quality_control_model.dart';
import 'package:dash_master_toolkit/quality_control/quality_control_routes.dart';
import 'package:dash_master_toolkit/quality_control/service/quality_control_service.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_comparison_screen.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_history_screen.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_home_screen.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_line_screen.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_machine_screen.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_screen.dart';

import 'fixtures/quality_control_config.dart';
import 'fixtures/quality_control_stats.dart';

GoRouter _router() => GoRouter(
      initialLocation: QcPaths.root,
      routes: [
        buildQualityControlRoute(
          canView: () => true,
          deniedRedirect: '/',
          screens: QcRouteScreens(
            home: () => const QualityControlHomeScreen(),
            history: (q) => QualityControlHistoryScreen(initialQuery: q),
            comparison: () => const QualityControlComparisonScreen(),
            line: (t) => QualityControlLineScreen(type: t),
            machine: (t, m) => QualityControlMachineScreen(type: t, machine: m),
            form: (id) => QualityControlScreen(controlId: id),
            newForm: (t, m) => QualityControlScreen.create(productionType: t, machine: m),
          ),
        ),
      ],
    );

Future<void> _settle(WidgetTester tester) async {
  // Les squelettes sont animés en boucle : pas de pumpAndSettle.
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      await GetStorage.init();
    } catch (_) {}
  });

  for (final width in [1440.0, 820.0, 390.0]) {
    testWidgets('écrans du module à ${width.toInt()}px : stables, aucun chiffre inventé hors ligne', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = _router();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'accueil');
      expect(find.text('Contrôle Qualité'), findsWidgets);
      expect(find.text('Statistiques générales'), findsOneWidget);
      expect(find.textContaining('Statistiques indisponibles'), findsOneWidget);
      expect(find.text('Réessayer'), findsWidgets);

      for (final (path, title) in [
        (QcPaths.promesh, 'PROMESH'),
        (QcPaths.machine('PROMESH', '1'), 'PROMESH / Machine 1'),
        (QcPaths.probar, 'PROBAR'),
        (QcPaths.machine('PROBAR', '1'), 'PROBAR / Machine 1'),
        (QcPaths.history, 'Historique des contrôles qualité'),
        (QcPaths.root, 'Contrôle Qualité'),
      ]) {
        router.go(path);
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: path);
        expect(find.text(title), findsWidgets, reason: path);
      }
    });
  }

  // Config + statistiques = réponses RÉELLES capturées sur l'API : blocs
  // PROMESH / PROBAR, machines et compteurs rendus avec de vraies données.
  for (final width in [1440.0, 820.0, 390.0]) {
    testWidgets('données réelles à ${width.toInt()}px : blocs lignes, machines, compteurs', (tester) async {
      final config = QualityConfig.fromJson(jsonDecode(kQualityControlConfig) as Map<String, dynamic>);
      final stats = QualityStats.fromJson(jsonDecode(kQualityControlStatsAll) as Map<String, dynamic>);
      QualityControlService.instance.seedForTest(config: config, stats: {'month': stats, 'all': stats});
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = _router();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'accueil');
      expect(find.text('Statistiques indisponibles'), findsNothing);
      expect(find.text('Contrôle qualité PROMESH'), findsOneWidget);
      expect(find.text('Contrôle qualité PROBAR'), findsOneWidget);
      // 4 machines par ligne, celles de la configuration.
      expect(find.text('Machine 1'), findsNWidgets(2));
      expect(find.text('Machine 4'), findsNWidgets(2));
      // Compteurs = ceux de l'API (total ${stats.totals.total}).
      expect(find.text('${stats.totals.total}'), findsWidgets);
      expect(find.text('${stats.machinesActives} / ${stats.machines}'), findsOneWidget);
      // Hiérarchie : PROMESH/PROBAR → derniers contrôles → statistiques
      // générales → actions rapides (ordre vertical à l'écran).
      double y(String text) => tester.getTopLeft(find.text(text).first).dy;
      expect(y('PROMESH'), lessThan(y('Derniers contrôles qualité')));
      expect(y('Derniers contrôles qualité'), lessThan(y('Statistiques générales')));
      expect(y('Statistiques générales'), lessThan(y('Actions rapides')));
      // Machines intégrées dans leur bloc (au-dessus des derniers contrôles).
      expect(y('Machine 4'), lessThan(y('Derniers contrôles qualité')));
      expect(find.text('MACHINES PROMESH'), findsOneWidget);
      expect(find.text('MACHINES PROBAR'), findsOneWidget);

      router.go(QcPaths.promesh);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'PROMESH');
      expect(find.text('30/09/2026 17:52'), findsOneWidget); // dernier contrôle machine 1
      expect(find.text('Ouvrir'), findsNWidgets(4));

      router.go(QcPaths.machine('PROMESH', '1'));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'machine');
      expect(find.text('30/09/2026 17:52'), findsWidgets); // dernière fiche (stats réelles)

      router.go(QcPaths.probar);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'PROBAR');
      expect(find.text('Aucun'), findsNWidgets(4)); // aucun contrôle PROBAR en base
    });
  }
}
