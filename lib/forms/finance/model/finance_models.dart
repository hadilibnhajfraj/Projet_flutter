// lib/forms/finance/model/finance_models.dart
//
// Modèles "Finance PROBAR" — mirrors GET/POST /finance/* (backend :
// Backend Master/src/modules/finance/). Un seul fichier pour l'ensemble du
// module (document/shipment/invoice/payment/dashboard), même convention que
// production_summary_model.dart.

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

// §CORRECTION EXTRACTION — SÉPARATION UNITÉ / DIAMÈTRE : utilitaire CENTRAL
// (§11 "une seule logique") — appelé par FinanceShipmentItemModel/
// FinanceInvoiceItemModel.displayUnit/displayDiameter, eux-mêmes consommés
// PARTOUT (tableau, détail, export Excel) au lieu du champ brut `unit`/
// `diameter` — jamais de logique de séparation dupliquée ailleurs.
//
// Certains documents impriment "Unité" et "Diam."/"Maille" comme deux
// colonnes DISTINCTES (cas normal, déjà géré par l'extraction positionnelle
// existante) ; d'autres — ou un repli OCR moins fiable — les fusionnent en
// une seule valeur ("M² 10", "ML 04"). Cette fonction ne fait qu'un
// DERNIER FILET DE SÉCURITÉ à l'affichage : si `diameter` est déjà rempli,
// rien n'est retouché (§6/§8) ; sinon, seule une unité RECONNUE suivie d'un
// nombre pur est séparée (§7) — jamais un designation/reference contenant un
// chiffre n'est confondu avec un diamètre (§2 "ne jamais inventer").
const List<String> kFinanceKnownUnits = [
  'M²', 'M2', 'ML', 'KG', 'LITRE', 'L', 'TONNE', 'PIECE', 'PCS', 'UNITE', 'UNITÉ', 'MILLILITRE', 'MILLILITR',
];

final RegExp _kFinanceMergedUnitPattern = RegExp(r'^([A-Za-zÀ-ÿ²0-9]+)\s+(\d+)$');

class FinanceNormalizedUnit {
  final String? unit;
  final String? diameter;
  const FinanceNormalizedUnit(this.unit, this.diameter);
}

FinanceNormalizedUnit normalizeFinanceUnit(String? rawUnit, String? rawDiameter) {
  final unit = rawUnit?.trim();
  final diameter = rawDiameter?.trim();

  // §6/§8 : le document (ou la DB) a déjà des valeurs séparées — ne jamais
  // essayer de re-parser/reconstruire, utiliser telles quelles.
  if (diameter != null && diameter.isNotEmpty) {
    return FinanceNormalizedUnit(unit, diameter);
  }
  if (unit == null || unit.isEmpty) {
    return FinanceNormalizedUnit(unit, diameter);
  }

  final match = _kFinanceMergedUnitPattern.firstMatch(unit);
  if (match != null) {
    final candidateUnit = match.group(1)!;
    // §4 : le diamètre capturé n'est JAMAIS reformaté — "04" reste "04",
    // jamais converti en "4".
    final candidateDiameter = match.group(2)!;
    if (kFinanceKnownUnits.contains(candidateUnit.toUpperCase())) {
      return FinanceNormalizedUnit(candidateUnit, candidateDiameter);
    }
  }

  // Rien à séparer (unité inconnue devant le nombre, ou pas de nombre du
  // tout) — valeur renvoyée telle quelle, jamais un diamètre inventé.
  return FinanceNormalizedUnit(unit, diameter);
}

class FinanceUserRef {
  final String? id;
  final String? email;
  const FinanceUserRef({this.id, this.email});

  factory FinanceUserRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FinanceUserRef();
    return FinanceUserRef(id: json['id']?.toString(), email: json['email']?.toString());
  }
}

class FinanceCustomerRef {
  final int? id;
  final String? raisonSociale;
  final String? matriculeFiscal;
  final String? contact;
  const FinanceCustomerRef({this.id, this.raisonSociale, this.matriculeFiscal, this.contact});

  factory FinanceCustomerRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FinanceCustomerRef();
    return FinanceCustomerRef(
      id: json['id'] == null ? null : _toInt(json['id']),
      raisonSociale: json['raisonSociale']?.toString(),
      matriculeFiscal: json['matriculeFiscal']?.toString(),
      contact: json['contact']?.toString(),
    );
  }

  String get displayName => (raisonSociale ?? '').trim().isNotEmpty ? raisonSociale! : 'Client #$id';
}

