// lib/forms/finance/view/widgets/finance_purchase_orders_table.dart
//
// Table des Bons de Commande — "Inflow of raw materials", colonnes Order #/
// Documents/Order date/Customer/Delivery address/Total HT/Actions.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';

class FinancePurchaseOrdersTable extends StatelessWidget {
  final List<FinancePurchaseOrderModel> orders;
  final ValueChanged<FinancePurchaseOrderModel> onView;
  final ValueChanged<FinancePurchaseOrderModel>? onDelete;

  const FinancePurchaseOrdersTable({super.key, required this.orders, required this.onView, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (orders.isEmpty) {
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
            columnSpacing: 20,
            columns: [
              DataColumn(label: Text(t.translate('Order #'))),
              DataColumn(label: Text(t.translate('Documents'))),
              DataColumn(label: Text(t.translate('Order date'))),
              DataColumn(label: Text(t.translate('Customer'))),
              DataColumn(label: Text(t.translate('Total HT')), numeric: true),
              DataColumn(label: Text(t.translate('Actions'))),
            ],
            rows: [
              for (final order in orders)
                DataRow(
                  color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.hovered) ? kCrmPrimary.withOpacity(0.04) : null),
                  onSelectChanged: (_) => onView(order),
                  cells: [
                    DataCell(Text(order.orderNumber ?? '—', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText))),
                    DataCell(_documentsCell(context, order)),
                    DataCell(Text(_dateFmt(order.orderDate))),
                    DataCell(Text(order.displayCustomerName)),
                    DataCell(Text(order.totalHT == null ? '—' : formatFinanceNumber(order.totalHT!))),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      Tooltip(
                        message: t.translate('View'),
                        child: OutlinedButton.icon(
                          onPressed: () => onView(order),
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
                          onPressed: () => onDelete!(order),
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

  Widget _documentsCell(BuildContext context, FinancePurchaseOrderModel order) {
    final t = AppLocalizations.of(context);
    if (order.documents.isEmpty) return Text('—', style: tInter(fontSize: 12.5, color: kCrmTextSub));
    final first = order.documents.first;
    final extra = order.documents.length - 1;
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

  String _dateFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d);
  }
}
