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
