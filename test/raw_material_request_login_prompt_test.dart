import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_login_prompt.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_service.dart';

class _MemoryStore implements RawMaterialPromptStore {
  String? value;
  @override
  String? read() => value;
  @override
  Future<void> write(String sessionId) async => value = sessionId;
}

/// Simule le backend et la session pour un compte donné.
class _Env {
  _Env(this.email, {this.sessionId = 'session-1', this.required = true, this.poste = 'matin'});
  String? email;
  String sessionId;
  bool required;
  String? poste;
  // Vendredi 30/10/2026, échéance 14 h à Tunis (13 h UTC) — renvoyée par le serveur.
  DateTime? deadlineAt = DateTime.utc(2026, 10, 30, 13);
  bool deadlinePassed = false;
  RawMaterialRejection? rejected;
  Object? requirementError;
  bool failSubmit = false;
  int requirementCalls = 0;
  int submits = 0;
  final store = _MemoryStore();

  Future<void> trigger(BuildContext context) => RawMaterialLoginPrompt.maybeShow(
        context,
        loadSessionId: () async => sessionId,
        loadEmail: () async => email,
        checkRequirement: () async {
          requirementCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 50)); // réponse réseau asynchrone
          if (requirementError != null) throw requirementError!;
          return RawMaterialRequirement(
            required: required,
            poste: poste,
            deadlineAt: deadlineAt,
            deadlinePassed: deadlinePassed,
            rejected: rejected,
          );
        },
        submit: (id, lines) async {
          submits++;
          if (failSubmit) throw Exception('Serveur indisponible');
          return null;
        },
        store: store,
      );
}

/// Reproduit AppShell : premier écran authentifié, déclenchement après la
/// première frame (initState + addPostFrameCallback), sans aucune action.
class _Shell extends StatefulWidget {
  const _Shell(this.env, {this.triggers = 1});
  final _Env env;
  final int triggers;
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var i = 0; i < widget.triggers; i++) {
        if (mounted) widget.env.trigger(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Tableau de bord PROMESH'));
}

Future<void> _openSession(WidgetTester tester, _Env env, {int triggers = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 1000);
  addTearDown(tester.view.reset);
  // Nouvelle clé : nouvel écran comme après une connexion / actualisation.
  await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: _Shell(env, triggers: triggers)));
  await tester.pumpAndSettle();
}

final _title = find.text('Demande de matières premières');

