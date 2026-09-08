// lib/production_records/service/production_summary_export_service.dart
//
// Export Excel/PDF/Impression pour "Production Summary" — reproduit
// EXACTEMENT les données actuellement filtrées/affichées à l'écran (voir
// production_summary_screen.dart), jamais recalculées différemment.
// Réutilise les mêmes patterns clients que le module POR PROMESH (dart:html
// pour Excel, package:pdf + printing pour PDF/Impression) — voir
// forms/por_promesh/service/por_promesh_{pdf,excel}_service.dart.

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;

import 'package:archive/archive.dart' as arc;
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:dash_master_toolkit/providers/auth_service.dart';
import 'package:dash_master_toolkit/forms/por_promesh/utils/por_promesh_pdf_theme.dart';

import '../model/production_record_model.dart';
import '../model/production_summary_model.dart';
import '../service/production_records_service.dart';

/// Contexte d'export — les mêmes filtres que ceux actuellement appliqués à
/// l'écran (période/machine/diamètre/statut), affichés en en-tête du
/// document exporté pour que celui-ci soit auto-suffisant.
class ProductionSummaryExportContext {
  final String periodLabel;
  final String? machineLabel;
  final String? diameterLabel;
  final String statusLabel;

  // Valeurs BRUTES des filtres (pas les libellés traduits ci-dessus) —
  // utilisées UNIQUEMENT par exportExcel() pour calculer "Start date"/
  // "End date" (voir _resolveExcelDateRange). PDF et Impression continuent
  // d'utiliser periodLabel tel quel, inchangé.
  // (Pas de "rawType" ici : chaque section Excel force son propre type
  // promesh/probar, voir _resolveExcelDateRange.)
  final String? rawPeriod;
  final String? rawStartDate;
  final String? rawEndDate;
  final String? rawMachineId;

  const ProductionSummaryExportContext({
    required this.periodLabel,
    this.machineLabel,
    this.diameterLabel,
    required this.statusLabel,
    this.rawPeriod,
    this.rawStartDate,
    this.rawEndDate,
    this.rawMachineId,
  });
}

const _pdfPromesh = PdfColor.fromInt(0xFF2563EB);
const _pdfProbar = PdfColor.fromInt(0xFFF97316);
const _pdfBg = PdfColor.fromInt(0xFFF8FAFC);
const _pdfBorder = PdfColor.fromInt(0xFFE2E8F0);
const _pdfText = PdfColor.fromInt(0xFF0F172A);
const _pdfTextSub = PdfColor.fromInt(0xFF64748B);

// §MODIFICATION — CORRECTION GLOBALE DES TRADUCTIONS (2026-09-17, ticket
// "l'interface mélange parfois l'anglais et le français") — ce fichier
// n'avait AUCUN accès à `AppLocalizations`/`BuildContext` (c'est un service
// pur, pas un widget) et écrivait donc ~45 chaînes 100% en dur (mélange
// anglais/français figé, indépendant de la langue réellement sélectionnée
// dans l'application — §11 du ticket). Corrigé en réutilisant TEL QUEL le
// système de localisation existant (§3 : jamais un second système) : un
// simple `Translator` (la fonction `AppLocalizations.of(context).translate`
// elle-même) est résolu UNE SEULE FOIS côté écran — qui a accès au
// `BuildContext` — puis transmis à `exportExcel`/`exportPdf`/`printSummary`.
// Les CLÉS utilisées ici sont, autant que possible, EXACTEMENT les mêmes que
// celles déjà utilisées à l'écran (`production_summary_screen.dart`) pour
// les mêmes libellés — jamais une clé dupliquée pour le même concept.
typedef Translator = String Function(String key);

class ProductionSummaryExportService {
  static final ProductionSummaryExportService instance = ProductionSummaryExportService._();
  ProductionSummaryExportService._();

  // Résolu au tout début de chaque méthode publique (exportExcel/exportPdf/
  // printSummary) — jamais partagé entre deux exports concurrents puisque
  // l'écran appelant désactive déjà les boutons d'export pendant qu'un
  // export est en cours (voir production_summary_screen.dart#_runExport,
  // `_exporting`), donc un seul export à la fois en pratique.
  late Translator _t;

  String _documentTitle(ProductionSummary summary) {
    final hasPromesh = summary.promesh != null;
    final hasProbar = summary.probar != null;
    if (hasPromesh && !hasProbar) return _t('Production Summary — PROMESH');
    if (hasProbar && !hasPromesh) return _t('Production Summary — PROBAR');
    return '${_t('Production Summary — PROBAR')} & ${_t('Production Summary — PROMESH')}';
  }

  // ════════════════════════════════════════════════════════════════════
  // PDF / IMPRESSION
  // ════════════════════════════════════════════════════════════════════

