// Compte back-office (consultation) — vues de détail réutilisées en lecture
// (VM). Le détail d'un Follow-up (agenda CRM) affiche toutes ses
// informations ; Modifier / Reporter / Marquer terminé / Annuler ne sont
// proposés qu'aux comptes autorisés. Le backend refuse de toute façon ces
// écritures (403, test/backofficeReadOnly.test.js).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'package:dash_master_toolkit/application/calendar/model/relance_calendar_item.dart';
import 'package:dash_master_toolkit/application/calendar/widgets/followup_detail_dialog.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

final _relance = RelanceCalendarItem(
  id: 'r-1',
  commercialContactId: 'c-1',
  dateRelance: '2026-11-04',
  heureRelance: '10:30',
  commentaire: 'Rappeler pour le devis PROBAR',
  statutRelance: 'planifiee',
  commercialName: 'Commercial 1',
  projectName: 'Clôture villa Hammamet',
  contact: RelanceContactInfo(id: 'c-1', nom: 'Ben Salah', prenom: 'Ali', nomSociete: 'SARL Test', telephone: '+216 20 000 000', email: 'ali@example.com'),
);

Future<void> _role(GetStorage box, String role, {bool readOnly = false}) async {
  await box.write('isLoggedIn', true);
  await box.write('userRole', role);
  await box.write('readOnly', readOnly);
}

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  rootBundle.evict('assets/lang/fr.json');
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('fr', 'FR'),
    supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
    localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: Scaffold(
      body: Builder(builder: (context) => Center(child: TextButton(onPressed: () => showFollowupDetailDialog(context, _relance), child: const Text('ouvrir')))),
    ),
  ));
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  late GetStorage box;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('backoffice_views_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    await GetStorage.init();
    box = GetStorage();
  });

  testWidgets('back-office : toutes les informations du Follow-up, aucune action de modification', (tester) async {
    await _role(box, 'backoffice_readonly', readOnly: true);
    await _open(tester);
    // Mêmes informations que le formulaire « Modifier » (date, heure,
    // commentaire) et le reste du détail.
    for (final v in ['2026-11-04', '10:30', 'Rappeler pour le devis PROBAR', 'Clôture villa Hammamet', 'Commercial 1', 'SARL Test', '+216 20 000 000', 'ali@example.com']) {
      expect(find.text(v), findsOneWidget, reason: v);
    }
    for (final action in ['Modifier', 'Reporter', 'Marquer terminé', 'Annuler']) {
      expect(find.text(action), findsNothing, reason: action);
    }
    expect(find.text('Fermer'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('autres comptes : actions inchangées (aucune régression)', (tester) async {
    await _role(box, 'commercial');
    await _open(tester);
    for (final action in ['Modifier', 'Reporter', 'Marquer terminé', 'Annuler']) {
      expect(find.text(action), findsOneWidget, reason: action);
    }
  });
}
