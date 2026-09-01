// lib/forms/finance/view/finance_inflow_raw_materials_screen.dart
//
// "Inflow of raw materials" — dépôt (Drag & Drop + Scan document) d'un Bon
// de Commande, lu automatiquement par OCR à l'upload (§CORRECTION —
// EXTRACTION AUTOMATIQUE DES BONS DE COMMANDE : numéro, client, adresse de
// livraison, lignes produit, total HT), puis affiché en tableau PROFESSIONNEL
// UNE LIGNE PAR PRODUIT (§MODIFIER FINANCE → INFLOW OF RAW MATERIALS) avec
// recherche/filtres/pagination/export Excel/export CSV — alimenté UNIQUEMENT
// par les données déjà extraites et enregistrées (aucun nouvel OCR ici, ni à
// l'affichage ni aux exports).
//
// "Amount HT" et "Total HT" (§SUPPRIMER HT + EXPORT CSV COMPLET) ne sont
// PLUS affichés dans cette interface — les valeurs restent en base et sont
// toujours incluses dans les deux exports (Excel §MODIFIER FINANCE, CSV
// §AJOUTER EXPORT CSV), jamais supprimées ni recalculées.

import 'dart:convert';
import 'dart:html' as html;

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/application/common/safe_snack.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/widgets/responsive_dialog_box.dart';

import '../model/finance_models.dart';
import '../service/finance_service.dart';
import '../theme/finance_theme.dart';
import 'widgets/finance_documents_table.dart';
import 'widgets/finance_preview_dialog.dart';
import 'widgets/finance_purchase_order_detail_dialog.dart';
import 'widgets/finance_purchase_orders_table.dart';
import 'widgets/finance_upload_dropzone.dart';

const int _kRowsPerPage = 50;
// Suffisamment grand pour charger la totalité des Bons de Commande en un
// seul appel — le filtrage/tri/pagination du tableau (recherche, Order #,
// Customer, Reference, dates) se fait ensuite CÔTÉ CLIENT sur les données
// déjà extraites, sans jamais relancer l'OCR ni ajouter d'endpoint backend
// (§1, §10 : les données existent déjà via GET /finance/raw-materials).
const int _kFetchAllPageSize = 2000;

class FinanceInflowRawMaterialsScreen extends StatefulWidget {
  const FinanceInflowRawMaterialsScreen({super.key});

  @override
  State<FinanceInflowRawMaterialsScreen> createState() => _FinanceInflowRawMaterialsScreenState();
}

class _FinanceInflowRawMaterialsScreenState extends State<FinanceInflowRawMaterialsScreen> {
  bool _loading = true;
  bool _uploading = false;
  bool _exporting = false;
  bool _exportingCsv = false;
  String? _error;
  List<FinancePurchaseOrderModel> _orders = const [];
  // §CORRECTION — SUPPRESSION FINANCE : empêche deux requêtes DELETE
  // simultanées sur le même Purchase Order (double-clic rapide sur 🗑).
  final Set<String> _deletingIds = {};

  // Filtres (§3) — tous appliqués côté client sur les lignes déjà aplaties.
  String _search = '';
  String _orderNumberFilter = '';
  String _customerFilter = '';
  String _referenceFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;
  int _page = 1;

  // Un document dont l'OCR a échoué (aucun numéro détecté) n'est pas un
  // Purchase Order valide — voir FinancePurchaseOrderModel.isExtractionFailed.
  List<FinancePurchaseOrderModel> get _validOrders => _orders.where((o) => !o.isExtractionFailed).toList();
  List<FinancePurchaseOrderModel> get _failedOrders => _orders.where((o) => o.isExtractionFailed).toList();

  // Aplatissement UNE LIGNE PAR PRODUIT (§2) — jamais une ligne par bon.
  List<RawMaterialRow> get _allRows => [
        for (final order in _validOrders)
          for (final item in order.items) RawMaterialRow(order: order, item: item),
      ];

