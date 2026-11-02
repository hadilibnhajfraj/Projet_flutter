// Module « Notes de calcul » — côté Flutter (VM). Le transport d'ApiClient
// est simulé : le vrai service, le vrai JSON et les vrais écrans sont
// exercés. Le backend reste l'autorité (test/calculationNotes.test.js).

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'package:dash_master_toolkit/calculation_notes/model/calculation_note.dart';
import 'package:dash_master_toolkit/calculation_notes/service/calculation_note_service.dart';
import 'package:dash_master_toolkit/calculation_notes/view/calculation_note_detail_screen.dart';
import 'package:dash_master_toolkit/calculation_notes/view/calculation_note_form_dialog.dart';
import 'package:dash_master_toolkit/calculation_notes/view/calculation_note_widgets.dart';
import 'package:dash_master_toolkit/calculation_notes/view/note_dropzone.dart';
import 'package:dash_master_toolkit/calculation_notes/view/calculation_notes_screen.dart';
import 'package:dash_master_toolkit/calculation_notes/view/project_calculation_notes_section.dart';
import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/app_shell_route/models/notification.dart';

const _me = {'id': 'u-me', 'email': 'medwethekgc@gmail.com', 'name': 'Mohamed'};
const _ref = {'id': 'u-ref', 'email': 'info@probardistribution.com', 'name': 'Info Probar'};
const _project = {'id': 'p-1', 'nomProjet': 'Villa Hammamet', 'statut': 'Identification', 'entreprise': 'SARL Test', 'isArchived': false};

Map<String, dynamic> _doc(String id, String name, String ext, String? comment, int size, {String origin = 'INITIAL', Map<String, dynamic> by = _me}) => {
      'id': id,
      'noteId': 7,
      'projectId': 'p-1',
      'originalName': name,
      'extension': ext,
      'mimeType': ext == 'pdf' ? 'application/pdf' : 'application/octet-stream',
      'sizeBytes': size,
      'commentaire': comment,
      'title': null,
      'origin': origin,
      'documentType': ext == 'pdf' ? 'note_de_calcul' : null,
      'uploadedBy': by,
      'createdAt': '2026-10-30T08:00:00.000Z',
    };

const _colleague = {'id': 'u-col', 'email': 'faycelmarzouk@probardistribution.com', 'name': 'Faycel Marzouk', 'role': 'user'};
const _colleague2 = {'id': 'u-col2', 'email': 'hadil.ibnhajfraj@gmail.com', 'name': 'Hadil', 'role': 'commercial'};

const _validator = {'id': 'u-val', 'email': 'medwethekgc@gmail.com', 'name': 'Mohamed Wethak Khochtali'};

Map<String, dynamic> _workflow({String status = 'EN_ATTENTE_VALIDATION', bool canDecide = false, bool canCancel = false, Map<String, dynamic> extra = const {}}) => {
      'status': status,
      'submissionVersion': 1,
      'submittedAt': '2026-10-30T08:00:00.000Z',
      'validator': _validator,
      'decidedBy': null,
      'decidedAt': null,
      'decisionComment': null,
      'cancelledBy': null,
      'cancelledAt': null,
      'cancellationReason': null,
      'canDecide': canDecide,
      'canCancel': canCancel,
      ...extra,
    };

Map<String, dynamic> _detail({bool canEdit = true, int id = 7, Map<String, dynamic> workflow = const {}}) => {
      'id': id,
      'reference': 'NC-2026-${id.toString().padLeft(4, '0')}',
      'project': _project,
      'requester': _ref,
      'creator': _me,
      'commentaire': 'Observations générales',
      'createdAt': '2026-10-30T08:00:00.000Z',
      'updatedAt': '2026-10-30T09:00:00.000Z',
      'documents': [
        _doc('d-1', 'Note de calcul dalle.pdf', 'pdf', 'Calcul principal', 2048),
        _doc('d-2', 'Hypothèses.docx', 'docx', 'Hypothèses de charge', 1536000),
      ],
      'history': [
        {'action': 'DOCUMENT_ADDED', 'user': _me, 'details': {'originalName': 'Hypothèses.docx'}, 'createdAt': '2026-10-30T08:00:01.000Z'},
        {'action': 'NOTE_CREATED', 'user': _me, 'details': {}, 'createdAt': '2026-10-30T08:00:00.000Z'},
      ],
      'canEdit': canEdit,
      'canAssign': canEdit,
      'canManageNotifications': true,
      ..._workflow(),
      ...workflow,
    };

Map<String, dynamic> _row(int id, String ref, {bool canEdit = false, int docs = 1, String status = 'EN_ATTENTE_VALIDATION', bool canDecide = false}) => {
      'id': id,
      'reference': ref,
      'project': _project,
      'requester': _ref,
      'creator': _me,
      'createdAt': '2026-10-30T08:00:00.000Z',
      'documentsCount': docs,
      'commentaire': 'Commentaire $ref',
      'observations': 'Observations $ref',
      'canEdit': canEdit,
      ..._workflow(status: status, canDecide: canDecide),
    };

