// lib/forms/finance/service/finance_excel_utils.dart
//
// Utilitaires .xlsx partagés par les exports Excel du module Finance —
// extrait de la logique déjà validée dans
// finance_customer_shipments_screen.dart#_freezeHeaderAndAddAutoFilter
// (§MODIFICATION — CUSTOMER SHIPMENTS — EXPORT EXCEL) pour être réutilisée
// par le Finance Dashboard (§MODIFICATION — DASHBOARD FINANCE PROFESSIONNEL,
// §12) sans dupliquer la manipulation XML bas niveau. N'affecte PAS l'export
// déjà en place de Customer Shipments (fichier séparé, non modifié).

import 'dart:html' as html;

import 'package:archive/archive.dart';

// Patch post-génération : `excel` ^2.1.0 n'expose aucune API publique pour
// figer une ligne ou ajouter un AutoFilter, seulement pour LIRE/ÉCRIRE des
// cellules. Le .xlsx encodé est un vrai ZIP OOXML — on le rouvre avec
// `package:archive`, on localise la feuille via workbook.xml (nom → r:id)
// puis workbook.xml.rels (r:id → chemin réel, JAMAIS par ordre de fichier
// dans l'archive : le classeur contient aussi la feuille "Sheet1" par
// défaut, vide, créée par `Excel.createExcel()`), puis on insère
// <pane .../> dans le <sheetView> existant (fige la ligne d'en-tête) et
// <autoFilter ref="A1:{dernièreColonne}{dernièreLigne}"/> juste après
// </sheetData> (ordre requis par le schéma OOXML). Repli silencieux (fichier
// original renvoyé tel quel) si la feuille attendue est introuvable — un
// classeur sans ce polish reste un classeur valide.
List<int> freezeHeaderAndAddAutoFilter(List<int> xlsxBytes, {required String sheetName, required int rowCount, required int colCount}) {
  final archive = ZipDecoder().decodeBytes(xlsxBytes);

  final workbookFile = archive.files.firstWhere((f) => f.name == 'xl/workbook.xml', orElse: () => ArchiveFile('', 0, const []));
  if (workbookFile.name.isEmpty) return xlsxBytes;
  final workbookXml = String.fromCharCodes(workbookFile.content as List<int>);
  final sheetIdMatch = RegExp('<sheet [^>]*name="$sheetName"[^>]*r:id="([^"]+)"').firstMatch(workbookXml);
  if (sheetIdMatch == null) return xlsxBytes;

  final relsFile = archive.files.firstWhere((f) => f.name == 'xl/_rels/workbook.xml.rels', orElse: () => ArchiveFile('', 0, const []));
  if (relsFile.name.isEmpty) return xlsxBytes;
  final relsXml = String.fromCharCodes(relsFile.content as List<int>);
  final relMatch = RegExp('<Relationship Id="${sheetIdMatch.group(1)}"[^>]*Target="([^"]+)"').firstMatch(relsXml);
  if (relMatch == null) return xlsxBytes;

  final targetPath = 'xl/${relMatch.group(1)}';
  final sheetFileIndex = archive.files.indexWhere((f) => f.name == targetPath);
  if (sheetFileIndex == -1) return xlsxBytes;
  var sheetXml = String.fromCharCodes(archive.files[sheetFileIndex].content as List<int>);

  sheetXml = sheetXml.replaceFirstMapped(
    RegExp(r'<sheetView([^>]*)/>'),
    (m) => '<sheetView${m.group(1)}><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView>',
  );

  final range = 'A1:${excelColumnLetter(colCount - 1)}$rowCount';
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
// 0-based — générique au-delà de 26 colonnes.
String excelColumnLetter(int index) {
  var n = index;
  var letters = '';
  while (true) {
    letters = String.fromCharCode(65 + (n % 26)) + letters;
    n = n ~/ 26 - 1;
    if (n < 0) break;
  }
  return letters;
}

// Téléchargement navigateur via dart:html — même mécanisme que les autres
// exports Finance (Blob + AnchorElement + revokeObjectUrl).
void downloadBytes(List<int> bytes, String fileName, {required String mimeType}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

const String kXlsxMimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
