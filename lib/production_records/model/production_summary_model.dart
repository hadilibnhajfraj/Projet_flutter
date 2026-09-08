// lib/production_records/model/production_summary_model.dart
//
// "Production Summary" — même jeu de fiches que "Production records" (une
// ligne par fiche PROBAR/PROMESH, voir production_record_model.dart), pas
// une agrégation. Mirrors GET /production-records/summary (backend :
// modules/production-records/services/productionRecords.service.js#getProductionSummary).
// Aucune donnée dupliquée : lecture seule des fiches existantes, `rows`
// réutilise directement ProductionRecordModel (même DTO backend que
// "Fiches de production" — normalizePromesh/normalizeProbar), jamais un
// second schéma parallèle.

import 'production_record_model.dart';

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
  return 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Un tableau complet (PROMESH ou PROBAR) — fiches individuelles + total général.
class ProductionSummaryTable {
  final List<ProductionRecordModel> rows;
  final double grandTotal;
  final String unit;
  final int totalRecords;
  // §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS RECOVERABLES
  // — total Waste (kg), mirrors `grandTotalWaste`/`wasteUnit` backend (voir
  // productionRecords.service.js#buildPromeshSummary/buildProbarSummary) :
  // somme des dates DISTINCTES du tableau, jamais une somme "par ligne"
  // (double-compterait une date partagée par plusieurs lignes).
  final double grandTotalWaste;
  final String wasteUnit;

  const ProductionSummaryTable({
    this.rows = const [],
    this.grandTotal = 0,
    this.unit = '',
    this.totalRecords = 0,
    this.grandTotalWaste = 0,
    this.wasteUnit = 'kg',
  });

