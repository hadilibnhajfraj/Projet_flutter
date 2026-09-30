// Contrôle Machine PROMESH — mode CRÉATION (champs vides) vs mode ÉDITION
// (valeurs enregistrées chargées), avec les VRAIES fonctions utilisées par
// PorPromeshController (utils/por_promesh_process_rows.dart) et une VRAIE
// réponse de GET /por-promesh/:id (fiche créée via le backend avec
// "Pression air comprimé" = 5 — test/fixtures/por_promesh_machine_api_response.dart).
// Dart pur : exécutable sur la VM.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/por_promesh/model/por_promesh_model.dart';
import 'package:dash_master_toolkit/forms/por_promesh/utils/por_promesh_diff.dart';
import 'package:dash_master_toolkit/forms/por_promesh/utils/por_promesh_process_rows.dart';

import 'fixtures/por_promesh_machine_api_response.dart';

const _blocs = ['controle_08h20', 'controle_10h20', 'controle_14h20'];
const _b = 'controle_08h20';
const _pression = "Pression d'air comprimé";
// Même liste que PorPromeshController (processParamsRetired).
const _retired = ["Température d'eau", "Fuite d'eau", 'Etat disque de coupe'];

// Valeurs saisies à la création (payload envoyé au backend pour le fixture).
const _saved = {
  'Diamètre de bar': '8',
  'Température de machine': '185',
  _pression: '5',
  'Validation impression': 'Conforme',
  'Nombre de barre en longueur': '42',
  'Dimensions de maille': '150',
  'Dimensions côté 1 long': '6000',
  'Dimensions côté 2 long': '2400',
  "Fuite d'air comprimé": 'Non',
  'Nombre de barre en largeur': '17',
};

PorPromeshModel _apiFiche() => PorPromeshModel.fromJson(jsonDecode(kPorPromeshMachineApiResponse) as Map<String, dynamic>);

ProcessControlRow _row(Map<String, List<ProcessControlRow>> blocs, String p, [String bloc = _b]) =>
    blocs[bloc]!.firstWhere((r) => r.parametre == p);

void main() {
  test('ÉTAPES 1-2 — création : tous les champs sont vides (aucune valeur par défaut)', () {
    final blocs = buildProcessControlBlocs(_blocs);
    for (final rows in blocs.values) {
      for (final r in rows) {
        expect(r.p1.text, '', reason: r.parametre);
      }
    }
    expect(_row(blocs, _pression).p1.text, '');
  });

  test('ÉTAPE 5 — édition : chaque champ reprend la valeur ENREGISTRÉE (réponse API réelle)', () {
    final blocs = buildProcessControlBlocs(_blocs);
    final pressionCtrl = _row(blocs, _pression).p1; // controller existant
    loadProcessRows(blocs, _apiFiche().processControl);

    expect(_row(blocs, _pression).p1.text, '5');
    for (final e in _saved.entries) {
      expect(_row(blocs, e.key).p1.text, e.value, reason: e.key);
    }
    // Même instance : le controller n'est jamais recréé par le chargement.
    expect(identical(_row(blocs, _pression).p1, pressionCtrl), isTrue);
    expect(pressionCtrl.text, '5');
  });

  test('champs Contrôle Machine (boutons) : valeurs enregistrées chargées', () {
    final m = _apiFiche();
    expect(m.air, '> 6 bars');
    expect(m.niveauBainEau, 'Bien');
    expect(m.etatPistons, 'Propre');
    expect(m.fluideVisuel, 'Absence');
    expect(m.temperaturePistons, 170.0);
  });

  test('ÉTAPES 6-8 — 5 → 6 : la valeur ACTUELLE part dans le payload, puis est relue', () {
    final blocs = buildProcessControlBlocs(_blocs);
    loadProcessRows(blocs, _apiFiche().processControl);
    final before = serializeProcessRows(blocs, exclude: _retired);

    _row(blocs, _pression).p1.text = '6';
    final after = serializeProcessRows(blocs, exclude: _retired);

    final sent = after.firstWhere((r) => r['bloc'] == _b && r['parametre'] == _pression);
    expect(sent['valeurP1'], '6');
    // Les autres champs repartent inchangés, les paramètres retirés jamais.
    for (final e in _saved.entries.where((e) => e.key != _pression)) {
      expect(after.firstWhere((r) => r['bloc'] == _b && r['parametre'] == e.key)['valeurP1'], e.value);
    }
    expect(after.any((r) => _retired.contains(r['parametre'])), isFalse);
    // Diff : seul `processControl` change → UPDATE partiel.
    expect(changedFields({'processControl': before}, {'processControl': after}).keys, ['processControl']);

    // Réouverture : le serveur renvoie les lignes enregistrées → "6".
    final reopened = buildProcessControlBlocs(_blocs);
    loadProcessRows(reopened, after);
    expect(_row(reopened, _pression).p1.text, '6');
  });

  test('ouvrir puis enregistrer sans modifier : payload identique (rien ne change)', () {
    final blocs = buildProcessControlBlocs(_blocs);
    loadProcessRows(blocs, _apiFiche().processControl);
    final a = serializeProcessRows(blocs, exclude: _retired);
    final b = serializeProcessRows(blocs, exclude: _retired);
    expect(changedFields({'processControl': a}, {'processControl': b}), isEmpty);
  });

  test('passer à une NOUVELLE fiche après une édition : plus aucune ancienne valeur', () {
    final blocs = buildProcessControlBlocs(_blocs);
    loadProcessRows(blocs, _apiFiche().processControl);
    clearProcessRows(blocs);
    for (final rows in blocs.values) {
      for (final r in rows) {
        expect(r.p1.text, '', reason: r.parametre);
      }
    }
  });
}
