// Récapitulatif de production PROMESH / PROBAR — tableau détaillé :
//   - « Lignes par page » 15 (défaut) / 50 / 100, pagination, total affiché ;
//   - plus de 100 fiches : toutes consultables page par page ;
//   - largeur réduite (zoom du navigateur, petite fenêtre) : largeur minimale +
//     défilement horizontal, jamais de colonnes superposées ;
//   - tri conservé, totaux calculés sur TOUTES les lignes (jamais la page).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/production_records/model/production_record_model.dart';
import 'package:dash_master_toolkit/production_records/model/production_summary_model.dart';
import 'package:dash_master_toolkit/production_records/view/mesh_size_display.dart';
import 'package:dash_master_toolkit/production_records/view/production_summary_table_card.dart';

/// Traductions chargées une fois (fichier réel `assets/lang/fr.json`).
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

final _dateTooltip = RegExp(r'^\d{2}/\d{2}/\d{4}$');

/// Lignes de données affichées : une cellule « date » par ligne.
Finder get _dataRows => find.byWidgetPredicate((w) => w is Tooltip && _dateTooltip.hasMatch(w.message ?? ''));

List<ProductionRecordModel> _rows(int n, {required bool promesh}) => [
      for (var i = 0; i < n; i++)
        ProductionRecordModel(
          id: '${promesh ? 'promesh' : 'probar'}:$i',
          type: promesh ? 'promesh' : 'probar',
          machine: '${i % 3 + 1}',
          poste: i.isEven ? 'matin' : 'nuit',
          // Dates décroissantes, comme le backend (la plus récente d'abord).
          date: DateTime(2031, 12, 28).subtract(Duration(days: i)).toIso8601String().substring(0, 10),
          quantite: 100.0 + i,
          quantiteUnite: promesh ? 'm²' : 'm',
          tailleMaille: promesh ? '85*50' : null,
          diametre: '${6 + i % 4 * 2}',
          statut: 'validee',
        ),
    ];

ProductionSummaryTable _table(int n, {required bool promesh, bool truncated = false, int? totalMatching}) {
  final rows = _rows(n, promesh: promesh);
  return ProductionSummaryTable(
    rows: rows,
    grandTotal: rows.fold(0, (sum, r) => sum + (r.quantite ?? 0)),
    unit: promesh ? 'm²' : 'm',
    totalRecords: n,
    totalMatching: totalMatching ?? n,
    truncated: truncated,
  );
}