  List<RawMaterialRow> get _filteredRows {
    final search = _search.trim().toLowerCase();
    final orderFilter = _orderNumberFilter.trim().toLowerCase();
    final customerFilter = _customerFilter.trim().toLowerCase();
    final refFilter = _referenceFilter.trim().toLowerCase();
    return _allRows.where((r) {
      if (search.isNotEmpty) {
        // Recherche par PO #/Order #/Customer/Reference/Designation (§8) —
        // ex. "PO-00001" n'affiche que les produits de ce Purchase Order.
        final haystack = [
          r.order.poNumber,
          r.order.orderNumber,
          r.order.displayCustomerName,
          r.item.reference,
          r.item.designation,
        ].where((v) => v != null).map((v) => v!.toLowerCase()).join(' ');
        if (!haystack.contains(search)) return false;
      }
      if (orderFilter.isNotEmpty && !(r.order.orderNumber ?? '').toLowerCase().contains(orderFilter)) return false;
      if (customerFilter.isNotEmpty && !r.order.displayCustomerName.toLowerCase().contains(customerFilter)) return false;
      if (refFilter.isNotEmpty && !(r.item.reference ?? '').toLowerCase().contains(refFilter)) return false;
      if (_startDate != null || _endDate != null) {
        final d = r.order.orderDate == null ? null : DateTime.tryParse(r.order.orderDate!);
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        if (_startDate != null && day.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) return false;
        if (_endDate != null && day.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day))) return false;
      }
      return true;
    }).toList();
  }

  double get _filteredTotalHT => _filteredRows.fold(0.0, (sum, r) => sum + (r.item.amountHT ?? 0));

  int get _pageCount => (_filteredRows.length / _kRowsPerPage).ceil().clamp(1, 1 << 30);

  List<RawMaterialRow> get _pageRows {
    final start = (_page - 1) * _kRowsPerPage;
    if (start >= _filteredRows.length) return const [];
    return _filteredRows.skip(start).take(_kRowsPerPage).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await FinanceService.instance.fetchRawMaterials(pageSize: _kFetchAllPageSize);
      if (!mounted) return;
      setState(() {
        _orders = page.items;
        _page = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetFilters() {
    setState(() {
      _search = '';
      _orderNumberFilter = '';
      _customerFilter = '';
      _referenceFilter = '';
      _startDate = null;
      _endDate = null;
      _page = 1;
    });
  }

  // "Inflow of raw materials" upload = 1 fichier = 1 Bon de Commande, lu
  // indépendamment par OCR (même principe que "Upload invoice") — une boucle
  // par fichier sélectionné, le dropzone peut recevoir plusieurs fichiers.
  Future<void> _handleFilesSelected(List<FinancePickedFile> files) async {
    setState(() => _uploading = true);
    var successCount = 0;
    String? lastError;
    FinancePurchaseOrderModel? lastOrder;
    for (final file in files) {
      try {
        lastOrder = await FinanceService.instance.uploadRawMaterial(file);
        successCount++;
      } catch (e) {
        lastError = e.toString();
      }
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    if (successCount > 0) await _load();
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    if (lastError != null) {
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${t.translate('Erreur')} : $lastError'), backgroundColor: kCrmDanger),
      );
    } else if (successCount == 1 && lastOrder != null) {
      // Un seul fichier traité : ouvre directement la fiche extraite, comme
      // "Upload invoice" le fait déjà pour les factures.
      showFinancePurchaseOrderDetail(context, lastOrder);
    } else if (successCount > 0) {
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(successCount == 1 ? t.translate('Document déposé') : t.translate('Documents déposés')),
          backgroundColor: kCrmSuccess,
        ),
      );
    }
  }

  Future<void> _handleView(FinancePurchaseOrderModel order) async {
    await showFinancePurchaseOrderDetail(context, order);
  }

  // §MODIFICATION — INFLOW RAW MATERIALS : "Order date" éditable directement
  // depuis le tableau (§2/§6 du ticket). Le PATCH réel se fait dans
  // FinanceService (jamais un recalcul local) — ce screen ne fait que
  // transmettre l'appel et appliquer le Purchase Order mis à jour renvoyé
  // par le backend à `_orders`, sans jamais recharger toute la liste
  // (§6 : "éviter de recharger toute la page inutilement").
  Future<FinancePurchaseOrderModel> _saveOrderDate(String id, DateTime newDate) {
    return FinanceService.instance.updateRawMaterialOrderDate(id, newDate);
  }

  void _applyUpdatedOrder(FinancePurchaseOrderModel updated) {
    if (!mounted) return;
    setState(() => _orders = [for (final o in _orders) if (o.id == updated.id) updated else o]);
    final t = AppLocalizations.of(context);
    SafeSnack.messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(t.translate('Date updated successfully')), backgroundColor: kCrmSuccess, duration: const Duration(seconds: 2)),
    );
  }

  // §MODIFICATION — SCAN DOCUMENTS (INCLUDE IMPORT) : PLUSIEURS DOCUMENTS PAR
  // LIGNE (2026-09-01) — même principe que `_applyUpdatedOrder` ci-dessus
  // (met à jour `_orders` avec le bon de commande renvoyé par le backend,
  // jamais un rechargement complet de la liste), mais SANS le message "Date
  // updated successfully" (propre à l'édition de date) : l'ajout/la
  // suppression d'un document affiche son propre message au bon endroit
  // (voir _AddDocumentsDialogBody/_OrderDocumentsDialogBody plus bas).
  void _applyUpdatedOrderSilently(FinancePurchaseOrderModel updated) {
    if (!mounted) return;
    setState(() => _orders = [for (final o in _orders) if (o.id == updated.id) updated else o]);
  }

  // Suppression réelle côté backend (§AJOUTER LA SUPPRESSION DES DOCUMENTS
  // FINANCE) — confirmation via le Modal existant (AlertDialog), jamais
  // window.confirm(). Supprimer le bon retire aussi ses lignes du tableau
  // (relations CASCADE existantes, §9) — un simple retrait de `_orders`
  // suffit ici, aucune ligne orpheline ne peut subsister.
  Future<void> _handleDelete(FinancePurchaseOrderModel order) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      // IMPORTANT : ne JAMAIS utiliser le `context` de l'écran englobant pour
      // fermer ce dialogue — avec la navigation par shell/branches de
      // go_router, ce `context` peut résoudre vers le Navigator INTERNE de la
      // branche courante (qui n'a qu'UNE seule page), pas vers le Navigator
      // racine sur lequel `showDialog` a réellement empilé ce dialogue.
      // `Navigator.of(context).pop()` viderait alors la pile de la branche
      // ("You have popped the last page off of the stack"). Utiliser
      // systématiquement le contexte PROPRE du builder du dialogue.
      builder: (dialogContext) => AlertDialog(
        title: Text(t.translate('Delete this purchase order?')),
        content: Text(t.translate('Are you sure you want to delete this purchase order and its associated documents?')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(t.translate('Cancel'))),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.translate('Delete'), style: const TextStyle(color: kCrmDanger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_deletingIds.contains(order.id)) return; // suppression déjà en cours pour ce bon
    _deletingIds.add(order.id);
    try {
      await FinanceService.instance.deleteRawMaterial(order.id);
      if (!mounted) return;
      // La ligne n'est retirée QUE si le backend a confirmé la suppression.
      setState(() => _orders = _orders.where((o) => o.id != order.id).toList());
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(t.translate('Purchase order deleted successfully')), backgroundColor: kCrmSuccess),
      );
    } catch (e) {
      if (!mounted) return;
      SafeSnack.messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      _deletingIds.remove(order.id);
    }
  }

  // ── Export Excel (§4-6) ─────────────────────────────────────────────────
  // Exporte les lignes actuellement FILTRÉES (toutes les pages, pas
  // seulement la page affichée) — aucune ré-extraction, aucun appel réseau :
  // uniquement les données déjà chargées en mémoire. Quantités/montants
  // écrits comme de VRAIES valeurs numériques Excel (jamais des chaînes),
  // avec une ligne TOTAL en bas (§5-6).
  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      final rows = _filteredRows;
      final excelFile = xl.Excel.createExcel();
      final sheet = excelFile['Inflow Raw Materials'];
      excelFile.setDefaultSheet('Inflow Raw Materials');

      const headers = [
        'PO #',
        'Order #',
        'Order date',
        'Customer',
        'Customer code',
        'Customer address',
        'Reference',
        'Designation',
        'Unit',
        'Quantity',
        'P.U. HT',
        'Amount HT',
      ];
      for (int col = 0; col < headers.length; col++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          ..value = headers[col]
          ..cellStyle = xl.CellStyle(bold: true, backgroundColorHex: '#EEF2FF', fontColorHex: '#1E293B');
      }

      for (int ri = 0; ri < rows.length; ri++) {
        final r = rows[ri];
        final rowIdx = ri + 1;
        final values = <dynamic>[
          r.order.poNumber ?? '',
          r.order.orderNumber ?? '',
          _dateFmt(r.order.orderDate),
          r.order.displayCustomerName,
          r.order.customerCode ?? '',
          r.order.customerAddress ?? '',
          r.item.reference ?? '',
          r.item.designation ?? '',
          r.item.unit ?? '',
          r.item.quantity, // valeur numérique — jamais une chaîne (§5)
          r.item.unitPriceHT,
          r.item.amountHT,
        ];
        for (int col = 0; col < values.length; col++) {
          final v = values[col];
          if (v == null) continue; // cellule vide plutôt qu'un 0 inventé
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx)).value = v;
        }
      }

      // Ligne TOTAL (§6) — uniquement Amount HT, jamais une somme de
      // quantités/prix unitaires hétérogènes entre produits différents.
      final totalRowIdx = rows.length + 1;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRowIdx))
        ..value = 'TOTAL'
        ..cellStyle = xl.CellStyle(bold: true);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: totalRowIdx))
        ..value = _filteredTotalHT
        ..cellStyle = xl.CellStyle(bold: true);

      const widths = <int, double>{
        0: 14, 1: 16, 2: 14, 3: 24, 4: 16, 5: 30, 6: 16, 7: 32, 8: 12, 9: 14, 10: 14, 11: 14,
      };
      for (int col = 0; col < headers.length; col++) {
        sheet.setColWidth(col, widths[col] ?? 16);
      }

      final bytes = excelFile.encode();
      if (bytes == null) throw Exception('Échec de la génération du fichier Excel');

      final fileName = 'inflow-raw-materials-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
      _downloadBytes(bytes, fileName);

      if (!mounted) return;
      final t = AppLocalizations.of(context);
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${t.translate('Export terminé')} · $fileName'), backgroundColor: kCrmSuccess),
      );
    } catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      SafeSnack.messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _downloadBytes(List<int> bytes, String name, {String mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'}) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', name)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ── Export CSV (§AJOUTER EXPORT CSV) ────────────────────────────────────
  // Contrairement à l'affichage/à l'export Excel, le CSV n'est PAS limité
  // aux colonnes visibles : il inclut Amount HT/Total HT (retirés de
  // l'interface mais toujours en base) + les infos document (§4, §6).
  // Mêmes lignes FILTRÉES que le tableau (§9), aucune ré-extraction — juste
  // les données déjà chargées en mémoire, sérialisées en CSV.
  Future<void> _exportCsv() async {
    setState(() => _exportingCsv = true);
    try {
      final rows = _filteredRows;
      const sep = ';'; // séparateur adapté à Excel francophone (§8)
      final buffer = StringBuffer();

      void writeRow(List<String> cells) {
        buffer.write(cells.map(_csvEscape).join(sep));
        buffer.write('\r\n');
      }

      writeRow(const [
        'PO #',
        'Order #',
        'Order date',
        'Customer',
        'Customer code',
        'Customer address',
        'Reference',
        'Designation',
        'Unit',
        'Quantity',
        'P.U. HT',
        'Amount HT',
        'Total HT',
        'Document name',
        'Upload date',
        'Uploaded by',
      ]);

      for (final r in rows) {
        // Plusieurs documents possibles sur un même bon (§6) — aucune
        // information perdue, mais UNE seule ligne par produit reste la
        // règle (§5) : les infos des différents documents sont regroupées
        // dans les mêmes cellules plutôt que de dupliquer la ligne produit.
        final docs = r.order.documents;
        final docNames = docs.map((d) => d.originalName).join('; ');
        final docDates = docs.map((d) => _dateFmt(d.createdAt)).where((s) => s.isNotEmpty).join('; ');
        final docUploaders = docs.map((d) => d.uploader?.email ?? '').where((s) => s.isNotEmpty).join('; ');

        writeRow([
          r.order.poNumber ?? '',
          r.order.orderNumber ?? '',
          _dateFmt(r.order.orderDate),
          r.order.displayCustomerName,
          r.order.customerCode ?? '',
          r.order.customerAddress ?? '',
          r.item.reference ?? '',
          r.item.designation ?? '',
          r.item.unit ?? '',
          _csvNumber(r.item.quantity),
          _csvNumber(r.item.unitPriceHT),
          _csvNumber(r.item.amountHT),
          _csvNumber(r.order.totalHT), // valeur déjà extraite/enregistrée, jamais recalculée (§11)
          docNames,
          docDates,
          docUploaders,
        ]);
      }

      // UTF-8 avec BOM (§8) — accents français correctement affichés à
      // l'ouverture dans Excel.
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())];
      final fileName = 'inflow-raw-materials-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
      _downloadBytes(bytes, fileName, mimeType: 'text/csv;charset=utf-8;');

      if (!mounted) return;
      final t = AppLocalizations.of(context);
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${t.translate('Export terminé')} · $fileName'), backgroundColor: kCrmSuccess),
      );
    } catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      SafeSnack.messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  // Un champ contenant le séparateur, un guillemet, une virgule ou un retour
  // à la ligne doit être quoté (guillemets doublés à l'intérieur) — sinon un
  // champ comme une adresse ("Zi Sidi Rezig, Rue Du Plastique, ...") reste
  // lisible tel quel, la virgule n'étant pas le séparateur retenu (§8).
  String _csvEscape(String value) {
    final needsQuoting = value.contains(';') || value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
    if (!needsQuoting) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  // Valeur numérique RÉELLE (§7) — jamais "940 000" avec séparateur de
  // milliers qui forcerait Excel à interpréter le champ comme du texte.
  // Entier quand la valeur n'a pas de décimale (cas de tous les exemples du
  // ticket), sinon virgule décimale (cohérent avec le séparateur ';' choisi
  // pour l'environnement Excel francophone).
  String _csvNumber(double? v) {
    if (v == null) return '';
    if (v == v.truncateToDouble()) return v.toInt().toString();
    var s = v.toStringAsFixed(3);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s.replaceAll('.', ',');
  }

  String _dateFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final filteredRows = _filteredRows;
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: kFinanceColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.inventory_2_outlined, size: 22, color: kFinanceColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.translate('Inflow of raw materials'), style: tInter(fontSize: 21, fontWeight: FontWeight.w800, color: kCrmText)),
                    const SizedBox(height: 2),
                    Text(t.translate('Deposit and review raw material documents.'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  ]),
                ),
                OutlinedButton.icon(
                  onPressed: _exportingCsv || filteredRows.isEmpty ? null : _exportCsv,
                  icon: _exportingCsv
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kFinanceColor))
                      : const Icon(Icons.description_outlined, size: 18),
                  label: Text(t.translate('Export CSV')),
                  style: OutlinedButton.styleFrom(foregroundColor: kFinanceColor, side: const BorderSide(color: kFinanceColor)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _exporting || filteredRows.isEmpty ? null : _exportExcel,
                  icon: _exporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(t.translate('Export Excel')),
                  style: ElevatedButton.styleFrom(backgroundColor: kFinanceColor, foregroundColor: Colors.white),
                ),
              ]),
              const SizedBox(height: 22),
              FinanceUploadDropzone(onFilesSelected: _handleFilesSelected, busy: _uploading),
              const SizedBox(height: 26),
              // ── Recherche + filtres (§3) ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
                child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(
                    width: 240,
                    child: _filterField(
                      hint: t.translate('Search'),
                      icon: Icons.search_rounded,
                      onChanged: (v) => setState(() {
                        _search = v;
                        _page = 1;
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: _filterField(
                      hint: t.translate('Order #'),
                      onChanged: (v) => setState(() {
                        _orderNumberFilter = v;
                        _page = 1;
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: _filterField(
                      hint: t.translate('Customer'),
                      onChanged: (v) => setState(() {
                        _customerFilter = v;
                        _page = 1;
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: _filterField(
                      hint: t.translate('Reference'),
                      onChanged: (v) => setState(() {
                        _referenceFilter = v;
                        _page = 1;
                      }),
                    ),
                  ),
                  _datePickerChip(
                    label: t.translate('Date début'),
                    value: _startDate,
                    onPicked: (d) => setState(() {
                      _startDate = d;
                      _page = 1;
                    }),
                  ),
                  _datePickerChip(
                    label: t.translate('Date fin'),
                    value: _endDate,
                    onPicked: (d) => setState(() {
                      _endDate = d;
                      _page = 1;
                    }),
                  ),
                  TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: kCrmTextSub),
                    label: Text(t.translate('Réinitialiser'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              // §CORRECTION — RENOMMAGE LIBELLÉS INFLOW (2026-08-31) :
              // "N line(s)" → "Sage Documents" (libellé fixe, plus de
              // compteur affiché) — renommage d'affichage UNIQUEMENT,
              // `filteredRows`/le tableau en dessous restent inchangés.
              Text(t.translate('Sage Documents'), style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
              const SizedBox(height: 14),
              if (_error != null)
                _buildError(t)
              else if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
              else ...[
                FinancePurchaseOrdersTable(
                  rows: _pageRows,
                  onView: _handleView,
                  onDelete: _handleDelete,
                  onOrderDateSave: _saveOrderDate,
                  onOrderDateSaved: _applyUpdatedOrder,
                ),
                if (filteredRows.length > _kRowsPerPage) ...[
                  const SizedBox(height: 14),
                  _buildPagination(t),
                ],
                if (_failedOrders.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  // §CORRECTION — RENOMMAGE SECTION INFLOW (2026-08-31) :
                  // libellé visuel "Export" → "Import" — renommage
                  // d'affichage UNIQUEMENT (voir aussi le commentaire
                  // "SECTION EXPORT" plus bas, qui documente toujours la
                  // logique réelle inchangée : même liste `_failedOrders`,
                  // bons dont l'OCR a échoué, rien retiré/supprimé/modifié
                  // côté backend/API/Keys/sidebar/Export Excel).
                  Text(t.translate('Scan Documents (include Import)'), style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: kCrmText)),
                  const SizedBox(height: 4),
                  Text(t.translate('These files could not be read automatically. You can still view or delete them.'),
                      style: tInter(fontSize: 12, color: kCrmTextSub)),
                  const SizedBox(height: 10),
                  // §MODIFICATION — INFLOW RAW MATERIALS / SECTION EXPORT :
                  // `_ExportOrdersTable` remplace `FinanceDocumentsTable` ici
                  // UNIQUEMENT (ce widget générique reste inchangé, partagé
                  // par Invoice/Shipment/Purchase Order detail — §13, "ne pas
                  // modifier inutilement"). `_failedOrders` reste le MÊME
                  // `FinancePurchaseOrderModel` que le tableau principal —
                  // Order date est donc le MÊME champ, la MÊME donnée
                  // persistée (§5 du ticket), éditée via `OrderDateCell`
                  // (widget PARTAGÉ avec FinancePurchaseOrdersTable — jamais
                  // une deuxième implémentation) + `_saveOrderDate`/
                  // `_applyUpdatedOrder` (les MÊMES méthodes que le tableau
                  // principal, qui mutent le MÊME `_orders` : modifier depuis
                  // l'un des deux tableaux met donc IMMÉDIATEMENT à jour
                  // l'autre, puisque tous deux sont de simples vues dérivées
                  // de cette unique liste).
                  _ExportOrdersTable(
                    orders: _failedOrders,
                    onView: (doc) => showFinanceDocumentPreview(context, doc),
                    onDelete: (order) => _handleDelete(order),
                    onOrderDateSave: _saveOrderDate,
                    onOrderDateSaved: _applyUpdatedOrder,
                    // §MODIFICATION — SCAN DOCUMENTS (INCLUDE IMPORT) :
                    // PLUSIEURS DOCUMENTS PAR LIGNE (2026-09-01) — mêmes
                    // méthodes `FinanceService` que ci-dessus, appliquées au
                    // MÊME `_orders` via `_applyUpdatedOrderSilently` (donc
                    // reflétées instantanément dans les DEUX tableaux, sans
                    // jamais recharger toute la page — §14 du ticket).
                    onAddDocuments: FinanceService.instance.addRawMaterialDocuments,
                    onDeleteDocument: FinanceService.instance.deleteRawMaterialDocument,
                    onOrderUpdated: _applyUpdatedOrderSilently,
                  ),
                ],
              ],
            ]),
          ),
        ),
      ),
    );
  }

  // Pagination (§3 : "si nécessaire" — seulement affichée au-delà d'une
  // page). Le bloc "Total HT" a été retiré de cette interface
  // (§SUPPRIMER LE TOTAL HT DE L'INTERFACE) — la valeur reste disponible
  // dans les deux exports (Excel/CSV), jamais affichée ici.
  Widget _buildPagination(AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: _page > 1 ? () => setState(() => _page--) : null,
        ),
        Text('${t.translate('Page')} $_page / $_pageCount', style: tInter(fontSize: 12.5, color: kCrmTextSub)),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: _page < _pageCount ? () => setState(() => _page++) : null,
        ),
      ]),
    );
  }

  Widget _filterField({required String hint, IconData? icon, required ValueChanged<String> onChanged}) {
    return TextField(
      onChanged: onChanged,
      style: tInter(fontSize: 13, color: kCrmText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: tInter(fontSize: 12, color: kCrmTextSub),
        prefixIcon: icon == null ? null : Icon(icon, size: 18, color: kCrmTextSub),
        isDense: true,
        filled: true,
        fillColor: kCrmBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmBorder)),
      ),
    );
  }

  Widget _datePickerChip({required String label, required DateTime? value, required ValueChanged<DateTime> onPicked}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: kCrmTextSub),
          const SizedBox(width: 6),
          Text(value == null ? label : DateFormat('dd/MM/yyyy').format(value), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText)),
        ]),
      ),
    );
  }

  Widget _buildError(AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: kCrmDanger, size: 36),
          const SizedBox(height: 8),
          Text('${t.translate('Erreur de chargement :')} $_error', textAlign: TextAlign.center, style: tInter(fontSize: 13, color: kCrmTextSub)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: Text(t.translate('Réessayer'))),
        ]),
      ),
    );
  }
}

