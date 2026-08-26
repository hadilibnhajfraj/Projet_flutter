// lib/forms/finance/view/finance_customer_shipments_screen.dart
//
// "Shipment of products to the customers" (§MODIFICATION — CUSTOMER
// SHIPMENTS — EXPORT EXCEL) — table PROFESSIONNELLE UNE LIGNE PAR PRODUIT
// avec Shipment # (identifiant métier dédié, distinct de Delivery number/
// Customer code), recherche multi-champs, export Excel (.xlsx) complet +
// "+ New shipment". Alimentée UNIQUEMENT par les données déjà extraites/
// enregistrées (aucun nouvel OCR ici, ni à l'affichage ni à l'export).
//
// Export Excel — PAS de CSV (§4/§13, explicitement interdit) : un vrai
// classeur .xlsx généré avec `package:excel` (même convention que Inflow Raw
// Materials), post-traité avec `package:archive` pour ajouter l'en-tête figé
// + les filtres Excel (§6) — non supportés nativement par `excel: ^2.1.0`,
// voir `_freezeHeaderAndAddAutoFilter` ci-dessous. Toutes les valeurs
// pouvant contenir des zéros initiaux (référence produit, code client,
// diamètre, téléphone...) sont écrites comme cellules TEXTE — jamais
// numériques — pour qu'Excel ne les réinterprète jamais et ne les tronque
// jamais (§6 : "conservation des références avec les zéros initiaux").

import 'dart:html' as html;

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/application/common/safe_snack.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../model/finance_models.dart';
import '../service/finance_service.dart';
import '../theme/finance_theme.dart';
import 'widgets/finance_shipment_detail_dialog.dart';
import 'widgets/finance_shipment_form_dialog.dart';
import 'widgets/finance_shipments_table.dart';

// Suffisamment grand pour charger la totalité des Customer Shipments en un
// seul appel — la recherche (Shipment #/Delivery number/Customer/Customer
// code/Reference/Designation, §7) se fait ensuite CÔTÉ CLIENT sur les
// données déjà extraites, sans jamais relancer l'OCR ni ajouter d'endpoint
// backend.
const int _kFetchAllPageSize = 2000;

class FinanceCustomerShipmentsScreen extends StatefulWidget {
  const FinanceCustomerShipmentsScreen({super.key});

  @override
  State<FinanceCustomerShipmentsScreen> createState() => _FinanceCustomerShipmentsScreenState();
}

class _FinanceCustomerShipmentsScreenState extends State<FinanceCustomerShipmentsScreen> {
  bool _loading = true;
  bool _exportingExcel = false;
  String? _error;
  String _search = '';
  List<FinanceShipmentModel> _shipments = const [];
  // §CORRECTION — SUPPRESSION FINANCE : empêche deux requêtes DELETE
  // simultanées sur le même Shipment (double-clic rapide sur 🗑).
  final Set<String> _deletingIds = {};

  List<CustomerShipmentRow> get _allRows => [
        for (final s in _shipments)
          for (final item in s.items) CustomerShipmentRow(shipment: s, item: item),
      ];

  List<CustomerShipmentRow> get _filteredRows {
    final search = _search.trim().toLowerCase();
    if (search.isEmpty) return _allRows;
    return _allRows.where((r) {
      final haystack = [
        r.shipment.shipmentNumber,
        r.shipment.reference,
        r.shipment.customer?.displayName ?? r.shipment.customerName,
        r.shipment.customerCode,
        r.item.reference,
        r.item.designation,
      ].where((v) => v != null).map((v) => v!.toLowerCase()).join(' ');
      return haystack.contains(search);
    }).toList();
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
      final page = await FinanceService.instance.fetchShipments(pageSize: _kFetchAllPageSize);
      if (!mounted) return;
      setState(() => _shipments = page.items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewShipment() async {
    final created = await showNewShipmentDialog(context);
    if (created == null) return;
    await _load();
    if (!mounted) return;
    // §CORRECTION — BUG LIFECYCLE "New shipment" : la notification de
    // succès est affichée ICI, depuis l'écran parent — jamais depuis le
    // dialog lui-même (voir finance_shipment_form_dialog.dart#_submitUpload).
    // Par construction, `await showNewShipmentDialog(context)` ne se résout
    // QU'UNE FOIS la fermeture du dialog et sa transition entièrement
    // terminées — ce `context` (celui de l'écran, jamais démonté par cette
    // opération) et ce moment précis ne peuvent donc plus tomber dans la
    // fenêtre d'instabilité qui produisait "Looking up a deactivated
    // widget's ancestor is unsafe" pendant la fermeture du dialog.
    final t = AppLocalizations.of(context);
    SafeSnack.messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('${t.translate('Shipment created successfully')} — ${created.reference}'),
        backgroundColor: kCrmSuccess,
      ),
    );
    // "puis ouvrir/actualiser le Customer Shipment" — ouvre automatiquement
    // la fiche du Shipment qui vient d'être lu par OCR.
    showFinanceShipmentDetail(context, created, onChanged: _load);
  }