// ── DOCUMENT (Inflow of raw materials + pièces jointes shipment/invoice) ──

class FinanceDocumentModel {
  final String id;
  final String module; // INFLOW_RAW_MATERIALS | SHIPMENT | INVOICE | PAYMENT | OTHER
  final String? entityId;
  final String originalName;
  // §MODIFICATION — FINANCE > OTHER : nom d'affichage modifiable par
  // l'utilisateur (§7/§19) — le backend retombe déjà sur `originalName`
  // quand absent, donc toujours non-null ici.
  final String displayName;
  final String fileUrl;
  final String mimeType;
  final int fileSize;
  final String status; // PENDING | VALIDATED | REJECTED
  final FinanceUserRef? uploader;
  final String? createdAt;
  final String? updatedAt;

  const FinanceDocumentModel({
    required this.id,
    required this.module,
    this.entityId,
    required this.originalName,
    required this.displayName,
    required this.fileUrl,
    required this.mimeType,
    this.fileSize = 0,
    this.status = 'PENDING',
    this.uploader,
    this.createdAt,
    this.updatedAt,
  });

  factory FinanceDocumentModel.fromJson(Map<String, dynamic> json) {
    final originalName = (json['originalName'] ?? '').toString();
    return FinanceDocumentModel(
      id: (json['id'] ?? '').toString(),
      module: (json['module'] ?? '').toString(),
      entityId: json['entityId']?.toString(),
      originalName: originalName,
      displayName: (json['displayName'] ?? originalName).toString(),
      fileUrl: (json['fileUrl'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      fileSize: _toInt(json['fileSize']),
      status: (json['status'] ?? 'PENDING').toString(),
      uploader: json['uploader'] is Map ? FinanceUserRef.fromJson(Map<String, dynamic>.from(json['uploader'] as Map)) : null,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  // Toujours dérivée d'`originalName` (jamais `displayName`) — le fichier
  // PHYSIQUE et son type réel ne changent jamais au renommage (§7/§19) ;
  // dériver de `displayName` casserait la détection PDF/image si
  // l'utilisateur renomme sans conserver l'extension (ex. "Contrat" sans
  // ".pdf").
  String get extension {
    final dot = originalName.lastIndexOf('.');
    return dot == -1 ? '' : originalName.substring(dot + 1).toLowerCase();
  }

  bool get isPdf => mimeType == 'application/pdf' || extension == 'pdf';
  bool get isImage => mimeType.startsWith('image/') || ['jpg', 'jpeg', 'png', 'webp'].contains(extension);
}

// ── SHIPMENT ────────────────────────────────────────────────────────────

class FinanceProductLine {
  final String designation;
  final double quantity;
  final String unit;
  const FinanceProductLine({this.designation = '', this.quantity = 0, this.unit = ''});

  factory FinanceProductLine.fromJson(Map<String, dynamic> json) {
    return FinanceProductLine(
      designation: (json['designation'] ?? '').toString(),
      quantity: _toDouble(json['quantity']) ?? 0,
      unit: (json['unit'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'designation': designation, 'quantity': quantity, 'unit': unit};
}

class FinanceInvoiceRefLite {
  final String id;
  final String invoiceNumber;
  const FinanceInvoiceRefLite({required this.id, required this.invoiceNumber});

  factory FinanceInvoiceRefLite.fromJson(Map<String, dynamic> json) {
    return FinanceInvoiceRefLite(
      id: (json['id'] ?? '').toString(),
      invoiceNumber: (json['invoiceNumber'] ?? '').toString(),
    );
  }
}

// Ligne produit d'un Bon de Livraison extraite par OCR — toutes les valeurs
// restent nullable : une case vide dans l'UI signifie "non détecté", jamais
// une valeur inventée.
class FinanceShipmentItemModel {
  final String id;
  final String? reference;
  final String? designation;
  final String? unit;
  final String? diameter;
  final String? meshSize;
  final double? quantity;

  const FinanceShipmentItemModel({
    this.id = '',
    this.reference,
    this.designation,
    this.unit,
    this.diameter,
    this.meshSize,
    this.quantity,
  });

  factory FinanceShipmentItemModel.fromJson(Map<String, dynamic> json) {
    return FinanceShipmentItemModel(
      id: (json['id'] ?? '').toString(),
      reference: json['reference']?.toString(),
      designation: json['designation']?.toString(),
      unit: json['unit']?.toString(),
      diameter: json['diameter']?.toString(),
      meshSize: json['meshSize']?.toString(),
      quantity: _toDouble(json['quantity']),
    );
  }

  // Toujours utiliser ces deux getters à l'affichage/export — jamais `unit`/
  // `diameter` bruts (§9-11).
  String? get displayUnit => normalizeFinanceUnit(unit, diameter).unit;
  String? get displayDiameter => normalizeFinanceUnit(unit, diameter).diameter;
}

class FinanceShipmentModel {
  final String id;
  // Identifiant métier généré INCONDITIONNELLEMENT par l'application
  // (§MODIFICATION — CUSTOMER SHIPMENTS), format "SH-00001" — distinct de
  // `reference` ci-dessous (numéro de BL LU sur le document, ou un repli
  // auto-généré quand l'OCR est peu fiable) et de `customerCode`.
  final String? shipmentNumber;
  final String reference;
  final String? customerReference;
  final int customerId;
  final FinanceCustomerRef? customer;
  // Instantané client/livraison lu sur le Bon de Livraison (OCR) — distinct
  // de `customer` (jamais résolu automatiquement vers un client existant).
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? customerGovernorate;
  final String? customerTaxId;
  final String? customerCode;
  final String? customerHeadOfficeAddress;
  final String? truckRegistration;
  final String? truckManufacturer;
  final String? driverName;
  final String? deliveryAddress;
  final String? shipmentDate;
  final List<FinanceProductLine> products;
  final double? totalQuantity;
  final double totalAmount;
  final String? deliveryInfo;
  final String status; // DRAFT | PREPARED | SHIPPED | DELIVERED | CANCELLED | NEEDS_REVIEW
  final double? ocrConfidence;
  // §CORRECTION — WORKFLOW OCR CUSTOMER SHIPMENTS (2026-08-31) : signal
  // exposé par le backend (finance.dto.js#toShipmentResponse), équivalent
  // de `FinancePurchaseOrderModel.orderNumber == null` pour les Purchase
  // Orders — `reference` ne peut PAS jouer ce rôle ici (elle reçoit
  // TOUJOURS une valeur, réelle ou générée par repli, jamais null — voir
  // isExtractionFailed ci-dessous).
  final bool hasReliableReference;
  final List<FinanceInvoiceRefLite> invoices;
  final List<FinanceShipmentItemModel> items;
  final FinanceUserRef? creator;
  final List<FinanceDocumentModel> documents;
  final String? createdAt;

  const FinanceShipmentModel({
    required this.id,
    this.shipmentNumber,
    required this.reference,
    this.customerReference,
    required this.customerId,
    this.customer,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.customerGovernorate,
    this.customerTaxId,
    this.customerCode,
    this.customerHeadOfficeAddress,
    this.truckRegistration,
    this.truckManufacturer,
    this.driverName,
    this.deliveryAddress,
    this.shipmentDate,
    this.products = const [],
    this.totalQuantity,
    this.totalAmount = 0,
    this.deliveryInfo,
    this.status = 'DRAFT',
    this.ocrConfidence,
    this.hasReliableReference = false,
    this.invoices = const [],
    this.items = const [],
    this.creator,
    this.documents = const [],
    this.createdAt,
  });

  bool get needsReview => status == 'NEEDS_REVIEW';

  // §CORRECTION — WORKFLOW OCR CUSTOMER SHIPMENTS (2026-08-31) : aligné
  // EXACTEMENT sur `FinancePurchaseOrderModel.isExtractionFailed` (Inflow of
  // raw materials, la référence explicite du ticket) :
  // `status == 'OCR_FAILED' || (identifiant fiable absent)`. Pour Purchase
  // Orders, l'identifiant fiable est `orderNumber` (nullable, jamais
  // généré). Pour Shipments, `reference` reçoit TOUJOURS une valeur (repli
  // auto-généré "SHIP-{année}-NNNNNN" quand l'OCR ne trouve rien de
  // fiable — colonne `allowNull:false, unique`) : elle ne peut donc PAS
  // servir de signal, contrairement à `orderNumber`. `hasReliableReference`
  // (exposé par le backend, recalculé depuis `ocrExtraction.deliveryNumber`
  // avec le MÊME seuil de confiance que celui utilisé pour décider
  // `reference` à l'upload) joue exactement ce rôle à la place. Résultat :
  // un document dont le numéro de BL n'a jamais été détecté de façon fiable
  // (même si l'OCR a "trouvé" des lignes produit ailleurs dans un document
  // sans rapport) reste dans "Scan" — jamais affiché comme un Customer
  // Shipment réel, exactement comme un Purchase Order sans orderNumber
  // fiable reste dans "Export".
  bool get isExtractionFailed => status == 'OCR_FAILED' || !hasReliableReference;

  factory FinanceShipmentModel.fromJson(Map<String, dynamic> json) {
    return FinanceShipmentModel(
      id: (json['id'] ?? '').toString(),
      shipmentNumber: json['shipmentNumber']?.toString(),
      reference: (json['reference'] ?? '').toString(),
      customerReference: json['customerReference']?.toString(),
      customerId: _toInt(json['customerId']),
      customer: json['customer'] is Map ? FinanceCustomerRef.fromJson(Map<String, dynamic>.from(json['customer'] as Map)) : null,
      customerName: json['customerName']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      customerAddress: json['customerAddress']?.toString(),
      customerGovernorate: json['customerGovernorate']?.toString(),
      customerTaxId: json['customerTaxId']?.toString(),
      customerCode: json['customerCode']?.toString(),
      customerHeadOfficeAddress: json['customerHeadOfficeAddress']?.toString(),
      truckRegistration: json['truckRegistration']?.toString(),
      truckManufacturer: json['truckManufacturer']?.toString(),
      driverName: json['driverName']?.toString(),
      deliveryAddress: json['deliveryAddress']?.toString(),
      shipmentDate: json['shipmentDate']?.toString(),
      products: (json['products'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FinanceProductLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalQuantity: _toDouble(json['totalQuantity']),
      totalAmount: _toDouble(json['totalAmount']) ?? 0,
      deliveryInfo: json['deliveryInfo']?.toString(),
      status: (json['status'] ?? 'DRAFT').toString(),
      ocrConfidence: _toDouble(json['ocrConfidence']),
      hasReliableReference: json['hasReliableReference'] == true,
      invoices: (json['invoices'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FinanceInvoiceRefLite.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      items: (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FinanceShipmentItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      creator: json['creator'] is Map ? FinanceUserRef.fromJson(Map<String, dynamic>.from(json['creator'] as Map)) : null,
      documents: (json['documents'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FinanceDocumentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

// ── INVOICE / PAYMENT ──────────────────────────────────────────────────

class FinancePaymentModel {
  final String id;
  final String invoiceId;
  final double amount;
  final String? paidDate;
  final String? method;
  final String? reference;
  // Champs spécifiques Chèque/Traite (§REGISTER PAYMENT) — NULL pour les
  // modes qui ne les nécessitent pas (Carte bancaire/Espèce).
  final String? chequeNumber;
  final String? bankName;
  final String? chequeDate;
  final String? billOfExchangeNumber;
  final String? dueDate;
  // Document justificatif du paiement (module "PAYMENT") — référence souple
  // FinanceDocument, jamais une association Sequelize directe.
  final List<FinanceDocumentModel> documents;
  final String? createdAt;

  const FinancePaymentModel({
    required this.id,
    required this.invoiceId,
    this.amount = 0,
    this.paidDate,
    this.method,
    this.reference,
    this.chequeNumber,
    this.bankName,
    this.chequeDate,
    this.billOfExchangeNumber,
    this.dueDate,
    this.documents = const [],
    this.createdAt,
  });

  factory FinancePaymentModel.fromJson(Map<String, dynamic> json) {
    return FinancePaymentModel(
      id: (json['id'] ?? '').toString(),
      invoiceId: (json['invoiceId'] ?? '').toString(),
      amount: _toDouble(json['amount']) ?? 0,
      paidDate: json['paidDate']?.toString(),
      method: json['method']?.toString(),
      reference: json['reference']?.toString(),
      chequeNumber: json['chequeNumber']?.toString(),
      bankName: json['bankName']?.toString(),
      chequeDate: json['chequeDate']?.toString(),
      billOfExchangeNumber: json['billOfExchangeNumber']?.toString(),
      dueDate: json['dueDate']?.toString(),
      documents: (json['documents'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FinanceDocumentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class FinanceShipmentRef {
  final String id;
  final String reference;
  const FinanceShipmentRef({required this.id, required this.reference});

  factory FinanceShipmentRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FinanceShipmentRef(id: '', reference: '');
    return FinanceShipmentRef(id: (json['id'] ?? '').toString(), reference: (json['reference'] ?? '').toString());
  }
}

// Ligne de facture extraite par OCR (§ Invoice items) — toutes les valeurs
// restent nullable : une case vide dans l'UI signifie "non détecté", jamais
// une valeur inventée.
class FinanceInvoiceItemModel {
  final String id;
  final String? reference;
  final String? designation;
  final String? unit;
  final String? diameter;
  final String? meshSize;
  final double? quantity;
  final double? unitPriceHT;
  final double? rms;
  final double? amountHT;
  final double? tax1;
  final double? tax2;

  const FinanceInvoiceItemModel({
    this.id = '',
    this.reference,
    this.designation,
    this.unit,
    this.diameter,
    this.meshSize,
    this.quantity,
    this.unitPriceHT,
    this.rms,
    this.amountHT,
    this.tax1,
    this.tax2,
  });

  factory FinanceInvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return FinanceInvoiceItemModel(
      id: (json['id'] ?? '').toString(),
      reference: json['reference']?.toString(),
      designation: json['designation']?.toString(),
      unit: json['unit']?.toString(),
      diameter: json['diameter']?.toString(),
      meshSize: json['meshSize']?.toString(),
      quantity: _toDouble(json['quantity']),
      unitPriceHT: _toDouble(json['unitPriceHT']),
      rms: _toDouble(json['rms']),
      amountHT: _toDouble(json['amountHT']),
      tax1: _toDouble(json['tax1']),
      tax2: _toDouble(json['tax2']),
    );
  }

  // Toujours utiliser ces deux getters à l'affichage/export — jamais `unit`/
  // `diameter` bruts (§9-11).
  String? get displayUnit => normalizeFinanceUnit(unit, diameter).unit;
  String? get displayDiameter => normalizeFinanceUnit(unit, diameter).diameter;
}

// Ligne du bloc fiscal (Code/Base/Taux/Taxe, §STRUCTURE DES TAXES) — nombre
// de lignes dynamique, `rate`/`amount` restent nullable (ex. TFV sans taux
// ni montant imprimés sur le document), jamais une valeur inventée.
class FinanceInvoiceTaxModel {
  final String id;
  final int sortOrder;
  final String? code;
  final double? base;
  final double? rate;
  final double? amount;

  const FinanceInvoiceTaxModel({this.id = '', this.sortOrder = 0, this.code, this.base, this.rate, this.amount});

  factory FinanceInvoiceTaxModel.fromJson(Map<String, dynamic> json) {
    return FinanceInvoiceTaxModel(
      id: (json['id'] ?? '').toString(),
      sortOrder: _toInt(json['sortOrder']),
      code: json['code']?.toString(),
      base: _toDouble(json['base']),
      rate: _toDouble(json['rate']),
      amount: _toDouble(json['amount']),
    );
  }
}

class FinanceInvoiceModel {
  final String id;
  final String invoiceNumber;
  final String? reference;
  final String? shipmentId;
  final FinanceShipmentRef? shipment;
  final int customerId;
  final FinanceCustomerRef? customer;
  // Instantané client lu sur le document (OCR) — distinct de `customer`
  // (jamais résolu automatiquement vers un client existant en base).
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? customerGovernorate;
  final String? customerTaxId;
  final String? customerCode;
  final String? invoiceDate;
  final double amount;
  final double tax;
  final double total;
  // Totaux/règlement additionnels lus sur le document (§CORRIGER
  // L'EXTRACTION DES FACTURES) — jamais recalculés, extraits verbatim.
  final double? downPayment;
  final double? netToPay;
  final String? paymentCondition;
  final String? paymentDate;
  final String? paymentMethod;
  final String? amountInWords;
  final double? ocrConfidence;
  // §CORRECTION — WORKFLOW OCR FACTURED SHIPMENTS (2026-08-31) : signal
  // exposé par le backend (finance.dto.js#toInvoiceResponse), même principe
  // que `FinanceShipmentModel.hasReliableReference` — `invoiceNumber` ne
  // peut pas jouer ce rôle ici (il reçoit TOUJOURS une valeur, réelle ou
  // générée par repli, jamais null — voir isExtractionFailed ci-dessous).
  final bool hasReliableInvoiceNumber;
  final List<FinanceInvoiceTaxModel> taxes;
  final List<FinancePaymentModel> payments;
  final List<FinanceInvoiceItemModel> items;
  final List<FinanceDocumentModel> documents;
  final FinanceUserRef? creator;
  final String? createdAt;

  const FinanceInvoiceModel({
    required this.id,
    required this.invoiceNumber,
    this.reference,
    this.shipmentId,
    this.shipment,
    required this.customerId,
    this.customer,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.customerGovernorate,
    this.customerTaxId,
    this.customerCode,
    this.invoiceDate,
    this.amount = 0,
    this.tax = 0,
    this.total = 0,
    this.downPayment,
    this.netToPay,
    this.paymentCondition,
    this.paymentDate,
    this.paymentMethod,
    this.amountInWords,
    this.ocrConfidence,
    this.hasReliableInvoiceNumber = false,
    this.taxes = const [],
    this.payments = const [],
    this.items = const [],
    this.documents = const [],
    this.creator,
    this.createdAt,
  });

  // §CORRECTION — WORKFLOW OCR FACTURED SHIPMENTS (2026-08-31) : aligné
  // EXACTEMENT sur `FinancePurchaseOrderModel.isExtractionFailed` (Inflow of
  // raw materials, la référence explicite du ticket) — une facture dont le
  // numéro n'a jamais été détecté de façon fiable (même si l'OCR a "trouvé"
  // des lignes/montants ailleurs dans un document sans rapport) reste dans
  // "Export", jamais affichée comme une facture réelle dans le tableau
  // principal — exactement comme un Purchase Order sans orderNumber fiable
  // reste dans "Export". `!hasReliableInvoiceNumber` couvre aussi le cas
  // OCR totalement en échec (aucun texte exploitable → aucun champ n'est
  // jamais détecté avec confiance).
  bool get isExtractionFailed => !hasReliableInvoiceNumber;

  factory FinanceInvoiceModel.fromJson(Map<String, dynamic> json) {
    return FinanceInvoiceModel(
      id: (json['id'] ?? '').toString(),
      invoiceNumber: (json['invoiceNumber'] ?? '').toString(),
      reference: json['reference']?.toString(),
      shipmentId: json['shipmentId']?.toString(),
      shipment: json['shipment'] is Map ? FinanceShipmentRef.fromJson(Map<String, dynamic>.from(json['shipment'] as Map)) : null,
      customerId: _toInt(json['customerId']),
      customer: json['customer'] is Map ? FinanceCustomerRef.fromJson(Map<String, dynamic>.from(json['customer'] as Map)) : null,
      customerName: json['customerName']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      customerAddress: json['customerAddress']?.toString(),
      customerGovernorate: json['customerGovernorate']?.toString(),
      customerTaxId: json['customerTaxId']?.toString(),
      customerCode: json['customerCode']?.toString(),
      invoiceDate: json['invoiceDate']?.toString(),
      amount: _toDouble(json['amount']) ?? 0,
      tax: _toDouble(json['tax']) ?? 0,
      total: _toDouble(json['total']) ?? 0,
      downPayment: _toDouble(json['downPayment']),
      netToPay: _toDouble(json['netToPay']),
      paymentCondition: json['paymentCondition']?.toString(),
      paymentDate: json['paymentDate']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      amountInWords: json['amountInWords']?.toString(),
      ocrConfidence: _toDouble(json['ocrConfidence']),
      hasReliableInvoiceNumber: json['hasReliableInvoiceNumber'] == true,
      taxes: (json['taxes'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FinanceInvoiceTaxModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      payments: (json['payments'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FinancePaymentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      items: (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FinanceInvoiceItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      documents: (json['documents'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FinanceDocumentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      creator: json['creator'] is Map ? FinanceUserRef.fromJson(Map<String, dynamic>.from(json['creator'] as Map)) : null,
      createdAt: json['createdAt']?.toString(),
    );
  }
}

// ── PURCHASE ORDER (Inflow of raw materials — Bon de Commande, lu par OCR) ──

class FinancePurchaseOrderItemModel {
  final String id;
  final String? reference;
  final String? designation;
  final String? unit;
  final double? quantity;
  final double? unitPriceHT;
  final double? amountHT;

  const FinancePurchaseOrderItemModel({
    this.id = '',
    this.reference,
    this.designation,
    this.unit,
    this.quantity,
    this.unitPriceHT,
    this.amountHT,
  });

  factory FinancePurchaseOrderItemModel.fromJson(Map<String, dynamic> json) {
    return FinancePurchaseOrderItemModel(
      id: (json['id'] ?? '').toString(),
      reference: json['reference']?.toString(),
      designation: json['designation']?.toString(),
      unit: json['unit']?.toString(),
      quantity: _toDouble(json['quantity']),
      unitPriceHT: _toDouble(json['unitPriceHT']),
      amountHT: _toDouble(json['amountHT']),
    );
  }
}

class FinancePurchaseOrderModel {
  final String id;
  // Identifiant métier généré par l'application (§IDENTIFICATION DES
  // DIFFÉRENTS PURCHASE ORDERS), format "PO-00001" — distinct de
  // `orderNumber` (champ OCR, nullable, non-unique). Un seul par Purchase
  // Order, jamais par ligne produit.
  final String? poNumber;
  final String? orderNumber;
  final String? orderDate;
  final int? customerId;
  final FinanceCustomerRef? customer;
  // Instantané client lu sur le document (OCR) — distinct de `customer`
  // (jamais résolu automatiquement vers un client existant en base).
  final String? customerCode;
  final String? customerName;
  final String? customerAddress;
  final String? deliveryAddress;
  final double? totalHT;
  final double? ocrConfidence;
  // EXTRACTED | NEEDS_REVIEW | OCR_FAILED — voir
  // purchaseOrderFieldExtraction.service.js. Un bon OCR_FAILED n'a aucune
  // donnée fiable (numéro/client/produits/total tous null) : ne jamais
  // l'afficher comme un Purchase Order valide (§CORRIGER LES PROBLÈMES
  // ACTUELS DU MODULE FINANCE) — voir `isExtractionFailed` ci-dessous.
  final String status;
  final List<FinancePurchaseOrderItemModel> items;
  final List<FinanceDocumentModel> documents;
  final FinanceUserRef? creator;
  final String? createdAt;

  const FinancePurchaseOrderModel({
    required this.id,
    this.poNumber,
    this.orderNumber,
    this.orderDate,
    this.customerId,
    this.customer,
    this.customerCode,
    this.customerName,
    this.customerAddress,
    this.deliveryAddress,
    this.totalHT,
    this.ocrConfidence,
    this.status = 'NEEDS_REVIEW',
    this.items = const [],
    this.documents = const [],
    this.creator,
    this.createdAt,
  });

  factory FinancePurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    return FinancePurchaseOrderModel(
      id: (json['id'] ?? '').toString(),
      poNumber: json['poNumber']?.toString(),
      orderNumber: json['orderNumber']?.toString(),
      orderDate: json['orderDate']?.toString(),
      customerId: json['customerId'] == null ? null : _toInt(json['customerId']),
      customer: json['customer'] is Map ? FinanceCustomerRef.fromJson(Map<String, dynamic>.from(json['customer'] as Map)) : null,
      customerCode: json['customerCode']?.toString(),
      customerName: json['customerName']?.toString(),
      customerAddress: json['customerAddress']?.toString(),
      deliveryAddress: json['deliveryAddress']?.toString(),
      totalHT: _toDouble(json['totalHT']),
      ocrConfidence: _toDouble(json['ocrConfidence']),
      status: (json['status'] ?? 'NEEDS_REVIEW').toString(),
      items: (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FinancePurchaseOrderItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      documents: (json['documents'] as List? ?? [])
          .whereType<Map>()
          .map((e) => FinanceDocumentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      creator: json['creator'] is Map ? FinanceUserRef.fromJson(Map<String, dynamic>.from(json['creator'] as Map)) : null,
      createdAt: json['createdAt']?.toString(),
    );
  }

  // Aucune donnée fiable extraite (numéro absent) — c'est un document dont
  // l'OCR a échoué, pas un Purchase Order exploitable. Basé sur `orderNumber`
  // plutôt que sur `status` seul : un bon EXTRACTED/NEEDS_REVIEW avec un
  // numéro réel reste un vrai Purchase Order même si d'autres champs
  // manquent (jamais tout-ou-rien).
  bool get isExtractionFailed => status == 'OCR_FAILED' || (orderNumber == null || orderNumber!.isEmpty);

  String get displayCustomerName {
    if ((customerName ?? '').isNotEmpty) return customerName!;
    if (customer != null) return customer!.displayName;
    return '—';
  }
}

// ── DASHBOARD ───────────────────────────────────────────────────────────

// Finance Alerts (§10) — uniquement des compteurs réellement calculés côté
// backend (COUNT filtré sur 7 jours / statut), jamais un texte statique.
class FinanceDashboardAlertsModel {
  final int unpaidInvoices;
  final int newPurchaseOrdersThisWeek;
  final int newShipmentsThisWeek;
  final int recentDocumentsCount;

  const FinanceDashboardAlertsModel({
    this.unpaidInvoices = 0,
    this.newPurchaseOrdersThisWeek = 0,
    this.newShipmentsThisWeek = 0,
    this.recentDocumentsCount = 0,
  });

  factory FinanceDashboardAlertsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FinanceDashboardAlertsModel();
    return FinanceDashboardAlertsModel(
      unpaidInvoices: _toInt(json['unpaidInvoices']),
      newPurchaseOrdersThisWeek: _toInt(json['newPurchaseOrdersThisWeek']),
      newShipmentsThisWeek: _toInt(json['newShipmentsThisWeek']),
      recentDocumentsCount: _toInt(json['recentDocumentsCount']),
    );
  }
}

// KPI du Finance Dashboard (§4) — tous calculés dynamiquement côté backend
// (COUNT/SUM/GROUP BY), jamais de valeur statique côté frontend.
class FinanceDashboardModel {
  final int purchaseOrders;
  final int customerShipments;
  final int invoices;
  final int paidInvoices;
  final double totalPurchases;
  final double totalInvoiced;
  final double totalPaid;
  final double outstanding;
  final FinanceDashboardAlertsModel alerts;

  const FinanceDashboardModel({
    this.purchaseOrders = 0,
    this.customerShipments = 0,
    this.invoices = 0,
    this.paidInvoices = 0,
    this.totalPurchases = 0,
    this.totalInvoiced = 0,
    this.totalPaid = 0,
    this.outstanding = 0,
    this.alerts = const FinanceDashboardAlertsModel(),
  });

  factory FinanceDashboardModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FinanceDashboardModel();
    return FinanceDashboardModel(
      purchaseOrders: _toInt(json['purchaseOrders']),
      customerShipments: _toInt(json['customerShipments']),
      invoices: _toInt(json['invoices']),
      paidInvoices: _toInt(json['paidInvoices']),
      totalPurchases: _toDouble(json['totalPurchases']) ?? 0,
      totalInvoiced: _toDouble(json['totalInvoiced']) ?? 0,
      totalPaid: _toDouble(json['totalPaid']) ?? 0,
      outstanding: _toDouble(json['outstanding']) ?? 0,
      alerts: json['alerts'] is Map ? FinanceDashboardAlertsModel.fromJson(Map<String, dynamic>.from(json['alerts'] as Map)) : const FinanceDashboardAlertsModel(),
    );
  }
}

// "Financial Overview" (§5) — un point de la série mensuelle Purchase
// Orders/Invoices/Paid Invoices, agrégé côté backend.
class FinanceMonthlyPointModel {
  final String month; // "YYYY-MM"
  final double purchaseOrders;
  final double invoices;
  final double paidInvoices;

  const FinanceMonthlyPointModel({
    required this.month,
    this.purchaseOrders = 0,
    this.invoices = 0,
    this.paidInvoices = 0,
  });

  factory FinanceMonthlyPointModel.fromJson(Map<String, dynamic> json) {
    return FinanceMonthlyPointModel(
      month: (json['month'] ?? '').toString(),
      purchaseOrders: _toDouble(json['purchaseOrders']) ?? 0,
      invoices: _toDouble(json['invoices']) ?? 0,
      paidInvoices: _toDouble(json['paidInvoices']) ?? 0,
    );
  }

  // "Janvier"/"Février"/... (§5) — libellé du mois pour l'axe du graphique.
  String monthLabel(List<String> monthNames) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    final idx = int.tryParse(parts[1]);
    if (idx == null || idx < 1 || idx > 12) return month;
    return monthNames[idx - 1];
  }
}

// Format professionnel des grands nombres — même convention que
// production_summary_model.dart#formatProductionNumber.
String formatFinanceNumber(double value) {
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

String formatFinanceFileSize(int bytes) {
  if (bytes <= 0) return '0 KB';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
