import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_dialog.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_service.dart';

/// Monte un bouton « Nouvelle fiche » qui reproduit l'enchaînement des
/// dashboards : ensureRawMaterialRequest() puis création de la fiche.
class _Harness {
  bool? result;
  int creations = 0;
  int requirementCalls = 0;
  final submitted = <(String, List<RawMaterialLine>)>[];

  Future<void> pump(
    WidgetTester tester, {
    required String poste,
    bool required = true,
    Object? requirementError,
    Future<void> Function()? onSubmit,
    Size size = const Size(1200, 1000),
  }) async {
    // Taille réelle de la vue (MediaQuery suit), pas seulement la surface.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await ensureRawMaterialRequest(
                context,
                module: 'promesh',
                machine: '1',
                poste: poste,
                checkRequired: () async {
                  requirementCalls++;
                  if (requirementError != null) throw requirementError;
                  return required;
                },
                submit: (id, lines) async {
                  submitted.add((id, lines));
                  if (onSubmit != null) await onSubmit();
                  return null;
                },
              );
              if (result == true) creations++;
            },
            child: const Text('Nouvelle fiche'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Nouvelle fiche'));
    await tester.pumpAndSettle();
  }
}

Future<void> _fill(WidgetTester tester) async {
  for (final code in ['RESINE', 'FIBRE']) {
    await tester.enterText(find.byKey(ValueKey('ref-$code')), 'REF-$code');
    await tester.enterText(find.byKey(ValueKey('lot-$code')), 'LOT-$code');
    await tester.enterText(find.byKey(ValueKey('dispo-$code')), '100');
    await tester.enterText(find.byKey(ValueKey('besoin-$code')), '150,5');
    await tester.enterText(find.byKey(ValueKey('demandee-$code')), '50.5');
  }
}

