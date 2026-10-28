// Bandeau de conformité (dates manquantes / autorisations de rattrapage) avec
// un volume réel : résumé compact, détail repliable et complet, aucun
// débordement de la page Rendement.
//
// ModuleScaffold lui-même ne se charge pas hors navigateur (son contrôleur
// importe my_route, qui dépend de dart:html) : `_moduleLayout` reproduit sa
// structure exacte — en-tête, zone défilante Expanded, rangée Enregistrer /
// Suivant — avec le bandeau placé AVANT (hors zone défilante) ou APRÈS la
// correction (dans la zone défilante).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/localization/app_localizations.dart';

import 'package:dash_master_toolkit/production_compliance/view/production_compliance_banner.dart';

// 30 dates manquantes (septembre) et 12 autorisations actives en 2 accords (août).
final _missing = [for (var i = 1; i <= 30; i++) '2026-09-${i.toString().padLeft(2, '0')}'];
final _auths = [
  for (var i = 1; i <= 8; i++)
    {
      'date': '2026-08-0$i',
      'authorizedByEmail': 'responsable_logistique@cbi-tunisia.com',
      'authorizedAt': '2026-10-25T08:00:00.000Z',
      'expiresAt': '2026-10-27T08:00:00.000Z',
    },
  for (var i = 10; i <= 13; i++)
    {
      'date': '2026-08-$i',
      'authorizedByEmail': 'cbitunisia@cbi-tunisia.com',
      'authorizedAt': '2026-10-24T08:00:00.000Z',
      'expiresAt': '2026-10-26T20:00:00.000Z',
    },
];

Map<String, dynamic> _status() => {
      'monitored': true,
      'production': 'PROD1',
      'missingDates': _missing,
      'backfillDates': _auths,
      'requests': [
        {'status': 'PARTIALLY_USED', 'missingDates': _missing.take(5).toList()},
      ],
    };

/// Même configuration de langue que main.dart, en français.
MaterialApp _app(Widget home, {Key? key}) => MaterialApp(
      key: key,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

String _fr(String iso) {
  final p = iso.split('-');
  return '${p[2]}/${p[1]}/${p[0]}';
}

/// Même arborescence que ModuleScaffold.build (Scaffold > SafeArea > Column).
Widget _moduleLayout({required bool bannerInScroll, required VoidCallback onSave, required VoidCallback onNext}) {
  final content = Column(children: [
    for (var i = 0; i < 6; i++) Container(height: 90, margin: const EdgeInsets.only(bottom: 8), color: Colors.black12),
    const Text('Fin du formulaire Rendement', key: ValueKey('form-end')),
  ]);
  return _app(
    Scaffold(
      body: SafeArea(
        child: Column(children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 0), child: SizedBox(height: 120, child: Text('En-tête Rendement'))),
          if (!bannerInScroll) const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 0), child: ProductionComplianceBanner()),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: bannerInScroll
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const ProductionComplianceBanner(), content])
                  : content,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: onSave, child: const Text('Enregistrer'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: onNext, child: const Text('Suivant'))),
            ]),
          ),
        ]),
      ),
    ),
  );
}

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// Les traductions (assets/lang/fr.json) se chargent par une vraie lecture
/// d'asset, que pumpAndSettle n'attend pas ; le bandeau lit ensuite son
/// statut (2e tour).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

bool _onScreen(WidgetTester tester, Finder f) {
  final r = tester.getRect(f);
  final screen = Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  return screen.contains(r.topLeft) && screen.contains(r.bottomRight - const Offset(1, 1));
}