  factory ProductionSummaryTable.fromJson(Map<String, dynamic> json, {required bool isPromesh}) {
    return ProductionSummaryTable(
      rows: (json['rows'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ProductionRecordModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      grandTotal: _toDouble(json['grandTotal']),
      unit: (json['unit'] ?? '').toString(),
      totalRecords: _toInt(json['totalRecords']),
      grandTotalWaste: _toDouble(json['grandTotalWaste']),
      wasteUnit: (json['wasteUnit'] ?? 'kg').toString(),
    );
  }
}

// Affichage du Cell size PROMESH — "85*50"/"85/50" -> "85X50" (uniquement
// pour l'affichage : la valeur enregistrée en base et envoyée par l'API
// garde son séparateur d'origine, jamais modifiée ici). "/" et "*" sont
// tous deux utilisés comme séparateur selon la fiche d'origine — les deux
// sont normalisés vers "X". Centralisé pour être réutilisé partout où le
// Cell size PROMESH est affiché (écran Summary, exports Excel et PDF).
String formatCellSize(Object? value) {
  final s = value?.toString() ?? '';
  return s.replaceAll('/', 'X').replaceAll('*', 'X');
}

// Machine PROMESH — la colonne `machine` en base ne contient que le numéro
// ("1".."4", voir route /production/promesh/machine/<n>), jamais le libellé
// complet : ce formateur ajoute uniquement le préfixe d'affichage "PROMESH ",
// il n'invente jamais une valeur absente (machine vide/null -> "—").
// Tolère aussi une valeur déjà préfixée (ex. donnée historique "PROMESH 4")
// sans la doubler.
String formatPromeshMachineLabel(String? machine) {
  final v = (machine ?? '').trim();
  if (v.isEmpty) return '—';
  if (v.toUpperCase().startsWith('PROMESH')) return v.toUpperCase();
  return 'PROMESH $v';
}

// §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS RECOVERABLES
// (§2 du ticket — "Machine" affiché aussi pour PROBAR désormais) — même
// convention que formatPromeshMachineLabel ci-dessus : la colonne `machine`
// en base ne contient que le numéro, jamais le libellé complet ; tolère une
// valeur déjà préfixée sans la doubler ; machine vide/null -> "—".
String formatProbarMachineLabel(String? machine) {
  final v = (machine ?? '').trim();
  if (v.isEmpty) return '—';
  if (v.toUpperCase().startsWith('PROBAR')) return v.toUpperCase();
  return 'PROBAR $v';
}

// Vrai uniquement si la fiche provient réellement de la machine PROMESH 4
// (valeur de la colonne `machine`, jamais déduite de la position de la ligne
// ni d'aucun autre champ) — accepte "4" (forme actuellement enregistrée) et
// "PROMESH 4"/"PROMESH4" (au cas où une fiche future/historique stockerait
// déjà le libellé complet).
bool isPromesh4Machine(String? machine) {
  final v = (machine ?? '').trim().toUpperCase().replaceAll(' ', '');
  return v == '4' || v == 'PROMESH4';
}

// Format professionnel des grands nombres : "1250" -> "1 250" (séparateur
// espace, décimales conservées seulement si non nulles). N'affiche jamais
// NaN/Infinity (retombe sur "0") — même convention que
// production_records_screen.dart#_formatNumber, partagée ici pour être
// réutilisée par l'écran Summary ET ses exports (Excel/PDF/Impression).
String formatProductionNumber(double value) {
  if (!value.isFinite) return '0';
  final isNegative = value < 0;
  final absValue = value.abs();
  final intPart = absValue.truncate();
  final decimals = absValue - intPart;
  final intStr = intPart.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < intStr.length; i++) {
    if (i > 0 && (intStr.length - i) % 3 == 0) grouped.write(' ');
    grouped.write(intStr[i]);
  }
  var result = grouped.toString();
  if (decimals > 0.001) {
    var decStr = decimals.toStringAsFixed(2).substring(2);
    decStr = decStr.replaceFirst(RegExp(r'0$'), '');
    if (decStr.isNotEmpty) result += ',$decStr';
  }
  return isNegative ? '-$result' : result;
}

// §MODIFICATION — RÉCAPITULATIF PAR MACHINE : LOGIQUE PARTAGÉE UI/EXPORT
// (2026-09-10, ticket "export Excel — Récapitulatif dans une feuille
// séparée") — DÉPLACÉ ICI depuis production_summary_screen.dart (où ce
// bloc était privé, `_MachineDiameterGroup`/`_MachineSection`/
// `_aggregateByMachine`) pour être réutilisé TEL QUEL par
// production_summary_export_service.dart (§13 du ticket : "créer/réutiliser
// une même fonction de transformation des données afin d'éviter les
// différences entre UI et Excel" — jamais une seconde implémentation
// parallèle). Logique de regroupement INCHANGÉE par ce déplacement.
//
// GROUP BY MACHINE + DIAMETER (+ CELL SIZE si `groupByCellSize`), SUM
// (quantity). Le SHIFT n'est JAMAIS une dimension de regroupement (Matin/
// Soir d'une même machine/diamètre/cell size → UNE SEULE ligne, quantités
// additionnées), ni la Date (ce bloc synthétise l'INTÉGRALITÉ des lignes
// actuellement filtrées, peu importe le nombre de dates distinctes
// couvertes). `groupByCellSize: false` (NOUVEAU, pour PROBAR — §10 du
// ticket : "Regroupement par Machine + Diameter", jamais de Cell size côté
// PROBAR) ignore complètement `tailleMaille` comme dimension de groupe.
//
// IMPORTANT — WASTE : `r.waste` (voir production_record_model.dart) est une
// valeur agrégée PAR DATE côté backend (attachWaste, productionRecords.
// service.js), jamais par machine/diamètre/cell size (Recuperables n'a pas
// cette granularité). Pour éviter de la compter plusieurs fois quand
// plusieurs fiches d'un même groupe partagent la même date, chaque date
// n'est comptée QU'UNE SEULE FOIS par groupe — mais si un même groupe est
// alimenté par PLUSIEURS dates distinctes, leurs valeurs de Waste
// respectives sont additionnées entre elles : la décomposition la plus
// honnête possible avec les données disponibles. Les lignes TOTAL/TOTAL
// WASTE finales restent néanmoins TOUJOURS `table.grandTotal`/
// `table.grandTotalWaste` (jamais recalculées ici).
class MachineDiameterGroup {
  final String? machine;
  final String? diametre;
  final String? cellSize;
  final double quantity;
  final double waste;
  const MachineDiameterGroup({
    required this.machine,
    required this.diametre,
    required this.cellSize,
    required this.quantity,
    required this.waste,
  });
}

class MachineSection {
  final String? machine;
  final List<MachineDiameterGroup> rows;
  const MachineSection({required this.machine, required this.rows});
}

List<MachineSection> aggregateByMachine(List<ProductionRecordModel> rows, {required bool groupByCellSize}) {
  final wasteByDate = <String, double>{};
  final quantityByGroup = <String, double>{};
  final machineByGroup = <String, String?>{};
  final diametreByGroup = <String, String?>{};
  final cellSizeByGroup = <String, String?>{};
  final datesByGroup = <String, Set<String>>{};

  for (final r in rows) {
    final date = r.date;
    if (date != null && date.isNotEmpty) {
      wasteByDate[date] = r.waste; // valeur déjà agrégée par date côté backend.
    }
    final machine = r.machine?.trim();
    final diametre = r.diametre?.trim();
    // Cell size normalisé AVANT regroupement : "20x20"/"20*20"/"20/20" ne
    // doivent jamais créer des groupes distincts pour une même valeur.
    // Toujours `null` quand `groupByCellSize` est faux (PROBAR).
    String? cellSize;
    if (groupByCellSize) {
      final tailleMaille = r.tailleMaille?.trim();
      cellSize = (tailleMaille != null && tailleMaille.isNotEmpty) ? formatCellSize(tailleMaille).toUpperCase() : null;
    }
    final key = groupByCellSize ? '${machine ?? ''}|${diametre ?? ''}|${cellSize ?? ''}' : '${machine ?? ''}|${diametre ?? ''}';

    quantityByGroup[key] = (quantityByGroup[key] ?? 0) + (r.quantite ?? 0);
    machineByGroup[key] = machine;
    diametreByGroup[key] = diametre;
    cellSizeByGroup[key] = cellSize;
    if (date != null && date.isNotEmpty) {
      (datesByGroup[key] ??= <String>{}).add(date);
    }
  }

  final keys = quantityByGroup.keys.toList()
    ..sort((a, b) {
      final mCompare = _compareMachineField(machineByGroup[a], machineByGroup[b]);
      if (mCompare != 0) return mCompare;
      final na = double.tryParse(diametreByGroup[a] ?? '');
      final nb = double.tryParse(diametreByGroup[b] ?? '');
      if (na != null && nb != null && na != nb) return na.compareTo(nb);
      return (cellSizeByGroup[a] ?? '').compareTo(cellSizeByGroup[b] ?? '');
    });

  final groups = [
    for (final k in keys)
      MachineDiameterGroup(
        machine: machineByGroup[k],
        diametre: diametreByGroup[k],
        cellSize: cellSizeByGroup[k],
        quantity: quantityByGroup[k]!,
        waste: (datesByGroup[k] ?? const <String>{}).fold<double>(0, (s, d) => s + (wasteByDate[d] ?? 0)),
      ),
  ];

  final byMachine = <String?, List<MachineDiameterGroup>>{};
  for (final g in groups) {
    (byMachine[g.machine] ??= []).add(g);
  }
  final machineKeys = byMachine.keys.toList()..sort(_compareMachineField);
  return [for (final m in machineKeys) MachineSection(machine: m, rows: byMachine[m]!)];
}

// Comparateur "machine" partagé — extrait de aggregateByMachine ci-dessus
// pour être réutilisé TEL QUEL par sortProductionRows (tri de la colonne
// Machine du tableau détaillé, voir plus bas) : "1".."4" comparés
// numériquement (jamais "10" avant "2"), avec repli alphabétique si la
// valeur n'est pas un nombre pur (ex. une fiche historique qui stockerait
// déjà "PROMESH 4").
int _compareMachineField(String? a, String? b) {
  final na = int.tryParse(a ?? '');
  final nb = int.tryParse(b ?? '');
  if (na != null && nb != null) return na.compareTo(nb);
  return (a ?? '').compareTo(b ?? '');
}

class ProductionSummary {
  final ProductionSummaryTable? promesh;
  final ProductionSummaryTable? probar;

