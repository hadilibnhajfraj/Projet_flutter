// Contrat JSON « Notes de calcul » : les modèles Dart lisent les RÉPONSES
// RÉELLES du backend (6 cas : sans document, plusieurs documents, en attente,
// validée, refusée, annulée — vues par le créateur, Wethek et le back-office).
// Réponses produites par le test backend test/calculationNoteApiContract.test.js
// avec CALCULATION_NOTES_CONTRACT_DUMP=<dossier> ; ce test relit ce dossier
// (même variable). Sans elle, il est ignoré.
//
// Régression couverte : `summary.byCreator` est une LISTE ; l'ancien code
// convertissait chaque valeur de `summary` en `num?` →
// « type 'List<dynamic>' is not a subtype of type 'num?' ».

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/calculation_notes/model/calculation_note.dart';
import 'package:dash_master_toolkit/calculation_notes/service/calculation_note_service.dart';

void main() {
  final dir = Platform.environment['CALCULATION_NOTES_CONTRACT_DUMP'];
  final files = dir == null || !Directory(dir).existsSync()
      ? <File>[]
      : Directory(dir).listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
  Map<String, dynamic> read(File f) => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  String name(File f) => f.uri.pathSegments.last;

  group('réponses réelles du backend', () {
    test('listes et file de validation : compteurs numériques, byCreator lu comme une liste', () {
      final pages = files.where((f) => name(f).contains('-liste') || name(f).endsWith('-validation.json')).toList();
      expect(pages, isNotEmpty);
      for (final f in pages) {
        final json = read(f);
        final page = CalculationNotePage.fromJson(json);
        final summary = json['summary'] as Map;
        // Le champ fautif est bien une liste dans la réponse réelle.
        expect(summary['byCreator'], isA<List>(), reason: name(f));
        for (final k in ['total', 'thisMonth', 'documents', 'mine', 'EN_ATTENTE_VALIDATION', 'VALIDEE', 'REFUSEE', 'ANNULEE']) {
          expect(page.summary[k], summary[k], reason: '${name(f)} $k');
        }
        expect(page.summary.containsKey('byCreator'), isFalse);
        expect(page.byCreator.fold<int>(0, (a, c) => a + c.count), page.summary['total'], reason: name(f));
        expect(page.data.length, (json['data'] as List).length);
        expect(page.total, (json['pagination'] as Map)['total']);
        for (final n in page.data) {
          expect(kNoteStatusLabels.containsKey(n.workflow.status), isTrue);
        }
        // Ancien code : échoue exactement comme dans la console Chrome.
        expect(() => summary.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)), throwsA(isA<TypeError>()), reason: name(f));
      }
    });

    test('statuts filtrés : chaque liste ne contient que son statut', () {
      for (final (suffix, status) in [('liste-en-attente', kNoteStatusPending), ('liste-validees', kNoteStatusValidated), ('liste-refusees', kNoteStatusRejected), ('liste-annulees', kNoteStatusCancelled)]) {
        for (final f in files.where((f) => name(f).endsWith('$suffix.json'))) {
          final page = CalculationNotePage.fromJson(read(f));
          expect(page.data, isNotEmpty, reason: name(f));
          expect(page.data.every((n) => n.workflow.status == status), isTrue, reason: name(f));
        }
      }
    });

    test('détails des 6 cas, pour chaque compte : documents, commentaires, statut, droits', () {
      final details = files.where((f) => name(f).contains('-detail-')).toList();
      // 5 notes × 3 comptes ; « en attente » = les notes sans document et à
      // plusieurs documents (jamais décidées).
      expect(details.length, 15);
      for (final f in details) {
        final json = read(f);
        final d = CalculationNoteDetail.fromJson(json['data'] as Map);
        final raw = json['data'] as Map;
        expect(d.documents.length, (raw['documents'] as List).length, reason: name(f));
        expect(d.history.length, (raw['history'] as List).length, reason: name(f));
        if (name(f).endsWith('sansDocument.json')) expect([d.documents.isEmpty, d.workflow.status], [true, kNoteStatusPending]);
        if (name(f).endsWith('plusieursDocuments.json')) {
          expect(d.documents.map((x) => x.commentaire), ['Commentaire 1', 'Commentaire 2', 'Commentaire 3']);
          expect(d.documents.first.documentType, 'note_de_calcul');
          expect(d.workflow.status, kNoteStatusPending);
        }
        if (name(f).endsWith('validee.json')) expect(d.workflow.status, kNoteStatusValidated);
        if (name(f).endsWith('refusee.json')) expect([d.workflow.status, d.workflow.decisionComment], [kNoteStatusRejected, 'Plans manquants']);
        if (name(f).endsWith('annulee.json')) expect([d.workflow.status, d.workflow.cancellationReason], [kNoteStatusCancelled, 'Doublon']);
        if (name(f).startsWith('backoffice-')) expect(d.canEdit, isFalse);
      }
    });

    test('options : listes lues', () {
      for (final f in files.where((f) => name(f).endsWith('-options.json'))) {
        final o = CalculationNoteOptions.fromJson(read(f)['data'] as Map);
        expect(o.requesters, isNotEmpty, reason: name(f));
        expect(o.assignees, isNotEmpty, reason: name(f));
      }
    });
  }, skip: files.isEmpty ? 'CALCULATION_NOTES_CONTRACT_DUMP absent : réponses réelles non disponibles' : null);

  group('robustesse de la désérialisation (indépendante du backend)', () {
    test('summary : byCreator (liste) jamais converti en nombre', () {
      final page = CalculationNotePage.fromJson({
        'data': const [],
        'pagination': {'page': 1, 'limit': 20, 'total': 3, 'totalPages': 1},
        'summary': {
          'total': 3,
          'EN_ATTENTE_VALIDATION': 1,
          'byCreator': [
            {'user': {'id': 'u1', 'email': 'a@b.c', 'name': 'A'}, 'count': 3},
          ],
        },
      });
      expect(page.summary, {'total': 3, 'EN_ATTENTE_VALIDATION': 1});
      expect(page.byCreator.single.count, 3);
    });

    test('valeur inattendue : erreur explicite nommant le champ, jamais une TypeError anonyme', () {
      expect(
        () => CalculationNoteSummary.fromJson({'id': [1], 'reference': 'NC'}),
        throwsA(isA<CalculationNoteFormatException>().having((e) => e.field, 'champ', 'id')),
      );
      expect(noteErrorMessage(const CalculationNoteFormatException('id', null)), contains('« id »'));
      // Compteur facultatif mal formé : valeur par défaut, pas de plantage.
      final n = CalculationNoteSummary.fromJson({'id': 7, 'reference': 'NC', 'documentsCount': [1, 2]});
      expect(n.documentsCount, 0);
    });
  });
}
