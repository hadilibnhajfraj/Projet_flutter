import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_paths.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_screen.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_service.dart';

const _history = '/melange/historique';
const _form = '/melange/form';

/// Backend simulé : la demande devient « déjà disponible » une fois enregistrée.
class _Backend {
  _Backend(this.email);
  final String email;
  bool required = true;
  Object? checkError;
  bool failSubmit = false;
  int checks = 0;
  int submits = 0;
  bool failReload = false;
  final loads = <String>[];
  // Table « en base » : demandes enregistrées, telles que le serveur les stocke.
  final stored = <String, Map<String, dynamic>>{};
  String? pendingId;

  Future<RawMaterialRequirement> check() async {
    checks++;
    if (checkError != null) throw checkError!;
    return RawMaterialRequirement(
      required: required,
      poste: email.contains('production_2') ? 'nuit' : 'matin',
      pendingRequestId: required ? null : pendingId,
      deadlineAt: DateTime.utc(2026, 10, 30, 13),
    );
  }

  Future<Map<String, dynamic>> load(String id) async {
    loads.add(id);
    if (failReload) throw Exception('Lecture impossible');
    return stored[id]!;
  }

  Future<Map<String, dynamic>?> submit(String clientRequestId, List<RawMaterialLine> lines) async {
    submits++;
    if (failSubmit) throw Exception('Serveur indisponible');
    final id = 'req-$submits';
    stored[id] = {
      'id': id,
      'items': [for (final l in lines) {...l.toJson(), 'unite': 'KG'}],
    };
    pendingId = id;
    required = false; // demande enregistrée et disponible
    return {'id': id};
  }
}

GoRouter _router(_Backend b) => GoRouter(
      initialLocation: _history,
      routes: [
        GoRoute(
          path: _history,
          builder: (context, _) => Scaffold(
            body: Builder(
              builder: (context) => Column(children: [
                const Text('Historique MÉLANGE'),
                ElevatedButton(
                  onPressed: () async {
                    // Même enchaînement que melange_history_screen.dart#_openNewFiche.
                    final r = await checkMelangeRawMaterialRequest(context,
                        returnTo: _history, loadEmail: () async => b.email, checkRequirement: b.check);
                    if (r == RawMaterialGateResult.proceed && context.mounted) context.go(_form);
                  },
                  child: const Text('Nouvelle fiche'),
                ),
              ]),
            ),
          ),
        ),
        GoRoute(path: _form, builder: (_, __) => const Scaffold(body: Text('FORMULAIRE MÉLANGE'))),
        GoRoute(
          path: RawMaterialPaths.request,
          builder: (_, state) => RawMaterialRequestScreen(
            module: state.uri.queryParameters['module'],
            returnTo: state.uri.queryParameters['retour'] ?? _history,
            continueTo: _form,
            continueLabel: 'Créer la fiche Mélange',
            checkRequirement: b.check,
            submit: b.submit,
            loadRequest: b.load,
          ),
        ),
      ],
    );

Future<GoRouter> _pump(WidgetTester tester, _Backend b) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 1100);
  addTearDown(tester.view.reset);
  final router = _router(b);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter r) => r.routerDelegate.currentConfiguration.uri.toString();

Future<void> _tapNewFiche(WidgetTester tester) async {
  await tester.tap(find.text('Nouvelle fiche'));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester) async {
  for (final code in ['RESINE', 'FIBRE']) {
    await tester.enterText(find.byKey(ValueKey('ref-$code')), 'REF-$code');
    await tester.enterText(find.byKey(ValueKey('dispo-$code')), '40');
    await tester.enterText(find.byKey(ValueKey('besoin-$code')), '100');
    await tester.enterText(find.byKey(ValueKey('demandee-$code')), '60');
  }
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('raw-material-submit')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('raw-material-submit')));
  await tester.pumpAndSettle();
}

const _message = 'Avant de créer votre fiche de production, vous devez renseigner et valider '
    'votre demande de matières premières.';