  const ProductionSummary({this.promesh, this.probar});

  factory ProductionSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProductionSummary();
    return ProductionSummary(
      promesh: json['promesh'] is Map
          ? ProductionSummaryTable.fromJson(Map<String, dynamic>.from(json['promesh'] as Map), isPromesh: true)
          : null,
      probar: json['probar'] is Map
          ? ProductionSummaryTable.fromJson(Map<String, dynamic>.from(json['probar'] as Map), isPromesh: false)
          : null,
    );
  }
}

// §MODIFICATION — TRI DES TABLEAUX "PROMESH/PROBAR PRODUCTION" (2026-09-11,
// ticket "ajouter une fonctionnalité de tri") — logique PARTAGÉE entre
// l'écran (tableau détaillé paginé, voir production_summary_screen.dart#
// _SummaryTableCardState) et l'export (Excel/PDF doivent respecter le tri
// actuellement actif, voir production_summary_screen.dart#
// _sortedSummaryForExport) — jamais deux implémentations séparées (§23 du
// ticket). Tri purement CLIENT (aucun appel backend, §22) : `rows` est
// toujours le jeu déjà filtré par le backend (Custom Date/machine/diamètre/
// statut), jamais retouché ici — seul l'ORDRE change, jamais son contenu.
//
// IMPORTANT — le récapitulatif ("RÉCAPITULATIF DE PRODUCTION", voir
// aggregateByMachine ci-dessus) n'utilise JAMAIS le résultat de cette
// fonction : il continue de lire `table.rows` dans son ordre d'origine (peu
// importe puisqu'il regroupe et retrie de toute façon en interne par
// machine/diamètre/cell size) — le tri du tableau détaillé ne peut donc
// jamais "casser" le récapitulatif ni les totaux (§15/§16 du ticket).
enum ProductionSortColumn { rowNumber, date, machine, shift, diameter, cellSize, quantity, waste }

