// Module Contrôle Qualité — navigation (VM, assertions Flutter ACTIVES).
//
// Monte le VRAI arbre de routes du module (buildQualityControlRoute, celui
// utilisé par MyRoute.router) dans un ShellRoute comme l'application, avec
// des écrans factices, puis rejoue le parcours demandé :
// Contrôle Qualité → PROMESH → Machine 1 → retour → Machine 2 → retour →
// PROBAR → Machine 1 → retour → Historique → retour → Contrôle Qualité.
// L'assertion `!keyReservation.contains(key)` du Navigator ferait échouer
// le test (exception capturée par le framework de test).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/quality_control/quality_control_routes.dart';

Widget _screen(String label) => Scaffold(body: Center(child: Text(label)));

final _screens = QcRouteScreens(
  home: () => _screen('screen:home'),
  history: (q) => _screen('screen:history:${q ?? ''}'),
  comparison: () => _screen('screen:comparison'),
  line: (type) => _screen('screen:line:$type'),
  machine: (type, m) => _screen('screen:machine:$type:$m'),
  form: (id) => _screen('screen:form:$id'),
  newForm: (type, machine) => _screen('screen:new:$type:$machine'),
);

GoRouter _router(RouteBase qcRoute) => GoRouter(
      initialLocation: QcPaths.root,
      routes: [
        ShellRoute(
          navigatorKey: GlobalKey<NavigatorState>(),
          builder: (context, state, child) => child,
          routes: [qcRoute, GoRoute(path: '/dashboard', builder: (_, __) => _screen('screen:dashboard'))],
        ),
      ],
    );

Future<GoRouter> _pump(WidgetTester tester, RouteBase qcRoute) async {
  final router = _router(qcRoute);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _go(WidgetTester tester, GoRouter router, String location, String expected) async {
  router.go(location);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'navigation vers $location');
  expect(find.text(expected), findsOneWidget, reason: location);
}

/// Clés des pages actuellement dans la pile du Navigator du shell.
List<Key?> _shellPageKeys(WidgetTester tester) {
  final navigators = tester.widgetList<Navigator>(find.byType(Navigator)).toList();
  return navigators.last.pages.map((p) => p.key).toList();
}

