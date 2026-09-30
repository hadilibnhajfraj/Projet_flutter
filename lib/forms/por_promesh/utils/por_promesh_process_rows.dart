// lib/forms/por_promesh/utils/por_promesh_process_rows.dart
//
// Champs "Contrôle Process" du Contrôle Machine PROMESH (Diamètre de barre,
// Température machine, Pression air comprimé, État impression, dimensions,
// nombres de barres...) — une ligne par (bloc, paramètre), chacune avec ses
// TextEditingController PERSISTANTS (créés une seule fois avec le contrôleur
// permanent, jamais dans un build(), jamais recréés).
//
// Chargement et sérialisation isolés ici (sans dépendance web) pour être
// testés tels quels sur la VM — utilisés par PorPromeshController.
//   - création : toutes les lignes vides ('') — aucune valeur par défaut ;
//   - édition  : chaque ligne reprend la valeur renvoyée par l'API
//     (GET /por-promesh/:id → processControl[]), '' si absente ;
//   - envoi    : la valeur ACTUELLE de chaque controller.

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class ProcessControlRow {
  final String parametre;
  final p1 = TextEditingController();
  final p2 = TextEditingController();
  final RxBool corP1 = false.obs;
  final RxBool corP2 = false.obs;

  ProcessControlRow(this.parametre);

  void clear() {
    p1.clear();
    p2.clear();
    corP1.value = false;
    corP2.value = false;
  }

  void dispose() {
    p1.dispose();
    p2.dispose();
  }
}

/// Grille à lignes fixes, répétée pour chaque créneau de contrôle.
const List<String> kProcessControlParametres = [
  'Niveau bain de résine',
  'Diamètre de bar',
  'Température de machine',
  "Température d'eau",
  "Pression d'air comprimé",
  'Validation impression',
  'Nombre de barre en longueur',
  'Dimensions de maille',
  'Dimensions côté 1 long',
  'Dimensions côté 2 long',
  "Fuite d'eau",
  "Fuite d'air comprimé",
  'Etat disque de coupe',
  'Nombre de barre en largeur',
];

Map<String, List<ProcessControlRow>> buildProcessControlBlocs(Iterable<String> blocs) => {
      for (final bloc in blocs) bloc: kProcessControlParametres.map((p) => ProcessControlRow(p)).toList(),
    };

/// Mode ÉDITION : remplit chaque ligne avec la valeur enregistrée (API),
/// '' si la fiche n'a pas de valeur pour ce (bloc, paramètre). Écrit dans les
/// controllers EXISTANTS (jamais recréés) — le formulaire affiché se met à
/// jour sans reconstruction.
void loadProcessRows(Map<String, List<ProcessControlRow>> blocs, List<Map<String, dynamic>> apiRows) {
  final byKey = <String, Map<String, dynamic>>{
    for (final row in apiRows) '${row['bloc'] ?? ''}|${row['parametre'] ?? ''}': row,
  };
  for (final entry in blocs.entries) {
    for (final row in entry.value) {
      final data = byKey['${entry.key}|${row.parametre}'];
      row.p1.text = data?['valeurP1']?.toString() ?? '';
      row.p2.text = data?['valeurP2']?.toString() ?? '';
      row.corP1.value = data?['corP1'] == true;
      row.corP2.value = data?['corP2'] == true;
    }
  }
}

/// Mode CRÉATION : toutes les lignes vides.
void clearProcessRows(Map<String, List<ProcessControlRow>> blocs) {
  for (final rows in blocs.values) {
    for (final row in rows) {
      row.clear();
    }
  }
}

/// Valeurs ACTUELLES des controllers → payload `processControl` (les
/// paramètres [exclude] — retirés de l'interface — ne sont jamais envoyés).
List<Map<String, dynamic>> serializeProcessRows(Map<String, List<ProcessControlRow>> blocs, {Iterable<String> exclude = const []}) {
  final excluded = exclude.toSet();
  return [
    for (final entry in blocs.entries)
      for (final row in entry.value)
        if (!excluded.contains(row.parametre))
          {
            'bloc': entry.key,
            'parametre': row.parametre,
            'valeurP1': row.p1.text.trim(),
            'corP1': row.corP1.value,
            'valeurP2': row.p2.text.trim(),
            'corP2': row.corP2.value,
          },
  ];
}
