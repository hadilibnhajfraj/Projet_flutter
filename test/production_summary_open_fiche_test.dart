// Récapitulatifs PROMESH / PROBAR → fiche ORIGINALE :
//   - chaque ligne ouvre la fiche par son id RÉEL (jamais date/machine/rang) ;
//   - action « Consulter la fiche » + clic sur la ligne ;
//   - écran de détail existant, autorisé au back-office (liste blanche).
// Le backend est vérifié par test/backofficeSummaryFiche.test.js.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/core/config/read_only_access.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/production_dashboard/production_dashboard_routes.dart';
import 'package:dash_master_toolkit/production_records/model/production_record_model.dart';
import 'package:dash_master_toolkit/production_records/model/production_summary_model.dart';
import 'package:dash_master_toolkit/production_records/view/production_summary_table_card.dart';

class _PreloadedDelegate extends LocalizationsDelegate<AppLocalizations> {
  final AppLocalizations value;
  const _PreloadedDelegate(this.value);
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(value);
  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

const _uuids = ['0b6d2f1e-1111-4a8b-9c3d-000000000001', '0b6d2f1e-2222-4a8b-9c3d-000000000002', '0b6d2f1e-3333-4a8b-9c3d-000000000003'];

ProductionSummaryTable _table({required bool promesh}) {
  final rows = [
    for (var i = 0; i < _uuids.length; i++)
      ProductionRecordModel(
        id: '${promesh ? 'promesh' : 'probar'}:${_uuids[i]}',
        type: promesh ? 'promesh' : 'probar',
        machine: '${i + 1}',
        poste: i.isEven ? 'matin' : 'nuit',
        // Même date et même machine possibles : seule l'id distingue les fiches.
        date: '2026-09-15',
        quantite: 100.0 + i,
        quantiteUnite: promesh ? 'm²' : 'ml',
        tailleMaille: promesh ? '20X20' : null,
        diametre: '8',
        statut: 'validee',
      ),
  ];
  return ProductionSummaryTable(rows: rows, grandTotal: 303, unit: promesh ? 'm²' : 'ml', totalRecords: rows.length, totalMatching: rows.length);
}

void main() {
  group('ProdPaths.ficheDetail — fiche originale par son id réel', () {
    test('PROMESH : écran de détail PROMESH existant', () {
      expect(ProdPaths.ficheDetail(compositeId: 'promesh:${_uuids[0]}', type: 'promesh', machine: '3', poste: 'nuit'), '/por-promesh/detail?id=${_uuids[0]}');
    });

    test('PROBAR : écran de détail PROBAR existant (machine et équipe de la fiche)', () {
      expect(ProdPaths.ficheDetail(compositeId: 'probar:${_uuids[1]}', type: 'probar', machine: '2', poste: 'nuit'),
          '/production/probar/machine/2/poste/nuit/detail?id=${_uuids[1]}');
      // Machine / équipe absentes : la fiche reste ouverte par son id.
      expect(ProdPaths.ficheDetail(compositeId: 'probar:${_uuids[1]}', type: 'probar'), '/production/probar/machine/-/poste/-/detail?id=${_uuids[1]}');
    });

    test('id inexploitable ou type inconnu : aucune navigation', () {
      expect(ProdPaths.ficheDetail(compositeId: 'promesh:', type: 'promesh'), isNull);
      expect(ProdPaths.ficheDetail(compositeId: 'x:${_uuids[0]}', type: 'autre'), isNull);
    });

    test('les deux écrans de détail sont ouverts au back-office', () {
      for (final route in [
        ProdPaths.ficheDetail(compositeId: 'promesh:${_uuids[0]}', type: 'promesh')!,
        ProdPaths.ficheDetail(compositeId: 'probar:${_uuids[0]}', type: 'probar', machine: '1', poste: 'matin')!,
        ProdPaths.ficheDetail(compositeId: 'probar:${_uuids[0]}', type: 'probar')!,
      ]) {
        expect(readOnlyProductionRouteAllowed(Uri.parse(route).path), isTrue, reason: route);
      }
    });
  });

  group('tableau du récapitulatif — « Consulter la fiche »', () {
    late AppLocalizations fr;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      fr = AppLocalizations(const Locale('fr'));
      await fr.load();
    });

    Future<void> pump(WidgetTester tester, {required bool promesh, ValueChanged<ProductionRecordModel>? onOpen}) async {
      tester.view.physicalSize = const Size(1400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: [_PreloadedDelegate(fr), GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductionSummaryTableCard(
              color: Colors.blue,
              table: _table(promesh: promesh),
              isPromesh: promesh,
              grandTotalLabelKey: promesh ? 'Total PROMESH' : 'Total PROBAR',
              sort: null,
              onSortChanged: (_) {},
              onOpenFiche: onOpen,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    for (final promesh in [true, false]) {
      final type = promesh ? 'promesh' : 'probar';

      testWidgets('$type : l’action ouvre la fiche de SA ligne (id réel)', (tester) async {
        final opened = <String>[];
        await pump(tester, promesh: promesh, onOpen: (r) => opened.add(r.id));
        expect(find.byTooltip('Consulter la fiche'), findsNWidgets(3));
        await tester.tap(find.byKey(ValueKey('summary-open-fiche-$type:${_uuids[2]}')));
        expect(opened, ['$type:${_uuids[2]}']);
      });

      testWidgets('$type : un clic sur la ligne ouvre aussi la fiche', (tester) async {
        final opened = <String>[];
        await pump(tester, promesh: promesh, onOpen: (r) => opened.add(r.id));
        await tester.tap(find.byKey(ValueKey('summary-row-$type:${_uuids[1]}')));
        expect(opened, ['$type:${_uuids[1]}']);
      });
    }

    testWidgets('sans gestionnaire : aucune action, lignes non cliquables (comportement inchangé)', (tester) async {
      await pump(tester, promesh: true);
      expect(find.byTooltip('Consulter la fiche'), findsNothing);
      expect(find.byKey(ValueKey('summary-row-promesh:${_uuids[0]}')), findsNothing);
    });
  });
}