  // Suppression réelle côté backend (§AJOUTER LA SUPPRESSION DES DOCUMENTS
  // FINANCE) — confirmation via le Modal existant (AlertDialog, même
  // composant que partout ailleurs dans ce module), jamais window.confirm().
  // Supprimer le bon retire aussi ses lignes du tableau (§9, relations
  // CASCADE existantes) — un simple retrait de `_shipments` suffit.
  Future<void> _handleDelete(FinanceShipmentModel shipment) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      // IMPORTANT : jamais le `context` de l'écran englobant ici — voir
      // finance_inflow_raw_materials_screen.dart#_handleDelete pour
      // l'explication complète (Navigator de branche go_router vs Navigator
      // racine sur lequel `showDialog` empile réellement ce dialogue).
      builder: (dialogContext) => AlertDialog(
        title: Text(t.translate('Delete this shipment?')),
        content: Text(t.translate('Are you sure you want to delete this shipment and its associated documents?')),
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
    if (_deletingIds.contains(shipment.id)) return; // suppression déjà en cours pour ce shipment
    _deletingIds.add(shipment.id);
    try {
      await FinanceService.instance.deleteShipment(shipment.id);
      if (!mounted) return;
      // La ligne n'est retirée QUE si le backend a confirmé la suppression.
      setState(() => _shipments = _shipments.where((s) => s.id != shipment.id).toList());
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(t.translate('Shipment deleted successfully')), backgroundColor: kCrmSuccess),
      );
    } catch (e) {
      if (!mounted) return;
      SafeSnack.messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      _deletingIds.remove(shipment.id);
    }
  }

  // ── Export Excel (§4-6) — colonnes fixes de la première à la dernière. ────
  static const _kExcelHeaders = [
    'Shipment #',
    'Delivery number',
    'Delivery date',
    'Customer code',
    'Customer',
    'Customer tax ID',
    'Customer phone',
    'Head office address',
    'Governorate',
    'Delivery address',
    'Truck registration',
    'Manufacturer',
    'Driver',
    'Reference',
    'Designation',
    'Unit',
    'Diameter',
    'Mesh size',
    'Quantity',
    'Total quantity',
    'Document name',
    'Upload date',
    'Uploaded by',
  ];

  // Colonnes numériques (double, jamais arrondies) — TOUTES les autres,
  // notamment Reference/Diameter/Customer code/Customer phone/Delivery
  // number, restent du texte pour ne jamais perdre un zéro initial
  // (ex. "00100001", "08") ni être réinterprétées par Excel (§6).
  static const _kQuantityCol = 18; // "Quantity"
  static const _kTotalQuantityCol = 19; // "Total quantity"

  // Exporte TOUTES les données disponibles (pas seulement les colonnes
  // visibles à l'écran) pour les lignes actuellement FILTRÉES — aucune
  // ré-extraction, uniquement les données déjà chargées en mémoire.
  Future<void> _exportExcel() async {
    setState(() => _exportingExcel = true);
    try {
      final rows = _filteredRows;
      const sheetName = 'Customer Shipments';
      final excelFile = xl.Excel.createExcel();
      final sheet = excelFile[sheetName];
      excelFile.setDefaultSheet(sheetName);

      for (int col = 0; col < _kExcelHeaders.length; col++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          ..value = _kExcelHeaders[col]
          ..cellStyle = xl.CellStyle(bold: true, backgroundColorHex: '#EEF2FF', fontColorHex: '#1E293B');
      }

      for (int ri = 0; ri < rows.length; ri++) {
        final r = rows[ri];
        final s = r.shipment;
        final rowIdx = ri + 1;
        // Plusieurs documents possibles sur un même bon — aucune information
        // perdue, mais UNE seule ligne par produit reste la règle : les
        // infos des différents documents sont regroupées dans les mêmes
        // cellules plutôt que de dupliquer la ligne produit.
        final docs = s.documents;
        final docNames = docs.map((d) => d.originalName).join('; ');
        final docDates = docs.map((d) => _dateFmt(d.createdAt)).where((v) => v.isNotEmpty).join('; ');
        final docUploaders = docs.map((d) => d.uploader?.email ?? '').where((v) => v.isNotEmpty).join('; ');

        final values = <dynamic>[
          s.shipmentNumber ?? '',
          s.reference,
          _dateFmt(s.shipmentDate),
          s.customerCode ?? '',
          s.customer?.displayName ?? s.customerName ?? '',
          s.customerTaxId ?? '',
          s.customerPhone ?? '',
          s.customerHeadOfficeAddress ?? '',
          s.customerGovernorate ?? '',
          s.deliveryAddress ?? '',
          s.truckRegistration ?? '',
          s.truckManufacturer ?? '',
          s.driverName ?? '',
          r.item.reference ?? '', // texte — jamais numérique (§6, zéros initiaux)
          r.item.designation ?? '',
          // §CORRECTION EXTRACTION — SÉPARATION UNITÉ / DIAMÈTRE (§10-11) :
          // mêmes valeurs NETTOYÉES que le tableau, jamais `r.item.unit`/
          // `r.item.diameter` bruts — voir FinanceShipmentItemModel.
          r.item.displayUnit ?? '',
          r.item.displayDiameter ?? '', // texte — jamais numérique (ex. "08")
          r.item.meshSize ?? '',
          r.item.quantity, // valeur numérique réelle, jamais arrondie (§6)
          s.totalQuantity,
          docNames,
          docDates,
          docUploaders,
        ];
        for (int col = 0; col < values.length; col++) {
          final v = values[col];
          if (v == null) continue; // cellule vide plutôt qu'une valeur inventée
          if ((col == _kQuantityCol || col == _kTotalQuantityCol) && v is double) {
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx)).value = v;
          } else {
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx)).value = v.toString();
          }
        }
      }

      // Largeur automatique (§6) — `excel` ^2.1.0 n'a pas de calcul de
      // largeur basé sur le contenu, seulement un indicateur "bestFit" laissé
      // à Excel à l'ouverture ; complété par une largeur de base raisonnable
      // pour les lecteurs qui ignorent ce indicateur (ex. LibreOffice).
      const baseWidths = <int, double>{
        0: 12, 1: 16, 2: 14, 3: 16, 4: 24, 5: 18, 6: 16, 7: 28, 8: 14, 9: 28,
        10: 16, 11: 16, 12: 16, 13: 14, 14: 32, 15: 10, 16: 10, 17: 12, 18: 12,
        19: 14, 20: 22, 21: 14, 22: 20,
      };
      for (int col = 0; col < _kExcelHeaders.length; col++) {
        sheet.setColWidth(col, baseWidths[col] ?? 16);
        sheet.setColAutoFit(col);
      }

      var bytes = excelFile.encode();
      if (bytes == null) throw Exception('Échec de la génération du fichier Excel');
      // En-tête figée + filtres Excel (§6) — non supportés par l'API
      // publique d'`excel` ^2.1.0, ajoutés en patchant le XML du classeur
      // déjà généré (validé par un aller-retour Excel.decodeBytes avant
      // intégration ici — voir le commentaire en tête de fichier).
      bytes = _freezeHeaderAndAddAutoFilter(bytes, sheetName: sheetName, rowCount: rows.length + 1, colCount: _kExcelHeaders.length);

      final fileName = 'customer-shipments-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
      final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

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
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  // Patch post-génération (§6) : `excel` ^2.1.0 n'expose aucune API publique
  // pour figer une ligne ou ajouter un AutoFilter, seulement pour LIRE/ÉCRIRE
  // des cellules. Le .xlsx encodé est un vrai ZIP OOXML — on le rouvre avec
  // `package:archive`, on localise la feuille via workbook.xml (nom → r:id)
  // puis workbook.xml.rels (r:id → chemin réel, jamais par ordre de fichier
  // dans l'archive : le classeur contient aussi la feuille "Sheet1" par
  // défaut, vide, créée par `Excel.createExcel()`), puis on insère
  // <pane .../> dans le <sheetView> existant (fige la ligne d'en-tête) et
  // <autoFilter ref="A1:{dernièreColonne}{dernièreLigne}"/> juste après
  // </sheetData> (ordre requis par le schéma OOXML). Le classeur en sort
  // toujours valide — vérifié en le rechargeant avec Excel.decodeBytes
  // pendant le développement de cette fonction.
  List<int> _freezeHeaderAndAddAutoFilter(List<int> xlsxBytes, {required String sheetName, required int rowCount, required int colCount}) {
    final archive = ZipDecoder().decodeBytes(xlsxBytes);

    final workbookFile = archive.files.firstWhere((f) => f.name == 'xl/workbook.xml');
    final workbookXml = String.fromCharCodes(workbookFile.content as List<int>);
    final sheetIdMatch = RegExp('<sheet [^>]*name="$sheetName"[^>]*r:id="([^"]+)"').firstMatch(workbookXml);
    if (sheetIdMatch == null) return xlsxBytes; // repli silencieux — le fichier reste valide sans ce polish

    final relsFile = archive.files.firstWhere((f) => f.name == 'xl/_rels/workbook.xml.rels');
    final relsXml = String.fromCharCodes(relsFile.content as List<int>);
    final relMatch = RegExp('<Relationship Id="${sheetIdMatch.group(1)}"[^>]*Target="([^"]+)"').firstMatch(relsXml);
    if (relMatch == null) return xlsxBytes;

    final targetPath = 'xl/${relMatch.group(1)}';
    final sheetFile = archive.files.firstWhere((f) => f.name == targetPath, orElse: () => throw StateError('sheet not found'));
    var sheetXml = String.fromCharCodes(sheetFile.content as List<int>);

    sheetXml = sheetXml.replaceFirstMapped(
      RegExp(r'<sheetView([^>]*)/>'),
      (m) => '<sheetView${m.group(1)}><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView>',
    );

    final range = 'A1:${_columnLetter(colCount - 1)}$rowCount';
    if (sheetXml.contains('</sheetData>')) {
      sheetXml = sheetXml.replaceFirst('</sheetData>', '</sheetData><autoFilter ref="$range"/>');
    }

    final newArchive = Archive();
    for (final f in archive.files) {
      if (f.name == targetPath) {
        final data = sheetXml.codeUnits;
        newArchive.addFile(ArchiveFile(f.name, data.length, data));
      } else {
        newArchive.addFile(f);
      }
    }
    return ZipEncoder().encode(newArchive) ?? xlsxBytes;
  }

  // Notation colonne Excel (A, B, ..., Z, AA, AB, ...) à partir d'un index
  // 0-based — générique au-delà de 26 colonnes bien que ce classeur en ait 23.
  String _columnLetter(int index) {
    var n = index;
    var letters = '';
    while (true) {
      letters = String.fromCharCode(65 + (n % 26)) + letters;
      n = n ~/ 26 - 1;
      if (n < 0) break;
    }
    return letters;
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
                  child: const Icon(Icons.local_shipping_outlined, size: 22, color: kFinanceColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.translate('Shipment of products to the customers'),
                        style: tInter(fontSize: 20, fontWeight: FontWeight.w800, color: kCrmText)),
                    const SizedBox(height: 2),
                    Text(t.translate('Manage customer shipments.'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  ]),
                ),
                OutlinedButton.icon(
                  onPressed: _exportingExcel || filteredRows.isEmpty ? null : _exportExcel,
                  icon: _exportingExcel
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kFinanceColor))
                      : const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(t.translate('Export Excel')),
                  style: OutlinedButton.styleFrom(foregroundColor: kFinanceColor, side: const BorderSide(color: kFinanceColor)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _openNewShipment,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(t.translate('New shipment')),
                  style: ElevatedButton.styleFrom(backgroundColor: kFinanceColor, foregroundColor: Colors.white),
                ),
              ]),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: Text('${filteredRows.length} ${t.translate('line(s)')}', style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: tInter(fontSize: 13, color: kCrmText),
                    decoration: InputDecoration(
                      // Shipment #/Delivery number/Customer/Customer code/
                      // Reference/Designation (§7).
                      hintText: t.translate('Shipment # / Delivery number / Customer / Reference'),
                      hintStyle: tInter(fontSize: 12, color: kCrmTextSub),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kCrmTextSub),
                      isDense: true,
                      filled: true,
                      fillColor: kCrmSurface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmBorder)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              if (_error != null)
                _buildError(t)
              else if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
              else
                FinanceShipmentsTable(
                  rows: filteredRows,
                  onView: (s) => showFinanceShipmentDetail(context, s, onChanged: _load),
                  onDelete: _handleDelete,
                ),
            ]),
          ),
        ),
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