// §MODIFICATION — INFLOW RAW MATERIALS / SECTION EXPORT : table dédiée à la
// section "Export" (ex-"Documents requiring extraction") — Document name/
// File type/File size/Upload date/Order date (éditable)/Uploaded by/Actions
// (§2/§8 du ticket). Opère sur `FinancePurchaseOrderModel` (jamais sur un
// `FinanceDocumentModel` isolé comme `FinanceDocumentsTable`) précisément
// pour garder l'accès à `order.orderDate` — LE MÊME champ, LA MÊME donnée
// persistée que le tableau principal (§5) — jamais un deuxième modèle/une
// deuxième table PostgreSQL. `FinanceDocumentsTable` (générique, partagée
// avec les dialogues Invoice/Shipment/Purchase Order) n'est pas touchée.
class _ExportOrdersTable extends StatelessWidget {
  final List<FinancePurchaseOrderModel> orders;
  final ValueChanged<FinanceDocumentModel> onView;
  final ValueChanged<FinancePurchaseOrderModel> onDelete;
  final Future<FinancePurchaseOrderModel> Function(String id, DateTime newDate) onOrderDateSave;
  final ValueChanged<FinancePurchaseOrderModel> onOrderDateSaved;
  // §MODIFICATION — SCAN DOCUMENTS (INCLUDE IMPORT) : PLUSIEURS DOCUMENTS PAR
  // LIGNE (2026-09-01) — une ligne (un bon de commande) peut désormais avoir
  // PLUSIEURS documents associés (jamais une nouvelle ligne créée, §5 du
  // ticket) : `onAddDocuments` ajoute N fichier(s) au bon EXISTANT,
  // `onDeleteDocument` supprime UN SEUL document sans toucher aux autres
  // (§9), `onOrderUpdated` répercute le bon de commande à jour (renvoyé par
  // le backend) dans `_orders` côté écran parent.
  final Future<FinancePurchaseOrderModel> Function(String orderId, List<FinancePickedFile> files) onAddDocuments;
  final Future<FinancePurchaseOrderModel> Function(String orderId, String documentId) onDeleteDocument;
  final ValueChanged<FinancePurchaseOrderModel> onOrderUpdated;

