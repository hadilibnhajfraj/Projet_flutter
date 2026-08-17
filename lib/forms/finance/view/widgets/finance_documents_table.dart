// lib/forms/finance/view/widgets/finance_documents_table.dart
//
// Tableau réutilisable de documents Finance (name/type/size/date/uploader/
// status/actions) — utilisé par Inflow of raw materials, et par les
// sections "Documents" des détails Shipment/Invoice.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';

class FinanceDocumentsTable extends StatelessWidget {
  final List<FinanceDocumentModel> documents;
  final ValueChanged<FinanceDocumentModel> onView;
  final ValueChanged<FinanceDocumentModel>? onDelete;
  // Customer Shipments n'affiche plus aucun statut (§CORRECTION URGENTE) —
  // les autres écrans (Invoice, Inflow of raw materials) gardent la colonne.
  final bool showStatus;

  const FinanceDocumentsTable({
    super.key,
    required this.documents,
    required this.onView,
    this.onDelete,
    this.showStatus = true,
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
              DataColumn(label: Text(t.translate('File size'))),
              DataColumn(label: Text(t.translate('Upload date'))),
              DataColumn(label: Text(t.translate('Uploaded by'))),
              if (showStatus) DataColumn(label: Text(t.translate('Status'))),
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
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(doc.originalName,
                            style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ])),
                    DataCell(Text(doc.extension.toUpperCase().isEmpty ? '—' : doc.extension.toUpperCase())),
                    DataCell(Text(formatFinanceFileSize(doc.fileSize))),
                    DataCell(Text(_dateFmt(doc.createdAt))),
                    DataCell(Text(doc.uploader?.email ?? '—')),
                    if (showStatus) DataCell(_StatusBadge(status: doc.status)),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      OutlinedButton.icon(
                        onPressed: () => onView(doc),
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
                      if (onDelete != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: t.translate('Delete'),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kCrmDanger),
                          onPressed: () => onDelete!(doc),
                        ),
                      ],
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
    return DateFormat('dd/MM/yyyy HH:mm').format(d);
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final Color color;
    final String label;
    switch (status) {
      case 'VALIDATED':
        color = kCrmSuccess;
        label = t.translate('Validated');
      case 'REJECTED':
        color = kCrmDanger;
        label = t.translate('Rejected');
      default:
        color = kCrmWarning;
        label = t.translate('Pending');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: tInter(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
