// Popup « FICHES DE PRODUCTION MANQUANTES » (showProductionError sur le 403
// PREVIOUS_PRODUCTION_MISSING du backend) : jamais de débordement, pied et
// boutons toujours visibles, toutes les dates accessibles en défilant (y
// compris à la molette), « Demander une autorisation » inchangé.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/production_compliance/service/production_compliance_service.dart';
import 'package:dash_master_toolkit/production_compliance/view/production_compliance_dialogs.dart';

/// [n] jours ouvrés manquants à partir du 1er septembre 2026.
List<String> _dates(int n) {
  final out = <String>[];
  var d = DateTime(2026, 9, 1);
  while (out.length < n) {
    if (d.weekday != DateTime.sunday) out.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    d = d.add(const Duration(days: 1));
  }
  return out;
}

String _fr(String iso) {
  final p = iso.split('-');
  return '${p[2]}/${p[1]}/${p[0]}';
}

// Corps réel du 403 renvoyé par le backend (compliance.service.js).
ProductionApiException _error(List<String> missing) => ProductionApiException(
      'Des fiches de production précédentes sont manquantes.',
      code: 'PREVIOUS_PRODUCTION_MISSING',
      statusCode: 403,
      data: {
        'code': 'PREVIOUS_PRODUCTION_MISSING',
        'production': 'PROD1',
        'requestedDate': '2026-10-27',
        'missingDates': [...missing].reversed.toList(), // ordre quelconque : la popup trie
      },
    );

/// Même configuration de langue que main.dart, en français.
Widget _app(ProductionApiException error) => MaterialApp(
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const ValueKey('create-fiche'),
              onPressed: () => showProductionError(context, error),
              child: const Text('Nouvelle fiche'),
            ),
          ),
        ),
      ),
    );

/// Traductions lues par une vraie lecture d'asset, que pumpAndSettle n'attend pas.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<List<String>> _open(WidgetTester tester, Size size, List<String> missing) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(d.exceptionAsString());
  addTearDown(() => FlutterError.onError = previous);
  rootBundle.evict('assets/lang/fr.json');
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(_error(missing)));
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('create-fiche')));
  await tester.pumpAndSettle();
  return errors;
}

Rect _screen(WidgetTester tester) => Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);

bool _fullyInside(Rect outer, Rect inner) =>
    inner.left >= outer.left - 0.5 && inner.top >= outer.top - 0.5 && inner.right <= outer.right + 0.5 && inner.bottom <= outer.bottom + 0.5;

const _sizes = [
  ('Chrome 1366×768', Size(1366, 768)),
  ('fenêtre basse 1280×560', Size(1280, 560)),
  ('mobile 390×640', Size(390, 640)),
];

void main() {
  for (final n in [2, 10, 23, 30]) {
    for (final (label, size) in _sizes) {
      testWidgets('$n dates — $label : aucun débordement, pied et boutons visibles, toutes les dates accessibles', (tester) async {
        final missing = _dates(n);
        final errors = await _open(tester, size, missing);
        final dialog = find.byKey(const ValueKey('missing-sheets-dialog'));
        expect(dialog, findsOneWidget);

        // Titre, icône et explication conservés.
        expect(find.text('FICHES DE PRODUCTION MANQUANTES'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.text('Vous ne pouvez pas encore créer la fiche du 27/10/2026'), findsOneWidget);
        expect(find.text('$n fiches manquantes'), findsOneWidget);

        // Jamais plus haute que 88 % de la fenêtre, toujours entièrement à l'écran.
        final dialogRect = tester.getRect(find.descendant(of: dialog, matching: find.byType(Material)).first);
        expect(dialogRect.height, lessThanOrEqualTo(_screen(tester).height * 0.88 + 1));
        expect(_fullyInside(_screen(tester), dialogRect), isTrue);

        // Boutons du pied entièrement visibles, dans la popup.
        for (final key in ['missing-sheets-cancel', 'missing-sheets-request']) {
          final r = tester.getRect(find.byKey(ValueKey(key)));
          expect(_fullyInside(dialogRect, r), isTrue, reason: '$key coupé');
        }
        expect(find.text('ANNULER'), findsOneWidget);
        expect(find.text('DEMANDER UNE AUTORISATION'), findsOneWidget);

        // Toutes les dates, dans l'ordre, en faisant défiler la liste seule.
        final list = find.byKey(const ValueKey('missing-sheets-dates'));
        for (final d in missing) {
          await tester.scrollUntilVisible(find.text(_fr(d)), 30, scrollable: find.descendant(of: list, matching: find.byType(Scrollable)));
          expect(find.text(_fr(d)), findsOneWidget);
        }
        // Les boutons restent en place pendant le défilement.
        expect(_fullyInside(dialogRect, tester.getRect(find.byKey(const ValueKey('missing-sheets-request')))), isTrue);

        expect(errors, isEmpty);
      });
    }
  }

  testWidgets('30 dates : la liste défile à la molette de la souris', (tester) async {
    final missing = _dates(30);
    await _open(tester, const Size(1366, 768), missing);
    final list = find.byKey(const ValueKey('missing-sheets-dates'));
    final controller = tester.widget<ListView>(list).controller!;
    expect(controller.offset, 0);
    final center = tester.getCenter(list);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 300)));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    // Jusqu'en bas : la dernière date apparaît.
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 5000)));
    await tester.pumpAndSettle();
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(tester.any(find.text(_fr(missing.last))), isTrue);
  });

  testWidgets('ANNULER ferme la popup ; DEMANDER UNE AUTORISATION ouvre la demande avec toutes les dates', (tester) async {
    final missing = _dates(23);
    await _open(tester, const Size(1366, 900), missing);
    await tester.tap(find.byKey(const ValueKey('missing-sheets-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('missing-sheets-dialog')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('create-fiche')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('missing-sheets-request')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('missing-sheets-dialog')), findsNothing);
    // Fenêtre de demande existante, inchangée : les 23 dates y figurent.
    for (final d in missing) {
      expect(find.text(_fr(d)), findsOneWidget);
    }
  });

  testWidgets('une seule date manquante : texte au singulier, pas de compteur', (tester) async {
    final errors = await _open(tester, const Size(1366, 768), ['2026-10-26']);
    expect(find.text('FICHE DE PRODUCTION MANQUANTE'), findsOneWidget);
    expect(find.text('26/10/2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('missing-sheets-count')), findsNothing);
    expect(errors, isEmpty);
  });
}