  const _ExportOrdersTable({
    required this.orders,
    required this.onView,
    required this.onDelete,
    required this.onOrderDateSave,
    required this.onOrderDateSaved,
    required this.onAddDocuments,
    required this.onDeleteDocument,
    required this.onOrderUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Un bon dont l'extraction a échoué peut, en théorie, n'avoir aucun
    // document rattaché (upload interrompu) — jamais affiché dans ce cas
    // plutôt que de deviner un nom de fichier.
    final entries = [for (final o in orders) if (o.documents.isNotEmpty) (order: o, doc: o.documents.first)];

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text(t.translate('Aucun document'), style: tInter(fontSize: 13, color: kCrmTextSub))),
      );
    }

    return Container(
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTableTheme(
          data: DataTableThemeData(
            headingRowColor: WidgetStateProperty.all(kCrmBg),
            headingTextStyle: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: kCrmTextSub),
            dataTextStyle: tInter(fontSize: 12.5, color: kCrmText),
            dividerThickness: 1,
          ),
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 56,
            columnSpacing: 22,
            columns: [
              DataColumn(label: Text(t.translate('Document name'))),
              DataColumn(label: Text(t.translate('File type'))),
              DataColumn(label: Text(t.translate('File size'))),
              DataColumn(label: Text(t.translate('Upload date'))),
              DataColumn(label: Text(t.translate('Order date'))),
              DataColumn(label: Text(t.translate('Uploaded by'))),
              DataColumn(label: Text(t.translate('Actions'))),
            ],
            rows: [
              for (final e in entries)
                DataRow(
                  color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.hovered) ? kCrmPrimary.withOpacity(0.04) : null),
                  onSelectChanged: (_) => onView(e.doc),
                  cells: [
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_iconFor(e.doc), size: 16, color: kCrmPrimary),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(e.doc.originalName,
                            style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      // §MODIFICATION — SCAN DOCUMENTS (INCLUDE IMPORT) :
                      // PLUSIEURS DOCUMENTS PAR LIGNE (2026-09-01, §1 du
                      // ticket) — "+N" quand la ligne a plus d'un document,
                      // MÊME style de puce que `_documentsCell` (Factured
                      // Shipments/Paid Invoices), jamais une deuxième ligne
                      // créée pour ces fichiers supplémentaires.
                      if (e.order.documents.length > 1) ...[
                        const SizedBox(width: 4),
                        Text('+${e.order.documents.length - 1} ${t.translate('more')}',
                            style: tInter(fontSize: 11, color: kCrmTextSub)),
                      ],
                    ])),
                    DataCell(Text(e.doc.extension.toUpperCase().isEmpty ? '—' : e.doc.extension.toUpperCase())),
                    DataCell(Text(formatFinanceFileSize(e.doc.fileSize))),
                    DataCell(Text(_dateTimeFmt(e.doc.createdAt))),
                    // §MODIFICATION — INFLOW RAW MATERIALS / SECTION EXPORT :
                    // même `OrderDateCell` que le tableau principal — même
                    // widget, même appel PATCH, même `_orders` mis à jour
                    // (voir onOrderDateSave/onOrderDateSaved ci-dessus).
                    DataCell(OrderDateCell(
                      key: ValueKey('export-order-date-${e.order.id}'),
                      order: e.order,
                      onSave: onOrderDateSave,
                      onSaved: onOrderDateSaved,
                    )),
                    DataCell(Text(e.doc.uploader?.email ?? '—')),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      // §MODIFICATION — SCAN DOCUMENTS (INCLUDE IMPORT) :
                      // PLUSIEURS DOCUMENTS PAR LIGNE (2026-09-01, §3 du
                      // ticket) — "Upload" ajoute des fichiers au MÊME bon de
                      // commande (jamais une nouvelle ligne) ; réutilise TEL
                      // QUEL `FinanceUploadDropzone` (Drag & Drop OS +
                      // sélection multi-fichiers déjà en place) dans une
                      // modal dédiée, voir `_showAddDocumentsDialog` plus bas.
                      Tooltip(
                        message: t.translate('Upload'),
                        child: IconButton(
                          icon: const Icon(Icons.upload_outlined, size: 18, color: kCrmPrimary),
                          onPressed: () => _showAddDocumentsDialog(context, e.order, onAddDocuments, onOrderUpdated),
                        ),
                      ),
                      Tooltip(
                        message: t.translate('View'),
                        child: OutlinedButton.icon(
                          // §2/§8 du ticket : un seul document → comportement
                          // actuel inchangé (aperçu direct) ; plusieurs
                          // documents → modal listant chacun individuellement
                          // avec son propre View (jamais un mélange des deux).
                          onPressed: () => e.order.documents.length > 1
                              ? _showOrderDocumentsDialog(context, e.order, onDeleteDocument, onOrderUpdated)
                              : onView(e.doc),
                          icon: const Icon(Icons.visibility_outlined, size: 15),
                          label: Text(t.translate('View'), style: tInter(fontSize: 12, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kCrmPrimary,
                            side: const BorderSide(color: kCrmBorder),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: t.translate('Delete'),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kCrmDanger),
                        onPressed: () => onDelete(e.order),
                      ),
                    ])),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(FinanceDocumentModel doc) {
    if (doc.isPdf) return Icons.picture_as_pdf_outlined;
    if (doc.isImage) return Icons.image_outlined;
    if (['xls', 'xlsx', 'csv'].contains(doc.extension)) return Icons.grid_on_outlined;
    if (['doc', 'docx'].contains(doc.extension)) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _dateTimeFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy HH:mm').format(d);
  }
}