void main() {
  testWidgets('production_1 / Nouvelle fiche Mélange : popup (titre, message, 2 boutons), pas de notification rouge', (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com');
    final router = await _pump(tester, b);
    await _tapNewFiche(tester);

    expect(find.text('Demande de matières premières'), findsOneWidget);
    expect(find.text(_message), findsOneWidget);
    expect(find.text('Validation requise avant vendredi à 14 h'), findsOneWidget);
    expect(find.text('Créer la demande'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(_location(router), _history);
  });

  testWidgets('Annuler : popup fermée, on reste sur la page, aucune fiche', (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com');
    final router = await _pump(tester, b);
    await _tapNewFiche(tester);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text(_message), findsNothing);
    expect(_location(router), _history);
    expect(find.text('FORMULAIRE MÉLANGE'), findsNothing);
  });

  testWidgets('Créer la demande → page de demande (5 matières), enregistrement, confirmation, puis fiche Mélange', (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com');
    final router = await _pump(tester, b);
    await _tapNewFiche(tester);
    await tester.tap(find.text('Créer la demande'));
    await tester.pumpAndSettle();

    final uri = Uri.parse(_location(router));
    expect(uri.path, RawMaterialPaths.request);
    expect(uri.queryParameters, {'module': 'melange', 'retour': _history});
    expect(find.byKey(const ValueKey('ref-RESINE')), findsOneWidget);
    expect(find.byKey(const ValueKey('ref-FIBRE')), findsOneWidget);
    expect(find.text('Poste Matin'), findsOneWidget);
    for (final label in ['ISO', 'RESINE', 'ACCELERATEUR', 'GRAIN PLASTIQUE', 'FIBRE']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Courant'), findsNothing);

    await _fill(tester);
    await _submit(tester);
    expect(b.submits, 1);
    expect(find.byKey(const ValueKey('raw-material-saved')), findsOneWidget);
    expect(find.text('Demande enregistrée'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('raw-material-continue')));
    await tester.pumpAndSettle();
    expect(_location(router), _form);
  });

  testWidgets('retour à la production après enregistrement : Nouvelle fiche ouvre directement le formulaire', (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com');
    final router = await _pump(tester, b);
    await _tapNewFiche(tester);
    await tester.tap(find.text('Créer la demande'));
    await tester.pumpAndSettle();
    await _fill(tester);
    await _submit(tester);

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(_location(router), _history);

    await _tapNewFiche(tester);
    expect(find.text(_message), findsNothing);
    expect(_location(router), _form);
  });

  testWidgets('échec de l\'enregistrement : erreur explicite, valeurs conservées, pas de confirmation', (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com')..failSubmit = true;
    await _pump(tester, b);
    await _tapNewFiche(tester);
    await tester.tap(find.text('Créer la demande'));
    await tester.pumpAndSettle();
    await _fill(tester);
    await _submit(tester);

    expect(find.byKey(const ValueKey('raw-material-error')), findsOneWidget);
    expect(find.textContaining("La demande n'a pas pu être enregistrée"), findsOneWidget);
    expect(find.textContaining('Serveur indisponible'), findsOneWidget);
    expect(find.text('REF-RESINE'), findsOneWidget);
    expect(find.text('Demande enregistrée'), findsNothing);
  });

  testWidgets('Annuler sur la page de demande : retour à la page d\'origine', (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com');
    final router = await _pump(tester, b);
    await _tapNewFiche(tester);
    await tester.tap(find.text('Créer la demande'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Annuler'));
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(_location(router), _history);
    expect(b.submits, 0);
  });

  testWidgets('vérification automatique en échec : erreur affichée dans la popup, formulaire accessible', (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com')
      ..checkError = Exception('Erreur lors du traitement de la demande de matières premières.');
    final router = await _pump(tester, b);
    await _tapNewFiche(tester);

    expect(find.byKey(const ValueKey('raw-material-check-error')), findsOneWidget);
    expect(find.textContaining('La vérification automatique a échoué'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('Créer la demande'));
    await tester.pumpAndSettle();
    expect(Uri.parse(_location(router)).path, RawMaterialPaths.request);
    expect(find.byKey(const ValueKey('raw-material-check-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('ref-RESINE')), findsOneWidget);
  });

  testWidgets('production_2 et autres comptes : aucune popup, aucun appel, formulaire ouvert directement', (tester) async {
    for (final email in ['production_2@cbi-tunisia.com', 'responsable_logistique@cbi-tunisia.com', 'admin@cbi-tunisia.com']) {
      final b = _Backend(email);
      final router = await _pump(tester, b);
      await _tapNewFiche(tester);
      expect(find.text(_message), findsNothing, reason: email);
      expect(b.checks, 0, reason: email);
      expect(_location(router), _form, reason: email);
    }
  });

  testWidgets('production_1 sans demande exigée (backend) : formulaire ouvert directement', (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com')..required = false;
    final router = await _pump(tester, b);
    await _tapNewFiche(tester);
    expect(find.text(_message), findsNothing);
    expect(_location(router), _form);
  });

  Future<void> openRequestPage(WidgetTester tester, GoRouter router) async {
    router.go(rawMaterialRequestPath(module: 'melange', returnTo: _history));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(find.byKey(ValueKey(key))).controller!.text;

  testWidgets("ouverture : quantités vides, aucun « 0 » par défaut", (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com');
    final router = await _pump(tester, b);
    await openRequestPage(tester, router);
    for (final code in ['RESINE', 'FIBRE']) {
      for (final f in ['ref', 'lot', 'dispo', 'besoin', 'demandee']) {
        expect(fieldText(tester, '$f-$code'), '', reason: '$f-$code');
      }
    }
    expect(find.text('0'), findsNothing);
  });

  testWidgets('après enregistrement : valeurs relues depuis le backend, exactes et en lecture seule', (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com');
    final router = await _pump(tester, b);
    await openRequestPage(tester, router);
    final values = {
      'ref-RESINE': 'REF-PG-2026', 'lot-RESINE': 'LOT-A12', 'dispo-RESINE': '1250,5', 'besoin-RESINE': '2000', 'demandee-RESINE': '749,5',
      'ref-FIBRE': 'CR-07', 'lot-FIBRE': 'LOT-B3', 'dispo-FIBRE': '0', 'besoin-FIBRE': '25,125', 'demandee-FIBRE': '25,125',
    };
    for (final e in values.entries) {
      await tester.enterText(find.byKey(ValueKey(e.key)), e.value);
    }
    await _submit(tester);

    // Envoyé tel que saisi…
    final sent = b.stored['req-1']!['items'] as List;
    expect(sent.first, containsPair('quantiteDisponible', 1250.5));
    expect(sent.last, containsPair('quantiteDisponible', 0.0));
    // …puis relu depuis le « backend » et réaffiché sans troncature ni valeur par défaut.
    expect(b.loads, ['req-1']);
    expect(find.text('Demande enregistrée'), findsOneWidget);
    for (final e in values.entries) {
      expect(fieldText(tester, e.key), e.value, reason: e.key);
    }
    expect(find.byKey(const ValueKey('raw-material-submit')), findsNothing);
    final editable = tester.widget<EditableText>(
        find.descendant(of: find.byKey(const ValueKey('dispo-RESINE')), matching: find.byType(EditableText)));
    expect(editable.readOnly, isTrue);
  });

  testWidgets('demande déjà enregistrée : rechargée et réaffichée (pas de formulaire vierge ni de zéros)', (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com')
      ..required = false
      ..pendingId = 'req-9'
      ..stored['req-9'] = {
        'id': 'req-9',
        'items': [
          {'material': 'RESINE', 'reference': 'REF-9', 'lot': null, 'quantiteDisponible': 300, 'besoinProduction': 450, 'quantiteDemandee': 150, 'unite': 'KG'},
          {'material': 'FIBRE', 'reference': null, 'lot': 'L-9', 'quantiteDisponible': 12.5, 'besoinProduction': 20, 'quantiteDemandee': 7.5, 'unite': 'KG'},
        ],
      };
    final router = await _pump(tester, b);
    await openRequestPage(tester, router);

    expect(b.loads, ['req-9']);
    expect(find.text('Demande déjà enregistrée'), findsOneWidget);
    expect(fieldText(tester, 'ref-RESINE'), 'REF-9');
    expect(fieldText(tester, 'lot-RESINE'), '');
    expect(fieldText(tester, 'dispo-RESINE'), '300');
    expect(fieldText(tester, 'demandee-RESINE'), '150');
    expect(fieldText(tester, 'lot-FIBRE'), 'L-9');
    expect(fieldText(tester, 'dispo-FIBRE'), '12,5');
    expect(fieldText(tester, 'demandee-FIBRE'), '7,5');
    expect(find.byKey(const ValueKey('raw-material-submit')), findsNothing);
    expect(b.submits, 0);
  });

  testWidgets('relecture impossible : erreur claire, aucun formulaire vierge proposé', (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com')
      ..required = false
      ..pendingId = 'req-9'
      ..failReload = true;
    final router = await _pump(tester, b);
    await openRequestPage(tester, router);
    expect(find.textContaining('Relecture de la demande impossible'), findsOneWidget);
    expect(find.byKey(const ValueKey('raw-material-submit')), findsNothing);
  });

  testWidgets('popup responsive (360 px) : pas de débordement', (tester) async {
    final b = _Backend('production_1@cbi-tunisia.com');
    await _pump(tester, b);
    tester.view.physicalSize = const Size(360, 700);
    await tester.pumpAndSettle();
    await _tapNewFiche(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Créer la demande'), findsOneWidget);
  });
}
