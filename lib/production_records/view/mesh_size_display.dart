// lib/production_records/view/mesh_size_display.dart
//
// AFFICHAGE d'une dimension de maille — présentation uniquement : appliqué
// juste avant le widget `Text`, jamais aux données, aux regroupements, aux
// tris ni aux exports.
//
// Tous les séparateurs connus (x, X, ×, ainsi que * et / déjà utilisés par les
// fiches existantes) deviennent « X » entouré d'un espace :
//   20x20 → 20 X 20 · 20X20 → 20 X 20 · 20 x 20 → 20 X 20 · 12 × 12 → 12 X 12
//   20*20 → 20 X 20 · 200/200 → 200 X 200 · 15 x 15 mm → 15 X 15 mm
// Nombres et unités sont conservés.

final _meshSeparators = RegExp(r'\s*[xX×*/]\s*');

String formatMeshSizeForDisplay(dynamic value) {
  if (value == null) return '';
  return value.toString().replaceAll(_meshSeparators, ' X ').trim();
}