// §MODIFICATION — SCAN DOCUMENTS (INCLUDE IMPORT) : PLUSIEURS DOCUMENTS PAR
// LIGNE (2026-09-01, §2/§8/§9 du ticket) — modal "Associated documents" :
// liste TOUS les documents du bon de commande, chacun avec son propre "View"
// (showFinanceDocumentPreview, réutilisé tel quel) et son propre "Delete"
// (jamais toute la ligne). Réutilise le widget `FinanceDocumentsTable` DÉJÀ
// existant (partagé avec les fiches détail Invoice/Shipment/Purchase Order,
// §12 : "ne pas modifier inutilement") plutôt que d'écrire un second tableau
// de documents.
Future<void> _showOrderDocumentsDialog(
  BuildContext context,
  FinancePurchaseOrderModel order,
  Future<FinancePurchaseOrderModel> Function(String orderId, String documentId) onDeleteDocument,
  ValueChanged<FinancePurchaseOrderModel> onOrderUpdated,
) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ResponsiveDialogBox(
        width: 820,
        height: 560,
        child: _OrderDocumentsDialogBody(order: order, onDeleteDocument: onDeleteDocument, onOrderUpdated: onOrderUpdated),
      ),
    ),
  );
}

class _OrderDocumentsDialogBody extends StatefulWidget {
  final FinancePurchaseOrderModel order;
  final Future<FinancePurchaseOrderModel> Function(String orderId, String documentId) onDeleteDocument;
  final ValueChanged<FinancePurchaseOrderModel> onOrderUpdated;

