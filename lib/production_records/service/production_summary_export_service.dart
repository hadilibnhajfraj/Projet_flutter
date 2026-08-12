// lib/production_records/service/production_summary_export_service.dart
//
// Export Excel/PDF/Impression pour "Production Summary" — reproduit
// EXACTEMENT les données actuellement filtrées/affichées à l'écran (voir
// production_summary_screen.dart), jamais recalculées différemment.
// Réutilise les mêmes patterns clients que le module POR PROMESH (dart:html
// pour Excel, package:pdf + printing pour PDF/Impression) — voir
// forms/por_promesh/service/por_promesh_{pdf,excel}_service.dart.

import 'dart:html' as html;

import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;

import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:dash_master_toolkit/providers/auth_service.dart';
import 'package:dash_master_toolkit/forms/por_promesh/utils/por_promesh_pdf_theme.dart';

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

class ProductionSummaryExportService {
  static final ProductionSummaryExportService instance = ProductionSummaryExportService._();
  ProductionSummaryExportService._();

  String _documentTitle(ProductionSummary summary) {
    final hasPromesh = summary.promesh != null;
    final hasProbar = summary.probar != null;
    if (hasPromesh && !hasProbar) return 'Production Summary — PROMESH';
    if (hasProbar && !hasPromesh) return 'Production Summary — PROBAR';
    return 'Production Summary — PROBAR & PROMESH';
  }

  // ════════════════════════════════════════════════════════════════════
  // PDF / IMPRESSION
  // ════════════════════════════════════════════════════════════════════