/// Transport simulé : enregistre chaque requête et répond selon le chemin.
class _Api implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool detailCanEdit = true;
  // Statut / droits du workflow renvoyés par le détail.
  Map<String, dynamic> detailWorkflow = const {};
  bool assigneeRequired = false;
  // Documents complémentaires déjà déposés (renvoyés par le détail).
  List<Map<String, dynamic>> complementaryDocs = [];
  List<Map<String, dynamic>> emails = [
    {'id': 'e-1', 'to': 'medwethekgc@gmail.com', 'subject': 'Nouvelle demande de validation – Note de calcul NC-2026-0007', 'status': 'SENT', 'attempts': 1, 'sentAt': '2026-10-30T08:00:05.000Z'},
    {'id': 'e-2', 'to': 'faycelmarzouk@probardistribution.com', 'subject': 'Nouvelle note de calcul qui vous est affectée – NC-2026-0007', 'status': 'FAILED', 'attempts': 1, 'lastErrorMessage': '550 mailbox unavailable'},
  ];
  // Projets proposés (le backend renvoie aussi les projets créés ensuite).
  List<Map<String, dynamic>> projects = [_project];
  // Réponse d'erreur du backend pour la création d'une note.
  Map<String, dynamic>? createError;
  List<Map<String, dynamic>> rows = [_row(7, 'NC-2026-0007', canEdit: true, docs: 2), _row(8, 'NC-2026-0008')];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(o);
    final p = o.path;
    Object body;
    if (p == '/calculation-notes/options') {
      body = {'success': true, 'data': {'projects': projects, 'requesters': [_me, _ref], 'assignees': [_colleague, _colleague2, _me], 'assigneeRequired': assigneeRequired, 'currentUserId': 'u-me'}};
    } else if (p.endsWith('/assignments')) {
      body = {
        'success': true,
        'data': [
          {'action': 'ASSIGNMENT_CHANGED', 'from': _colleague2, 'to': _colleague, 'by': _me, 'createdAt': '2026-10-30T09:00:00.000Z'},
          {'action': 'NOTE_ASSIGNED', 'from': null, 'to': _colleague2, 'by': _me, 'createdAt': '2026-10-30T08:00:00.000Z'},
        ],
      };
    } else if (p.endsWith('/email-notifications/resend')) {
      body = {'success': true, 'data': {'retried': 1}};
    } else if (p.endsWith('/email-notifications')) {
      body = {'success': true, 'data': emails};
    } else if (p == '/calculation-notes' && o.method == 'POST' && createError != null) {
      return ResponseBody.fromString(jsonEncode(createError), 403, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    } else if ((p == '/calculation-notes' || p == '/calculation-notes/validation') && o.method == 'GET') {
      body = {
        'success': true,
        'data': rows,
        'pagination': {'page': o.queryParameters['page'] ?? 1, 'limit': 20, 'total': 41, 'totalPages': 3},
        'summary': {
          'total': 41, 'thisMonth': 3, 'documents': 63, 'mine': 12, 'EN_ATTENTE_VALIDATION': 5, 'VALIDEE': 30, 'REFUSEE': 4, 'ANNULEE': 9,
          'byCreator': [
            {'user': _me, 'count': 26},
            {'user': _ref, 'count': 15},
          ],
        },
      };
    } else if (p.endsWith('/download')) {
      return ResponseBody.fromBytes(utf8.encode('%PDF-1.4 test'), 200, headers: {Headers.contentTypeHeader: ['application/pdf']});
    } else {
      final id = int.tryParse(RegExp(r'^/calculation-notes/(\d+)').firstMatch(p)?.group(1) ?? '') ?? 7;
      final d = _detail(canEdit: detailCanEdit, id: id, workflow: detailWorkflow);
      d['documents'] = [...d['documents'] as List, ...complementaryDocs];
      if (p.endsWith('/complementary-documents')) {
        d['documents'] = [...d['documents'] as List, _doc('d-new', 'Réponse.pdf', 'pdf', 'Envoyé', 10, origin: 'COMPLEMENTARY', by: _colleague)];
      }
      body = {'success': true, 'data': d};
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}

  List<RequestOptions> where(String method, String path) => requests.where((r) => r.method == method && r.path == path).toList();
}