void main() {
  group('Validation des quantités', () {
    test('accepte les valeurs positives ou nulles (virgule ou point)', () {
      for (final v in ['0', '12', '12,5', '12.125']) {
        expect(validateRawMaterialQuantity(v), isNull, reason: v);
      }
      expect(parseRawMaterialQuantity('12,5'), 12.5);
    });
    test('messages explicites pour les valeurs invalides', () {
      expect(validateRawMaterialQuantity(''), 'Champ obligatoire');
      expect(validateRawMaterialQuantity('-3'), 'La quantité ne peut pas être négative');
      expect(validateRawMaterialQuantity('abc'), 'Nombre invalide (ex. 12,5)');
      expect(validateRawMaterialQuantity('1,2,3'), 'Nombre invalide (ex. 12,5)');
      expect(validateRawMaterialQuantity('1.12345'), 'Nombre invalide (ex. 12,5)');
      expect(validateRawMaterialQuantity('99999999'), 'Valeur trop élevée');
    });
  });

  testWidgets('1. compte concerné au poste Matin : popup affichée avec les 5 matières', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin');

    expect(find.text('Demande de matières premières'), findsOneWidget);
    for (final label in ['ISO', 'RESINE', 'ACCELERATEUR', 'GRAIN PLASTIQUE', 'FIBRE']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Courant'), findsNothing);
    expect(h.creations, 0);
  });

  testWidgets("format tableau : titre centré, 7 colonnes bleu foncé dans l'ordre, 5 lignes ISO → FIBRE, Validation", (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin');

    final title = find.text('DEMANDE DE MATIÈRES PREMIÈRES');
    expect(title, findsOneWidget);
    expect(tester.widget<Text>(title).textAlign, TextAlign.center);

    final table = tester.widget<Table>(find.byKey(const ValueKey('raw-material-table')));
    expect(table.children, hasLength(6), reason: 'en-tête + 5 matières');
    expect(find.text('PG'), findsNothing);
    expect(find.text('Colorant'), findsNothing);
    expect((table.children.first.decoration as BoxDecoration).color, kRawMaterialHeaderColor);

    const columns = ['Matière', 'Référence', 'Lot', 'Quantité disponible', 'Besoin production', 'Quantité demandée', 'Unité'];
    double? previousX;
    for (final col in columns) {
      final header = find.text(col);
      expect(header, findsOneWidget, reason: col);
      final text = tester.widget<Text>(header);
      expect(text.style?.color, Colors.white, reason: col);
      expect(text.style?.fontWeight, FontWeight.w700, reason: col);
      expect(text.textAlign, TextAlign.center, reason: col);
      // Intitulé entier sur sa cellule, sans chevauchement avec la colonne suivante.
      final x = tester.getTopLeft(header).dx;
      if (previousX != null) expect(x, greaterThan(previousX), reason: col);
      previousX = tester.getTopRight(header).dx;
    }

    // 5 lignes fixes dans l'ordre, mêmes cellules éditables sur chaque ligne.
    double? previousY;
    for (final label in ['ISO', 'RESINE', 'ACCELERATEUR', 'GRAIN PLASTIQUE', 'FIBRE']) {
      final y = tester.getTopLeft(find.text(label)).dy;
      if (previousY != null) expect(y, greaterThan(previousY), reason: label);
      previousY = y;
    }
    expect(find.text('Courant'), findsNothing);
    for (final code in ['ISO', 'RESINE', 'ACCELERATEUR', 'GRAIN_PLASTIQUE', 'FIBRE']) {
      for (final field in ['ref', 'lot', 'dispo', 'besoin', 'demandee']) {
        final f = tester.widget<TextFormField>(find.byKey(ValueKey('$field-$code')));
        expect(f.enabled, isTrue, reason: '$field-$code');
      }
      // Unité fixe KG : simple texte, aucun champ de saisie.
      expect(tester.widget<Text>(find.byKey(ValueKey('unite-$code'))).data, 'KG');
      expect(find.descendant(of: find.byKey(ValueKey('unite-$code')), matching: find.byType(EditableText)), findsNothing);
    }
    // Les champs d'une ligne sont alignés horizontalement, dans l'ordre des colonnes.
    final y = tester.getTopLeft(find.byKey(const ValueKey('ref-RESINE'))).dy;
    expect(tester.getTopLeft(find.byKey(const ValueKey('demandee-RESINE'))).dy, y);
    expect(tester.getTopLeft(find.byKey(const ValueKey('lot-RESINE'))).dx,
        greaterThan(tester.getTopLeft(find.byKey(const ValueKey('ref-RESINE'))).dx));

    // Zone Validation sous le tableau.
    expect(find.text('Validation'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('raw-material-validation'))).dy,
        greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('raw-material-table'))).dy - 1));
    expect(find.text('Valider la demande'), findsOneWidget);
  });

  testWidgets('2/3. poste Soir : aucune popup, aucun appel, création directe', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'nuit');
    expect(find.text('Demande de matières premières'), findsNothing);
    expect(h.requirementCalls, 0);
    expect(h.creations, 1);
  });

  testWidgets('4. autre utilisateur (backend : non requis) : aucune popup', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin', required: false);
    expect(find.text('Demande de matières premières'), findsNothing);
    expect(h.creations, 1);
  });

  testWidgets('5. formulaire vide : « au moins une matière », rien envoyé, fiche non créée', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin');
    await tester.tap(find.byKey(const ValueKey('raw-material-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Champ obligatoire'), findsNothing);
    expect(find.text('Renseignez au moins une matière avant de valider.'), findsOneWidget);
    expect(find.byKey(const ValueKey('raw-material-error')), findsOneWidget);
    expect(h.submitted, isEmpty);
    expect(h.creations, 0);
    expect(find.text('Demande de matières premières'), findsOneWidget);
  });

  testWidgets('5. Annuler : popup fermée sans création de fiche', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Demande de matières premières'), findsNothing);
    expect(h.result, isFalse);
    expect(h.creations, 0);
  });

  testWidgets('6. demande enregistrée : popup fermée puis création de la fiche', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin');
    await _fill(tester);
    await tester.tap(find.byKey(const ValueKey('raw-material-submit')));
    await tester.pumpAndSettle();

    expect(h.submitted, hasLength(1));
    final lines = h.submitted.single.$2;
    expect(lines.map((l) => l.material), ['RESINE', 'FIBRE']);
    expect(lines.first.toJson(), {
      'material': 'RESINE',
      'reference': 'REF-RESINE',
      'lot': 'LOT-RESINE',
      'quantiteDisponible': 100.0,
      'besoinProduction': 150.5,
      'quantiteDemandee': 50.5,
    });
    expect(find.text('Demande de matières premières'), findsNothing);
    expect(h.creations, 1);
  });

  testWidgets('7. échec API : valeurs conservées, erreur affichée, création bloquée ; nouvel essai sans doublon', (tester) async {
    final h = _Harness();
    var fail = true;
    await h.pump(tester, poste: 'matin', onSubmit: () async {
      if (fail) throw Exception('Serveur indisponible');
    });
    await _fill(tester);
    await tester.tap(find.byKey(const ValueKey('raw-material-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('raw-material-error')), findsOneWidget);
    expect(find.textContaining('Serveur indisponible'), findsOneWidget);
    expect(find.text('REF-RESINE'), findsOneWidget);
    expect(find.text('150,5'), findsNWidgets(2));
    expect(h.creations, 0);

    fail = false;
    await tester.tap(find.byKey(const ValueKey('raw-material-submit')));
    await tester.pumpAndSettle();
    expect(h.creations, 1);
    // Même identifiant client pour les deux envois : le backend renvoie la même demande.
    expect(h.submitted.map((s) => s.$1).toSet(), hasLength(1));
  });

  testWidgets('double clic sur « Valider la demande » : un seul envoi', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin', onSubmit: () => Future.delayed(const Duration(milliseconds: 300)));
    await _fill(tester);
    await tester.tap(find.byKey(const ValueKey('raw-material-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('raw-material-submit')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(h.submitted, hasLength(1));
    expect(h.creations, 1);
  });

  for (final width in [1280.0, 1024.0]) {
    testWidgets('popup (${width.toInt()} px) : les 7 colonnes visibles sans défilement, champs vides', (tester) async {
      final h = _Harness();
      await h.pump(tester, poste: 'matin', size: Size(width, 900));
      final scroll = find.byKey(const ValueKey('raw-material-table-scroll'));
      final position = tester.state<ScrollableState>(find.descendant(of: scroll, matching: find.byType(Scrollable)).first).position;
      expect(position.maxScrollExtent, 0);
      final visible = tester.getRect(scroll);
      for (final col in ['Matière', 'Référence', 'Lot', 'Quantité disponible', 'Besoin production', 'Quantité demandée', 'Unité']) {
        final r = tester.getRect(find.text(col));
        expect(r.left >= visible.left && r.right <= visible.right, isTrue, reason: col);
      }
      for (final code in ['RESINE', 'FIBRE']) {
        for (final f in ['dispo', 'besoin', 'demandee']) {
          expect(tester.widget<TextFormField>(find.byKey(ValueKey('$f-$code'))).controller!.text, '');
        }
      }
      expect(find.text('0'), findsNothing);
    });
  }

  testWidgets('ligne commencée : ses 3 quantités obligatoires, les autres matières restent libres', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin');
    await tester.enterText(find.byKey(const ValueKey('ref-RESINE')), 'R-12');
    await tester.tap(find.byKey(const ValueKey('raw-material-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Champ obligatoire'), findsNWidgets(3));
    expect(h.submitted, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('dispo-RESINE')), '10');
    await tester.enterText(find.byKey(const ValueKey('besoin-RESINE')), '30');
    await tester.enterText(find.byKey(const ValueKey('demandee-RESINE')), '20');
    await tester.tap(find.byKey(const ValueKey('raw-material-submit')));
    await tester.pumpAndSettle();
    expect(h.submitted, hasLength(1));
    expect(h.submitted.single.$2.map((l) => l.material), ['RESINE']);
    expect(h.creations, 1);
  });

  testWidgets('5 matières saisies : toutes envoyées, dans l\'ordre', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin');
    var i = 0;
    for (final code in ['ISO', 'RESINE', 'ACCELERATEUR', 'GRAIN_PLASTIQUE', 'FIBRE']) {
      i++;
      await tester.enterText(find.byKey(ValueKey('ref-$code')), 'REF-$code');
      await tester.enterText(find.byKey(ValueKey('dispo-$code')), '$i');
      await tester.enterText(find.byKey(ValueKey('besoin-$code')), '${i * 10}');
      await tester.enterText(find.byKey(ValueKey('demandee-$code')), '${i * 5},5');
    }
    await tester.tap(find.byKey(const ValueKey('raw-material-submit')));
    await tester.pumpAndSettle();
    final lines = h.submitted.single.$2;
    expect(lines.map((l) => l.material), ['ISO', 'RESINE', 'ACCELERATEUR', 'GRAIN_PLASTIQUE', 'FIBRE']);
    expect(lines.last.toJson(), {
      'material': 'FIBRE',
      'reference': 'REF-FIBRE',
      'lot': null,
      'quantiteDisponible': 5.0,
      'besoinProduction': 50.0,
      'quantiteDemandee': 25.5,
    });
  });

  testWidgets('écran 1280×1000 : les 5 lignes visibles sans défilement, boutons visibles', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin', size: const Size(1280, 1000));
    final vertical = tester.state<ScrollableState>(find.descendant(of: find.byKey(const ValueKey('raw-material-vertical-scroll')), matching: find.byType(Scrollable)).first).position;
    expect(vertical.maxScrollExtent, 0);
    final screen = tester.getRect(find.byType(Dialog));
    for (final label in ['ISO', 'RESINE', 'ACCELERATEUR', 'GRAIN PLASTIQUE', 'FIBRE']) {
      final r = tester.getRect(find.text(label));
      expect(r.top >= screen.top && r.bottom <= screen.bottom, isTrue, reason: label);
    }
    expect(tester.getRect(find.byKey(const ValueKey('raw-material-submit'))).bottom, lessThanOrEqualTo(screen.bottom));
  });

  testWidgets('écran bas (1280×640) : le tableau défile, Valider la demande reste visible', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin', size: const Size(1280, 640));
    expect(tester.takeException(), isNull);
    final vertical = tester.state<ScrollableState>(find.descendant(of: find.byKey(const ValueKey('raw-material-vertical-scroll')), matching: find.byType(Scrollable)).first).position;
    expect(vertical.maxScrollExtent, greaterThan(0));
    final submit = tester.getRect(find.byKey(const ValueKey('raw-material-submit')));
    expect(submit.bottom, lessThanOrEqualTo(640));
    // La dernière ligne s'atteint par défilement vertical.
    await tester.drag(find.byKey(const ValueKey('raw-material-vertical-scroll')), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('FIBRE')).bottom, lessThanOrEqualTo(submit.top));
    expect(tester.getRect(find.byKey(const ValueKey('raw-material-submit'))), submit);
  });

  testWidgets('largeur téléphone (360 px) : tableau en défilement horizontal, colonnes non déformées', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin', size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    expect(find.text('Demande de matières premières'), findsOneWidget);
    // Le tableau garde sa largeur minimale et défile horizontalement.
    final scroll = find.byKey(const ValueKey('raw-material-table-scroll'));
    final position = tester.state<ScrollableState>(find.descendant(of: scroll, matching: find.byType(Scrollable)).first).position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(tester.getSize(find.byKey(const ValueKey('raw-material-table'))).width, greaterThanOrEqualTo(775));
    // Même ligne qu'à l'écran large : Référence et Lot côte à côte.
    final ref = tester.getTopLeft(find.byKey(const ValueKey('ref-RESINE')));
    final lot = tester.getTopLeft(find.byKey(const ValueKey('lot-RESINE')));
    expect(lot.dy, ref.dy);
    expect(lot.dx, greaterThan(ref.dx));
    // Le bouton de validation est atteignable en faisant défiler la popup.
    await tester.ensureVisible(find.byKey(const ValueKey('raw-material-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('raw-material-submit')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('raw-material-error')), findsOneWidget);
    expect(h.creations, 0);
  });

  testWidgets('vérification impossible : création bloquée avec message', (tester) async {
    final h = _Harness();
    await h.pump(tester, poste: 'matin', requirementError: Exception('réseau'));
    expect(find.text('Demande de matières premières'), findsNothing);
    expect(find.textContaining('Vérification de la demande de matières premières impossible'), findsOneWidget);
    expect(h.creations, 0);
  });
}
