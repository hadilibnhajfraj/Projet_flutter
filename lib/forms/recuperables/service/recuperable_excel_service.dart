// lib/forms/recuperables/service/recuperable_excel_service.dart
//
// Export Excel (.xlsx) client-side d'une fiche RÉCUPÉRABLES — même pattern
// dart:html que por_promesh_excel_service.dart (web uniquement).
//
// §MODIFICATION — CORRIGER LA PAGE "RECOVERABLES RECORD DETAIL" : le tableau
// des 12 diamètres (Ø6-Ø28) est supprimé de cet export — ne contient plus
// que Module/Date/Machine/Line/Shift/Operator/Creation Date/Status/Waste
// (kg)/Finished Product (kg) (`waste`/`finishedProduct` jamais additionnés,
// `?? 0` pour une fiche créée avant ce ticket). Uniquement ce fichier généré
// côté client est modifié — aucune donnée backend touchée.

import 'dart:html' as html;

import 'package:excel/excel.dart' as xl;

import '../model/recuperable_models.dart';

class RecuperableExcelService {
  static final RecuperableExcelService instance = RecuperableExcelService._();
  RecuperableExcelService._();

  void export(RecuperableFicheModel f) {
    final excelFile = xl.Excel.createExcel();
    final sheet = excelFile['Récupérables'];
    excelFile.delete('Sheet1');

    int row = _title(sheet, 0, 'Fiche Récupérables Traités — ${f.module} · Machine ${f.machine}');
    row++;

    row = _sectionHeader(sheet, row, 'General Information');
    row = _kv(sheet, row, 'Module', f.module);
    row = _kv(sheet, row, 'Date', f.date);
    row = _kv(sheet, row, 'Machine', f.machine);
    row = _kv(sheet, row, 'Line', f.ligne);
    row = _kv(sheet, row, 'Shift', f.posteLabel);
    row = _kv(sheet, row, 'Operator', f.operateur);
    row = _kv(sheet, row, 'Creation Date', f.createdAt);
    row = _kv(sheet, row, 'Status', f.isOpen ? 'In progress' : 'Completed');
    row++;

    // §MODIFICATION — CORRIGER LA PAGE "RECOVERABLES RECORD DETAIL" :
    // `waste`/`finishedProduct` uniquement — jamais additionnés, `?? 0` pour
    // une fiche créée avant ce ticket. Plus de tableau de diamètres.
    row = _sectionHeader(sheet, row, 'Totals');
    row = _kv(sheet, row, 'Waste (kg)', (f.waste ?? 0).toStringAsFixed(2));
    row = _kv(sheet, row, 'Finished Product (kg)', (f.finishedProduct ?? 0).toStringAsFixed(2));

    sheet.setColWidth(0, 20);
    sheet.setColWidth(1, 24);

    final bytes = excelFile.encode();
    if (bytes == null) throw Exception('Échec de la génération du fichier Excel');
    _downloadBytes(bytes, 'recuperable-${f.id ?? DateTime.now().millisecondsSinceEpoch}.xlsx');
  }

  int _title(xl.Sheet sheet, int row, String text) {
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
    );
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = text
      ..cellStyle = xl.CellStyle(bold: true, fontSize: 14, backgroundColorHex: '#16A34A', fontColorHex: '#FFFFFF');
    return row + 1;
  }

  int _sectionHeader(xl.Sheet sheet, int row, String text) {
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
    );
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = text
      ..cellStyle = xl.CellStyle(bold: true, backgroundColorHex: '#E2E8F0', fontColorHex: '#0F172A');
    return row + 1;
  }

  int _kv(xl.Sheet sheet, int row, String label, String? value) {
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = label
      ..cellStyle = xl.CellStyle(bold: true, fontColorHex: '#64748B');
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = value ?? '-';
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