Future<void> _fillAndSubmit(WidgetTester tester) async {
  for (final code in ['RESINE', 'FIBRE']) {
    await tester.enterText(find.byKey(ValueKey('dispo-$code')), '10');
    await tester.enterText(find.byKey(ValueKey('besoin-$code')), '20');
    await tester.enterText(find.byKey(ValueKey('demandee-$code')), '10');
  }
  await tester.tap(find.byKey(const ValueKey('raw-material-submit')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(RawMaterialLoginPrompt.resetForTest);

  testWidgets('production_1 : popup affichée dès la connexion, sans clic, 5 matières', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com');
    await _openSession(tester, env);

    expect(_title, findsOneWidget);
    expect(find.byKey(const ValueKey('ref-RESINE')), findsOneWidget);
    expect(find.byKey(const ValueKey('ref-FIBRE')), findsOneWidget);
    for (final label in ['ISO', 'RESINE', 'ACCELERATEUR', 'GRAIN PLASTIQUE', 'FIBRE']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Poste Matin'), findsOneWidget);
    for (final col in ['Matière', 'Référence', 'Lot', 'Quantité disponible', 'Besoin production', 'Quantité demandée', 'Unité']) {
      expect(find.text(col), findsOneWidget, reason: col);
    }
  });

  testWidgets('email avec majuscules et espaces : reconnu', (tester) async {
    final env = _Env('  Production_1@CBI-Tunisia.com ');
    await _openSession(tester, env);
    expect(_title, findsOneWidget);
  });

  testWidgets('déclenchements multiples (reconstructions) : une seule popup', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com');
    await _openSession(tester, env, triggers: 3);
    expect(_title, findsOneWidget);
    expect(env.requirementCalls, 1);
  });

  testWidgets('validée : enregistrée, fermée, puis plus de popup dans la même session (navigation / actualisation)', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com');
    await _openSession(tester, env);
    await _fillAndSubmit(tester);
    expect(env.submits, 1);
    expect(_title, findsNothing);

    await _openSession(tester, env); // actualisation : même session
    expect(_title, findsNothing);
    expect(env.requirementCalls, 1);
  });

  testWidgets('annulée : pas de réaffichage en boucle dans la même session', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com');
    await _openSession(tester, env);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(_title, findsNothing);

    await _openSession(tester, env);
    expect(_title, findsNothing);
  });

  testWidgets('déconnexion puis reconnexion : nouvelle session → popup de nouveau', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com');
    await _openSession(tester, env);
    await _fillAndSubmit(tester);

    env.sessionId = 'session-2';
    await _openSession(tester, env);
    expect(_title, findsOneWidget);
  });

  testWidgets('actualisation pendant que la popup est ouverte : elle réapparaît', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com');
    await _openSession(tester, env);
    expect(_title, findsOneWidget);

    RawMaterialLoginPrompt.resetForTest(); // la page rechargée repart de zéro en mémoire
    await _openSession(tester, env);
    expect(_title, findsOneWidget);
  });

  testWidgets('échec API à la validation : valeurs conservées, popup toujours ouverte', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com')..failSubmit = true;
    await _openSession(tester, env);
    await _fillAndSubmit(tester);
    expect(_title, findsOneWidget);
    expect(find.textContaining('Serveur indisponible'), findsOneWidget);
    expect(find.text('20'), findsNWidgets(2));
    expect(env.store.value, isNull);
  });

  testWidgets('demande déjà validée et non utilisée (backend) : pas de doublon', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com', required: false);
    await _openSession(tester, env);
    expect(_title, findsNothing);
  });

  testWidgets('production_2 : aucune popup, aucun appel réseau', (tester) async {
    final env = _Env('production_2@cbi-tunisia.com');
    await _openSession(tester, env);
    expect(_title, findsNothing);
    expect(env.requirementCalls, 0);
  });

  testWidgets('autres comptes : aucune popup, aucun appel réseau', (tester) async {
    for (final email in ['responsable_logistique@cbi-tunisia.com', 'admin@cbi-tunisia.com', 'production_10@cbi-tunisia.com', null]) {
      final env = _Env(email, sessionId: 'session-$email');
      await _openSession(tester, env);
      expect(_title, findsNothing, reason: '$email');
      expect(env.requirementCalls, 0, reason: '$email');
    }
  });

  testWidgets('poste non déterminé par le backend : pas de popup', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com', poste: null);
    await _openSession(tester, env);
    expect(_title, findsNothing);
  });

  testWidgets("vérification impossible : popup avec l'erreur (pas de notification rouge), une seule fois par session", (tester) async {
    final env = _Env('production_1@cbi-tunisia.com')..requirementError = Exception('réseau');
    await _openSession(tester, env);
    expect(find.text('Créer la demande'), findsOneWidget);
    expect(find.textContaining('La vérification automatique a échoué'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(env.store.value, 'session-1');
    await _openSession(tester, env);
    expect(find.text('Créer la demande'), findsNothing);
  });

  testWidgets("vendredi avant 14 h : popup avec l'échéance « Validation requise avant vendredi à 14 h »", (tester) async {
    final env = _Env('production_1@cbi-tunisia.com');
    await _openSession(tester, env);
    expect(_title, findsOneWidget);
    expect(find.text('Validation requise avant vendredi à 14 h'), findsOneWidget);
    expect(find.textContaining('Échéance dépassée'), findsNothing);
  });

  testWidgets('vendredi après 14 h : popup, échéance signalée comme dépassée', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com')..deadlinePassed = true;
    await _openSession(tester, env);
    expect(find.text('Validation requise avant vendredi à 14 h'), findsOneWidget);
    expect(find.textContaining('Échéance dépassée'), findsOneWidget);
  });

  testWidgets('jeudi (le serveur ne demande rien) : aucune popup', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com', required: false)..deadlineAt = null;
    await _openSession(tester, env);
    expect(_title, findsNothing);
    expect(env.requirementCalls, 1);
  });

  testWidgets('reconnexion le même vendredi après soumission : pas de nouvelle popup', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com');
    await _openSession(tester, env);
    await _fillAndSubmit(tester);
    expect(env.submits, 1);

    // Nouvelle session (déconnexion / reconnexion) : le serveur sait que la demande est soumise.
    env
      ..sessionId = 'session-2'
      ..required = false;
    await _openSession(tester, env);
    expect(_title, findsNothing);
    expect(env.requirementCalls, 2);
  });

  testWidgets('demande rejetée : popup avec le motif, valeurs rechargées pour correction', (tester) async {
    final env = _Env('production_1@cbi-tunisia.com')
      ..rejected = const RawMaterialRejection(
        id: 'req-1',
        comment: 'Quantité ISO trop élevée',
        items: [
          {'material': 'ISO', 'reference': 'ISO-9', 'lot': 'L-2', 'quantiteDisponible': 120, 'besoinProduction': 300, 'quantiteDemandee': 180},
        ],
      );
    await _openSession(tester, env);
    expect(find.text('Demande rejetée par le responsable logistique achats'), findsOneWidget);
    expect(find.text('« Quantité ISO trop élevée »'), findsOneWidget);
    String field(String k) => tester.widget<TextFormField>(find.byKey(ValueKey(k))).controller!.text;
    expect([field('ref-ISO'), field('lot-ISO'), field('dispo-ISO'), field('besoin-ISO'), field('demandee-ISO')],
        ['ISO-9', 'L-2', '120', '300', '180']);
    expect(field('dispo-FIBRE'), '');
  });
}
