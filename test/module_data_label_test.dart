// Carte-module de la grille de saisie : libellé fidèle aux données chargées.
// « Aucune donnée enregistrée » uniquement si le module est réellement vide.

import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/por_promesh/view/modules/module_data_label.dart';

void main() {
  final dt = DateTime(2026, 10, 21, 9, 55);

  test('module complet : date de modification', () {
    expect(moduleDataLabel(completed: true, hasData: true, lastUpdatedAt: dt), 'Modifié le 21/10/2026 à 09:55');
  });

  test('module complet sans date connue : jamais « Aucune donnée »', () {
    expect(moduleDataLabel(completed: true, hasData: true, lastUpdatedAt: null), 'Données enregistrées');
  });

  test('données présentes mais incomplètes (ex. m² saisi, diamètres absents)', () {
    expect(moduleDataLabel(completed: false, hasData: true, lastUpdatedAt: dt), 'Données partielles enregistrées — à compléter');
  });

  test('module réellement vide en base', () {
    expect(moduleDataLabel(completed: false, hasData: false, lastUpdatedAt: dt), 'Aucune donnée enregistrée');
  });
}