  Future<void> exportPdf(ProductionSummary summary, ProductionSummaryExportContext ctx, Translator translate) async {
    _t = translate;
    try {
      final doc = await _buildDocument(summary, ctx);
      await Printing.sharePdf(bytes: await doc.save(), filename: 'production-summary-${DateTime.now().millisecondsSinceEpoch}.pdf');
    } catch (e, stackTrace) {
      debugPrint('[ProductionSummary] PDF export error: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> printSummary(ProductionSummary summary, ProductionSummaryExportContext ctx, Translator translate) async {
    _t = translate;
    try {
      final doc = await _buildDocument(summary, ctx);
      await Printing.layoutPdf(onLayout: (_) => doc.save());
    } catch (e, stackTrace) {
      debugPrint('[ProductionSummary] Print error: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<pw.Document> _buildDocument(ProductionSummary summary, ProductionSummaryExportContext ctx) async {
    final doc = pw.Document(theme: await robotoPdfTheme());
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final generatedBy = AuthService().displayName;
    final title = _documentTitle(summary);

    pw.Widget footer(pw.Context c) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _pdfBorder, width: 0.5))),
          child: pw.Row(children: [
            pw.Expanded(
                child: pw.Text('${_t('Généré le')} $generatedAt ${_t('par')} $generatedBy',
                    style: pw.TextStyle(fontSize: 7.5, color: _pdfTextSub))),
            pw.Text('${_t('Page')} ${c.pageNumber} ${_t('sur')} ${c.pagesCount}', style: pw.TextStyle(fontSize: 7.5, color: _pdfTextSub)),
          ]),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 32),
      footer: footer,
      header: (c) => c.pageNumber == 1 ? _pdfHeader(title, ctx, generatedAt) : pw.SizedBox(height: 0),
      build: (c) => [
        if (summary.promesh != null) ..._pdfSection('PROMESH', _pdfPromesh, summary.promesh!, isPromesh: true),
        if (summary.promesh != null && summary.probar != null) pw.SizedBox(height: 16),
        if (summary.probar != null) ..._pdfSection('PROBAR', _pdfProbar, summary.probar!, isPromesh: false),
      ],
    ));

    return doc;
  }

  pw.Widget _pdfHeader(String title, ProductionSummaryExportContext ctx, String generatedAt) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _pdfBorder, width: 1))),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: _pdfText)),
        pw.SizedBox(height: 8),
        pw.Wrap(spacing: 18, runSpacing: 4, children: [
          _metaChip(_t("Date d'export"), generatedAt),
          _metaChip(_t('Période'), ctx.periodLabel),
          if (ctx.machineLabel != null) _metaChip(_t('Machine'), ctx.machineLabel!),
          if (ctx.diameterLabel != null) _metaChip(_t('Diamètre'), '${ctx.diameterLabel} mm'),
          _metaChip(_t('Statut'), ctx.statusLabel),
        ]),
      ]),
    );
  }

  pw.Widget _metaChip(String label, String value) => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text('$label : ', style: pw.TextStyle(fontSize: 8.5, color: _pdfTextSub)),
        pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _pdfText)),
      ]);

  static const _pdfPromesh4Bg = PdfColor.fromInt(0xFFFEF3C7);

  List<pw.Widget> _pdfSection(String label, PdfColor color, ProductionSummaryTable table, {required bool isPromesh}) {
    final flexIndex = 1, flexDate = 3, flexMachine = 3, flexDiameter = 2, flexMesh = 3, flexQty = 3, flexWaste = 3;

    pw.Widget headerRow() => pw.Container(
          color: _pdfBg,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Row(children: [
            pw.Expanded(flex: flexIndex, child: pw.Text('#', style: _pdfHeadStyle)),
            pw.Expanded(flex: flexDate, child: pw.Text(_t('Date production'), style: _pdfHeadStyle)),
            // §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS
            // RECOVERABLES — "Machine" affiché pour PROBAR aussi désormais.
            pw.Expanded(flex: flexMachine, child: pw.Text(_t('Machine'), style: _pdfHeadStyle)),
            pw.Expanded(flex: flexDiameter, child: pw.Text(_t('Diameter'), style: _pdfHeadStyle)),
            if (isPromesh) pw.Expanded(flex: flexMesh, child: pw.Text(_t('Cell size'), style: _pdfHeadStyle)),
            pw.Expanded(flex: flexQty, child: pw.Text('${_t('Quantity')} (${table.unit})', style: _pdfHeadStyle, textAlign: pw.TextAlign.right)),
            pw.Expanded(
                flex: flexWaste, child: pw.Text('${_t('Waste')} (${table.wasteUnit})', style: _pdfHeadStyle, textAlign: pw.TextAlign.right)),
          ]),
        );

    pw.Widget dataRow(int index, ProductionRecordModel r) {
      final isPromesh4 = isPromesh && isPromesh4Machine(r.machine);
      final style = pw.TextStyle(fontSize: 8.5, color: _pdfText, fontWeight: isPromesh4 ? pw.FontWeight.bold : null);
      final dateLabel = _pdfFormatDate(r.date);
      final machineLabel = isPromesh ? formatPromeshMachineLabel(r.machine) : formatProbarMachineLabel(r.machine);
      final diameterLabel = (r.diametre == null || r.diametre!.isEmpty) ? _t('Non renseigné') : '${r.diametre} mm';
      final meshLabel = (r.tailleMaille == null || r.tailleMaille!.isEmpty) ? _t('Non renseigné') : formatCellSize(r.tailleMaille!);
      final qtyLabel = '${formatProductionNumber(r.quantite ?? 0)} ${table.unit}';
      // Jamais recalculé — voir productionRecords.service.js#attachWaste.
      final wasteLabel = '${r.waste.toStringAsFixed(2)} ${table.wasteUnit}';

      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(
          color: isPromesh4 ? _pdfPromesh4Bg : null,
          border: const pw.Border(bottom: pw.BorderSide(color: _pdfBorder, width: 0.5)),
        ),
        child: pw.Row(children: [
          pw.Expanded(flex: flexIndex, child: pw.Text('$index', style: style)),
          pw.Expanded(flex: flexDate, child: pw.Text(dateLabel, style: style)),
          pw.Expanded(flex: flexMachine, child: pw.Text(machineLabel, style: style)),
          pw.Expanded(flex: flexDiameter, child: pw.Text(diameterLabel, style: style)),
          if (isPromesh) pw.Expanded(flex: flexMesh, child: pw.Text(meshLabel, style: style)),
          pw.Expanded(flex: flexQty, child: pw.Text(qtyLabel, textAlign: pw.TextAlign.right, style: style)),
          pw.Expanded(flex: flexWaste, child: pw.Text(wasteLabel, textAlign: pw.TextAlign.right, style: style)),
        ]),
      );
    }

    final grandTotalLabel = (isPromesh ? _t('Total PROMESH') : _t('Total PROBAR')).toUpperCase();
    final leadingFlex = flexIndex + flexDate + flexMachine + flexDiameter + (isPromesh ? flexMesh : 0);
    pw.Widget grandTotalRow() => pw.Container(
          color: color,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          margin: const pw.EdgeInsets.only(top: 2),
          child: pw.Row(children: [
            pw.Expanded(
              flex: leadingFlex,
              child: pw.Text(grandTotalLabel, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
            pw.Expanded(
              flex: flexQty,
              child: pw.Text('${formatProductionNumber(table.grandTotal)} ${table.unit}',
                  textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
            pw.Expanded(flex: flexWaste, child: pw.SizedBox()),
          ]),
        );

    // §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS RECOVERABLES
    // — deuxième ligne de total (Waste), jamais fusionnée avec Quantity.
    pw.Widget grandTotalWasteRow() => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          margin: const pw.EdgeInsets.only(top: 1),
          decoration: pw.BoxDecoration(color: color, border: const pw.Border(top: pw.BorderSide(color: PdfColors.white, width: 0.5))),
          child: pw.Row(children: [
            pw.Expanded(
              flex: leadingFlex + flexQty,
              child: pw.Text(_t('TOTAL WASTE'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
            pw.Expanded(
              flex: flexWaste,
              child: pw.Text('${table.grandTotalWaste.toStringAsFixed(2)} ${table.wasteUnit}',
                  textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
          ]),
        );

    // Une ligne par fiche réelle (table.rows — même jeu de données que
    // l'écran et que "Fiches de production"), jamais recalculé.
    final rows = <pw.Widget>[for (int i = 0; i < table.rows.length; i++) dataRow(i + 1, table.rows[i])];

    return [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      ),
      pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _pdfBorder, width: 0.6)),
        child: pw.Column(children: [
          headerRow(),
          if (rows.isEmpty)
            pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Text(_t('Aucune donnée'), style: pw.TextStyle(fontSize: 8.5, color: _pdfTextSub)))
          else
            ...rows,
          grandTotalRow(),
          grandTotalWasteRow(),
        ]),
      ),
      pw.SizedBox(height: 10),
    ];
  }

  static final _pdfHeadStyle = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdfTextSub);

  // Date réelle de production ("yyyy-MM-dd" côté API) — jamais la date du
  // jour — voir _formatProductionDate côté écran, même règle.
  String _pdfFormatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  // ════════════════════════════════════════════════════════════════════
  // EXCEL
  // ════════════════════════════════════════════════════════════════════

  // IMPORTANT — bug confirmé du package `excel` v2.1.0 (reproduit avec le
  // package réellement installé dans ce projet, voir le probe autonome
  // exécuté avant cette implémentation) : `Excel.delete()` ET
  // `Excel.rename()` (qui appelle `delete()` en interne) tentent
  // `_archive.files.removeWhere(...)` sur une liste NON modifiable
  // (`UnmodifiableListMixin`) DÈS QUE la feuille visée est celle créée par
  // le gabarit interne de `Excel.createExcel()` (celle que
  // `getDefaultSheet()` renvoie) — ce qui lève systématiquement
  // "Unsupported operation: Cannot remove from an unmodifiable list".
  // Renommer/supprimer une feuille ADDITIONNELLE créée après coup (jamais
  // celle du gabarit) fonctionne, elle, normalement — mais ça ne suffit pas
  // ici puisque c'est justement CETTE feuille de gabarit qu'il faut pouvoir
  // nommer proprement ("PROMESH Production"/"PROBAR Production", §1/§10 du
  // ticket "Export Excel — feuilles séparées").
  //
  // Solution retenue (testée) : ne JAMAIS appeler `delete()`/`rename()` sur
  // l'objet `Excel` — écrire le tableau détaillé du PREMIER type présent
  // directement DANS la feuille de gabarit (elle reste alors la toute
  // première feuille du classeur, sans réordonnancement nécessaire), créer
  // les feuilles suivantes normalement via `excelFile['Nom']` (toujours sûr,
  // ce sont de nouvelles feuilles), PUIS — une fois les octets `.xlsx`
  // produits par `encode()` — renommer la feuille de gabarit en éditant
  // directement `xl/workbook.xml` dans une archive ZIP reconstruite de zéro
  // (voir _renameSheetInXlsx) : cette étape ne touche JAMAIS l'objet `Excel`
  // interne, donc ne peut pas déclencher le bug ci-dessus.
  Future<void> exportExcel(ProductionSummary summary, ProductionSummaryExportContext ctx, Translator translate) async {
    _t = translate;
    try {
      final excelFile = xl.Excel.createExcel();
      final templateSheetName = excelFile.getDefaultSheet()!;
      String? renameTemplateSheetTo;

      Future<void> writeType(String label, ProductionSummaryTable table, {required bool isPromesh, required bool isFirst}) async {
        final dateRange = await _resolveExcelDateRange(ctx, isPromesh: isPromesh);
        final detailSheetName = _safeSheetName('$label Production');
        final recapSheetName = _safeSheetName('Récapitulatif $label');

        final detailSheet = isFirst ? excelFile[templateSheetName] : excelFile[detailSheetName];
        if (isFirst) renameTemplateSheetTo = detailSheetName;
        _writeExcelDetailSheet(detailSheet, label, table, ctx, dateRange, isPromesh: isPromesh);

        // §13 du ticket : la feuille "Récapitulatif" réutilise EXACTEMENT
        // `aggregateByMachine` (production_summary_model.dart) — la MÊME
        // fonction que le bloc "RÉCAPITULATIF DE PRODUCTION" affiché à
        // l'écran (voir production_summary_screen.dart#_machineBreakdownBlock)
        // — jamais une logique recalculée séparément pour l'export.
        _writeExcelRecapSheet(excelFile[recapSheetName], label, table, isPromesh: isPromesh);
      }

      if (summary.promesh != null) {
        await writeType('PROMESH', summary.promesh!, isPromesh: true, isFirst: true);
      }
      if (summary.probar != null) {
        await writeType('PROBAR', summary.probar!, isPromesh: false, isFirst: summary.promesh == null);
      }
      if (summary.promesh == null && summary.probar == null) {
        excelFile[templateSheetName].cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
            _t('Aucune donnée pour ces filtres');
      }

      var bytes = excelFile.encode();
      if (bytes == null) throw Exception('Échec de la génération du fichier Excel');
      if (renameTemplateSheetTo != null) {
        bytes = _renameSheetInXlsx(bytes, templateSheetName, renameTemplateSheetTo!);
      }
      final fileName = 'Production_Summary_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
      _downloadBytes(bytes, fileName);
    } catch (e, stackTrace) {
      debugPrint('[ProductionSummary] Excel export error: $e');
      debugPrintStack(stackTrace: stackTrace);
      // Le message utilisateur (SnackBar) est géré par l'appelant — voir
      // production_summary_screen.dart#_runExport.
      rethrow;
    }
  }

  // Édite `xl/workbook.xml` directement dans une archive ZIP reconstruite
  // (mutable par construction, contrairement à celle décodée par le package
  // `excel`) pour renommer une feuille SANS jamais passer par
  // `Excel.rename()`/`Excel.delete()` (voir commentaire ci-dessus). Validé
  // par un probe autonome : le fichier produit est bien re-décodable par
  // `Excel.decodeBytes` avec le nom et le contenu attendus.
  List<int> _renameSheetInXlsx(List<int> bytes, String from, String to) {
    final archive = arc.ZipDecoder().decodeBytes(bytes);
    final newArchive = arc.Archive();
    for (final file in archive.files) {
      if (file.name == 'xl/workbook.xml') {
        final xmlStr = utf8.decode(file.content as List<int>);
        final patched = xmlStr.replaceFirst('name="$from"', 'name="$to"');
        final patchedBytes = utf8.encode(patched);
        newArchive.addFile(arc.ArchiveFile(file.name, patchedBytes.length, patchedBytes));
      } else {
        newArchive.addFile(arc.ArchiveFile(file.name, file.size, file.content));
      }
    }
    final encoded = arc.ZipEncoder().encode(newArchive);
    return encoded ?? bytes;
  }

  // §11 du ticket : respecte la limite Excel de 31 caractères par nom de
  // feuille et retire les caractères interdits (: \ / ? * [ ]) — tous les
  // noms réellement utilisés ici ("PROMESH Production", "Récapitulatif
  // PROBAR", ...) tiennent largement en-dessous de cette limite, ce
  // garde-fou couvre uniquement un cas futur imprévu.
  String _safeSheetName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), '');
    return cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
  }

  // Résout "Start date"/"End date" — jamais une date fixe :
  //   • Si l'utilisateur a choisi une période explicite (dates de début/fin
  //     personnalisées, voir ctx.rawStartDate/rawEndDate), ce sont CES
  //     dates-là qui sont utilisées telles quelles.
  //   • Sinon ("All periods", ou un préréglage sans dates explicites côté
  //     UI), les dates sont calculées à partir des fiches RÉELLEMENT
  //     incluses dans l'export — voir GET /production-records (déjà
  //     utilisé par "Fiches de production"), triées par date croissante
  //     puis décroissante pour obtenir la date min/max sans récupérer
  //     toutes les fiches. `type` est forcé à la section en cours
  //     (promesh/probar) pour que chaque section reflète exactement sa
  //     propre plage de dates même quand le filtre Type est "Toutes les
  //     productions".
  // En cas d'échec réseau ou d'absence de fiche, retombe sur des valeurs
  // nulles (la ligne correspondante est alors simplement omise) plutôt que
  // de bloquer l'export.
  Future<({String? start, String? end})> _resolveExcelDateRange(ProductionSummaryExportContext ctx, {required bool isPromesh}) async {
    if (ctx.rawStartDate != null && ctx.rawEndDate != null) {
      return (start: _reformatIsoDate(ctx.rawStartDate!), end: _reformatIsoDate(ctx.rawEndDate!));
    }
    try {
      final type = isPromesh ? 'promesh' : 'probar';
      final earliest = await ProductionRecordsService.instance.fetchPage(
        type: type,
        period: ctx.rawPeriod,
        startDate: ctx.rawStartDate,
        endDate: ctx.rawEndDate,
        machineId: ctx.rawMachineId,
        sort: 'date_asc',
        page: 1,
        limit: 1,
      );
      final latest = await ProductionRecordsService.instance.fetchPage(
        type: type,
        period: ctx.rawPeriod,
        startDate: ctx.rawStartDate,
        endDate: ctx.rawEndDate,
        machineId: ctx.rawMachineId,
        sort: 'date_desc',
        page: 1,
        limit: 1,
      );
      final minDate = earliest.items.isNotEmpty ? earliest.items.first.date : null;
      final maxDate = latest.items.isNotEmpty ? latest.items.first.date : null;
      return (
        start: minDate == null ? null : _reformatIsoDate(minDate),
        end: maxDate == null ? null : _reformatIsoDate(maxDate),
      );
    } catch (_) {
      return (start: null, end: null);
    }
  }

  String? _reformatIsoDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    return DateFormat('dd/MM/yyyy').format(d);
  }

  static const _xlPromesh4Bg = '#FEF3C7';
  static const _xlPromesh4Orange = '#F59E0B';
  static const _xlBorderColor = '#E2E8F0';

  xl.Border get _thinBorder => xl.Border(borderStyle: xl.BorderStyle.Thin, borderColorHex: _xlBorderColor);

  xl.CellStyle _headerCellStyle({xl.HorizontalAlign align = xl.HorizontalAlign.Left}) => xl.CellStyle(
        bold: true,
        backgroundColorHex: '#F8FAFC',
        fontColorHex: '#0F172A',
        horizontalAlign: align,
        leftBorder: _thinBorder,
        rightBorder: _thinBorder,
        topBorder: _thinBorder,
        bottomBorder: _thinBorder,
      );

  xl.CellStyle _dataCellStyle({
    bool bold = false,
    String backgroundColorHex = '#FFFFFF',
    String fontColorHex = '#0F172A',
    xl.HorizontalAlign align = xl.HorizontalAlign.Left,
  }) =>
      xl.CellStyle(
        bold: bold,
        backgroundColorHex: backgroundColorHex,
        fontColorHex: fontColorHex,
        horizontalAlign: align,
        leftBorder: _thinBorder,
        rightBorder: _thinBorder,
        topBorder: _thinBorder,
        bottomBorder: _thinBorder,
      );

  // Écrit le tableau détaillé (une ligne par fiche réelle, IDENTIQUE aux
  // données actuellement filtrées/affichées à l'écran) dans sa PROPRE
  // feuille — toujours à partir de la ligne 0 (FEUILLE 1, §1/§10 du
  // ticket "Export Excel — feuilles séparées").
  void _writeExcelDetailSheet(
    xl.Sheet sheet,
    String sectionLabel,
    ProductionSummaryTable table,
    ProductionSummaryExportContext ctx,
    ({String? start, String? end}) dateRange, {
    required bool isPromesh,
  }) {
    // Colonnes PROMESH : #, Date production, Machine, Diamètre, Cell size, Quantity, Waste
    // Colonnes PROBAR  : #, Date production, Machine, Diamètre, Quantity, Waste
    final lastCol = isPromesh ? 6 : 5;

    int row = 0;
    row = _mergedTitle(sheet, row, lastCol, '$sectionLabel Production', isPromesh ? '#2563EB' : '#F97316');
    row = _kv(sheet, row, _t('Exported on'), DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()));
    row = _kv(sheet, row, _t('Exported by'), AuthService().displayName);
    if (dateRange.start != null) row = _kv(sheet, row, _t('Start date'), dateRange.start!);
    if (dateRange.end != null) row = _kv(sheet, row, _t('End date'), dateRange.end!);
    if (ctx.machineLabel != null) row = _kv(sheet, row, _t('Machine'), ctx.machineLabel!);
    if (ctx.diameterLabel != null) row = _kv(sheet, row, _t('Diamètre'), '${ctx.diameterLabel} mm');
    row++;

    // En-têtes — seule la colonne Quantity porte l'unité (m/m²) dans son
    // TITRE ; les cellules Quantity elles-mêmes contiennent des valeurs
    // NUMÉRIQUES pures (ni séparateur de milliers, ni unité, ni chaîne
    // formatée — demande explicite, voir _numericCell).
    final headers = isPromesh
        ? ['#', _t('Date production'), _t('Machine'), _t('Diameter'), _t('Cell size'), '${_t('Quantity')} (${table.unit})', '${_t('Waste')} (${table.wasteUnit})']
        : ['#', _t('Date production'), _t('Machine'), _t('Diameter'), '${_t('Quantity')} (${table.unit})', '${_t('Waste')} (${table.wasteUnit})'];
    for (int c = 0; c < headers.length; c++) {
      final isNumericHeader = c == headers.length - 1 || c == headers.length - 2;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
        ..value = headers[c]
        ..cellStyle = _headerCellStyle(align: isNumericHeader ? xl.HorizontalAlign.Right : xl.HorizontalAlign.Left);
    }
    row++;

    // Une ligne par fiche réelle (table.rows — même jeu de données que
    // l'écran et que "Fiches de production"), jamais recalculé. La ligne
    // PROMESH machine 4 (valeur réelle du champ `machine`, jamais la
    // position) est mise en évidence sur toute la ligne — même convention
    // que l'écran (surlignage discret), jamais confondue avec le "nom en
    // orange uniquement" du récapitulatif (§9 du ticket, propre à
    // _writeExcelRecapSheet ci-dessous).
    for (int i = 0; i < table.rows.length; i++) {
      final r = table.rows[i];
      final isPromesh4 = isPromesh && isPromesh4Machine(r.machine);
      final bg = isPromesh4 ? _xlPromesh4Bg : '#FFFFFF';
      final dateLabel = _pdfFormatDate(r.date);
      final diameterLabel = (r.diametre == null || r.diametre!.isEmpty) ? _t('Non renseigné') : r.diametre!;

      int col = 0;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        ..value = i + 1
        ..cellStyle = _dataCellStyle(bold: isPromesh4, backgroundColorHex: bg, align: xl.HorizontalAlign.Right);
      col++;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        ..value = dateLabel
        ..cellStyle = _dataCellStyle(bold: isPromesh4, backgroundColorHex: bg);
      col++;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        ..value = isPromesh ? formatPromeshMachineLabel(r.machine) : formatProbarMachineLabel(r.machine)
        ..cellStyle = _dataCellStyle(bold: isPromesh4, backgroundColorHex: bg);
      col++;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        ..value = diameterLabel
        ..cellStyle = _dataCellStyle(bold: isPromesh4, backgroundColorHex: bg);
      col++;
      if (isPromesh) {
        final meshLabel = (r.tailleMaille == null || r.tailleMaille!.isEmpty) ? _t('Non renseigné') : formatCellSize(r.tailleMaille!);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
          ..value = meshLabel
          ..cellStyle = _dataCellStyle(bold: isPromesh4, backgroundColorHex: bg);
        col++;
      }
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        ..value = _numericCell(r.quantite ?? 0)
        ..cellStyle = _dataCellStyle(bold: isPromesh4, backgroundColorHex: bg, align: xl.HorizontalAlign.Right);
      col++;
      // Jamais recalculé — voir productionRecords.service.js#attachWaste.
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        ..value = _numericCell(r.waste)
        ..cellStyle = _dataCellStyle(bold: isPromesh4, backgroundColorHex: bg, align: xl.HorizontalAlign.Right);
      row++;
    }

    row++;
    final qtyCol = lastCol - 1;
    if (qtyCol > 0) {
      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        xl.CellIndex.indexByColumnRow(columnIndex: qtyCol - 1, rowIndex: row),
      );
    }
    final totalStyle = xl.CellStyle(bold: true, fontSize: 13, backgroundColorHex: isPromesh ? '#2563EB' : '#F97316', fontColorHex: '#FFFFFF');
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = (isPromesh ? _t('Total PROMESH') : _t('Total PROBAR')).toUpperCase()
      ..cellStyle = totalStyle;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: qtyCol, rowIndex: row))
      ..value = _numericCell(table.grandTotal)
      ..cellStyle = totalStyle;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: row))
      ..value = ''
      ..cellStyle = totalStyle;
    row++;

    // Deuxième ligne "TOTAL WASTE", jamais fusionnée avec Quantity.
    if (lastCol > 0) {
      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        xl.CellIndex.indexByColumnRow(columnIndex: lastCol - 1, rowIndex: row),
      );
    }
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = _t('TOTAL WASTE')
      ..cellStyle = totalStyle;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: row))
      ..value = _numericCell(table.grandTotalWaste)
      ..cellStyle = totalStyle;

    for (int c = 0; c <= lastCol; c++) {
      sheet.setColAutoFit(c);
    }
  }

  // FEUILLE 2 — "Récapitulatif PROMESH/PROBAR" — reproduit EXACTEMENT la
  // structure du bloc "RÉCAPITULATIF DE PRODUCTION" affiché à l'écran
  // (production_summary_screen.dart#_machineBreakdownBlock), puis TOTAL/
  // TOTAL WASTE généraux repris TELS QUELS de `table.grandTotal`/
  // `table.grandTotalWaste` (jamais recalculés ici).
  //
  // §MODIFICATION — RÉCAPITULATIF PROMESH : REGROUPEMENT 1-2-3 / 4 SÉPARÉ
  // (2026-09-12, ticket "modifier UNIQUEMENT la structure du RÉCAPITULATIF
  // DE PRODUCTION") — UNIQUEMENT pour PROMESH (§12/§13 du ticket) : les
  // sections dont la machine n'est jamais PROMESH 4 (`isPromesh4Machine`,
  // jamais hardcodé "1,2,3") sont aplaties dans UN bloc combiné avec
  // colonne Machine (_writeExcelCombinedMachineBlock, §1-§5) ; PROMESH 4
  // garde sa propre section (§6/§7). PROBAR n'est JAMAIS concerné par ce
  // ticket : `isolatedSections = sections` (toutes, comportement PROBAR
  // strictement inchangé, une section par machine — voir
  // _writeExcelMachineSection ci-dessous, qui reproduit bit pour bit
  // l'ancien corps de boucle).
  void _writeExcelRecapSheet(
    xl.Sheet sheet,
    String sectionLabel,
    ProductionSummaryTable table, {
    required bool isPromesh,
  }) {
    // §CORRECTION — EXCLUSION DES LIGNES "NOT SPECIFIED" (2026-09-21, ticket
    // "corriger l'affichage du Production Summary") — filtre appliqué
    // UNIQUEMENT pour PROMESH : `hasValidDiameterAndCellSize` exige un Cell
    // size renseigné, un champ qui n'existe JAMAIS pour PROBAR (jamais de
    // Cell size côté PROBAR, voir `groupByCellSize: false` plus bas) — filtrer
    // PROBAR avec ce même critère viderait sa feuille entière. PROBAR (aucun
    // ticket ne l'a jamais concerné) garde `table.rows` intégral, inchangé.
    final rowsForRecap = isPromesh ? table.rows.where(hasValidDiameterAndCellSize).toList() : table.rows;
    final sections = aggregateByMachine(rowsForRecap, groupByCellSize: isPromesh);
    final color = isPromesh ? '#2563EB' : '#F97316';

    final isolatedSections = isPromesh ? [for (final s in sections) if (isPromesh4Machine(s.machine)) s] : sections;
    // §MODIFICATION — SUPPRESSION COLONNE MACHINE DU BLOC 1-2-3 (2026-09-20,
    // ticket "supprimer complètement la colonne Machine") — le bloc combiné
    // PROMESH 1-2-3 n'est PLUS dérivé des sections par-machine : il est
    // recalculé par `aggregateByDiameterCellSize` sur les lignes BRUTES des
    // machines non-4 (§2/§3 du ticket — GROUP BY Diameter+Cell size
    // UNIQUEMENT, jamais Machine). `combinedMachineNumbers` (extrait des
    // lignes brutes, jamais des groupes qui ne portent plus l'info machine)
    // sert uniquement au libellé d'en-tête/sous-total "PROMESH 1-2-3".
    final combinedRows = isPromesh ? rowsForRecap.where((r) => !isPromesh4Machine(r.machine)).toList() : const <ProductionRecordModel>[];
    final combinedGroups = isPromesh ? aggregateByDiameterCellSize(combinedRows) : const <MachineDiameterGroup>[];
    final combinedMachineNumbers = <String>{
      for (final r in combinedRows)
        if (r.machine != null && r.machine!.trim().isNotEmpty) r.machine!.trim(),
    }.toList()
      ..sort((a, b) {
        final na = int.tryParse(a);
        final nb = int.tryParse(b);
        if (na != null && nb != null) return na.compareTo(nb);
        return a.compareTo(b);
      });

    // Colonnes bloc combiné (PROMESH uniquement) : Diameter, Cell size,
    // Quantity, Waste (plus de colonne Machine, §1 du ticket — mêmes
    // colonnes que la section isolée ci-dessous). Colonnes section isolée :
    // Diameter [+ Cell size si PROMESH], Quantity, Waste (jamais de Cell
    // size pour PROBAR, comportement historique inchangé).
    final isolatedLastCol = isPromesh ? 3 : 2;
    final combinedLastCol = isolatedLastCol;
    final overallLastCol = combinedGroups.isNotEmpty ? combinedLastCol : isolatedLastCol;

    int row = 0;
    row = _mergedTitle(sheet, row, overallLastCol, '${_t('Récapitulatif de production')} — $sectionLabel', color);
    row++;

    if (sections.isEmpty) {
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = _t('Aucune donnée pour ces filtres');
    }

    if (combinedGroups.isNotEmpty) {
      row = _writeExcelCombinedMachineBlock(sheet, row, combinedGroups, combinedMachineNumbers, table, color);
      row++; // ligne vide de séparation avant la section PROMESH 4.
    }

    for (final section in isolatedSections) {
      row = _writeExcelMachineSection(sheet, row, section, table, color, isPromesh: isPromesh);
      row++; // ligne vide de séparation avant la section suivante.
    }

    // TOTAL général — pour PROBAR, repris TEL QUEL de `table.grandTotal`
    // (jamais recalculé, jamais concerné par ce ticket). §13 du ticket
    // "Excel de référence" (2026-09-13) : le libellé PROMESH devient "GRAND
    // TOTAL MESH" (calqué sur le fichier Excel de référence du client) —
    // PROBAR garde "TOTAL PROBAR" inchangé.
    //
    // §CORRECTION — EXCLUSION DES LIGNES "NOT SPECIFIED" (2026-09-21) — §7
    // du ticket : "TOTAL PROMESH doit être calculé uniquement à partir des
    // lignes valides affichées dans les deux blocs" = SOUS-TOTAL PROMESH
    // 1-2-3 + SOUS-TOTAL PROMESH 4 (jamais `table.grandTotal`, qui inclut
    // les fiches sans Diameter/Cell size renseignés).
    final qtyTotal = isPromesh
        ? isolatedSections.expand((s) => s.rows).fold<double>(0, (sum, g) => sum + g.quantity) +
            combinedGroups.fold<double>(0, (sum, g) => sum + g.quantity)
        : table.grandTotal;
    //
    // §CORRECTION — INCOHÉRENCE SOUS-TOTAUX/TOTAL WASTE PROMESH (2026-09-19,
    // ticket "corriger le calcul du Waste dans Production Summary —
    // PROMESH") — AVANT cette correction, "TOTAL WASTE" utilisait
    // `table.grandTotalWaste` (compte chaque date une seule fois sur
    // L'ENSEMBLE de la feuille), alors que les sous-totaux ci-dessus
    // comptent chaque date une seule fois PAR GROUPE — deux méthodes
    // différentes pour la "même" valeur, exactement le même défaut que sur
    // l'écran (voir production_summary_screen.dart#_recapWasteTotal, même
    // correction appliquée ici, même principe : TOTAL WASTE PROMESH = somme
    // du `waste` de TOUS les groupes déjà utilisés pour les sous-totaux —
    // jamais une valeur backend indépendante, §7 du ticket). PROBAR (aucun
    // ticket ne l'a jamais concerné) garde `table.grandTotalWaste` inchangé.
    //
    // §MISE À JOUR — SUPPRESSION COLONNE MACHINE DU BLOC 1-2-3 (2026-09-20)
    // — doit désormais suivre EXACTEMENT la même logique que le bloc combiné
    // ci-dessus (`aggregateByDiameterCellSize`, jamais `aggregateByMachine`)
    // pour rester la somme réelle des sous-totaux affichés dans cette
    // feuille : PROMESH 4 isolé (inchangé) + PROMESH 1-2-3 (nouveau calcul).
    final wasteTotal = isPromesh
        ? isolatedSections.expand((s) => s.rows).fold<double>(0, (sum, g) => sum + g.waste) +
            combinedGroups.fold<double>(0, (sum, g) => sum + g.waste)
        : table.grandTotalWaste;
    final totalStyle = xl.CellStyle(bold: true, fontSize: 13, backgroundColorHex: color, fontColorHex: '#FFFFFF');
    if (overallLastCol > 0) {
      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        xl.CellIndex.indexByColumnRow(columnIndex: overallLastCol - 1, rowIndex: row),
      );
    }
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = isPromesh ? _t('GRAND TOTAL MESH') : _t('Total PROBAR').toUpperCase()
      ..cellStyle = totalStyle;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: overallLastCol, rowIndex: row))
      ..value = _numericCell(qtyTotal)
      ..cellStyle = totalStyle;
    row++;
    if (overallLastCol > 0) {
      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        xl.CellIndex.indexByColumnRow(columnIndex: overallLastCol - 1, rowIndex: row),
      );
    }
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = _t('TOTAL WASTE')
      ..cellStyle = totalStyle;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: overallLastCol, rowIndex: row))
      ..value = _numericCell(wasteTotal)
      ..cellStyle = totalStyle;

    for (int c = 0; c <= overallLastCol; c++) {
      sheet.setColAutoFit(c);
    }
  }

  // §MODIFICATION — SUPPRESSION COLONNE MACHINE DU BLOC 1-2-3 (2026-09-20,
  // ticket "supprimer complètement la colonne Machine") — UN SEUL bloc pour
  // PROMESH 1-2-3, avec EXACTEMENT les mêmes colonnes que la section
  // isolée PROMESH 4 (_writeExcelMachineSection) : Diameter, Cell size,
  // Quantity, Waste — plus de colonne Machine (§1 du ticket). `groups`
  // arrive déjà trié Diameter → Cell size (produit par
  // `aggregateByDiameterCellSize`, jamais retrié ici) ; `machineNumbers`
  // (extrait des lignes brutes par l'appelant, les groupes ne portent plus
  // l'info machine) sert uniquement au libellé d'en-tête/sous-total.
  // Retourne la prochaine ligne libre (comme les autres écrivains de
  // section de ce fichier).
  int _writeExcelCombinedMachineBlock(
    xl.Sheet sheet,
    int startRow,
    List<MachineDiameterGroup> groups,
    List<String> machineNumbers,
    ProductionSummaryTable table,
    String color,
  ) {
    int row = startRow;
    const lastCol = 3; // Diameter, Cell size, Quantity, Waste

    final headerLabel = machineNumbers.isEmpty ? _t('Non renseigné') : machineNumbers.map(formatPromeshMachineLabel).join(' + ');
    // §5/§7/§9 du ticket "Excel de référence" : "SOUS-TOTAL PROMESH 1-2-3"
    // — UN SEUL total pour tout le bloc, jamais un sous-total par machine à
    // l'intérieur.
    final totalLabel = machineNumbers.isEmpty ? _t('SOUS-TOTAL') : '${_t('SOUS-TOTAL')} PROMESH ${machineNumbers.join('-')}';

    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = headerLabel
      ..cellStyle = xl.CellStyle(bold: true, fontSize: 13, fontColorHex: '#0F172A');
    row++;

    final headers = [_t('Diameter'), _t('Cell size'), '${_t('Quantity')} (${table.unit})', '${_t('Waste')} (${table.wasteUnit})'];
    for (int c = 0; c < headers.length; c++) {
      final isNumericHeader = c >= headers.length - 2;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
        ..value = headers[c]
        ..cellStyle = _headerCellStyle(align: isNumericHeader ? xl.HorizontalAlign.Right : xl.HorizontalAlign.Left);
    }
    row++;

    for (final g in groups) {
      final diameterLabel = (g.diametre == null || g.diametre!.isEmpty) ? _t('Non renseigné') : '${g.diametre} mm';
      final meshLabel = (g.cellSize == null || g.cellSize!.isEmpty) ? _t('Non renseigné') : g.cellSize!;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = diameterLabel
        ..cellStyle = _dataCellStyle();
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        ..value = meshLabel
        ..cellStyle = _dataCellStyle();
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        ..value = _numericCell(g.quantity)
        ..cellStyle = _dataCellStyle(align: xl.HorizontalAlign.Right);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        ..value = _numericCell(g.waste)
        ..cellStyle = _dataCellStyle(align: xl.HorizontalAlign.Right);
      row++;
    }

    // Le libellé ne fusionne QUE Diameter+Cell size (colonnes 0..lastCol-2),
    // Quantity a sa PROPRE cellule (colonne lastCol-1) et Waste la sienne
    // (colonne lastCol) — jamais l'une dans la colonne de l'autre.
    final subtotal = groups.fold<double>(0, (s, g) => s + g.quantity);
    // Simple somme des `waste` déjà calculés par groupe (voir
    // `MachineDiameterGroup.waste`, produit par `aggregateByDiameterCellSize`,
    // jamais retouché ici) — jamais un recalcul, jamais le total général
    // (`table.grandTotalWaste`, §4 du ticket).
    final wasteSubtotal = groups.fold<double>(0, (s, g) => s + g.waste);
    final qtyCol = lastCol - 1;
    if (qtyCol > 1) {
      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        xl.CellIndex.indexByColumnRow(columnIndex: qtyCol - 1, rowIndex: row),
      );
    }
    final subtotalStyle = xl.CellStyle(bold: true, backgroundColorHex: '#F8FAFC', fontColorHex: '#0F172A');
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = totalLabel
      ..cellStyle = subtotalStyle;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: qtyCol, rowIndex: row))
      ..value = _numericCell(subtotal)
      ..cellStyle = subtotalStyle.copyWith(horizontalAlignVal: xl.HorizontalAlign.Right, fontColorHexVal: color);
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: row))
      ..value = _numericCell(wasteSubtotal)
      ..cellStyle = subtotalStyle.copyWith(horizontalAlignVal: xl.HorizontalAlign.Right);
    row++;

    return row;
  }

  // Section d'UNE machine isolée — PROMESH 4 (§6/§7 du ticket) OU, pour
  // PROBAR (jamais concerné par ce ticket), CHAQUE machine (comportement
  // historique bit pour bit inchangé : une section par machine, wording
  // "Sous-total"). Retourne la prochaine ligne libre.
  int _writeExcelMachineSection(
    xl.Sheet sheet,
    int startRow,
    MachineSection section,
    ProductionSummaryTable table,
    String color, {
    required bool isPromesh,
  }) {
    int row = startRow;
    final lastCol = isPromesh ? 3 : 2;
    final isPromesh4 = isPromesh && isPromesh4Machine(section.machine);

    // §9 du ticket : PROMESH 4 identifiable UNIQUEMENT par la couleur de
    // son NOM (police orange) — jamais un fond de ligne/section coloré.
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = isPromesh ? formatPromeshMachineLabel(section.machine) : formatProbarMachineLabel(section.machine)
      ..cellStyle = xl.CellStyle(
        bold: true,
        fontSize: 13,
        fontColorHex: isPromesh4 ? _xlPromesh4Orange : '#0F172A',
      );
    row++;

    final headers = isPromesh
        ? [_t('Diameter'), _t('Cell size'), '${_t('Quantity')} (${table.unit})', '${_t('Waste')} (${table.wasteUnit})']
        : [_t('Diameter'), '${_t('Quantity')} (${table.unit})', '${_t('Waste')} (${table.wasteUnit})'];
    for (int c = 0; c < headers.length; c++) {
      final isNumericHeader = c >= headers.length - 2;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
        ..value = headers[c]
        ..cellStyle = _headerCellStyle(align: isNumericHeader ? xl.HorizontalAlign.Right : xl.HorizontalAlign.Left);
    }
    row++;

    for (final g in section.rows) {
      final diameterLabel = (g.diametre == null || g.diametre!.isEmpty) ? _t('Non renseigné') : '${g.diametre} mm';
      int col = 0;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        ..value = diameterLabel
        ..cellStyle = _dataCellStyle();
      col++;
      if (isPromesh) {
        final meshLabel = (g.cellSize == null || g.cellSize!.isEmpty) ? _t('Non renseigné') : g.cellSize!;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
          ..value = meshLabel
          ..cellStyle = _dataCellStyle();
        col++;
      }
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        ..value = _numericCell(g.quantity)
        ..cellStyle = _dataCellStyle(align: xl.HorizontalAlign.Right);
      col++;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        ..value = _numericCell(g.waste)
        ..cellStyle = _dataCellStyle(align: xl.HorizontalAlign.Right);
      row++;
    }

    // §7/§9 du ticket "Excel de référence" : PROMESH (toujours PROMESH 4
    // ici) affiche désormais "SOUS-TOTAL PROMESH 4", cohérent avec l'écran
    // (voir _machineCard). PROBAR (jamais concerné par ce ticket) garde
    // "Sous-total PROBAR X" — wording historique STRICTEMENT inchangé.
    //
    // §MODIFICATION — COLONNES QUANTITY/WASTE SÉPARÉES (2026-09-14, ticket
    // "corriger la ligne SOUS-TOTAL PROMESH 1-2") — AVANT cette correction,
    // le libellé fusionnait les colonnes 0..lastCol-1 et Quantity était
    // écrite dans la colonne lastCol (= la colonne WASTE, jamais
    // renseignée) — même défaut que _writeExcelCombinedMachineBlock
    // ci-dessus, corrigé ici à l'identique (Quantity et Waste ont
    // maintenant chacune leur propre colonne). Ce même défaut affectait
    // aussi PROBAR (fonction partagée) : corrigé pour les deux, la
    // correction étant un pur repositionnement de colonnes, jamais un
    // changement de logique/donnée.
    final subtotal = section.rows.fold<double>(0, (s, g) => s + g.quantity);
    final wasteSubtotal = section.rows.fold<double>(0, (s, g) => s + g.waste);
    final qtyCol = lastCol - 1;
    // Fusion UNIQUEMENT s'il y a réellement plus d'une colonne à fusionner
    // (PROBAR isolé : une seule colonne "Diameter" avant Quantity — une
    // "fusion" à cellule unique serait un no-op inutile).
    if (qtyCol > 1) {
      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        xl.CellIndex.indexByColumnRow(columnIndex: qtyCol - 1, rowIndex: row),
      );
    }
    final subtotalStyle = xl.CellStyle(bold: true, backgroundColorHex: '#F8FAFC', fontColorHex: '#0F172A');
    final machineLabel = isPromesh ? formatPromeshMachineLabel(section.machine) : formatProbarMachineLabel(section.machine);
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = isPromesh ? '${_t('SOUS-TOTAL')} $machineLabel' : 'Sous-total $machineLabel'
      ..cellStyle = subtotalStyle;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: qtyCol, rowIndex: row))
      ..value = _numericCell(subtotal)
      ..cellStyle = subtotalStyle.copyWith(horizontalAlignVal: xl.HorizontalAlign.Right, fontColorHexVal: color);
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: row))
      ..value = _numericCell(wasteSubtotal)
      ..cellStyle = subtotalStyle.copyWith(horizontalAlignVal: xl.HorizontalAlign.Right);
    row++;

    return row;
  }

  int _mergedTitle(xl.Sheet sheet, int row, int lastCol, String text, String hex) {
    if (lastCol > 0) {
      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        xl.CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: row),
      );
    }
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = text
      ..cellStyle = xl.CellStyle(bold: true, fontSize: 14, backgroundColorHex: hex, fontColorHex: '#FFFFFF');
    return row + 1;
  }

  // Valeur numérique PURE pour une cellule Quantity/Total — jamais de
  // séparateur de milliers, jamais de suffixe d'unité (demande explicite) :
  // le fichier `excel` package (`Data.value = dynamic`) détecte le type
  // Dart réel (int/double) et écrit une vraie cellule numérique, pas une
  // chaîne. Écrit un `int` pour les valeurs entières (cas courant ici,
  // affiché "1000" et non "1000.0") et un `double` sinon.
  num _numericCell(double value) {
    if (!value.isFinite) return 0;
    return value == value.roundToDouble() ? value.round() : value;
  }

  int _kv(xl.Sheet sheet, int row, String label, String value) {
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = label
      ..cellStyle = xl.CellStyle(bold: true, fontColorHex: '#64748B');
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = value;
    return row + 1;
  }

  void _downloadBytes(List<int> bytes, String name) {
    final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', name)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