void main() {
  setUp(() {
    ProductionComplianceBanner.debugLoadStatus = () async => _status();
    // Le Future de traduction mis en cache par un test précédent ne se
    // termine jamais dans la zone du test suivant.
    rootBundle.evict('assets/lang/fr.json');
  });
  tearDown(() => ProductionComplianceBanner.debugLoadStatus = null);

  testWidgets('avant la correction : bandeau hors zone défilante, tout déplié → RenderFlex overflow (cause du bug)', (tester) async {
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    addTearDown(() => FlutterError.onError = previous);

    await _size(tester, const Size(390, 700));
    await tester.pumpWidget(_moduleLayout(bannerInScroll: false, onSave: () {}, onNext: () {}));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('compliance-dates-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compliance-auths-toggle')), warnIfMissed: false);
    await tester.pumpAndSettle();
    FlutterError.onError = previous;
    // Même erreur que celle signalée : la colonne de la page déborde en bas.
    expect(errors, contains(matches(RegExp(r'A RenderFlex overflowed by \d+(\.\d+)? pixels on the bottom'))));
  });

  for (final (name, size) in [('Chrome 1366×768', const Size(1366, 768)), ('petite fenêtre 800×600', const Size(800, 600)), ('mobile 390×700', const Size(390, 700))]) {
    testWidgets('$name : aucun débordement, boutons accessibles, défilement jusqu\'en bas, tout consultable', (tester) async {
      var saved = 0, next = 0;
      await _size(tester, size);
      await tester.pumpWidget(_moduleLayout(bannerInScroll: true, onSave: () => saved++, onNext: () => next++));
      await _settle(tester);
      expect(tester.takeException(), isNull);

      // Résumé compact, détail replié par défaut.
      expect(find.text('30 fiches précédentes sont manquantes'), findsOneWidget);
      expect(find.text('12 autorisations de rattrapage actives'), findsOneWidget);
      expect(find.byKey(const ValueKey('compliance-missing-dates')), findsNothing);
      // Statut de la demande conservé.
      expect(find.text('Partiellement régularisée'), findsOneWidget);

      // Tout déplier : toujours aucun débordement.
      await tester.tap(find.byKey(const ValueKey('compliance-dates-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('compliance-auths-toggle')));
      await tester.tap(find.byKey(const ValueKey('compliance-auths-toggle')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final d in _missing) {
        expect(find.text(_fr(d)), findsOneWidget);
      }
      for (final a in _auths) {
        expect(find.text(_fr(a['date']!)), findsOneWidget);
      }
      // Regroupées par accord (responsable, date d'accord, expiration).
      expect(find.byKey(const ValueKey('compliance-auth-group-2026-08-01')), findsOneWidget);
      expect(find.byKey(const ValueKey('compliance-auth-group-2026-08-10')), findsOneWidget);
      expect(find.textContaining('responsable_logistique@cbi-tunisia.com'), findsOneWidget);
      expect(find.textContaining('cbitunisia@cbi-tunisia.com'), findsOneWidget);
      expect(find.textContaining('expire le'), findsNWidgets(2));

      // Boutons du bas toujours à l'écran et utilisables.
      expect(_onScreen(tester, find.text('Enregistrer')), isTrue);
      expect(_onScreen(tester, find.text('Suivant')), isTrue);
      await tester.tap(find.text('Enregistrer'));
      await tester.tap(find.text('Suivant'));
      expect((saved, next), (1, 1));

      // Défilement jusqu'à la fin du formulaire.
      await tester.scrollUntilVisible(find.byKey(const ValueKey('form-end')), 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(_onScreen(tester, find.byKey(const ValueKey('form-end'))), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('30 dates manquantes : compteur, zone de dates à hauteur limitée et défilante, page non allongée ; dates transmises à la page', (tester) async {
    Map<String, dynamic>? loaded;
    await _size(tester, const Size(1200, 900));
    await tester.pumpWidget(_app(Scaffold(body: SingleChildScrollView(child: ProductionComplianceBanner(onLoaded: (me) => loaded = me)))));
    await _settle(tester);
    expect((loaded!['missingDates'] as List).length, 30);
    expect(find.text('30 fiches précédentes sont manquantes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('compliance-dates-toggle')));
    await tester.pumpAndSettle();
    final zone = tester.getSize(find.byKey(const ValueKey('compliance-missing-dates-scroll')));
    expect(zone.height, lessThanOrEqualTo(kComplianceBannerDatesMaxHeight));
    // Toutes les dates restent consultables en faisant défiler la zone.
    final last = find.text(_fr(_missing.last));
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    expect(_onScreen(tester, last), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tableau de bord du poste : un bouton « Créer la fiche du … » par date autorisée', (tester) async {
    final created = <String>[];
    await _size(tester, const Size(1200, 900));
    await tester.pumpWidget(_app(
      Scaffold(body: SingleChildScrollView(child: ProductionComplianceBanner(onBackfill: (d) async => created.add(d)))),
    ));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('compliance-auths-toggle')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Créer la fiche du'), findsNWidgets(12));
    await tester.ensureVisible(find.byKey(const ValueKey('compliance-backfill-2026-08-12')));
    await tester.tap(find.byKey(const ValueKey('compliance-backfill-2026-08-12')));
    await tester.pumpAndSettle();
    expect(created, ['2026-08-12']);
  });

  testWidgets('peu de dates : affichage déplié comme avant ; compte non surveillé : aucun bandeau', (tester) async {
    ProductionComplianceBanner.debugLoadStatus = () async => {
          'monitored': true,
          'missingDates': ['2026-10-23'],
          'backfillDates': [],
          'requests': [],
        };
    await tester.pumpWidget(_app(const Scaffold(body: ProductionComplianceBanner())));
    await _settle(tester);
    expect(find.text('Une fiche précédente est manquante : 23/10/2026'), findsOneWidget);
    expect(find.text("Demander l'autorisation"), findsOneWidget);
    expect(find.byKey(const ValueKey('compliance-dates-toggle')), findsNothing);

    ProductionComplianceBanner.debugLoadStatus = () async => {'monitored': false};
    await tester.pumpWidget(_app(const Scaffold(body: ProductionComplianceBanner()), key: UniqueKey()));
    await _settle(tester);
    expect(find.byKey(const ValueKey('compliance-banner')), findsNothing);
  });
}
