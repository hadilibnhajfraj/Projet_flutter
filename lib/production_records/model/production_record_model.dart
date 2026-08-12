// lib/production_records/model/production_record_model.dart
//
// Modèle normalisé "Fiches de production" — mirrors GET /production-records
// (backend : modules/production-records/dto/productionRecords.dto.js). Ne
// duplique aucune donnée : projection en lecture seule des fiches PorPromesh
// et IndustrialRecord (module='probar') existantes.

class ProductionRecordModel {
  // Id composite "promesh:<uuid>" ou "probar:<uuid>" — voir backend
  // parseCompositeId(). Toujours utilisé tel quel pour GET /production-records/:id.
  final String id;
  final String type; // 'probar' | 'promesh'
  final String? numero;
  final String? machine;
  final String? poste; // 'matin' | 'nuit'
  final String? date; // yyyy-MM-dd
  final String? heureDebut;
  final String? heureFin;
  final String? operateur;
  final double? quantite;
  final String quantiteUnite; // 'm' (probar) | 'm²' (promesh)
  final String? tailleMaille; // promesh uniquement
  final String? diametre;
  final String diametreUnite; // 'mm'
  final String statut; // 'brouillon' | 'validee'
  final bool isLocked;
  final String? createdBy;
  final Map<String, String>? creator;
  final String? createdAt;
  final String? updatedAt;

  const ProductionRecordModel({
    required this.id,
    required this.type,
    this.numero,
    this.machine,
    this.poste,
    this.date,
    this.heureDebut,
    this.heureFin,
    this.operateur,
    this.quantite,
    this.quantiteUnite = '',
    this.tailleMaille,
    this.diametre,
    this.diametreUnite = 'mm',
    this.statut = 'brouillon',
    this.isLocked = false,
    this.createdBy,
    this.creator,
    this.createdAt,
    this.updatedAt,
  });

  bool get isProbar => type == 'probar';
  bool get isPromesh => type == 'promesh';

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  static Map<String, String>? _toNullableMapOfString(dynamic v) {
    if (v is! Map) return null;
    return v.map((k, val) => MapEntry(k.toString(), (val ?? '').toString()));
  }

  factory ProductionRecordModel.fromJson(Map<String, dynamic> json) {
    return ProductionRecordModel(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      numero: json['numero']?.toString(),
      machine: json['machine']?.toString(),
      poste: json['poste']?.toString(),
      date: json['date']?.toString(),
      heureDebut: json['heureDebut']?.toString(),
      heureFin: json['heureFin']?.toString(),
      operateur: json['operateur']?.toString(),
      quantite: _toDouble(json['quantite']),
      quantiteUnite: (json['quantiteUnite'] ?? '').toString(),
      tailleMaille: json['tailleMaille']?.toString(),
      diametre: json['diametre']?.toString(),
      diametreUnite: (json['diametreUnite'] ?? 'mm').toString(),
      statut: (json['statut'] ?? 'brouillon').toString(),
      isLocked: json['isLocked'] == true,
      createdBy: json['createdBy']?.toString(),
      creator: _toNullableMapOfString(json['creator']),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

}

class ProductionRecordPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const ProductionRecordPagination({this.page = 1, this.limit = 20, this.total = 0, this.totalPages = 1});

  factory ProductionRecordPagination.fromJson(Map<String, dynamic> json) {
    return ProductionRecordPagination(
      page: int.tryParse('${json['page']}') ?? 1,
      limit: int.tryParse('${json['limit']}') ?? 20,
      total: int.tryParse('${json['total']}') ?? 0,
      totalPages: int.tryParse('${json['totalPages']}') ?? 1,
    );
  }
}

class ProductionRecordStatistics {
  final int total;
  final int probar;
  final int promesh;
  final int thisWeek;
  final int thisMonth;

  const ProductionRecordStatistics({
    this.total = 0,
    this.probar = 0,
    this.promesh = 0,
    this.thisWeek = 0,
    this.thisMonth = 0,
  });

  factory ProductionRecordStatistics.fromJson(Map<String, dynamic> json) {
    return ProductionRecordStatistics(
      total: int.tryParse('${json['total']}') ?? 0,
      probar: int.tryParse('${json['probar']}') ?? 0,
      promesh: int.tryParse('${json['promesh']}') ?? 0,
      thisWeek: int.tryParse('${json['thisWeek']}') ?? 0,
      thisMonth: int.tryParse('${json['thisMonth']}') ?? 0,
    );
  }
}

class ProductionRecordFilters {
  final List<String> machines;
  final List<String> postes;
  final List<String> diameters;

  const ProductionRecordFilters({this.machines = const [], this.postes = const [], this.diameters = const []});

  factory ProductionRecordFilters.fromJson(Map<String, dynamic> json) {
    return ProductionRecordFilters(
      machines: (json['machines'] as List? ?? []).map((e) => e.toString()).toList(),
      postes: (json['postes'] as List? ?? []).map((e) => e.toString()).toList(),
      diameters: (json['diameters'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

// KPI industriels (Quantité produite / Diamètre / Taille de maille) —
// mirrors backend productionRecords.service.js#getProductionTotals.
// `null` = ce type est exclu par le filtre "Type" actif (Toutes les
// machines/postes/périodes restent appliqués), distinct de `0` qui signifie
// "applicable mais aucune fiche VALIDÉE ne correspond".
class ProductionTotalsSide {
  final double quantity;
  final String quantityUnite;
  final double diameter;
  final String diameterUnite;
  final double? meshSize; // PROMESH uniquement
  final String? meshSizeUnite;

  const ProductionTotalsSide({
    required this.quantity,
    required this.quantityUnite,
    required this.diameter,
    required this.diameterUnite,
    this.meshSize,
    this.meshSizeUnite,
  });

  factory ProductionTotalsSide.fromJson(Map<String, dynamic> json) {
    return ProductionTotalsSide(
      quantity: _toDouble(json['quantity']) ?? 0,
      quantityUnite: (json['quantityUnite'] ?? '').toString(),
      diameter: _toDouble(json['diameter']) ?? 0,
      diameterUnite: (json['diameterUnite'] ?? 'mm').toString(),
      meshSize: _toDouble(json['meshSize']),
      meshSizeUnite: json['meshSizeUnite']?.toString(),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }
}

class ProductionTotals {
  final ProductionTotalsSide? probar;
  final ProductionTotalsSide? promesh;

  const ProductionTotals({this.probar, this.promesh});

  factory ProductionTotals.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProductionTotals();
    return ProductionTotals(
      probar: json['probar'] is Map ? ProductionTotalsSide.fromJson(Map<String, dynamic>.from(json['probar'] as Map)) : null,
      promesh: json['promesh'] is Map ? ProductionTotalsSide.fromJson(Map<String, dynamic>.from(json['promesh'] as Map)) : null,
    );
  }
}

class ProductionRecordPage {
  final List<ProductionRecordModel> items;
  final ProductionRecordPagination pagination;
  final ProductionRecordStatistics statistics;
  final ProductionTotals productionTotals;

  const ProductionRecordPage({
    this.items = const [],
    this.pagination = const ProductionRecordPagination(),
    this.statistics = const ProductionRecordStatistics(),
    this.productionTotals = const ProductionTotals(),
  });
}