  const _OrderDocumentsDialogBody({required this.order, required this.onDeleteDocument, required this.onOrderUpdated});

  @override
  State<_OrderDocumentsDialogBody> createState() => _OrderDocumentsDialogBodyState();
}

class _OrderDocumentsDialogBodyState extends State<_OrderDocumentsDialogBody> {
  late List<FinanceDocumentModel> _documents;
  // §7 du ticket (même principe que Register Payment) : jamais deux
  // suppressions simultanées du même document sur un double-clic rapide.
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _documents = widget.order.documents;
  }

  Future<void> _handleDelete(FinanceDocumentModel doc) async {
    if (_deletingIds.contains(doc.id)) return;
    setState(() => _deletingIds.add(doc.id));
    final t = AppLocalizations.of(context);
    try {
      final updated = await widget.onDeleteDocument(widget.order.id, doc.id);
      if (!mounted) return;
      // §9 du ticket : seul CE document disparaît de la modal, les autres
      // restent — `updated.documents` (renvoyé par le backend) fait foi,
      // jamais un simple retrait optimiste côté client.
      setState(() => _documents = updated.documents);
      widget.onOrderUpdated(updated);
    } catch (e) {
      if (!mounted) return;
      SafeSnack.messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      if (mounted) setState(() => _deletingIds.remove(doc.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          const Icon(Icons.folder_copy_outlined, color: kCrmPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t.translate('Associated documents'),
                style: tInter(fontSize: 14.5, fontWeight: FontWeight.w800, color: kCrmText)),
          ),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FinanceDocumentsTable(
            documents: _documents,
            onView: (doc) => showFinanceDocumentPreview(context, doc),
            onDelete: _handleDelete,
            showStatus: false,
          ),
        ),
      ),
    ]);
  }
}

