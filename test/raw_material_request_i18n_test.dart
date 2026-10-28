import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_form.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

/// Charge les vrais fichiers `assets/lang/<langue>.json` (sans GetStorage).
class _AssetDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AssetDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<AppLocalizations> load(Locale locale) async {
    final l = AppLocalizations(locale);
    await l.load();
    return l;
  }
  @override
  bool shouldReload(_AssetDelegate old) => false;
}

Future<void> _pump(WidgetTester tester, Locale locale) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en', 'US'), Locale('fr', 'FR')],
    localizationsDelegates: const [
      _AssetDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: SingleChildScrollView(
        child: RawMaterialRequestForm(poste: 'matin', submit: (_, __) async => null, onSaved: (_) {}, onCancel: () {}),
      ),
    ),
  ));
  // Lecture asynchrone des fichiers de traduction.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('anglais : titre, en-têtes et boutons traduits ; matières et KG inchangés', (tester) async {
    await _pump(tester, const Locale('en', 'US'));
    for (final t in [
      'RAW MATERIAL REQUEST',
      'Material',
      'Reference',
      'Batch',
      'Available quantity',
      'Production need',
      'Requested quantity',
      'Unit',
      'Validation',
      'Submit request',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    for (final label in ['ISO', 'RESINE', 'ACCELERATEUR', 'GRAIN PLASTIQUE', 'FIBRE']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('KG'), findsNWidgets(5));

    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();
    expect(find.text('Fill in at least one material before submitting.'), findsOneWidget);
  });

  testWidgets('français : intitulés du document de référence', (tester) async {
    await _pump(tester, const Locale('fr', 'FR'));
    for (final t in [
      'DEMANDE DE MATIÈRES PREMIÈRES',
      'Matière',
      'Référence',
      'Lot',
      'Quantité disponible',
      'Besoin production',
      'Quantité demandée',
      'Unité',
      'Validation',
      'Valider la demande',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tester.tap(find.text('Valider la demande'));
    await tester.pumpAndSettle();
    expect(find.text('Renseignez au moins une matière avant de valider.'), findsOneWidget);
  });
}