void main() {
  group('Contrôle Qualité — navigation', () {
    testWidgets('parcours complet sans assertion du Navigator', (tester) async {
      final router = await _pump(tester, buildQualityControlRoute(screens: _screens, canView: () => true, deniedRedirect: '/dashboard'));
      expect(find.text('screen:home'), findsOneWidget);

      await _go(tester, router, QcPaths.promesh, 'screen:line:PROMESH');
      await _go(tester, router, QcPaths.machine('PROMESH', '1'), 'screen:machine:PROMESH:1');
      await _go(tester, router, QcPaths.promesh, 'screen:line:PROMESH'); // retour
      await _go(tester, router, QcPaths.machine('PROMESH', '2'), 'screen:machine:PROMESH:2');
      await _go(tester, router, QcPaths.promesh, 'screen:line:PROMESH'); // retour
      await _go(tester, router, QcPaths.probar, 'screen:line:PROBAR');
      await _go(tester, router, QcPaths.machine('PROBAR', '1'), 'screen:machine:PROBAR:1');
      await _go(tester, router, QcPaths.probar, 'screen:line:PROBAR'); // retour
      await _go(tester, router, QcPaths.history, 'screen:history:');
      await _go(tester, router, QcPaths.comparison, 'screen:comparison'); // Comparaison qualité
      await _go(tester, router, QcPaths.history, 'screen:history:');
      await _go(tester, router, QcPaths.root, 'screen:home'); // retour → Contrôle Qualité
    });

    testWidgets('retour par pop() (bouton retour du navigateur / AppBar)', (tester) async {
      final router = await _pump(tester, buildQualityControlRoute(screens: _screens, canView: () => true, deniedRedirect: '/dashboard'));
      await _go(tester, router, QcPaths.machine('PROMESH', '1'), 'screen:machine:PROMESH:1');
      router.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('screen:line:PROMESH'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('screen:home'), findsOneWidget);
    });

    testWidgets('pile imbriquée : une clé distincte par page (accueil, ligne, machine)', (tester) async {
      final router = await _pump(tester, buildQualityControlRoute(screens: _screens, canView: () => true, deniedRedirect: '/dashboard'));
      await _go(tester, router, QcPaths.machine('PROBAR', '3'), 'screen:machine:PROBAR:3');
      final keys = _shellPageKeys(tester);
      expect(keys, [qcPageKeyHome, qcPageKeyLine('PROBAR'), qcPageKeyMachine('PROBAR', '3')]);
      expect(keys.toSet(), hasLength(keys.length));
    });

    testWidgets('formulaire, historique avec recherche, ancien chemin /historique, accès refusé', (tester) async {
      var allowed = true;
      final router = await _pump(tester, buildQualityControlRoute(screens: _screens, canView: () => allowed, deniedRedirect: '/dashboard'));
      await _go(tester, router, QcPaths.control('abc'), 'screen:form:abc');
      await _go(tester, router, QcPaths.control('def'), 'screen:form:def');
      await _go(tester, router, QcPaths.historySearch('machine 1'), 'screen:history:machine 1');
      await _go(tester, router, QcPaths.legacyHistory, 'screen:history:');
      await _go(tester, router, QcPaths.form, 'screen:home'); // ni id ni machine → accueil
      await _go(tester, router, QcPaths.newControl('PROMESH', '1'), 'screen:new:PROMESH:1');
      await _go(tester, router, QcPaths.newControl('probar', '3'), 'screen:new:PROBAR:3');
      // Anciens liens /quality-control/controle?… → nouvelles routes.
      await _go(tester, router, '${QcPaths.legacyForm}?id=xyz', 'screen:form:xyz');
      await _go(tester, router, '${QcPaths.legacyForm}?type=promesh&machine=2', 'screen:new:PROMESH:2');
      allowed = false;
      await _go(tester, router, QcPaths.promesh, 'screen:dashboard');
    });

    // Témoin : l'ANCIENNE configuration (clé = URL complète sur le parent ET
    // l'enfant imbriqué) déclenche bien l'assertion — c'est la cause réelle.
    testWidgets('témoin : ValueKey(state.uri) sur parent + enfant → !keyReservation.contains(key)', (tester) async {
      final legacy = GoRoute(
        path: QcPaths.root,
        builder: (_, __) => _screen('screen:home'),
        routes: [
          GoRoute(
            path: 'ligne/:type',
            pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.toString()), child: _screen('line')),
            routes: [
              GoRoute(
                path: 'machine/:num',
                pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.toString()), child: _screen('machine')),
              ),
            ],
          ),
        ],
      );
      final router = await _pump(tester, legacy);
      // L'arbre cassé produit ensuite des erreurs en cascade au démontage :
      // toutes sont capturées, puis l'arbre est remplacé avant restauration.
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        router.go('${QcPaths.root}/ligne/promesh/machine/1');
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
      } finally {
        FlutterError.onError = previous;
      }
      expect(errors, isNotEmpty);
      expect(errors.first.exceptionAsString(), contains('keyReservation.contains(key)'));
    });
  });

  group('Contrôle Qualité — chemins et fil d\'Ariane', () {
    test('chemins uniques des pages', () {
      expect(QcPaths.line('PROMESH'), '/quality-control/promesh');
      expect(QcPaths.machine('PROBAR', '4'), '/quality-control/probar/machine/4');
      expect(QcPaths.control('x'), '/quality-control/control/x');
      expect(QcPaths.newControl('PROMESH', '1'), '/quality-control/control?type=promesh&machine=1');
      expect(QcPaths.historySearch('  '), QcPaths.history);
      expect(QcPaths.historySearch('PROMESH-2026-000886'), '/quality-control/history?q=PROMESH-2026-000886');
      final keys = {
        qcPageKeyHome,
        qcPageKeyHistory,
        for (final t in kQcRoutedLines) ...[qcPageKeyLine(t), for (final m in ['1', '2', '3', '4']) qcPageKeyMachine(t, m)],
      };
      expect(keys, hasLength(2 + 2 * 5));
    });

    test('fil d\'Ariane global', () {
      expect(qcBreadcrumb('/dashboard'), isNull);
      expect(qcBreadcrumb('/quality-control-other'), isNull);
      expect(qcBreadcrumb('/quality-control'), ('Contrôle Qualité', 'Contrôle Qualité', 'Tableau de bord'));
      expect(qcBreadcrumb('/quality-control/promesh'), ('PROMESH', 'Contrôle Qualité', 'PROMESH'));
      expect(qcBreadcrumb('/quality-control/probar/machine/2'), ('Machine 2', 'PROBAR', 'Machine 2'));
      expect(qcBreadcrumb('/quality-control/history'), ('Historique', 'Contrôle Qualité', 'Historique'));
      expect(qcBreadcrumb('/quality-control/control/abc'), ('Contrôle Qualité', 'Contrôle Qualité', 'Contrôle Qualité'));
      expect(qcBreadcrumb('/quality-control/comparison'), ('Comparaison qualité', 'Contrôle Qualité', 'Comparaison qualité'));
    });
  });
}
