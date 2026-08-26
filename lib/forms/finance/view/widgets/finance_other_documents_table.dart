// lib/forms/finance/view/widgets/finance_other_documents_table.dart
//
// Tableau DÉDIÉ à "Finance > Other" (§MODIFICATION — FINANCE > OTHER —
// SCAN SIMPLE DE DOCUMENTS, §8) — colonnes EXACTES du ticket : Document
// name (displayName)/File type/Size/Uploaded by/Upload date/Updated date/
// Actions (View/Edit name/Delete). Volontairement un widget SÉPARÉ de
// `FinanceDocumentsTable` (utilisé par Inflow of raw materials et les
// sections "Documents" des fiches Shipment/Invoice, colonnes différentes —
// pas de Status ni d'Updated date, pas d'action "Edit name") plutôt que de
// le modifier — §20 "Ne pas modifier... Inflow Raw Materials/Customer
// Shipments/Factured Shipments/Paid Invoices".

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';

class FinanceOtherDocumentsTable extends StatelessWidget {
  final List<FinanceDocumentModel> documents;
  final ValueChanged<FinanceDocumentModel> onView;
  final ValueChanged<FinanceDocumentModel> onRename;
  final ValueChanged<FinanceDocumentModel> onDelete;

  const FinanceOtherDocumentsTable({
    super.key,
    required this.documents,
    required this.onView,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (documents.isEmpty) {
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
              DataColumn(label: Text(t.translate('Size'))),
              DataColumn(label: Text(t.translate('Uploaded by'))),
              DataColumn(label: Text(t.translate('Upload date'))),
              DataColumn(label: Text(t.translate('Updated date'))),
              DataColumn(label: Text(t.translate('Actions'))),
            ],
            rows: [
              for (final doc in documents)
                DataRow(
                  color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.hovered) ? kCrmPrimary.withOpacity(0.04) : null),
                  onSelectChanged: (_) => onView(doc),
                  cells: [
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_iconFor(doc), size: 16, color: kCrmPrimary),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        // §7/§19 : nom D'AFFICHAGE, jamais originalName —
                        // c'est précisément ce que "Edit name" modifie.
                        child: Text(doc.displayName,
                            style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ])),
                    DataCell(Text(doc.extension.toUpperCase().isEmpty ? '—' : doc.extension.toUpperCase())),
                    DataCell(Text(formatFinanceFileSize(doc.fileSize))),
                    DataCell(Text(doc.uploader?.email ?? '—')),
                    DataCell(Text(_dateFmt(doc.createdAt))),
                    DataCell(Text(_dateFmt(doc.updatedAt))),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: t.translate('View'),
                        icon: const Icon(Icons.visibility_outlined, size: 18, color: kCrmPrimary),
                        onPressed: () => onView(doc),
                      ),
                      IconButton(
                        tooltip: t.translate('Edit name'),
                        icon: const Icon(Icons.edit_outlined, size: 18, color: kCrmPrimary),
                        onPressed: () => onRename(doc),
                      ),
                      IconButton(
                        tooltip: t.translate('Delete'),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kCrmDanger),
                        onPressed: () => onDelete(doc),
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

  String _dateFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d.toLocal());
  }
}