// Représente l'état de tri actif d'UN tableau (PROMESH ou PROBAR ont chacun
// le leur, totalement indépendants — voir _promeshSort/_probarSort côté
// écran). `null` (pas d'instance) = "aucun tri actif", 3ᵉ état du cycle
// clic (§2 du ticket : croissant → décroissant → aucun tri).
class ProductionRowSort {
  final ProductionSortColumn column;
  final bool ascending;
  const ProductionRowSort(this.column, this.ascending);
}

// Cycle à 3 états d'un clic sur un header triable (§2) : un clic sur une
// AUTRE colonne repart toujours à "croissant" sur cette nouvelle colonne
// (un seul tri actif à la fois, jamais un tri multi-colonnes — cohérent
// avec les indicateurs visuels du ticket qui ne montrent jamais deux
// flèches actives simultanément).
ProductionRowSort? cycleProductionSort(ProductionRowSort? current, ProductionSortColumn column) {
  if (current == null || current.column != column) return ProductionRowSort(column, true);
  if (current.ascending) return ProductionRowSort(column, false);
  return null;
}

// (largeur, hauteur) normalisées d'un Cell size PROMESH — réutilise
// `formatCellSize` (déjà partagé, normalise "/"/"*" vers "X") avant de
// séparer les deux dimensions. Valeur absente/non numérique -> (infini,
// infini) pour trier "Non renseigné" de façon prévisible en dernier en
// ordre croissant (et donc en premier en ordre décroissant, par symétrie du
// comparateur — §8 du ticket : "traiter proprement comme une valeur
// spéciale", jamais un crash ni un tri alphabétique brut).
(double, double) _parseCellSizeDimensions(String? raw) {
  if (raw == null || raw.trim().isEmpty) return (double.infinity, double.infinity);
  final parts = formatCellSize(raw).toUpperCase().split('X');
  if (parts.length != 2) return (double.infinity, double.infinity);
  final w = double.tryParse(parts[0].trim());
  final h = double.tryParse(parts[1].trim());
  if (w == null || h == null) return (double.infinity, double.infinity);
  return (w, h);
}

