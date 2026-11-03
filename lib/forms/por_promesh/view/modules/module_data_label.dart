// lib/forms/por_promesh/view/modules/module_data_label.dart
//
// Libellé d'état d'une carte-module de la grille de saisie, à partir des
// données RÉELLEMENT chargées de la fiche : jamais « Aucune donnée
// enregistrée » lorsqu'un module contient des valeurs, même incomplètes.

import 'package:intl/intl.dart';

String moduleDataLabel({required bool completed, required bool hasData, required DateTime? lastUpdatedAt}) {
  if (completed) {
    return lastUpdatedAt == null ? 'Données enregistrées' : 'Modifié le ${DateFormat('dd/MM/yyyy à HH:mm').format(lastUpdatedAt)}';
  }
  if (hasData) return 'Données partielles enregistrées — à compléter';
  return 'Aucune donnée enregistrée';
}
