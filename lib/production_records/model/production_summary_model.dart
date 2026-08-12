// lib/production_records/model/production_summary_model.dart
//
// "Production Summary" — tableau récapitulatif PROBAR/PROMESH groupé par
// Diamètre (+ Taille de maille pour PROMESH). Mirrors GET
// /production-records/summary (backend :
// modules/production-records/services/productionRecords.service.js#getProductionSummary).
// Aucune donnée dupliquée : agrégation en lecture seule des fiches
// existantes, calculée côté PostgreSQL (SUM/GROUP BY), jamais en Flutter.

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

/// Une ligne au sein d'un groupe Diamètre — PROMESH uniquement (une ligne
/// par Taille de maille). PROBAR n'a pas de sous-lignes (voir §8 : "PROBAR,
/// supprimer complètement la notion de Cell size").
class ProductionSummaryRow {
  final String? meshSize;
  final double quantity;
  final int records;

  const ProductionSummaryRow({this.meshSize, this.quantity = 0, this.records = 0});

  factory ProductionSummaryRow.fromJson(Map<String, dynamic> json) {
    return ProductionSummaryRow(
      meshSize: json['meshSize']?.toString(),
      quantity: _toDouble(json['quantity']),
      records: _toInt(json['records']),
    );
  }
}

/// Un groupe Diamètre — `rows` est vide pour PROBAR (Diameter + Quantity
/// uniquement), rempli pour PROMESH (une ligne par Taille de maille sous ce
/// diamètre, voir §1/§3 du cahier des charges).
class ProductionSummaryGroup {
  final String? diameter; // null = diamètre non renseigné sur la fiche
  final List<ProductionSummaryRow> rows;
  final double diameterTotal;
  final int records;

  const ProductionSummaryGroup({
    this.diameter,
    this.rows = const [],
    this.diameterTotal = 0,
    this.records = 0,
  });

  // Forme PROMESH (backend) : { diameter, rows:[{meshSize,quantity,records}], diameterTotal, records }
  factory ProductionSummaryGroup.fromPromeshJson(Map<String, dynamic> json) {
    return ProductionSummaryGroup(
      diameter: json['diameter']?.toString(),
      rows: (json['rows'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ProductionSummaryRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      diameterTotal: _toDouble(json['diameterTotal']),
      records: _toInt(json['records']),
    );
  }

  // Forme PROBAR (backend) : { diameter, quantity, records } — pas de sous-lignes.
  factory ProductionSummaryGroup.fromProbarJson(Map<String, dynamic> json) {
    return ProductionSummaryGroup(
      diameter: json['diameter']?.toString(),
      rows: const [],
      diameterTotal: _toDouble(json['quantity']),
      records: _toInt(json['records']),
    );
  }

  bool get hasMeshSizeRows => rows.isNotEmpty;
}

/// Un tableau complet (PROMESH ou PROBAR) — groupes + total général.
class ProductionSummaryTable {
  final List<ProductionSummaryGroup> groups;
  final double grandTotal;
  final String unit;
  final int totalRecords;
  final int diameterCount;

  const ProductionSummaryTable({
    this.groups = const [],
    this.grandTotal = 0,
    this.unit = '',
    this.totalRecords = 0,
    this.diameterCount = 0,
  });

  factory ProductionSummaryTable.fromJson(Map<String, dynamic> json, {required bool isPromesh}) {
    return ProductionSummaryTable(
      groups: (json['groups'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map((e) => isPromesh ? ProductionSummaryGroup.fromPromeshJson(e) : ProductionSummaryGroup.fromProbarJson(e))
          .toList(),
      grandTotal: _toDouble(json['grandTotal']),
      unit: (json['unit'] ?? '').toString(),
      totalRecords: _toInt(json['totalRecords']),
      diameterCount: _toInt(json['diameterCount']),
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