Future<void> _pump(WidgetTester tester, Widget child, {Size size = const Size(1400, 2600)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  late _Api api;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('calculation_notes_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (call) async => null);
    await GetStorage.init();
    final box = GetStorage();
    await box.write('isLoggedIn', true);
    await box.write('accessToken', 'jeton-de-test');
    await box.write('userRole', 'user');
    await box.write('userId', 'u-me');
  });

  setUp(() {
    api = _Api();
    ApiClient.instance.dio.httpClientAdapter = api;
  });

  group('liste /notes-calcul', () {
    testWidgets('tableau : référence, projet, demandeur, créateur, date, documents, commentaire, indicateurs, pagination', (tester) async {
      await _pump(tester, const CalculationNotesScreen(readOnly: false));
      for (final t in ['NC-2026-0007', 'NC-2026-0008', 'Info Probar', 'Mohamed', '30/10/2026', 'Commentaire NC-2026-0007']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expect(find.text('Villa Hammamet'), findsNWidgets(2));
      // Tous les statuts, documents, « Mes notes » (distinct du total).
      for (final v in ['41', '5', '30', '4', '9', '63', '12']) {
        expect(find.text(v), findsOneWidget, reason: v);
      }
      for (final l in ['Validée', 'Refusée', 'Annulée', 'Documents joints', 'Mes notes']) {
        expect(find.text(l), findsWidgets, reason: l);
      }
      // Notes par créateur.
      expect(find.byKey(const ValueKey('notes-by-creator')), findsOneWidget);
      expect(find.text('Mohamed · 26'), findsOneWidget);
      expect(find.text('Info Probar · 15'), findsOneWidget);
      expect(find.text('41 note(s) · Page 1 / 3'), findsOneWidget);
      // Actions selon les droits : Modifier uniquement si canEdit.
      expect(find.byKey(const ValueKey('note-view-7')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-edit-7')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-edit-8')), findsNothing);
      expect(find.byKey(const ValueKey('notes-new')), findsOneWidget);
    });

    testWidgets('recherche, tri et pagination envoyés au backend', (tester) async {
      await _pump(tester, const CalculationNotesScreen(readOnly: false));
      await tester.enterText(find.byKey(const ValueKey('notes-search-reference')), 'NC-2026-0007');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(api.where('GET', '/calculation-notes').last.queryParameters, containsPair('reference', 'NC-2026-0007'));
      await tester.enterText(find.byKey(const ValueKey('notes-search-project')), 'Villa');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(api.where('GET', '/calculation-notes').last.queryParameters, containsPair('project', 'Villa'));
      await tester.tap(find.byKey(const ValueKey('notes-sort-reference')));
      await tester.pumpAndSettle();
      expect(api.where('GET', '/calculation-notes').last.queryParameters, allOf(containsPair('sortBy', 'reference'), containsPair('sortDir', 'asc')));
      await tester.tap(find.byKey(const ValueKey('notes-next')));
      await tester.pumpAndSettle();
      expect(api.where('GET', '/calculation-notes').last.queryParameters, containsPair('page', 2));
    });

    testWidgets('mobile : cartes lisibles, sans débordement', (tester) async {
      await _pump(tester, const CalculationNotesScreen(readOnly: false), size: const Size(390, 2000));
      expect(tester.takeException(), isNull);
      expect(find.text('NC-2026-0007'), findsOneWidget);
    });

    testWidgets('back-office : consultation et téléchargement, ni création ni modification', (tester) async {
      await _pump(tester, const CalculationNotesScreen(readOnly: true));
      expect(find.byKey(const ValueKey('notes-new')), findsNothing);
      expect(find.byKey(const ValueKey('note-edit-7')), findsNothing);
      expect(find.byKey(const ValueKey('note-view-7')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-download-7')), findsOneWidget);
    });
  });

  group('formulaire de création', () {
    Map<String, String> fieldsOf(RequestOptions r) => Map.fromEntries((r.data as FormData).fields);

    Future<void> pick(WidgetTester tester, String field, String search, String optionId) async {
      await tester.tap(find.byKey(ValueKey(field)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('note-select-search')), search);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('note-select-option-$optionId')));
      await tester.pumpAndSettle();
    }

    testWidgets('en-tête, sections et champs automatiques (non modifiables) ; libellés et étoiles', (tester) async {
      await _pump(tester, const CalculationNoteFormDialog());
      for (final t in ['Nouvelle note de calcul', 'Créer une note de calcul et associer les documents techniques', 'Informations générales', 'Documents techniques', 'Généré automatiquement', 'Mohamed', 'Observations générales', 'Les champs marqués * sont obligatoires.', 'Annuler', 'Créer la note de calcul']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expect(find.text('NC-${DateTime.now().year}-XXXX'), findsOneWidget);
      // ID / référence / créateur : lecture seule.
      for (final k in ['note-form-id', 'note-form-reference', 'note-form-creator']) {
        final f = tester.widget<TextField>(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(TextField)));
        expect(f.readOnly, isTrue, reason: k);
      }
      expect(find.text('Projet *', findRichText: true), findsOneWidget);
      expect(find.text('Demandeur *', findRichText: true), findsOneWidget);
      expect(find.text('Observations générales *', findRichText: true), findsNothing); // facultatif
      expect(find.text('Mohamed — medwethekgc@gmail.com'), findsOneWidget); // demandeur par défaut
      expect(tester.takeException(), isNull);
    });

    testWidgets('1. projet existant : recherche, sélection, observations, création', (tester) async {
      await _pump(tester, const CalculationNoteFormDialog());
      await tester.tap(find.byKey(const ValueKey('note-form-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Sélectionnez un projet.'), findsOneWidget);
      expect(api.where('POST', '/calculation-notes'), isEmpty);
      await pick(tester, 'note-form-project', 'hammamet', 'p-1');
      await pick(tester, 'note-form-requester', 'info', 'u-ref');
      expect(find.text('Villa Hammamet — SARL Test'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('note-form-comment')), 'Dalle R+1');
      await tester.tap(find.byKey(const ValueKey('note-form-submit')));
      await tester.pumpAndSettle();
      expect(fieldsOf(api.where('POST', '/calculation-notes').single), {'projectId': 'p-1', 'requesterId': 'u-ref', 'commentaire': 'Dalle R+1'});
    });

    testWidgets('recherche sans accent ni casse ; aucun résultat signalé', (tester) async {
      await _pump(tester, const CalculationNoteFormDialog());
      await tester.tap(find.byKey(const ValueKey('note-form-project')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('note-select-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Aucun résultat'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('note-select-search')), 'VILLA');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-select-option-p-1')), findsOneWidget);
    });

    for (final viaSearch in [false, true]) {
      testWidgets('2-4. projet créé depuis la note (${viaSearch ? 'option de la liste' : 'lien sous le champ'}) : sélectionné, saisie conservée', (tester) async {
        var calls = 0;
        Future<NoteProject?> creator(BuildContext _) async {
          calls++;
          // Le projet est enregistré par le module Projets : le backend le
          // renvoie désormais dans les choix.
          api.projects = [_project, {'id': 'p-new', 'nomProjet': 'Nouveau chantier Sousse', 'entreprise': null, 'isArchived': false}];
          return const NoteProject(id: 'p-new', nomProjet: 'Nouveau chantier Sousse');
        }

        await _pump(tester, CalculationNoteFormDialog(createProject: creator));
        // Saisie AVANT la création du projet.
        await pick(tester, 'note-form-requester', 'info', 'u-ref');
        await tester.enterText(find.byKey(const ValueKey('note-form-comment')), 'Observations saisies avant');
        final optionsBefore = api.where('GET', '/calculation-notes/options').length;
        if (viaSearch) {
          await tester.tap(find.byKey(const ValueKey('note-form-project')));
          await tester.pumpAndSettle();
          expect(find.text('+ Créer un nouveau projet'), findsWidgets);
          await tester.tap(find.byKey(const ValueKey('note-select-action')));
        } else {
          await tester.tap(find.byKey(const ValueKey('note-form-create-project')));
        }
        await tester.pumpAndSettle();
        expect(calls, 1);
        // Liste actualisée depuis le backend, nouveau projet sélectionné.
        expect(api.where('GET', '/calculation-notes/options').length, optionsBefore + 1);
        expect(find.text('Nouveau chantier Sousse'), findsOneWidget);
        expect(find.text('Projet créé et sélectionné : Nouveau chantier Sousse'), findsOneWidget);
        // Rien de perdu.
        expect(find.text('Observations saisies avant'), findsOneWidget);
        expect(find.text('Info Probar — info@probardistribution.com'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('note-form-submit')));
        await tester.pumpAndSettle();
        expect(fieldsOf(api.where('POST', '/calculation-notes').single), {'projectId': 'p-new', 'requesterId': 'u-ref', 'commentaire': 'Observations saisies avant'});
      });
    }

    testWidgets('création de projet abandonnée : rien ne change', (tester) async {
      await _pump(tester, CalculationNoteFormDialog(createProject: (_) async => null));
      await pick(tester, 'note-form-project', 'villa', 'p-1');
      await tester.tap(find.byKey(const ValueKey('note-form-create-project')));
      await tester.pumpAndSettle();
      expect(find.text('Villa Hammamet — SARL Test'), findsOneWidget);
      expect(find.byKey(const ValueKey('note-form-info')), findsNothing);
    });

    testWidgets('depuis un projet : projet imposé, pas de création de projet', (tester) async {
      await _pump(tester, CalculationNoteFormDialog(projectId: 'p-1', projectName: 'Villa Hammamet', createProject: (_) async => null));
      expect(find.text('Villa Hammamet — SARL Test'), findsOneWidget);
      expect(find.byKey(const ValueKey('note-form-create-project')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('note-form-project')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-select-search')), findsNothing); // champ verrouillé
      await tester.tap(find.byKey(const ValueKey('note-form-submit')));
      await tester.pumpAndSettle();
      expect(fieldsOf(api.where('POST', '/calculation-notes').single), {'projectId': 'p-1', 'requesterId': 'u-me'});
    });

    testWidgets('aucune double soumission ; erreur du backend affichée dans le formulaire', (tester) async {
      api.createError = {'success': false, 'code': 'PERMISSION_DENIED', 'message': "Vous n'avez pas les droits de modification sur ce projet."};
      await _pump(tester, const CalculationNoteFormDialog(projectId: 'p-1'));
      await tester.tap(find.byKey(const ValueKey('note-form-submit')));
      await tester.tap(find.byKey(const ValueKey('note-form-submit')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(api.where('POST', '/calculation-notes'), hasLength(1));
      expect(find.byKey(const ValueKey('note-form-error')), findsOneWidget);
      expect(find.text("Vous n'avez pas les droits de modification sur ce projet."), findsOneWidget);
      expect(find.text('Nouvelle note de calcul'), findsOneWidget); // le formulaire reste ouvert
    });

    testWidgets('tablette : pas de débordement', (tester) async {
      await _pump(tester, const CalculationNoteFormDialog(), size: const Size(800, 1000));
      expect(tester.takeException(), isNull);
    });

    test('5. plusieurs documents : type et commentaire propres, nom réel du fichier (multipart)', () async {
      final docs = [
        PendingNoteDocument(name: 'calcul.pdf', bytes: utf8.encode('%PDF-1.4'), commentaire: 'Calcul principal', documentType: 'note_de_calcul'),
        PendingNoteDocument(name: 'métré.xlsx', bytes: [80, 75, 3, 4], commentaire: 'Métré'),
      ];
      await CalculationNoteService.instance.create(projectId: 'p-1', requesterId: 'u-me', documents: docs);
      final fd = api.where('POST', '/calculation-notes').single.data as FormData;
      String field(String k) => fd.fields.firstWhere((f) => f.key == k).value;
      expect(jsonDecode(field('commentaires')), ['Calcul principal', 'Métré']);
      expect(fd.fields.any((f) => f.key == 'titres'), isFalse); // plus de nom saisi
      expect(jsonDecode(field('types')), ['note_de_calcul', null]);
      expect(fd.files.map((f) => [f.key, f.value.filename, f.value.length]), [
        ['files', 'calcul.pdf', 8],
        ['files', 'métré.xlsx', 4],
      ]);
    });

    testWidgets('cartes de documents : icône, nom, taille, suppression avant envoi', (tester) async {
      final docs = [
        PendingNoteDocument(name: 'calcul.pdf', bytes: List.filled(2048, 1)),
        PendingNoteDocument(name: 'plan.docx', bytes: [1, 2, 3]),
      ];
      await _pump(tester, StatefulBuilder(builder: (c, set) => SingleChildScrollView(child: PendingNoteDocumentsEditor(documents: docs, onChanged: () => set(() {})))));
      expect(find.text('calcul.pdf'), findsOneWidget);
      expect(find.text('PDF · 2,0 Ko'), findsOneWidget);
      expect(find.text('Ajouter un autre document'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pending-doc-remove-0')));
      await tester.pumpAndSettle();
      expect(docs.map((d) => d.name), ['plan.docx']);
      expect(find.text('calcul.pdf'), findsNothing);
    });
  });

  group('détail', () {
    testWidgets('toutes les informations, documents et historique ; actions de modification si autorisé', (tester) async {
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: false));
      expect(api.where('GET', '/calculation-notes/7'), hasLength(1));
      for (final t in ['NC-2026-0007', 'Villa Hammamet — SARL Test', 'Identification', 'Observations générales', 'Calcul principal', 'Hypothèses de charge', 'Note créée', 'Document ajouté : Hypothèses.docx']) {
        expect(find.textContaining(t), findsWidgets, reason: t);
      }
      expect(find.text('Info Probar\ninfo@probardistribution.com'), findsOneWidget);
      expect(find.text('Mohamed\nmedwethekgc@gmail.com'), findsOneWidget);
      expect(find.text('Note de calcul dalle.pdf'), findsOneWidget); // nom réel du fichier
      expect(find.text('Note de calcul'), findsWidgets); // type
      expect(find.textContaining('PDF · 2,0 Ko'), findsOneWidget);
      expect(find.textContaining('DOCX · 1,5 Mo'), findsOneWidget);
      expect(find.byKey(const ValueKey('note-detail-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-detail-add-docs')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-doc-comment-d-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-doc-download-d-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-detail-readonly')), findsNothing);
    });

    testWidgets('modification : demandeur et observations envoyés (PATCH)', (tester) async {
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: false));
      await tester.tap(find.byKey(const ValueKey('note-detail-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('note-edit-comment')), 'Observations révisées');
      await tester.tap(find.byKey(const ValueKey('note-edit-save')));
      await tester.pumpAndSettle();
      expect(api.where('PATCH', '/calculation-notes/7').single.data, {'requesterId': 'u-ref', 'commentaire': 'Observations révisées'});
    });

    testWidgets('6. document : type et commentaire modifiés (PATCH), plus de nom saisi', (tester) async {
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: false));
      await tester.tap(find.byKey(const ValueKey('note-doc-comment-d-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('doc-edit-title')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('doc-edit-comment')), 'Charges révisées');
      await tester.tap(find.byKey(const ValueKey('doc-edit-save')));
      await tester.pumpAndSettle();
      expect(api.where('PATCH', '/calculation-notes/7/documents/d-2').single.data, {'commentaire': 'Charges révisées', 'documentType': ''});
    });

    testWidgets('sans droit (canEdit=false) : consultation uniquement', (tester) async {
      api.detailCanEdit = false;
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: false));
      expect(find.byKey(const ValueKey('note-detail-readonly')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-detail-edit')), findsNothing);
      expect(find.byKey(const ValueKey('note-detail-add-docs')), findsNothing);
      expect(find.byKey(const ValueKey('note-doc-comment-d-1')), findsNothing);
      expect(find.byKey(const ValueKey('note-doc-download-d-1')), findsOneWidget);
    });

    testWidgets('back-office : consultation même si le compte de référence peut modifier', (tester) async {
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: true, openEdit: true));
      expect(find.byKey(const ValueKey('note-detail-readonly')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-detail-edit')), findsNothing);
      expect(find.byKey(const ValueKey('note-detail-add-docs')), findsNothing);
      expect(find.byType(AlertDialog), findsNothing); // ?edit=1 ignoré
      expect(find.byKey(const ValueKey('note-doc-view-d-1')), findsOneWidget);
    });

    test('téléchargement : contenu authentifié par la route dédiée (jamais /uploads)', () async {
      final doc = NoteDocument.fromJson(_doc('d-1', 'Note.pdf', 'pdf', null, 13));
      final bytes = await CalculationNoteService.instance.fetchBytes(doc, inline: true);
      expect(utf8.decode(bytes), '%PDF-1.4 test');
      final r = api.requests.single;
      expect([r.path, r.queryParameters, r.responseType, r.headers['Authorization']], ['/calculation-notes/7/documents/d-1/download', {'inline': '1'}, ResponseType.bytes, 'Bearer jeton-de-test']);
    });
  });

  group('formulaire projet — Documents techniques', () {
    testWidgets('projet existant : notes liées, documents consultables et ajout d’une note', (tester) async {
      await _pump(tester, ProjectCalculationNotesSection(projectId: 'p-1', projectName: 'Villa Hammamet', drafts: const [], readOnly: false));
      expect(api.where('GET', '/calculation-notes').single.queryParameters, containsPair('projectId', 'p-1'));
      expect(find.text('Documents techniques – Notes de calcul'), findsOneWidget);
      expect(find.text('NC-2026-0007'), findsWidgets);
      expect(find.text('Note de calcul dalle.pdf'), findsWidgets);
      expect(find.text('Calcul principal'), findsWidgets);
      expect(find.byKey(const ValueKey('project-notes-add')), findsOneWidget);
    });

    testWidgets('nouveau projet : ajout facultatif de documents avant création', (tester) async {
      final drafts = [PendingNoteDocument(name: 'calcul.pdf', bytes: utf8.encode('%PDF-1.4'))];
      await _pump(tester, ProjectCalculationNotesSection(projectId: null, drafts: drafts, readOnly: false));
      expect(find.textContaining('Facultatif'), findsOneWidget);
      expect(find.textContaining('calcul.pdf'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('pending-doc-comment-0')), 'Note initiale');
      expect(api.requests, isEmpty); // rien n'est envoyé avant la création du projet
      // Création du projet → note liée au nouvel identifiant, commentaire conservé.
      final note = await tester.runAsync(() => submitProjectCalculationNoteDrafts('p-new', drafts));
      expect(note?.reference, 'NC-2026-0007');
      final fd = api.where('POST', '/calculation-notes').single.data as FormData;
      expect(fd.fields.firstWhere((f) => f.key == 'projectId').value, 'p-new');
      expect(fd.fields.firstWhere((f) => f.key == 'requesterId').value, 'u-me');
      expect(jsonDecode(fd.fields.firstWhere((f) => f.key == 'commentaires').value), ['Note initiale']);
      expect(drafts, isEmpty);
    });
  });

  group('validation des notes de calcul', () {
    testWidgets('badges de statut (orange, vert, rouge, gris) et filtre par statut', (tester) async {
      api.rows = [
        _row(1, 'NC-2026-0001'),
        _row(2, 'NC-2026-0002', status: 'VALIDEE'),
        _row(3, 'NC-2026-0003', status: 'REFUSEE'),
        _row(4, 'NC-2026-0004', status: 'ANNULEE'),
      ];
      await _pump(tester, const CalculationNotesScreen(readOnly: false));
      for (final (st, label) in [('EN_ATTENTE_VALIDATION', 'En attente de validation'), ('VALIDEE', 'Validée'), ('REFUSEE', 'Refusée'), ('ANNULEE', 'Annulée')]) {
        expect(find.descendant(of: find.byKey(ValueKey('note-status-$st')), matching: find.text(label)), findsOneWidget, reason: st);
      }
      Color colorOf(String st) => tester.widget<Icon>(find.descendant(of: find.byKey(ValueKey('note-status-$st')), matching: find.byType(Icon))).color!;
      expect(colorOf('EN_ATTENTE_VALIDATION'), const Color(0xFFEA580C));
      expect(colorOf('VALIDEE'), const Color(0xFF16A34A));
      expect(colorOf('REFUSEE'), const Color(0xFFDC2626));
      expect(colorOf('ANNULEE'), const Color(0xFF64748B));
      // Aucune décision possible ici (canDecide = false).
      expect(find.byKey(const ValueKey('note-validate-1')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('notes-filter-status-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refusée').last);
      await tester.pumpAndSettle();
      expect(api.where('GET', '/calculation-notes').last.queryParameters, containsPair('status', 'REFUSEE'));
    });

    testWidgets('rubrique du validateur : file en attente, colonnes, Valider (confirmation) et Refuser (motif obligatoire)', (tester) async {
      api.rows = [_row(7, 'NC-2026-0007', canDecide: true, docs: 2)];
      await _pump(tester, const CalculationNotesScreen(readOnly: false, validationMode: true));
      expect(api.where('GET', '/calculation-notes/validation').single.queryParameters, containsPair('status', 'EN_ATTENTE_VALIDATION'));
      expect(find.text('Validation des notes de calcul'), findsOneWidget);
      expect(find.byKey(const ValueKey('notes-new')), findsNothing);
      for (final t in ['NC-2026-0007', 'Villa Hammamet', 'Info Probar', 'Mohamed', '30/10/2026', 'Observations NC-2026-0007', 'Observations générales', 'Statut']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      for (final v in ['5', '30', '4', '9']) {
        expect(find.text(v), findsWidgets, reason: v); // indicateurs par statut
      }
      // Valider : confirmation puis POST avec la soumission attendue.
      await tester.tap(find.byKey(const ValueKey('note-validate-7')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Confirmez-vous la validation de la note NC-2026-0007'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-validate-confirm')));
      await tester.pumpAndSettle();
      expect(api.where('POST', '/calculation-notes/7/validate').single.data, {'submissionVersion': 1});
      // Refuser : bouton inactif tant que le motif est vide.
      await tester.tap(find.byKey(const ValueKey('note-reject-7')));
      await tester.pumpAndSettle();
      ElevatedButton confirm() => tester.widget<ElevatedButton>(find.byKey(const ValueKey('note-reject-confirm')));
      expect(confirm().onPressed, isNull);
      expect(find.text('Le motif est obligatoire.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('note-reject-reason')), '   ');
      await tester.pump();
      expect(confirm().onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('note-reject-reason')), 'Plans manquants');
      await tester.pump();
      expect(confirm().onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('note-reject-confirm')));
      await tester.pumpAndSettle();
      expect(api.where('POST', '/calculation-notes/7/reject').single.data, {'commentaire': 'Plans manquants', 'submissionVersion': 1});
    });

    testWidgets('back-office : rubrique de validation avec Valider / Refuser (décision autorisée par le backend), sans création', (tester) async {
      api.rows = [_row(7, 'NC-2026-0007', canDecide: true), _row(8, 'NC-2026-0008', status: 'VALIDEE')];
      await _pump(tester, const CalculationNotesScreen(readOnly: true, validationMode: true));
      expect(find.byKey(const ValueKey('notes-new')), findsNothing);
      expect(find.byKey(const ValueKey('note-validate-7')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-reject-7')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-validate-8')), findsNothing); // déjà validée
      expect(find.byKey(const ValueKey('note-edit-7')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('note-validate-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-validate-confirm')));
      await tester.pumpAndSettle();
      expect(api.where('POST', '/calculation-notes/7/validate'), hasLength(1));
    });

    testWidgets('détail (validateur) : boutons visibles, refus bloqué sans motif, validation confirmée', (tester) async {
      api.detailCanEdit = false;
      api.detailWorkflow = _workflow(canDecide: true);
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: false));
      expect(find.byKey(const ValueKey('note-workflow-card')), findsOneWidget);
      expect(find.text('Validateur : Mohamed Wethak Khochtali (medwethekgc@gmail.com)', findRichText: true), findsOneWidget);
      expect(find.byKey(const ValueKey('note-detail-cancel')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('note-detail-reject')));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('note-reject-confirm'))).onPressed, isNull);
      await tester.tap(find.text('Annuler').last);
      await tester.pumpAndSettle();
      expect(api.where('POST', '/calculation-notes/7/reject'), isEmpty);
      await tester.tap(find.byKey(const ValueKey('note-detail-validate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-validate-confirm')));
      await tester.pumpAndSettle();
      expect(api.where('POST', '/calculation-notes/7/validate'), hasLength(1));
    });

    testWidgets('détail (créateur) : annulation avec motif obligatoire ; pas de décision', (tester) async {
      api.detailWorkflow = _workflow(canCancel: true);
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: false));
      expect(find.byKey(const ValueKey('note-detail-validate')), findsNothing);
      expect(find.textContaining('En attente de la décision du validateur'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-detail-cancel')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('note-cancel-reason')), 'Créée en double');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('note-cancel-confirm')));
      await tester.pumpAndSettle();
      expect(api.where('POST', '/calculation-notes/7/cancel').single.data, {'motif': 'Créée en double'});
    });

    testWidgets('note refusée : motif affiché, soumission de nouveau ; note annulée : motif, aucune action', (tester) async {
      api.detailWorkflow = _workflow(status: 'REFUSEE', canCancel: true, extra: {'decidedBy': _validator, 'decidedAt': '2026-10-30T10:00:00.000Z', 'decisionComment': 'Plans manquants', 'canResubmit': true});
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: false));
      expect(find.text('Motif du refus : Plans manquants', findRichText: true), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-detail-resubmit')));
      await tester.pumpAndSettle();
      expect(api.where('POST', '/calculation-notes/7/resubmit'), hasLength(1));

      api.detailCanEdit = false;
      api.detailWorkflow = _workflow(status: 'ANNULEE', extra: {'cancelledBy': _me, 'cancelledAt': '2026-10-30T11:00:00.000Z', 'cancellationReason': 'Créée en double'});
      await _pump(tester, const CalculationNoteDetailScreen(key: ValueKey('second'), noteId: 7, readOnly: false));
      expect(find.text('Motif de l’annulation : Créée en double', findRichText: true), findsOneWidget);
      for (final k in ['note-detail-validate', 'note-detail-reject', 'note-detail-cancel', 'note-detail-resubmit', 'note-detail-edit', 'note-detail-add-docs']) {
        expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
      }
    });

    testWidgets('back-office : détail avec Valider / Refuser ; ni annulation, ni modification', (tester) async {
      api.detailWorkflow = _workflow(canDecide: true, canCancel: true);
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: true));
      expect(find.byKey(const ValueKey('note-workflow-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-detail-validate')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-detail-reject')), findsOneWidget);
      for (final k in ['note-detail-cancel', 'note-detail-edit', 'note-detail-add-docs', 'note-detail-assign']) {
        expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
      }
      // Refus : motif obligatoire, puis envoi.
      await tester.tap(find.byKey(const ValueKey('note-detail-reject')));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('note-reject-confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('note-reject-reason')), 'Plans non conformes');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('note-reject-confirm')));
      await tester.pumpAndSettle();
      expect(api.where('POST', '/calculation-notes/7/reject').single.data, {'commentaire': 'Plans non conformes', 'submissionVersion': 1});
    });

    test('notification : ouvre la note de calcul', () {
      final n = NotificationData.fromJson({'id': 'n1', 'title': 'Nouvelle note de calcul à valider', 'message': '…', 'isRead': false, 'type': 'CALCULATION_NOTE_PENDING', 'calculationNoteId': 42});
      expect(n.target, ('/notes-calcul/detail?id=42', 'Voir la note'));
      expect(NotificationData.fromJson({'id': 'n2', 'title': 't', 'message': 'm', 'type': 'X', 'calculationNoteId': null}).target, isNull);
    });
  });

  group('affectation', () {
    Map<String, String> fieldsOf(RequestOptions r) => Map.fromEntries((r.data as FormData).fields);

    testWidgets('formulaire : « Affecter à » (recherche nom / email, rôle affiché, retrait), envoyé à la création', (tester) async {
      await _pump(tester, const CalculationNoteFormDialog(projectId: 'p-1'));
      expect(find.text('Affecter à', findRichText: true), findsOneWidget);
      expect(find.text('Affecter à *', findRichText: true), findsNothing); // facultatif par défaut
      // Recherche par email.
      await tester.tap(find.byKey(const ValueKey('note-form-assignee')));
      await tester.pumpAndSettle();
      expect(find.text('Affecter la note à un collaborateur'), findsOneWidget);
      expect(find.text('faycelmarzouk@probardistribution.com · Utilisateur CRM'), findsOneWidget);
      expect(find.text('hadil.ibnhajfraj@gmail.com · Commercial'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('note-select-search')), 'FAYCELMARZOUK@');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-select-option-u-col2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('note-select-option-u-col')));
      await tester.pumpAndSettle();
      expect(find.text('Faycel Marzouk — faycelmarzouk@probardistribution.com · Utilisateur CRM'), findsOneWidget);
      // Retrait puis nouvelle sélection (par nom).
      await tester.tap(find.byKey(const ValueKey('note-select-clear')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Faycel Marzouk —'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('note-form-assignee')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('note-select-search')), 'hadil');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-select-option-u-col2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-form-submit')));
      await tester.pumpAndSettle();
      expect(fieldsOf(api.where('POST', '/calculation-notes').single), {'projectId': 'p-1', 'requesterId': 'u-me', 'assignedToUserId': 'u-col2'});
      expect(tester.takeException(), isNull);
    });

    testWidgets('formulaire : sans affectation (facultative), aucun champ envoyé', (tester) async {
      await _pump(tester, const CalculationNoteFormDialog(projectId: 'p-1'));
      await tester.tap(find.byKey(const ValueKey('note-form-submit')));
      await tester.pumpAndSettle();
      expect(fieldsOf(api.where('POST', '/calculation-notes').single).containsKey('assignedToUserId'), isFalse);
    });

    testWidgets('formulaire : affectation obligatoire si la règle serveur est activée', (tester) async {
      api.assigneeRequired = true;
      await _pump(tester, const CalculationNoteFormDialog(projectId: 'p-1'));
      expect(find.text('Affecter à *', findRichText: true), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-form-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Sélectionnez l’utilisateur affecté.'), findsOneWidget);
      expect(api.where('POST', '/calculation-notes'), isEmpty);
    });

    testWidgets('tablette : formulaire réorganisé sans débordement', (tester) async {
      await _pump(tester, const CalculationNoteFormDialog(), size: const Size(820, 1100));
      expect(tester.takeException(), isNull);
      // Ordre : ID, référence, date, créé par, projet, demandeur, affecter à, observations.
      double y(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
      expect(y('note-form-id') < y('note-form-project'), isTrue);
      expect(y('note-form-project') < y('note-form-requester'), isTrue);
      expect(y('note-form-requester'), y('note-form-assignee')); // côte à côte
      expect(y('note-form-assignee') < y('note-form-comment'), isTrue);
    });

    testWidgets('détail : affecté, historique, suivi des emails, modification et relance', (tester) async {
      api.detailWorkflow = _workflow(extra: {'assignedTo': _colleague, 'assignedAt': '2026-10-30T09:00:00.000Z', 'assignedBy': _me});
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: false));
      expect(find.byKey(const ValueKey('note-assignment-card')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('note-assignee-name'))).data, 'Faycel Marzouk');
      expect(find.text('Faycel Marzouk\nfaycelmarzouk@probardistribution.com'), findsOneWidget); // en-tête
      expect(find.textContaining('Hadil → Faycel Marzouk · par Mohamed'), findsOneWidget);
      expect(find.textContaining('Aucun → Hadil · par Mohamed'), findsOneWidget);
      // Suivi des emails : statut, erreur, relance.
      expect(find.textContaining('Envoyé'), findsWidgets);
      expect(find.textContaining('Échec d’envoi · 550 mailbox unavailable'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-emails-resend')));
      await tester.pumpAndSettle();
      expect(api.where('POST', '/calculation-notes/7/email-notifications/resend'), hasLength(1));
      // Modification : autre collaborateur.
      await tester.tap(find.byKey(const ValueKey('note-detail-assign')));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('note-assign-save'))).onPressed, isNull); // inchangé
      await tester.tap(find.byKey(const ValueKey('note-assign-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-select-option-u-col2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-assign-save')));
      await tester.pumpAndSettle();
      expect(api.where('PUT', '/calculation-notes/7/assignment').single.data, {'assignedToUserId': 'u-col2'});
      // Retrait.
      await tester.tap(find.byKey(const ValueKey('note-detail-assign')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-select-clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-assign-save')));
      await tester.pumpAndSettle();
      expect(api.where('PUT', '/calculation-notes/7/assignment').last.data, {'assignedToUserId': null});
    });

    testWidgets('détail sans droit / back-office : ni modification d’affectation, ni relance', (tester) async {
      api.detailCanEdit = false;
      api.detailWorkflow = _workflow(extra: {'assignedTo': _colleague});
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: true));
      expect(find.byKey(const ValueKey('note-detail-assign')), findsNothing);
      expect(find.byKey(const ValueKey('note-emails-resend')), findsNothing);
      expect(tester.widget<Text>(find.byKey(const ValueKey('note-assignee-name'))).data, 'Faycel Marzouk');
    });

    testWidgets('suivi des emails non chargé sans droit (canManageNotifications = false)', (tester) async {
      api.detailWorkflow = {'canManageNotifications': false};
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: false));
      expect(find.byKey(const ValueKey('note-emails-card')), findsNothing);
      expect(api.where('GET', '/calculation-notes/7/email-notifications'), isEmpty);
      expect(find.byKey(const ValueKey('note-assignee-none')), findsOneWidget);
    });
  });

  group('documents techniques et utilisateur affecté', () {
    testWidgets('carte de document à envoyer : nom réel, format et taille, type, commentaire, aperçu PDF, suppression — sans « Nom du document »', (tester) async {
      final docs = [
        PendingNoteDocument(name: 'Calcul dalle.pdf', bytes: List.filled(3072, 1)),
        PendingNoteDocument(name: 'Métré.xlsx', bytes: [1, 2, 3]),
      ];
      await _pump(tester, StatefulBuilder(builder: (c, set) => SingleChildScrollView(child: PendingNoteDocumentsEditor(documents: docs, onChanged: () => set(() {})))));
      expect(find.text('Calcul dalle.pdf'), findsOneWidget);
      expect(find.text('PDF · 3,0 Ko'), findsOneWidget);
      expect(find.text('XLSX · 3 o'), findsOneWidget);
      expect(find.text('Nom du document'), findsNothing);
      expect(find.text('Type de document'), findsNWidgets(2));
      expect(find.text('Commentaire'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('pending-doc-preview-0')), findsOneWidget); // PDF
      expect(find.byKey(const ValueKey('pending-doc-preview-1')), findsNothing); // Excel : pas d'aperçu
      // Type : liste complète, dans l'ordre demandé.
      await tester.tap(find.byKey(const ValueKey('pending-doc-type-0-Calcul dalle.pdf')));
      await tester.pumpAndSettle();
      for (final t in ['Non précisé', 'Note de calcul', 'Plan', 'Hypothèses', 'Métré', 'Rapport', 'Annexe', 'Autre']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();
      expect(docs[0].documentType, 'plan');
      await tester.enterText(find.byKey(const ValueKey('pending-doc-comment-0')), 'Plan R+1');
      expect(docs[0].comment.text, 'Plan R+1');
      await tester.tap(find.byKey(const ValueKey('pending-doc-remove-1')));
      await tester.pumpAndSettle();
      expect(docs.map((d) => d.name), ['Calcul dalle.pdf']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('utilisateur affecté : toutes les informations, documents reçus avec commentaires, zone de dépôt', (tester) async {
      api.detailCanEdit = false;
      api.detailWorkflow = {..._workflow(extra: {'assignedTo': _colleague}), 'canAddComplementary': true, 'canManageNotifications': false};
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: false));
      for (final t in ['NC-2026-0007', 'Villa Hammamet — SARL Test', 'Observations générales', 'Note de calcul dalle.pdf', 'Hypothèses.docx', 'Calcul principal', 'Hypothèses de charge']) {
        expect(find.textContaining(t), findsWidgets, reason: t);
      }
      expect(find.text('Faycel Marzouk\nfaycelmarzouk@probardistribution.com'), findsOneWidget);
      expect(find.byKey(const ValueKey('note-status-EN_ATTENTE_VALIDATION')), findsWidgets);
      expect(find.byKey(const ValueKey('note-doc-download-d-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-doc-view-d-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-doc-comment-d-1')), findsNothing); // pas d'édition des documents initiaux
      expect(find.text('Documents complémentaires – Réponse de l’utilisateur affecté (0)'), findsOneWidget);
      expect(find.text('Glissez-déposez vos documents ici ou cliquez pour parcourir vos fichiers'), findsOneWidget);
    });

    testWidgets('dépôt : plusieurs fichiers, formats refusés signalés, type et commentaire par fichier, envoi', (tester) async {
      api.detailCanEdit = false;
      api.detailWorkflow = {..._workflow(extra: {'assignedTo': _colleague}), 'canAddComplementary': true, 'canManageNotifications': false};
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: false));
      // Dépôt simulé (le glisser-déposer du navigateur appelle la même méthode).
      final zone = tester.state<NoteDropzoneState>(find.byType(NoteDropzone));
      zone.acceptFiles([
        (name: 'Réponse.pdf', bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 r'))),
        (name: 'Métré v2.xlsx', bytes: Uint8List.fromList([80, 75, 3, 4])),
        (name: 'virus.exe', bytes: Uint8List.fromList([77, 90])),
      ]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Format non accepté : virus.exe'), findsOneWidget);
      expect(find.text('Réponse.pdf'), findsOneWidget);
      expect(find.text('Métré v2.xlsx'), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-doc-add')), findsNothing); // la zone de dépôt suffit
      await tester.enterText(find.byKey(const ValueKey('pending-doc-comment-0')), 'Réponse aux hypothèses');
      await tester.tap(find.byKey(const ValueKey('note-complementary-send')));
      await tester.pumpAndSettle();
      final fd = api.where('POST', '/calculation-notes/7/complementary-documents').single.data as FormData;
      expect(fd.files.map((f) => f.value.filename), ['Réponse.pdf', 'Métré v2.xlsx']);
      expect(jsonDecode(fd.fields.firstWhere((f) => f.key == 'commentaires').value), ['Réponse aux hypothèses', '']);
      expect(jsonDecode(fd.fields.firstWhere((f) => f.key == 'types').value), [null, null]);
      // Après envoi : liste vidée, document complémentaire affiché avec son badge.
      expect(find.byKey(const ValueKey('note-complementary-send')), findsNothing);
      expect(find.text('Complémentaire'), findsOneWidget);
      expect(find.text('Documents complémentaires – Réponse de l’utilisateur affecté (1)'), findsOneWidget);
      // Les documents initiaux sont toujours là.
      expect(find.text('Note de calcul dalle.pdf'), findsOneWidget);
    });

    testWidgets('clic sur la zone : sélection de plusieurs fichiers', (tester) async {
      final received = <PendingNoteDocument>[];
      await _pump(
        tester,
        NoteDropzone(
          onFiles: received.addAll,
          pickFiles: () async => [PendingNoteDocument(name: 'a.pdf', bytes: [1]), PendingNoteDocument(name: 'b.docx', bytes: [2])],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('note-dropzone')));
      await tester.pumpAndSettle();
      expect(received.map((d) => d.name), ['a.pdf', 'b.docx']);
    });

    testWidgets('validateur / autres lecteurs : documents complémentaires visibles, aucune zone de dépôt', (tester) async {
      api.detailCanEdit = false;
      api.detailWorkflow = {..._workflow(canDecide: true, extra: {'assignedTo': _colleague}), 'canAddComplementary': false};
      api.complementaryDocs = [_doc('d-3', 'Plan ferraillage.pdf', 'pdf', 'Plan mis à jour', 4096, origin: 'COMPLEMENTARY', by: _colleague)];
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: false));
      expect(find.text('Plan ferraillage.pdf'), findsOneWidget);
      expect(find.text('Plan mis à jour'), findsOneWidget);
      expect(find.text('Complémentaire'), findsOneWidget);
      expect(find.textContaining('Faycel Marzouk'), findsWidgets); // déposé par
      expect(find.byType(NoteDropzone), findsNothing);
      expect(find.byKey(const ValueKey('note-detail-validate')), findsOneWidget); // décision toujours possible
      // Initiaux et complémentaires dans des cartes distinctes.
      expect(find.descendant(of: find.byKey(const ValueKey('note-initial-documents')), matching: find.text('Plan ferraillage.pdf')), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('note-complementary-card')), matching: find.text('Plan ferraillage.pdf')), findsOneWidget);
    });

    testWidgets('back-office : consultation, aucune zone de dépôt', (tester) async {
      api.detailWorkflow = {..._workflow(extra: {'assignedTo': _colleague}), 'canAddComplementary': true};
      await _pump(tester, const CalculationNoteDetailScreen(noteId: 7, readOnly: true));
      expect(find.byType(NoteDropzone), findsNothing);
      expect(find.byKey(const ValueKey('note-complementary-card')), findsOneWidget);
    });
  });
}