// §MODIFICATION — SCAN DOCUMENTS (INCLUDE IMPORT) : PLUSIEURS DOCUMENTS PAR
// LIGNE (2026-09-01, §3/§4/§7 du ticket) — modal "Add documents" : réutilise
// TEL QUEL `FinanceUploadDropzone` (même Drag & Drop OS + sélection
// multi-fichiers déjà en place pour la création d'un nouveau bon de
// commande, voir plus haut dans ce fichier) — seul le callback change : les
// fichiers sont ajoutés au bon de commande EXISTANT (`onAddDocuments`),
// jamais un nouveau bon créé.
Future<void> _showAddDocumentsDialog(
  BuildContext context,
  FinancePurchaseOrderModel order,
  Future<FinancePurchaseOrderModel> Function(String orderId, List<FinancePickedFile> files) onAddDocuments,
  ValueChanged<FinancePurchaseOrderModel> onOrderUpdated,
) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ResponsiveDialogBox(
        width: 640,
        height: 420,
        child: _AddDocumentsDialogBody(order: order, onAddDocuments: onAddDocuments, onOrderUpdated: onOrderUpdated),
      ),
    ),
  );
}

class _AddDocumentsDialogBody extends StatefulWidget {
  final FinancePurchaseOrderModel order;
  final Future<FinancePurchaseOrderModel> Function(String orderId, List<FinancePickedFile> files) onAddDocuments;
  final ValueChanged<FinancePurchaseOrderModel> onOrderUpdated;

  const _AddDocumentsDialogBody({required this.order, required this.onAddDocuments, required this.onOrderUpdated});

  @override
  State<_AddDocumentsDialogBody> createState() => _AddDocumentsDialogBodyState();
}

class _AddDocumentsDialogBodyState extends State<_AddDocumentsDialogBody> {
  bool _busy = false;

  Future<void> _handleFilesSelected(List<FinancePickedFile> files) async {
    setState(() => _busy = true);
    final t = AppLocalizations.of(context);
    try {
      final updated = await widget.onAddDocuments(widget.order.id, files);
      if (!mounted) return;
      widget.onOrderUpdated(updated);
      Navigator.of(context).pop();
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(files.length == 1 ? t.translate('Document déposé') : t.translate('Documents déposés')),
          backgroundColor: kCrmSuccess,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      SafeSnack.messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          const Icon(Icons.upload_file_outlined, color: kCrmPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t.translate('Add documents'),
                style: tInter(fontSize: 14.5, fontWeight: FontWeight.w800, color: kCrmText)),
          ),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: _busy ? null : () => Navigator.of(context).pop()),
        ]),
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FinanceUploadDropzone(onFilesSelected: _handleFilesSelected, busy: _busy),
        ),
      ),
    ]);
  }
}