  Future<void> exportPdf(ProductionSummary summary, ProductionSummaryExportContext ctx) async {
    try {
      final doc = await _buildDocument(summary, ctx);
      await Printing.sharePdf(bytes: await doc.save(), filename: 'production-summary-${DateTime.now().millisecondsSinceEpoch}.pdf');
    } catch (e, stackTrace) {
      debugPrint('[ProductionSummary] PDF export error: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> printSummary(ProductionSummary summary, ProductionSummaryExportContext ctx) async {
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
                child: pw.Text('Généré le $generatedAt par $generatedBy', style: pw.TextStyle(fontSize: 7.5, color: _pdfTextSub))),
            pw.Text('Page ${c.pageNumber} / ${c.pagesCount}', style: pw.TextStyle(fontSize: 7.5, color: _pdfTextSub)),
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
          _metaChip("Date d'export", generatedAt),
          _metaChip('Période', ctx.periodLabel),
          if (ctx.machineLabel != null) _metaChip('Machine', ctx.machineLabel!),
          if (ctx.diameterLabel != null) _metaChip('Diamètre', '${ctx.diameterLabel} mm'),
          _metaChip('Statut', ctx.statusLabel),
        ]),
      ]),
    );
  }

  pw.Widget _metaChip(String label, String value) => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text('$label : ', style: pw.TextStyle(fontSize: 8.5, color: _pdfTextSub)),
        pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _pdfText)),
      ]);

  List<pw.Widget> _pdfSection(String label, PdfColor color, ProductionSummaryTable table, {required bool isPromesh}) {
    final flexDiameter = 3, flexMesh = 4, flexQty = 3;

    pw.Widget headerRow() => pw.Container(
          color: _pdfBg,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Row(children: [
            pw.Expanded(flex: flexDiameter, child: pw.Text('Diameter', style: _pdfHeadStyle)),
            if (isPromesh) pw.Expanded(flex: flexMesh, child: pw.Text('Cell size', style: _pdfHeadStyle)),
            pw.Expanded(flex: flexQty, child: pw.Text('Quantity (${table.unit})', style: _pdfHeadStyle, textAlign: pw.TextAlign.right)),
          ]),
        );

    pw.Widget dataRow(String colA, String? colB, String colC, {bool bold = false}) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _pdfBorder, width: 0.5))),
          child: pw.Row(children: [
            pw.Expanded(
                flex: flexDiameter,
                child: pw.Text(colA, style: pw.TextStyle(fontSize: 8.5, color: _pdfText, fontWeight: bold ? pw.FontWeight.bold : null))),
            if (isPromesh)
              pw.Expanded(
                  flex: flexMesh,
                  child: pw.Text(colB ?? '', style: pw.TextStyle(fontSize: 8.5, color: _pdfText, fontWeight: bold ? pw.FontWeight.bold : null))),
            pw.Expanded(
              flex: flexQty,
              child: pw.Text(colC, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, color: _pdfText, fontWeight: bold ? pw.FontWeight.bold : null)),
            ),
          ]),
        );

    final grandTotalLabel = isPromesh ? 'TOTAL PROMESH' : 'TOTAL PROBAR';
    pw.Widget grandTotalRow() => pw.Container(
          color: color,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          margin: const pw.EdgeInsets.only(top: 2),
          child: pw.Row(children: [
            pw.Expanded(
              flex: flexDiameter + (isPromesh ? flexMesh : 0),
              child: pw.Text(grandTotalLabel, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
            pw.Expanded(
              flex: flexQty,
              child: pw.Text('${formatProductionNumber(table.grandTotal)} ${table.unit}',
                  textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
          ]),
        );

    // Lignes de production groupées par diamètre, sans sous-total
    // intermédiaire (retiré sur demande explicite) — seul le total de
    // section (grandTotalRow ci-dessous) reste affiché.
    final rows = <pw.Widget>[];
    for (final g in table.groups) {
      final diameterLabel = (g.diameter == null || g.diameter!.isEmpty) ? 'Non renseigné' : g.diameter!;
      if (isPromesh) {
        for (final r in g.rows) {
          final meshLabel = (r.meshSize == null || r.meshSize!.isEmpty) ? 'Non renseigné' : formatCellSize(r.meshSize!);
          rows.add(dataRow(diameterLabel, meshLabel, '${formatProductionNumber(r.quantity)} ${table.unit}'));
        }
      } else {
        rows.add(dataRow(diameterLabel, null, '${formatProductionNumber(g.diameterTotal)} ${table.unit}'));
      }
    }

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
                child: pw.Text('Aucune donnée', style: pw.TextStyle(fontSize: 8.5, color: _pdfTextSub)))
          else
            ...rows,
          grandTotalRow(),
        ]),
      ),
      pw.SizedBox(height: 10),
    ];
  }

  static final _pdfHeadStyle = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdfTextSub);

  // ════════════════════════════════════════════════════════════════════
  // EXCEL
  // ════════════════════════════════════════════════════════════════════

  // IMPORTANT — bug confirmé du package `excel` v2.1.0 (reproduit avec le
  // package réellement installé dans ce projet) : `Excel.delete()` ET
  // `Excel.rename()` (qui appelle `delete()` en interne) tentent
  // `_archive.files.removeWhere(...)` sur une liste NON modifiable
  // (`UnmodifiableListMixin`), ce qui lève systématiquement "Unsupported
  // operation: Cannot remove from an unmodifiable list" — y compris pour un
  // usage aussi simple qu'un classeur à une seule feuille annexe. C'est la
  // cause exacte de l'erreur rapportée sur Export Excel. La correction
  // consiste à ne JAMAIS appeler `delete()`/`rename()` : tout est donc
  // écrit dans LA feuille par défaut créée par `createExcel()`, jamais dans
  // une feuille annexe qu'il faudrait ensuite supprimer/renommer.
  Future<void> exportExcel(ProductionSummary summary, ProductionSummaryExportContext ctx) async {
    try {
      final excelFile = xl.Excel.createExcel();

      final sheetName = excelFile.getDefaultSheet() ?? 'Sheet1';
      final sheet = excelFile[sheetName];

      int row = 0;
      if (summary.promesh != null) {
        final dateRange = await _resolveExcelDateRange(ctx, isPromesh: true);
        row = _writeExcelSection(sheet, row, 'PROMESH', summary.promesh!, ctx, dateRange, isPromesh: true);
      }
      if (summary.probar != null) {
        if (row > 0) row++; // ligne vide de séparation entre les deux sections
        final dateRange = await _resolveExcelDateRange(ctx, isPromesh: false);
        row = _writeExcelSection(sheet, row, 'PROBAR', summary.probar!, ctx, dateRange, isPromesh: false);
      }
      if (summary.promesh == null && summary.probar == null) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 'Aucune donnée pour ces filtres';
      }

      final bytes = excelFile.encode();
      if (bytes == null) throw Exception('Échec de la génération du fichier Excel');
      _downloadBytes(bytes, 'production-summary-${DateTime.now().millisecondsSinceEpoch}.xlsx');
    } catch (e, stackTrace) {
      debugPrint('[ProductionSummary] Excel export error: $e');
      debugPrintStack(stackTrace: stackTrace);
      // Le message utilisateur (SnackBar) est géré par l'appelant — voir
      // production_summary_screen.dart#_runExport.
      rethrow;
    }
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

  // Écrit UNE section (PROMESH ou PROBAR) à partir de `startRow` dans la
  // feuille fournie et retourne la prochaine ligne libre — permet
  // d'empiler plusieurs sections dans une seule et même feuille (voir
  // commentaire de exportExcel ci-dessus sur pourquoi on ne crée jamais de
  // feuille annexe).
  int _writeExcelSection(
    xl.Sheet sheet,
    int startRow,
    String sectionLabel,
    ProductionSummaryTable table,
    ProductionSummaryExportContext ctx,
    ({String? start, String? end}) dateRange, {
    required bool isPromesh,
  }) {
    final lastCol = isPromesh ? 2 : 1;

    int row = startRow;
    row = _mergedTitle(sheet, row, lastCol, 'Production Summary — $sectionLabel', isPromesh ? '#2563EB' : '#F97316');
    if (dateRange.start != null) row = _kv(sheet, row, 'Start date', dateRange.start!);
    if (dateRange.end != null) row = _kv(sheet, row, 'End date', dateRange.end!);
    if (ctx.machineLabel != null) row = _kv(sheet, row, 'Machine', ctx.machineLabel!);
    if (ctx.diameterLabel != null) row = _kv(sheet, row, 'Diamètre', '${ctx.diameterLabel} mm');
    row++;

    // En-têtes — seule la colonne Quantity porte l'unité (m/m²) dans son
    // TITRE ; les cellules elles-mêmes contiennent des valeurs NUMÉRIQUES
    // pures (ni séparateur de milliers, ni unité, ni chaîne formatée —
    // demande explicite, voir _numericCell).
    final headers = isPromesh
        ? ['Diameter', 'Cell size', 'Quantity (${table.unit})']
        : ['Diameter', 'Quantity (${table.unit})'];
    for (int c = 0; c < headers.length; c++) {
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
        ..value = headers[c]
        ..cellStyle = xl.CellStyle(bold: true, backgroundColorHex: '#F8FAFC');
    }
    row++;

    // Lignes de production groupées par diamètre, sans sous-total
    // intermédiaire (retiré sur demande explicite) — seul le total de
    // section ("TOTAL PROMESH"/"TOTAL PROBAR" ci-dessous) reste affiché.
    for (final g in table.groups) {
      final diameterLabel = (g.diameter == null || g.diameter!.isEmpty) ? 'Non renseigné' : g.diameter!;
      if (isPromesh) {
        for (final r in g.rows) {
          final meshLabel = (r.meshSize == null || r.meshSize!.isEmpty) ? 'Non renseigné' : formatCellSize(r.meshSize!);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = diameterLabel;
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = meshLabel;
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = _numericCell(r.quantity);
          row++;
        }
      } else {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = diameterLabel;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = _numericCell(g.diameterTotal);
        row++;
      }
    }

    row++;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = isPromesh ? 'TOTAL PROMESH' : 'TOTAL PROBAR'
      ..cellStyle = xl.CellStyle(bold: true, fontSize: 13, backgroundColorHex: isPromesh ? '#2563EB' : '#F97316', fontColorHex: '#FFFFFF');
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: row))
      ..value = _numericCell(table.grandTotal)
      ..cellStyle = xl.CellStyle(bold: true, fontSize: 13, backgroundColorHex: isPromesh ? '#2563EB' : '#F97316', fontColorHex: '#FFFFFF');

    sheet.setColWidth(0, 26);
    sheet.setColWidth(1, 22);
    if (isPromesh) sheet.setColWidth(2, 20);

    return row + 1;
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