// Tri "logique" par taille (§8 du ticket) : surface (largeur × hauteur)
// d'abord — suffisant pour départager tous les cas carrés de l'exemple du
// ticket (15×15 < 20×20 < ... < 200×200) — puis largeur/hauteur en
// départage pour les cas rectangulaires non couverts par l'exemple.
int _compareCellSizeField(String? a, String? b) {
  final da = _parseCellSizeDimensions(a);
  final db = _parseCellSizeDimensions(b);
  final areaA = da.$1 * da.$2;
  final areaB = db.$1 * db.$2;
  if (areaA != areaB) return areaA.compareTo(areaB);
  if (da.$1 != db.$1) return da.$1.compareTo(db.$1);
  return da.$2.compareTo(db.$2);
}

// Ordre MÉTIER du Shift (§10 du ticket), jamais alphabétique : Matin
// (Morning) avant Nuit/Soir (Evening) ; une fiche sans poste enregistré
// (même convention que le badge Shift affiché à l'écran, voir
// _shiftBadge) est toujours classée en dernier en ordre croissant.
int _shiftRank(String? poste) {
  if (poste == 'matin') return 0;
  if (poste == 'nuit') return 1;
  return 2;
}

// Tri principal du tableau détaillé (§1-§12 du ticket) — `column: null`
// (aucun tri actif) renvoie `rows` STRICTEMENT inchangé (même ordre que
// fourni par le backend, §18 : "conserver l'ordre actuel provenant des
// données"), jamais une copie retriée par défaut sur une colonne implicite.
List<ProductionRecordModel> sortProductionRows(
  List<ProductionRecordModel> rows, {
  required ProductionSortColumn? column,
  required bool ascending,
}) {
  if (column == null) return rows;

  // "#" reflète la position d'affichage elle-même : le tri croissant est
  // donc l'ordre déjà fourni (identité), le tri décroissant en est le
  // simple reflet — aucune autre colonne n'a cette particularité.
  if (column == ProductionSortColumn.rowNumber) {
    return ascending ? rows : rows.reversed.toList();
  }

  int cmp(ProductionRecordModel a, ProductionRecordModel b) {
    switch (column) {
      case ProductionSortColumn.rowNumber:
        return 0; // inatteignable (voir garde ci-dessus) — exhaustivité du switch.
      case ProductionSortColumn.date:
        // §4 du ticket : tri chronologique réel, jamais une comparaison de
        // chaînes ("27/08/2026" ne doit jamais se retrouver après
        // "05/09/2026" à cause d'un tri alphabétique sur "27" vs "05").
        final da = DateTime.tryParse(a.date ?? '');
        final db = DateTime.tryParse(b.date ?? '');
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      case ProductionSortColumn.machine:
        return _compareMachineField(a.machine, b.machine);
      case ProductionSortColumn.shift:
        return _shiftRank(a.poste).compareTo(_shiftRank(b.poste));
      case ProductionSortColumn.diameter:
        // §7 du ticket : tri numérique réel (4, 6, 8, 10, 14... jamais
        // l'ordre alphabétique "10, 14, 16, 4, 6, 8").
        final na = double.tryParse(a.diametre ?? '');
        final nb = double.tryParse(b.diametre ?? '');
        if (na == null && nb == null) return 0;
        if (na == null) return 1;
        if (nb == null) return -1;
        return na.compareTo(nb);
      case ProductionSortColumn.cellSize:
        return _compareCellSizeField(a.tailleMaille, b.tailleMaille);
      case ProductionSortColumn.quantity:
        return (a.quantite ?? 0).compareTo(b.quantite ?? 0);
      case ProductionSortColumn.waste:
        return a.waste.compareTo(b.waste);
    }
  }

  final sorted = List<ProductionRecordModel>.from(rows);
  sorted.sort(ascending ? cmp : (a, b) => cmp(b, a));
  return sorted;
}
