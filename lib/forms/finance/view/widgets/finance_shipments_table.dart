// lib/forms/finance/view/widgets/finance_shipments_table.dart
//
// Table "Shipment of products to the customers" (§7) : Shipment # / Customer
// / Shipment date / Reference / Quantity / Amount / Status / Invoice /
// Actions. "Shipment #" = identifiant court dérivé de l'UUID (aucun champ
// dédié côté backend), "Reference" = FinanceShipmentModel.reference (le
// champ métier saisi par l'utilisateur).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';

class FinanceShipmentsTable extends StatelessWidget {
  final List<FinanceShipmentModel> shipments;
  final ValueChanged<FinanceShipmentModel> onView;
  final ValueChanged<FinanceShipmentModel>? onDelete;

  const FinanceShipmentsTable({super.key, required this.shipments, required this.onView, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (shipments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text(t.translate('Aucune donnée pour ces filtres'), style: tInter(fontSize: 13, color: kCrmTextSub))),
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
              DataColumn(label: Text(t.translate('Shipment #'))),
              DataColumn(label: Text(t.translate('Customer'))),
              DataColumn(label: Text(t.translate('Shipment date'))),
              DataColumn(label: Text(t.translate('Reference'))),
              DataColumn(label: Text(t.translate('Documents'))),
              DataColumn(label: Text(t.translate('Quantity')), numeric: true),
              DataColumn(label: Text(t.translate('Amount')), numeric: true),
              DataColumn(label: Text(t.translate('Invoice'))),
              DataColumn(label: Text(t.translate('Actions'))),
            ],
            rows: [
              for (final s in shipments)
                DataRow(
                  color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.hovered) ? kCrmPrimary.withOpacity(0.04) : null),
                  onSelectChanged: (_) => onView(s),
                  cells: [
                    DataCell(Text('#${s.id.length >= 8 ? s.id.substring(0, 8).toUpperCase() : s.id}',
                        style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText))),
                    DataCell(Text(_customerDisplay(s))),
                    DataCell(Text(_dateFmt(s.shipmentDate))),
                    DataCell(Text(s.reference)),
                    DataCell(_documentsCell(context, s)),
                    DataCell(Text(s.totalQuantity == null ? '—' : formatFinanceNumber(s.totalQuantity!))),
                    DataCell(Text(formatFinanceNumber(s.totalAmount))),
                    DataCell(_invoiceCell(context, s)),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      Tooltip(
                        message: t.translate('View'),
                        child: OutlinedButton.icon(
                          onPressed: () => onView(s),
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
                      if (onDelete != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: t.translate('Delete'),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kCrmDanger),
                          onPressed: () => onDelete!(s),
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

  String _customerDisplay(FinanceShipmentModel s) {
    if (s.customer != null) return s.customer!.displayName;
    if ((s.customerName ?? '').isNotEmpty) return s.customerName!;
    return '—';
  }

  Widget _documentsCell(BuildContext context, FinanceShipmentModel s) {
    final t = AppLocalizations.of(context);
    if (s.documents.isEmpty) return Text('—', style: tInter(fontSize: 12.5, color: kCrmTextSub));
    final first = s.documents.first;
    final extra = s.documents.length - 1;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_docIcon(first), size: 15, color: kCrmPrimary),
      const SizedBox(width: 6),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(first.originalName, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, color: kCrmText)),
      ),
      if (extra > 0) ...[
        const SizedBox(width: 4),
        Text('+$extra ${t.translate('more')}', style: tInter(fontSize: 11, color: kCrmTextSub)),
      ],
    ]);
  }

  IconData _docIcon(FinanceDocumentModel doc) {
    if (doc.isPdf) return Icons.picture_as_pdf_outlined;
    if (doc.isImage) return Icons.image_outlined;
    if (['xls', 'xlsx', 'csv'].contains(doc.extension)) return Icons.grid_on_outlined;
    if (['doc', 'docx'].contains(doc.extension)) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Widget _invoiceCell(BuildContext context, FinanceShipmentModel s) {
    final t = AppLocalizations.of(context);
    if (s.invoices.isEmpty) return Text('—', style: tInter(fontSize: 12.5, color: kCrmTextSub));
    if (s.invoices.length == 1) return Text(s.invoices.first.invoiceNumber);
    return Text('${s.invoices.length} ${t.translate('invoice(s)')}');
  }

  String _dateFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d);
  }
}
