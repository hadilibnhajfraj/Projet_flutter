// lib/forms/por_promesh/utils/por_promesh_diff.dart
//
// Diff du formulaire PROMESH pour l'UPDATE partiel (PUT /por-promesh/:id) —
// Dart pur (aucune dépendance Flutter/web), utilisé par
// PorPromeshController.pendingChanges().
//
// Règles :
// - '' et null sont équivalents, les nombres sont comparés en double, les
//   maps indépendamment de l'ordre des clés → une différence de
//   représentation n'est jamais prise pour une modification ;
// - l'instantané est une copie PROFONDE → une ligne de tableau modifiée en
//   place (même objet Map) reste détectée ;
// - vider un champ EST une modification (null envoyé).

import 'dart:convert';

dynamic normalizeForDiff(dynamic v) {
  if (v == null) return null;
  if (v is String) return v.trim().isEmpty ? null : v.trim();
  if (v is num) return v.toDouble();
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: normalizeForDiff(v[k])};
  }
  if (v is List) return v.map(normalizeForDiff).toList();
  return v;
}

bool sameForDiff(dynamic a, dynamic b) => jsonEncode(normalizeForDiff(a)) == jsonEncode(normalizeForDiff(b));

/// Copie profonde d'un payload JSON (maps/listes imbriquées comprises).
Map<String, dynamic> deepCopyJson(Map<String, dynamic> json) => jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

/// Champs de [current] différents de [snapshot] — payload exact du PUT.
Map<String, dynamic> changedFields(Map<String, dynamic> snapshot, Map<String, dynamic> current) => {
      for (final e in current.entries)
        if (!sameForDiff(e.value, snapshot[e.key])) e.key: e.value,
    };