void main() {
  late AppLocalizations fr;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    fr = AppLocalizations(const Locale('fr'));
    await fr.load();
  });

  Future<void> pump(
    WidgetTester tester,
    ProductionSummaryTable table, {
    required bool promesh,
    double width = 1400,
    ProductionRowSort? sort,
  }) async {
    tester.view.physicalSize = Size(width, 30000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: [_PreloadedDelegate(fr), GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ProductionSummaryTableCard(
              color: Colors.blue,
              table: table,
              isPromesh: promesh,
              grandTotalLabelKey: promesh ? 'Total PROMESH' : 'Total PROBAR',
              sort: sort,
              onSortChanged: (_) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey('production-summary-$key'))).data!;

  Future<void> choosePageSize(WidgetTester tester, int size) async {
    await tester.tap(find.byKey(const ValueKey('production-summary-page-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$size').last);
    await tester.pumpAndSettle();
  }

  Future<void> tapNav(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey('production-summary-$key')));
    await tester.pumpAndSettle();
  }

  test('fenêtre de pagination : bornes, pages, page ramenée dans les limites', () {
    expect(kProductionSummaryPageSizes, [15, 50, 100]);
    var w = ProductionPageWindow.of(total: 230, pageSize: 15, page: 0);
    expect([w.page, w.totalPages, w.start, w.end, w.hasPrevious, w.hasNext], [0, 16, 0, 15, false, true]);
    w = ProductionPageWindow.of(total: 230, pageSize: 15, page: 15);
    expect([w.page, w.start, w.end, w.hasNext], [15, 225, 230, false]); // dernière page partielle
    w = ProductionPageWindow.of(total: 230, pageSize: 100, page: 2);
    expect([w.totalPages, w.start, w.end], [3, 200, 230]);
    // Page devenue inexistante (taille de page agrandie, filtres resserrés) : ramenée à la dernière.
    w = ProductionPageWindow.of(total: 230, pageSize: 100, page: 9);
    expect([w.page, w.start, w.end], [2, 200, 230]);
    w = ProductionPageWindow.of(total: 100, pageSize: 100, page: 0);
    expect([w.totalPages, w.end, w.hasNext], [1, 100, false]);
    w = ProductionPageWindow.of(total: 0, pageSize: 15, page: 3);
    expect([w.page, w.totalPages, w.start, w.end], [0, 1, 0, 0]);
  });

  for (final promesh in [true, false]) {
    final line = promesh ? 'PROMESH' : 'PROBAR';

    testWidgets('$line — 230 fiches : 15 par défaut, puis 50 et 100 ; pagination jusqu\'à la dernière fiche ; total affiché', (tester) async {
      await pump(tester, _table(230, promesh: promesh), promesh: promesh);
      expect(tester.takeException(), isNull);

      // Par défaut : 15 lignes, total clairement affiché, page 1 sur 16.
      expect(_dataRows, findsNWidgets(15));
      expect(text(tester, 'total'), '230 résultats');
      expect(text(tester, 'range'), 'Lignes 1–15 sur 230');
      expect(text(tester, 'page'), 'Page 1 sur 16');
      expect(find.text('Lignes par page :'), findsOneWidget);
      expect(tester.widget<DropdownButton<int>>(find.byKey(const ValueKey('production-summary-page-size'))).value, 15);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('production-summary-previous'))).onPressed, isNull);

      // Page suivante.
      await tapNav(tester, 'next');
      expect(text(tester, 'range'), 'Lignes 16–30 sur 230');
      expect(text(tester, 'page'), 'Page 2 sur 16');
      expect(find.text('27/12/2031'), findsNothing); // 2ᵉ fiche : sur la page 1
      expect(find.text('13/12/2031'), findsOneWidget); // 16ᵉ fiche

      // 50 lignes : retour à la première page.
      await choosePageSize(tester, 50);
      expect(_dataRows, findsNWidgets(50));
      expect(text(tester, 'range'), 'Lignes 1–50 sur 230');
      expect(text(tester, 'page'), 'Page 1 sur 5');

      // 100 lignes : 3 pages (100 + 100 + 30) — plus de 100 fiches restent consultables.
      await choosePageSize(tester, 100);
      expect(_dataRows, findsNWidgets(100));
      expect(text(tester, 'page'), 'Page 1 sur 3');
      await tapNav(tester, 'next');
      expect(text(tester, 'range'), 'Lignes 101–200 sur 230');
      await tapNav(tester, 'last');
      expect(_dataRows, findsNWidgets(30));
      expect(text(tester, 'range'), 'Lignes 201–230 sur 230');
      expect(text(tester, 'page'), 'Page 3 sur 3');
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('production-summary-next'))).onPressed, isNull);
      // La toute dernière fiche (la plus ancienne) est bien atteinte.
      final last = DateTime(2031, 12, 28).subtract(const Duration(days: 229));
      expect(find.text('${last.day.toString().padLeft(2, '0')}/${last.month.toString().padLeft(2, '0')}/${last.year}'), findsOneWidget);
      await tapNav(tester, 'first');
      expect(text(tester, 'page'), 'Page 1 sur 3');
      expect(tester.takeException(), isNull);
    });

    testWidgets('$line — fenêtre étroite / fort zoom : largeur minimale + défilement horizontal, aucune colonne superposée', (tester) async {
      for (final width in [1600.0, 1100.0, 760.0, 480.0, 340.0]) {
        await pump(tester, _table(40, promesh: promesh), promesh: promesh, width: width);
        expect(tester.takeException(), isNull, reason: 'largeur $width');
        expect(_dataRows, findsNWidgets(15), reason: 'largeur $width');

        // Le contenu du tableau n'est jamais plus étroit que sa largeur lisible.
        final scroll = tester.widget<SingleChildScrollView>(find.byKey(const ValueKey('production-summary-hscroll')));
        final content = tester.getSize(find.descendant(of: find.byKey(const ValueKey('production-summary-hscroll')), matching: find.byType(SizedBox)).first);
        final viewport = tester.getSize(find.byKey(const ValueKey('production-summary-hscroll')));
        final minWidth = (promesh ? 20 : 17) * 46.0 + 36;
        expect(content.width, greaterThanOrEqualTo(minWidth), reason: 'largeur $width');
        expect(content.width, greaterThanOrEqualTo(viewport.width), reason: 'largeur $width');
        final scrolls = content.width > viewport.width + 0.5;
        expect(scrolls, width < minWidth + 32, reason: 'largeur $width');
        expect(scroll.scrollDirection, Axis.horizontal);

        // Cellules d'une même ligne : ordonnées de gauche à droite, sans chevauchement.
        final cells = [
          find.text('28/12/2031'),
          find.text('6 mm').first,
          find.textContaining(promesh ? '100' : '100').first,
        ];
        final date = tester.getRect(cells[0]);
        final diameter = tester.getRect(cells[1]);
        expect(date.right, lessThanOrEqualTo(diameter.left), reason: 'largeur $width');
        // Chaque cellule tient sur une seule ligne (jamais de retour à la ligne).
        for (final t in tester.widgetList<Text>(find.descendant(of: _dataRows, matching: find.byType(Text)))) {
          expect(t.maxLines, 1);
          expect(t.softWrap, isFalse);
          expect(t.overflow, TextOverflow.ellipsis);
          expect(t.style!.fontSize, 12.5); // texte jamais réduit pour « faire tenir »
        }
        // En-tête et lignes partagent la même largeur : colonnes alignées.
        final header = tester.getRect(find.text(fr.translate('Date production')));
        expect((header.left - date.left).abs(), lessThan(1.0), reason: 'largeur $width');
        // Sélecteur et pagination restent utilisables, même très étroit.
        expect(find.byKey(const ValueKey('production-summary-page-size')), findsOneWidget);
        expect(find.byKey(const ValueKey('production-summary-next')), findsOneWidget);
      }
    });

    testWidgets('$line — tri conservé sur toutes les pages ; totaux sur TOUTES les fiches ; période courte sans pagination superflue', (tester) async {
      // Tri par quantité décroissante : appliqué avant la pagination.
      await pump(tester, _table(60, promesh: promesh), promesh: promesh, sort: const ProductionRowSort(ProductionSortColumn.quantity, false));
      // Quantité la plus grande (159) en tête, donc la fiche la plus ancienne.
      final oldest = DateTime(2031, 12, 28).subtract(const Duration(days: 59));
      final oldestLabel = '${oldest.day.toString().padLeft(2, '0')}/${oldest.month.toString().padLeft(2, '0')}/${oldest.year}';
      expect(find.text(oldestLabel), findsOneWidget);
      expect(find.text('28/12/2031'), findsNothing); // plus petite quantité : dernière page
      await tapNav(tester, 'last');
      expect(find.text('28/12/2031'), findsOneWidget);
      expect(text(tester, 'page'), 'Page 4 sur 4');
      // Total de la section : somme des 60 fiches, identique quelle que soit la page.
      final total = formatProductionNumber(List.generate(60, (i) => 100.0 + i).fold(0.0, (a, b) => a + b));
      expect(find.textContaining(total), findsWidgets);
      await choosePageSize(tester, 100);
      expect(_dataRows, findsNWidgets(60));
      expect(text(tester, 'page'), 'Page 1 sur 1');
      expect(find.textContaining(total), findsWidgets);

      // Période courte : 7 fiches, une seule page, navigation désactivée.
      await pump(tester, _table(7, promesh: promesh), promesh: promesh);
      expect(_dataRows, findsNWidgets(7));
      expect(text(tester, 'total'), '7 résultats');
      expect(text(tester, 'range'), 'Lignes 1–7 sur 7');
      expect(text(tester, 'page'), 'Page 1 sur 1');
      for (final key in ['first', 'previous', 'next', 'last']) {
        expect(tester.widget<IconButton>(find.byKey(ValueKey('production-summary-$key'))).onPressed, isNull, reason: key);
      }
      expect(find.byKey(const ValueKey('production-summary-truncated')), findsNothing);

      // Aucune fiche : message, ni sélecteur ni pagination.
      await pump(tester, _table(0, promesh: promesh), promesh: promesh);
      expect(find.text(fr.translate('Aucune donnée pour ces filtres')), findsOneWidget);
      expect(find.byKey(const ValueKey('production-summary-page-size')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$line — nouveaux résultats (période / filtres modifiés) : retour à la première page, taille de page conservée', (tester) async {
      await pump(tester, _table(230, promesh: promesh), promesh: promesh);
      await choosePageSize(tester, 50);
      await tapNav(tester, 'last');
      expect(text(tester, 'page'), 'Page 5 sur 5');
      // Les filtres changent : le parent fournit un autre jeu de fiches.
      await pump(tester, _table(120, promesh: promesh), promesh: promesh);
      expect(text(tester, 'page'), 'Page 1 sur 3');
      expect(text(tester, 'range'), 'Lignes 1–50 sur 120');
      expect(tester.widget<DropdownButton<int>>(find.byKey(const ValueKey('production-summary-page-size'))).value, 50);
    });
  }

  test('affichage d\'une dimension de maille : tout séparateur → « X » entouré d\'un espace ; nombres et unités conservés', () {
    const cases = {
      '20x20': '20 X 20',
      '20X20': '20 X 20',
      '20 x 20': '20 X 20',
      '15x15': '15 X 15',
      '12 × 12': '12 X 12',
      '12×12': '12 X 12',
      '12x12': '12 X 12',
      '25x25': '25 X 25',
      '50x50': '50 X 50',
      '20  x  20': '20 X 20',
      '15 x 15 mm': '15 X 15 mm',
      '20x20 mm': '20 X 20 mm',
      '50 x 50 x 5 mm': '50 X 50 X 5 mm',
      // Séparateurs des fiches existantes : même présentation.
      '20*20': '20 X 20',
      '200/200': '200 X 200',
      '20 X 20': '20 X 20', // déjà au bon format : inchangé
      '': '',
    };
    cases.forEach((input, expected) {
      expect(formatMeshSizeForDisplay(input), expected, reason: input);
      // Appliquer deux fois ne change rien (libellés déjà formatés).
      expect(formatMeshSizeForDisplay(formatMeshSizeForDisplay(input)), expected, reason: '$input (deux fois)');
    });
    expect(formatMeshSizeForDisplay(null), '');
    // Les fonctions de données (regroupements, exports) ne sont PAS modifiées.
    expect(formatCellSize('20x20'), '20x20');
    expect(formatCellSize('85*50'), '85X50');
  });

  testWidgets('récapitulatif PROMESH : toutes les dimensions affichées « 20 X 20 » — tableau principal, regroupement PROMESH 1-2-3 et bloc PROMESH 4', (tester) async {
    // Mélange réel : anciennes saisies avec x, X, *, /, × et espaces variables.
    const stored = ['20x20', '20X20', '20*20', '15x15', '15X15', '12 × 12', '25x25', '50x50', '200/200', '15 x 15 mm'];
    final rows = [
      for (var i = 0; i < stored.length; i++)
        ProductionRecordModel(
          id: 'promesh:$i',
          type: 'promesh',
          // Machines 1 à 3 (bloc regroupé) et machine 4 (bloc isolé).
          machine: (i == 3 || i == 7) ? '4' : '${i % 3 + 1}',
          poste: 'matin',
          date: '2031-12-${(10 + i).toString().padLeft(2, '0')}',
          quantite: 100.0 + i,
          quantiteUnite: 'm²',
          tailleMaille: stored[i],
          diametre: '8',
          statut: 'validee',
        ),
    ];
    await pump(tester, ProductionSummaryTable(rows: rows, grandTotal: 1045, unit: 'm²', totalRecords: 10, totalMatching: 10), promesh: true);
    expect(tester.takeException(), isNull);
    expect(_dataRows, findsNWidgets(10));

    final synthese = find.text(fr.translate('Récapitulatif de production').toUpperCase());
    expect(synthese, findsOneWidget);
    final syntheseTop = tester.getTopLeft(synthese).dy;
    double top(Element e) => (e.renderObject as RenderBox).localToGlobal(Offset.zero).dy;
    int inMainTable(String label) => find.text(label).evaluate().where((e) => top(e) < syntheseTop).length;
    int inSynthese(String label) => find.text(label).evaluate().where((e) => top(e) > syntheseTop).length;

    // Tableau principal : une cellule par fiche, toutes au format « N X N ».
    expect(inMainTable('20 X 20'), 3); // 20x20, 20X20, 20*20
    expect(inMainTable('15 X 15'), 2); // 15x15, 15X15
    for (final label in ['12 X 12', '25 X 25', '50 X 50', '200 X 200', '15 X 15 mm']) {
      expect(inMainTable(label), 1, reason: '$label — tableau principal');
    }
    // Tableau de synthèse (PROMESH 1-2-3 regroupé + PROMESH 4) : même format.
    for (final label in ['20 X 20', '15 X 15', '12 X 12', '25 X 25', '50 X 50', '200 X 200']) {
      expect(inSynthese(label), greaterThanOrEqualTo(1), reason: '$label — synthèse');
    }
    // Plus AUCUNE dimension avec « x » minuscule, ni collée (« 20X20 »), ni avec * / ×.
    // (les dates « jj/mm/aaaa » contiennent des « / » : hors du contrôle)
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').where((d) => !_dateTooltip.hasMatch(d)).toList();
    expect(texts.where((d) => RegExp(r'\d\s*[x×*/]\s*\d').hasMatch(d)), isEmpty);
    expect(texts.where((d) => RegExp(r'\dX|X\d').hasMatch(d)), isEmpty);
    for (final raw in stored) {
      expect(find.text(raw), findsNothing, reason: raw);
    }

    // Seule la présentation change : données, regroupements, quantités et tri intacts.
    expect(rows.map((r) => r.tailleMaille), stored);
    final groups = aggregateByDiameterCellSize(rows.where((r) => r.machine != '4').toList());
    expect(groups.fold<double>(0, (sum, g) => sum + g.quantity), rows.where((r) => r.machine != '4').fold<double>(0, (sum, r) => sum + r.quantite!));
    expect(groups.firstWhere((g) => g.cellSize == '20X20').quantity, 100.0 + 101.0 + 102.0); // 20x20 + 20X20 + 20*20 : un seul groupe, comme avant
    expect(sortProductionRows(rows, column: ProductionSortColumn.cellSize, ascending: true), hasLength(10));
  });

  group('regroupement du récapitulatif de production — diamètre + taille de maille', () {
    ProductionRecordModel fiche(String id, {required String machine, required String diametre, String? maille, required double quantite, required String date, double waste = 0, String type = 'promesh'}) =>
        ProductionRecordModel(id: id, type: type, machine: machine, poste: 'matin', date: date, quantite: quantite, tailleMaille: maille, diametre: diametre, statut: 'validee', waste: waste);
    String line(MachineDiameterGroup g) => '${g.diametre}|${g.cellSize}|${g.quantity}|${g.waste}';

    test('clés normalisées : x, X, ×, *, / et espaces → même maille ; 8, 8.0, 8,0 → même diamètre', () {
      for (final v in ['20x20', '20X20', '20 X 20', '20 x 20', '20×20', '20 × 20', '20*20', '20/20', ' 20  x  20 ']) {
        expect(meshSizeGroupKey(v), '20X20', reason: v);
        expect(meshSizeGroupLabel(v), '20X20', reason: v);
      }
      expect(meshSizeGroupLabel('15 x 15 mm'), '15X15 MM');
      expect(meshSizeGroupKey('15 x 15 mm'), meshSizeGroupKey('15X15MM'));
      expect(meshSizeGroupKey('20x20'), isNot(meshSizeGroupKey('20x25')));
      expect({for (final d in ['8', '8.0', '8,0', ' 8 ', '08']) diameterGroupKey(d)}, {'8'});
      expect(diameterGroupKey('8.5'), '8.5');
      expect(diameterGroupKey('8'), isNot(diameterGroupKey('10')));
    });

    test('exemple de la demande : 8 mm / 20 X 20 (1 000 + 500) et 8 mm / 15 X 15 (300) → deux lignes', () {
      final rows = [
        fiche('a', machine: '1', diametre: '8', maille: '20 X 20', quantite: 1000, date: '2031-01-01'),
        fiche('b', machine: '2', diametre: '8', maille: '20x20', quantite: 500, date: '2031-01-02'),
        fiche('c', machine: '3', diametre: '8', maille: '15 X 15', quantite: 300, date: '2031-01-03'),
      ];
      final groups = aggregateByDiameterCellSize(rows);
      expect(groups.map((g) => '${g.diametre}|${g.cellSize}|${g.quantity}'), ['8|15X15|300.0', '8|20X20|1500.0']);
      // Affichage : libellé unique, au format du tableau.
      expect(groups.map((g) => formatMeshSizeForDisplay(g.cellSize)), ['15 X 15', '20 X 20']);
    });

    test('même diamètre + même maille (toutes écritures) → UNE ligne, quantités et déchets cumulés', () {
      final rows = [
        fiche('a', machine: '1', diametre: '8', maille: '20x20', quantite: 100, date: '2031-01-01', waste: 10),
        fiche('b', machine: '2', diametre: '8', maille: '20 X 20', quantite: 200, date: '2031-01-02', waste: 20),
        fiche('c', machine: '3', diametre: '8.0', maille: '20×20', quantite: 300, date: '2031-01-03', waste: 30),
        fiche('d', machine: '1', diametre: '8', maille: '20*20', quantite: 400, date: '2031-01-04', waste: 40),
      ];
      final groups = aggregateByDiameterCellSize(rows);
      expect(groups, hasLength(1));
      expect(line(groups.single), '8|20X20|1000.0|100.0');
    });

    test('même maille, diamètres différents → deux lignes ; même diamètre, mailles différentes → deux lignes', () {
      final sameMesh = aggregateByDiameterCellSize([
        fiche('a', machine: '1', diametre: '8', maille: '20x20', quantite: 100, date: '2031-01-01'),
        fiche('b', machine: '1', diametre: '10', maille: '20x20', quantite: 200, date: '2031-01-02'),
      ]);
      expect(sameMesh.map((g) => '${g.diametre}|${g.cellSize}|${g.quantity}'), ['8|20X20|100.0', '10|20X20|200.0']);
      final sameDiameter = aggregateByDiameterCellSize([
        fiche('a', machine: '1', diametre: '8', maille: '20x20', quantite: 100, date: '2031-01-01'),
        fiche('b', machine: '1', diametre: '8', maille: '15x15', quantite: 200, date: '2031-01-02'),
      ]);
      expect(sameDiameter.map((g) => '${g.diametre}|${g.cellSize}|${g.quantity}'), ['8|15X15|200.0', '8|20X20|100.0']);
    });

    test('PROMESH 4 regroupé à part de PROMESH 1-2-3 ; sommes regroupées = sommes des fiches sources ; fiches non modifiées', () {
      final rows = [
        fiche('a', machine: '1', diametre: '8', maille: '20x20', quantite: 100, date: '2031-01-01', waste: 5),
        fiche('b', machine: '2', diametre: '8', maille: '20 X 20', quantite: 150, date: '2031-01-02', waste: 7),
        fiche('c', machine: '3', diametre: '8', maille: '15x15', quantite: 60, date: '2031-01-03', waste: 2),
        fiche('d', machine: '4', diametre: '8', maille: '20x20', quantite: 900, date: '2031-01-04', waste: 11),
        fiche('e', machine: '4', diametre: '8', maille: '20×20', quantite: 50, date: '2031-01-05', waste: 3),
        fiche('f', machine: '4', diametre: '10', maille: '20x20', quantite: 25, date: '2031-01-06', waste: 1),
      ];
      final snapshot = rows.map((r) => '${r.id}|${r.diametre}|${r.tailleMaille}|${r.quantite}').toList();
      // Mêmes appels que l'écran (_machineBreakdownBlock) : PROMESH 4 isolé, le reste regroupé.
      final p4 = aggregateByMachine(rows, groupByCellSize: true).where((s) => isPromesh4Machine(s.machine)).expand((s) => s.rows).toList();
      final p123 = aggregateByDiameterCellSize(rows.where((r) => !isPromesh4Machine(r.machine)).toList());

      expect(p123.map(line), ['8|15X15|60.0|2.0', '8|20X20|250.0|12.0']);
      expect(p4.map(line), ['8|20X20|950.0|14.0', '10|20X20|25.0|1.0']);
      // Aucune fiche comptée deux fois, aucune oubliée.
      double sum(Iterable<double> v) => v.fold(0, (a, b) => a + b);
      expect(sum(p123.map((g) => g.quantity)), sum(rows.where((r) => r.machine != '4').map((r) => r.quantite!)));
      expect(sum(p4.map((g) => g.quantity)), sum(rows.where((r) => r.machine == '4').map((r) => r.quantite!)));
      expect(sum([...p123, ...p4].map((g) => g.quantity)), sum(rows.map((r) => r.quantite!)));
      expect(sum([...p123, ...p4].map((g) => g.waste)), sum(rows.map((r) => r.waste)));
      // Les fiches d'origine ne sont pas modifiées.
      expect(rows.map((r) => '${r.id}|${r.diametre}|${r.tailleMaille}|${r.quantite}').toList(), snapshot);
    });

    test('PROBAR : regroupement propre par diamètre (sans maille), jamais mélangé à PROMESH', () {
      final probar = [
        fiche('p1', type: 'probar', machine: '1', diametre: '12', quantite: 500, date: '2031-01-01', waste: 4),
        fiche('p2', type: 'probar', machine: '1', diametre: '12.0', quantite: 250, date: '2031-01-02', waste: 6),
        fiche('p3', type: 'probar', machine: '1', diametre: '10', quantite: 100, date: '2031-01-03', waste: 1),
      ];
      final groups = aggregateByMachine(probar, groupByCellSize: false).expand((s) => s.rows).toList();
      expect(groups.map(line), ['10|null|100.0|1.0', '12|null|750.0|10.0']);
      expect(groups.fold<double>(0, (a, g) => a + g.quantity), 850);
    });
  });

  testWidgets('récapitulatif à l\'écran : une seule ligne « 20 X 20 » par bloc, quantités cumulées', (tester) async {
    final rows = [
      for (final (i, (machine, maille, qty)) in const [('1', '20x20', 100.0), ('2', '20 X 20', 150.0), ('3', '20×20', 50.0), ('4', '20x20', 900.0), ('4', '20 x 20', 50.0)].indexed)
        ProductionRecordModel(id: 'promesh:$i', type: 'promesh', machine: machine, poste: 'matin', date: '2031-12-${10 + i}', quantite: qty, quantiteUnite: 'm²', tailleMaille: maille, diametre: '8', statut: 'validee'),
    ];
    await pump(tester, ProductionSummaryTable(rows: rows, grandTotal: 1250, unit: 'm²', totalRecords: 5, totalMatching: 5), promesh: true);
    expect(tester.takeException(), isNull);
    final syntheseTop = tester.getTopLeft(find.text(fr.translate('Récapitulatif de production').toUpperCase())).dy;
    double top(Element e) => (e.renderObject as RenderBox).localToGlobal(Offset.zero).dy;
    // Tableau principal : 5 fiches, 5 cellules ; synthèse : 1 ligne pour PROMESH 1-2-3 + 1 ligne pour PROMESH 4.
    expect(find.text('20 X 20').evaluate().where((e) => top(e) < syntheseTop), hasLength(5));
    expect(find.text('20 X 20').evaluate().where((e) => top(e) > syntheseTop), hasLength(2));
    // Quantités cumulées affichées : 300 (machines 1 à 3) et 950 (machine 4) ; total 1 250.
    for (final qty in [300.0, 950.0, 1250.0]) {
      expect(find.textContaining(formatProductionNumber(qty)), findsWidgets, reason: '$qty');
    }
  });

  testWidgets('récapitulatif PROBAR : aucune colonne de dimension de maille (barres) — rien à normaliser, affichage inchangé', (tester) async {
    await pump(tester, _table(5, promesh: false), promesh: false);
    expect(find.text(fr.translate('Cell size')), findsNothing);
    expect(find.text(fr.translate('Diameter')), findsOneWidget);
    expect(_dataRows, findsNWidgets(5));
  });

  testWidgets('plafond de lecture atteint : signalé clairement, jamais silencieux', (tester) async {
    await pump(tester, _table(30, promesh: false, truncated: true, totalMatching: 1480), promesh: false);
    final notice = find.byKey(const ValueKey('production-summary-truncated'));
    expect(notice, findsOneWidget);
    expect(find.descendant(of: notice, matching: find.textContaining('30')), findsOneWidget);
    expect(find.descendant(of: notice, matching: find.textContaining('1480')), findsOneWidget);
  });
}
