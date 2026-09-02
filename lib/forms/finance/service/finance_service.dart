// lib/forms/finance/service/finance_service.dart
//
// Client HTTP pour GET/POST /finance/* — même client Dio et même parsing
// d'enveloppe tolérant que les autres services de l'app (voir
// production_records_service.dart#_unwrapObject).

import 'dart:typed_data';

import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show ValueChanged;

import '../model/finance_models.dart';

class FinancePickedFile {
  final Uint8List bytes;
  final String filename;
  const FinancePickedFile({required this.bytes, required this.filename});
}

class FinancePagedResult<T> {
  final List<T> items;
  final int count;
  final int page;
  final int pageSize;
  const FinancePagedResult({this.items = const [], this.count = 0, this.page = 1, this.pageSize = 50});
}

class FinanceService {
  static final FinanceService instance = FinanceService._();
  FinanceService._();

  static const _basePath = '/finance';

  Map<String, dynamic> _unwrapObject(dynamic data) {
    if (data is Map && data['data'] is Map) return Map<String, dynamic>.from(data['data'] as Map);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Map<String, String> _cleanParams(Map<String, String?> raw) {
    final params = <String, String>{};
    raw.forEach((k, v) {
      if (v != null && v.isNotEmpty) params[k] = v;
    });
    return params;
  }

  // ── DASHBOARD ────────────────────────────────────────────────────────

  // Filtres optionnels (§11) — appliqués côté backend (COUNT/SUM/GROUP BY
  // filtrés, §16-17), jamais recalculés côté client.
  Future<FinanceDashboardModel> fetchDashboard({
    String? startDate,
    String? endDate,
    String? customer,
    String? paymentMethod,
  }) async {
    final res = await ApiClient.instance.dio.get(
      '$_basePath/dashboard',
      queryParameters: _cleanParams({'startDate': startDate, 'endDate': endDate, 'customer': customer, 'paymentMethod': paymentMethod}),
    );
    return FinanceDashboardModel.fromJson(_unwrapObject(res.data));
  }

  Future<List<FinanceMonthlyPointModel>> fetchDashboardMonthly({
    String? startDate,
    String? endDate,
    String? customer,
    String? paymentMethod,
  }) async {
    final res = await ApiClient.instance.dio.get(
      '$_basePath/dashboard/monthly',
      queryParameters: _cleanParams({'startDate': startDate, 'endDate': endDate, 'customer': customer, 'paymentMethod': paymentMethod}),
    );
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return (body['data'] as List? ?? []).whereType<Map>().map((e) => FinanceMonthlyPointModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // ── INFLOW OF RAW MATERIALS (Bon de Commande, lu par OCR à l'upload) ────

  Future<FinancePagedResult<FinancePurchaseOrderModel>> fetchRawMaterials({
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    final res = await ApiClient.instance.dio.get(
      '$_basePath/raw-materials',
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        ..._cleanParams({'search': search}),
      },
    );
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final items = (body['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => FinancePurchaseOrderModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return FinancePagedResult(
      items: items,
      count: _toInt(body['count']),
      page: _toInt(body['page']) == 0 ? page : _toInt(body['page']),
      pageSize: _toInt(body['pageSize']) == 0 ? pageSize : _toInt(body['pageSize']),
    );
  }

  // Le Bon de Commande est LU par OCR côté serveur à l'upload (numéro,
  // client, adresse de livraison, lignes produit, total) — même principe
  // que uploadInvoice, timeout allongé pour laisser le temps au traitement.
  Future<FinancePurchaseOrderModel> uploadRawMaterial(
    FinancePickedFile file, {
    ValueChanged<double>? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(file.bytes, filename: file.filename),
    });
    final res = await ApiClient.instance.dio.post(
      '$_basePath/raw-materials/upload',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 90), receiveTimeout: const Duration(seconds: 90)),
      onSendProgress: onProgress == null
          ? null
          : (sent, total) {
              if (total > 0) onProgress(sent / total);
            },
    );
    return FinancePurchaseOrderModel.fromJson(_unwrapObject(res.data));
  }

  Future<FinancePurchaseOrderModel> fetchRawMaterial(String id) async {
    final res = await ApiClient.instance.dio.get('$_basePath/raw-materials/$id');
    return FinancePurchaseOrderModel.fromJson(_unwrapObject(res.data));
  }

  Future<void> deleteRawMaterial(String id) async {
    await ApiClient.instance.dio.delete('$_basePath/raw-materials/$id');
  }

  // §MODIFICATION — INFLOW RAW MATERIALS : "Order date" éditable directement
  // depuis le tableau — corrige une date que l'OCR n'a pas trouvée ou a mal
  // lue. Format "AAAA-MM-JJ" uniquement (jamais `.toIso8601String()`, qui
  // inclurait une heure locale ambiguë) — évite tout décalage d'un jour lié
  // au fuseau horaire (§5 du ticket), revalidé de toute façon côté serveur
  // (§4/§12 — jamais fait confiance à la seule validation Flutter).
  Future<FinancePurchaseOrderModel> updateRawMaterialOrderDate(String id, DateTime newDate) async {
    final formatted =
        '${newDate.year.toString().padLeft(4, '0')}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
    final res = await ApiClient.instance.dio.patch('$_basePath/raw-materials/$id', data: {'orderDate': formatted});
    return FinancePurchaseOrderModel.fromJson(_unwrapObject(res.data));
  }

  // §MODIFICATION — SCAN DOCUMENTS (INCLUDE IMPORT) : PLUSIEURS DOCUMENTS PAR
  // LIGNE (2026-09-01) — ajoute N document(s) supplémentaire(s) à UN bon de
  // commande déjà EXISTANT (jamais un nouveau bon créé, contrairement à
  // uploadRawMaterial ci-dessus qui, lui, lit le fichier par OCR et crée
  // toujours un nouveau bon). Même pattern multipart "documents" (liste) que
  // createShipment/uploadInvoice — un seul POST envoie tous les fichiers.
  Future<FinancePurchaseOrderModel> addRawMaterialDocuments(String orderId, List<FinancePickedFile> files) async {
    final formData = FormData.fromMap({
      'documents': files.map((f) => MultipartFile.fromBytes(f.bytes, filename: f.filename)).toList(),
    });
    final res = await ApiClient.instance.dio.post(
      '$_basePath/raw-materials/$orderId/documents',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)),
    );
    return FinancePurchaseOrderModel.fromJson(_unwrapObject(res.data));
  }

  // §9 du ticket : supprime UN SEUL document d'un bon de commande, jamais le
  // bon de commande entier ni les autres documents qui lui sont rattachés
  // (voir deleteRawMaterial ci-dessus pour la suppression complète).
  Future<FinancePurchaseOrderModel> deleteRawMaterialDocument(String orderId, String documentId) async {
    final res = await ApiClient.instance.dio.delete('$_basePath/raw-materials/$orderId/documents/$documentId');
    return FinancePurchaseOrderModel.fromJson(_unwrapObject(res.data));
  }

  // ── FINANCE > OTHER + sous-menu "Import" des 4 autres pages Finance ─────
  // (§MODIFICATION CRM — AJOUTER UN SOUS-MENU IMPORT À CHAQUE MENU FINANCE) :
  // stockage documentaire pur, AUCUN OCR/extraction, EXACTEMENT le même
  // pipeline pour les 5 modules — seul `apiSegment` change ("other-documents"
  // pour Other, "raw-materials/import"/"shipments/import"/"invoices/import"/
  // "paid-invoices/import" pour les 4 nouveaux sous-menus, voir
  // finance.routes.js côté backend). fetchOtherDocuments/uploadOtherDocument/
  // renameOtherDocument/deleteOtherDocument restent exportées à l'identique
  // (enveloppes figées sur "other-documents") — jamais une seconde
  // implémentation d'upload.

  Future<FinancePagedResult<FinanceDocumentModel>> fetchImportDocuments(
    String apiSegment, {
    String? search,
    String? type,
    String? startDate,
    String? endDate,
    int page = 1,
    int pageSize = 50,
  }) async {
    final res = await ApiClient.instance.dio.get(
      '$_basePath/$apiSegment',
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        ..._cleanParams({'search': search, 'type': type, 'startDate': startDate, 'endDate': endDate}),
      },
    );
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final items = (body['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => FinanceDocumentModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return FinancePagedResult(
      items: items,
      count: _toInt(body['count']),
      page: _toInt(body['page']) == 0 ? page : _toInt(body['page']),
      pageSize: _toInt(body['pageSize']) == 0 ? pageSize : _toInt(body['pageSize']),
    );
  }

  // "Upload Document"/"Scan Document" (§4-5) — un simple dépôt de fichier,
  // AUCUN OCR/extraction déclenché côté serveur (voir
  // finance.service.js#uploadImportDocument) — le backend renvoie
  // immédiatement le document enregistré, pas de séquence "Reading.../
  // Extracting..." comme pour Invoice/Shipment/Purchase Order.
  Future<FinanceDocumentModel> uploadImportDocument(
    String apiSegment,
    FinancePickedFile file, {
    ValueChanged<double>? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(file.bytes, filename: file.filename),
    });
    final res = await ApiClient.instance.dio.post(
      '$_basePath/$apiSegment',
      data: formData,
      onSendProgress: onProgress == null
          ? null
          : (sent, total) {
              if (total > 0) onProgress(sent / total);
            },
    );
    return FinanceDocumentModel.fromJson(_unwrapObject(res.data));
  }

  // §7/§12/§19 : modifie UNIQUEMENT le nom d'affichage — jamais le fichier
  // physique ni son URL.
  Future<FinanceDocumentModel> renameImportDocument(String apiSegment, String id, String displayName) async {
    final res = await ApiClient.instance.dio.patch('$_basePath/$apiSegment/$id', data: {'displayName': displayName});
    return FinanceDocumentModel.fromJson(_unwrapObject(res.data));
  }

  Future<void> deleteImportDocument(String apiSegment, String id) async {
    await ApiClient.instance.dio.delete('$_basePath/$apiSegment/$id');
  }

  Future<FinancePagedResult<FinanceDocumentModel>> fetchOtherDocuments({
    String? search,
    String? type,
    String? startDate,
    String? endDate,
    int page = 1,
    int pageSize = 50,
  }) =>
      fetchImportDocuments('other-documents', search: search, type: type, startDate: startDate, endDate: endDate, page: page, pageSize: pageSize);

  Future<FinanceDocumentModel> uploadOtherDocument(FinancePickedFile file, {ValueChanged<double>? onProgress}) =>
      uploadImportDocument('other-documents', file, onProgress: onProgress);

  Future<FinanceDocumentModel> renameOtherDocument(String id, String displayName) =>
      renameImportDocument('other-documents', id, displayName);

  Future<void> deleteOtherDocument(String id) => deleteImportDocument('other-documents', id);

  // Aperçu — récupère les octets bruts du fichier (utilisé par le viewer
  // PDF/image), en réutilisant la même session Dio (donc les mêmes en-têtes
  // d'auth) qu'un simple `Image.network`/lien direct ne fournirait pas.
  Future<Uint8List> fetchFileBytes(String fileUrl) async {
    final res = await ApiClient.instance.dio.get<List<int>>(
      fileUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }

  // ── SHIPMENTS ────────────────────────────────────────────────────────

  Future<FinancePagedResult<FinanceShipmentModel>> fetchShipments({
    String? search,
    String? status,
    String? customerId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final res = await ApiClient.instance.dio.get(
      '$_basePath/shipments',
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        ..._cleanParams({'search': search, 'status': status, 'customerId': customerId}),
      },
    );
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final items = (body['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => FinanceShipmentModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return FinancePagedResult(
      items: items,
      count: _toInt(body['count']),
      page: _toInt(body['page']) == 0 ? page : _toInt(body['page']),
      pageSize: _toInt(body['pageSize']) == 0 ? pageSize : _toInt(body['pageSize']),
    );
  }

  // "New shipment" simplifié : le formulaire ne collecte que des documents —
  // le backend crée le Shipment ET les documents de façon atomique (référence
  // auto-générée SHIP-{année}-NNNNNN, statut DRAFT). `onProgress` reçoit une
  // fraction 0..1 (Dio `onSendProgress`, upload global — un seul POST envoie
  // tous les fichiers dans le champ multipart "documents").
  // Le premier fichier est lu par OCR côté serveur (Bon de Livraison) avant
  // que le Shipment ne soit créé — timeout nettement plus long que les
  // autres appels (~90s), même principe que uploadInvoice.
  Future<FinanceShipmentModel> createShipment({
    required List<FinancePickedFile> documents,
    ValueChanged<double>? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'documents': documents.map((f) => MultipartFile.fromBytes(f.bytes, filename: f.filename)).toList(),
    });
    final res = await ApiClient.instance.dio.post(
      '$_basePath/shipments',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 90), receiveTimeout: const Duration(seconds: 90)),
      onSendProgress: onProgress == null
          ? null
          : (sent, total) {
              if (total > 0) onProgress(sent / total);
            },
    );
    return FinanceShipmentModel.fromJson(_unwrapObject(res.data));
  }

  Future<FinanceShipmentModel> fetchShipment(String id) async {
    final res = await ApiClient.instance.dio.get('$_basePath/shipments/$id');
    return FinanceShipmentModel.fromJson(_unwrapObject(res.data));
  }

  Future<FinanceShipmentModel> updateShipment(String id, Map<String, dynamic> body) async {
    final res = await ApiClient.instance.dio.put('$_basePath/shipments/$id', data: body);
    return FinanceShipmentModel.fromJson(_unwrapObject(res.data));
  }

  // §MODIFICATION — CUSTOMER SHIPMENTS / SCAN : "Delivery date" éditable
  // depuis la section "Documents requiring extraction" — corrige une date que
  // l'OCR n'a pas trouvée ou a mal lue. Réutilise `updateShipment` ci-dessus
  // (endpoint existant, aucun nouveau endpoint créé — §10 du ticket). Format
  // "AAAA-MM-JJ" uniquement (même raisonnement que
  // updateRawMaterialOrderDate ci-dessus — §11 du ticket, "éviter le
  // décalage UTC"), revalidé de toute façon côté serveur.
  Future<FinanceShipmentModel> updateShipmentDeliveryDate(String id, DateTime newDate) {
    final formatted =
        '${newDate.year.toString().padLeft(4, '0')}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
    return updateShipment(id, {'shipmentDate': formatted});
  }

  // Suppression réelle côté backend (shipment + produits + documents +
  // fichiers, transaction Sequelize) — jamais un simple retrait côté
  // frontend. Ne supprime jamais une facture liée (son shipmentId est mis à
  // NULL côté serveur).
  Future<void> deleteShipment(String id) async {
    await ApiClient.instance.dio.delete('$_basePath/shipments/$id');
  }

  // §MODIFICATION — CUSTOMER SHIPMENTS / SCAN DOCUMENTS : PLUSIEURS
  // DOCUMENTS PAR LIGNE (2026-09-01) — ajoute N document(s) supplémentaire(s)
  // à UN shipment déjà EXISTANT (jamais un nouveau shipment créé,
  // contrairement à createShipment ci-dessus). Même pattern multipart
  // "documents" (liste) que createShipment/addRawMaterialDocuments — un seul
  // POST envoie tous les fichiers.
  Future<FinanceShipmentModel> addShipmentDocuments(String shipmentId, List<FinancePickedFile> files) async {
    final formData = FormData.fromMap({
      'documents': files.map((f) => MultipartFile.fromBytes(f.bytes, filename: f.filename)).toList(),
    });
    final res = await ApiClient.instance.dio.post(
      '$_basePath/shipments/$shipmentId/documents',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)),
    );
    return FinanceShipmentModel.fromJson(_unwrapObject(res.data));
  }

  // §8 du ticket : supprime UN SEUL document d'un shipment, jamais le
  // shipment entier ni les autres documents qui lui sont rattachés (voir
  // deleteShipment ci-dessus pour la suppression complète).
  Future<FinanceShipmentModel> deleteShipmentDocument(String shipmentId, String documentId) async {
    final res = await ApiClient.instance.dio.delete('$_basePath/shipments/$shipmentId/documents/$documentId');
    return FinanceShipmentModel.fromJson(_unwrapObject(res.data));
  }

  // ── INVOICES (Factured shipments / Paid factures) ───────────────────

  Future<FinancePagedResult<FinanceInvoiceModel>> _fetchInvoicesFrom(
    String path, {
    String? search,
    String? status,
    String? customerId,
    String? startDate,
    String? endDate,
    int page = 1,
    int pageSize = 50,
  }) async {
    final res = await ApiClient.instance.dio.get(
      path,
      queryParameters: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        ..._cleanParams({
          'search': search,
          'status': status,
          'customerId': customerId,
          'startDate': startDate,
          'endDate': endDate,
        }),
      },
    );
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final items = (body['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => FinanceInvoiceModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return FinancePagedResult(
      items: items,
      count: _toInt(body['count']),
      page: _toInt(body['page']) == 0 ? page : _toInt(body['page']),
      pageSize: _toInt(body['pageSize']) == 0 ? pageSize : _toInt(body['pageSize']),
    );
  }

  Future<FinancePagedResult<FinanceInvoiceModel>> fetchInvoices({
    String? search,
    String? status,
    String? customerId,
    String? startDate,
    String? endDate,
    int page = 1,
    int pageSize = 50,
  }) =>
      _fetchInvoicesFrom(
        '$_basePath/invoices',
        search: search,
        status: status,
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
        page: page,
        pageSize: pageSize,
      );

  Future<FinancePagedResult<FinanceInvoiceModel>> fetchPaidInvoices({
    String? search,
    String? customerId,
    String? startDate,
    String? endDate,
    int page = 1,
    int pageSize = 50,
  }) =>
      _fetchInvoicesFrom(
        '$_basePath/paid-invoices',
        search: search,
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
        page: page,
        pageSize: pageSize,
      );

  Future<FinanceInvoiceModel> fetchInvoice(String id) async {
    final res = await ApiClient.instance.dio.get('$_basePath/invoices/$id');
    return FinanceInvoiceModel.fromJson(_unwrapObject(res.data));
  }

  // §CORRECTION — FACTURED SHIPMENTS / PAID INVOICES (2026-09-01) : "Invoice
  // date" éditable directement depuis le tableau "Sage Documents" — corrige
  // une date que l'OCR n'a pas trouvée ou a mal lue. Réutilise le NOUVEL
  // endpoint dédié PATCH /finance/invoices/:id (aucun endpoint existant ne
  // permettait de modifier un champ de facture arbitraire — voir §13/§1 du
  // ticket). Format "AAAA-MM-JJ" uniquement (même raisonnement que
  // updateRawMaterialOrderDate/updateShipmentDeliveryDate — éviter le
  // décalage UTC), revalidé de toute façon côté serveur.
  Future<FinanceInvoiceModel> updateInvoiceDate(String id, DateTime newDate) async {
    final formatted =
        '${newDate.year.toString().padLeft(4, '0')}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
    final res = await ApiClient.instance.dio.patch('$_basePath/invoices/$id', data: {'invoiceDate': formatted});
    return FinanceInvoiceModel.fromJson(_unwrapObject(res.data));
  }

  Future<FinanceInvoiceModel> createInvoice({
    required String invoiceNumber,
    String? shipmentId,
    required int customerId,
    required String invoiceDate,
    required double amount,
    double tax = 0,
  }) async {
    final res = await ApiClient.instance.dio.post('$_basePath/invoices', data: {
      'invoiceNumber': invoiceNumber,
      if (shipmentId != null && shipmentId.isNotEmpty) 'shipmentId': shipmentId,
      'customerId': customerId,
      'invoiceDate': invoiceDate,
      'amount': amount,
      'tax': tax,
    });
    return FinanceInvoiceModel.fromJson(_unwrapObject(res.data));
  }

  // "Upload invoice" simplifié (page Factured shipments) : le modal ne
  // collecte que des documents — le backend crée la facture ET les documents
  // de façon atomique (numéro auto-généré INV-{année}-NNNNNN, statut par
  // défaut du modèle). Même principe que createShipment ci-dessus.
  // "Upload invoice" — 1 fichier = 1 facture indépendamment lue par OCR
  // (confirmé avec l'utilisateur), donc la réponse est un TABLEAU même si un
  // seul fichier a été envoyé. Le traitement (OCR + extraction) tourne côté
  // serveur après l'upload, d'où un timeout nettement plus long que les
  // autres appels (~90s, un PDF scanné multi-pages peut prendre du temps).
  Future<List<FinanceInvoiceModel>> uploadInvoice({
    required List<FinancePickedFile> documents,
    ValueChanged<double>? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'documents': documents.map((f) => MultipartFile.fromBytes(f.bytes, filename: f.filename)).toList(),
    });
    final res = await ApiClient.instance.dio.post(
      '$_basePath/invoices',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 90), receiveTimeout: const Duration(seconds: 90)),
      onSendProgress: onProgress == null
          ? null
          : (sent, total) {
              if (total > 0) onProgress(sent / total);
            },
    );
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final list = (body['data'] as List? ?? []);
    return list.whereType<Map>().map((e) => FinanceInvoiceModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // "Register payment" (§MODIFIER LE WORKFLOW PAYMENT / PAID FACTURES) —
  // formulaire minimal : `method` (dropdown fermé à 4 valeurs, voir
  // PAYMENT_METHODS côté backend) + `document` (justificatif, obligatoire —
  // vérifié côté service) sont les SEULS champs collectés par l'UI.
  // amount/paidDate ne sont plus saisis manuellement — le backend les déduit
  // (montant total de la facture, date de règlement déjà extraite par
  // l'OCR) quand ils sont absents, d'où un envoi multipart systématique
  // (même principe que uploadInvoice) plutôt qu'un JSON simple.
  // §CORRECTION — SIMPLIFICATION REGISTER PAYMENT (2026-08-31) :
  // chequeNumber/bankName/chequeDate/billOfExchangeNumber/dueDate (ajoutés
  // au ticket précédent) retirés — plus aucun appelant ne les envoie (§2 du
  // ticket : "le formulaire doit rester minimal"). Restent acceptés par
  // registerPaymentSchema côté backend (finance.validator.js, jamais
  // modifié) si un futur appelant en a besoin — seule cette méthode ne les
  // expose plus.
  Future<FinanceInvoiceModel> registerPayment(
    String invoiceId, {
    required String method,
    FinancePickedFile? document,
    double? amount,
    String? paidDate,
    String? reference,
  }) async {
    final formData = FormData.fromMap({
      'method': method,
      if (amount != null) 'amount': amount,
      if (paidDate != null && paidDate.isNotEmpty) 'paidDate': paidDate,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (document != null) 'document': MultipartFile.fromBytes(document.bytes, filename: document.filename),
    });
    final res = await ApiClient.instance.dio.post('$_basePath/invoices/$invoiceId/payments', data: formData);
    return FinanceInvoiceModel.fromJson(_unwrapObject(res.data));
  }

  // Suppression réelle côté backend (invoice + lignes + paiements +
  // documents + fichiers, transaction Sequelize) — jamais un simple retrait
  // côté frontend.
  Future<void> deleteInvoice(String id) async {
    await ApiClient.instance.dio.delete('$_basePath/invoices/$id');
  }

  // §MODIFICATION — FACTURED SHIPMENTS / SCAN DOCUMENTS (INCLUDE EXPORT) :
  // PLUSIEURS DOCUMENTS PAR LIGNE (2026-09-02) — ajoute N document(s)
  // supplémentaire(s) à UNE facture déjà EXISTANTE (jamais une nouvelle
  // facture créée, contrairement à uploadInvoice ci-dessus). Même pattern
  // multipart "documents" (liste) que createShipment/addRawMaterialDocuments/
  // addShipmentDocuments — un seul POST envoie tous les fichiers.
  Future<FinanceInvoiceModel> addInvoiceDocuments(String invoiceId, List<FinancePickedFile> files) async {
    final formData = FormData.fromMap({
      'documents': files.map((f) => MultipartFile.fromBytes(f.bytes, filename: f.filename)).toList(),
    });
    final res = await ApiClient.instance.dio.post(
      '$_basePath/invoices/$invoiceId/documents',
      data: formData,
      options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)),
    );
    return FinanceInvoiceModel.fromJson(_unwrapObject(res.data));
  }

  // §6 du ticket : supprime UN SEUL document d'une facture, jamais la
  // facture entière ni les autres documents qui lui sont rattachés (voir
  // deleteInvoice ci-dessus pour la suppression complète).
  Future<FinanceInvoiceModel> deleteInvoiceDocument(String invoiceId, String documentId) async {
    final res = await ApiClient.instance.dio.delete('$_basePath/invoices/$invoiceId/documents/$documentId');
    return FinanceInvoiceModel.fromJson(_unwrapObject(res.data));
  }

  // ── CUSTOMERS (réutilise la table clients existante, GET /api/clients/all
  // — pas de nouvel endpoint) ──────────────────────────────────────────

  Future<List<FinanceCustomerRef>> fetchCustomers() async {
    final res = await ApiClient.instance.dio.get('/api/clients/all');
    final list = res.data is List ? (res.data as List) : const [];
    return list.whereType<Map>().map((e) => FinanceCustomerRef.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
