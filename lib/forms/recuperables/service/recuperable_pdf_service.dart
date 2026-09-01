// lib/forms/recuperables/service/recuperable_pdf_service.dart
//
// Export PDF client-side d'une fiche RÉCUPÉRABLES — même pattern que
// por_promesh_pdf_service.dart (thème Roboto Unicode, page A4, pied de
// page avec pagination), aucun document officiel de référence ici (rapport
// interne, pas de mise en page imposée).
//
// §MODIFICATION — CORRIGER LA PAGE "RECOVERABLES RECORD DETAIL" : le tableau
// des 12 diamètres (Ø6-Ø28) est supprimé de ce PDF — `Totaux` n'affiche plus
// que `waste`/`finishedProduct` (jamais additionnés, `?? 0` pour une fiche
// créée avant ce ticket). Uniquement ce document généré côté client est
// modifié — aucune donnée backend touchée.

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:dash_master_toolkit/forms/por_promesh/utils/por_promesh_pdf_theme.dart';

import '../model/recuperable_models.dart';

const _pdfGreen = PdfColor.fromInt(0xFF16A34A);
const _pdfBorder = PdfColor.fromInt(0xFFE2E8F0);
const _pdfText = PdfColor.fromInt(0xFF0F172A);
const _pdfTextSub = PdfColor.fromInt(0xFF64748B);

class RecuperablePdfService {
  static final RecuperablePdfService instance = RecuperablePdfService._();
  RecuperablePdfService._();

  Future<void> exportPdf(RecuperableFicheModel f) async {
    final doc = await _buildDocument(f);
    await Printing.sharePdf(bytes: await doc.save(), filename: 'recuperable-${f.id ?? DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  Future<void> printPdf(RecuperableFicheModel f) async {
    final doc = await _buildDocument(f);
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  Future<pw.Document> _buildDocument(RecuperableFicheModel f) async {
    final doc = pw.Document(theme: await robotoPdfTheme());
    final statutLabel = f.isOpen ? 'In progress' : 'Completed';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 32),
      footer: (ctx) => pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: _pdfTextSub), textAlign: pw.TextAlign.center),
      build: (ctx) => [
        pw.Text('RECOVERABLES RECORD', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _pdfGreen)),
        pw.SizedBox(height: 4),
        pw.Text('Référence : ${f.id ?? "-"}', style: const pw.TextStyle(fontSize: 9, color: _pdfTextSub)),
        pw.SizedBox(height: 16),

        _sectionTitle('General Information'),
        _infoGrid([
          ('Module', f.module),
          ('Date', f.date),
          ('Machine', 'Machine ${f.machine}'),
          ('Line', f.ligne),
          ('Shift', f.posteLabel),
          ('Operator', (f.operateur ?? '').trim().isEmpty ? '-' : f.operateur!),
          ('Creation Date', f.createdAt ?? '-'),
          ('Status', statutLabel),
        ]),
        pw.SizedBox(height: 16),

        // §MODIFICATION — CORRIGER LA PAGE "RECOVERABLES RECORD DETAIL" :
        // `waste`/`finishedProduct` uniquement — jamais additionnés, `?? 0`
        // pour une fiche créée avant ce ticket. Plus de tableau de diamètres.
        _sectionTitle('Totals'),
        _infoGrid([
          ('Waste', '${(f.waste ?? 0).toStringAsFixed(2)} kg'),
          ('Finished Product', '${(f.finishedProduct ?? 0).toStringAsFixed(2)} kg'),
        ]),

        pw.SizedBox(height: 16),
        pw.Text('Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: _pdfTextSub)),
      ],
    ));

    return doc;
  }

  pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _pdfText)),
      );

  pw.Widget _infoGrid(List<(String, String)> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: _pdfBorder, width: 0.5),
      columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3)},
      children: [
        for (final r in rows)
          pw.TableRow(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(r.$1, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _pdfTextSub)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(r.$2, style: const pw.TextStyle(fontSize: 10, color: _pdfText)),
            ),
          ]),
      ],
    );
  }

}
