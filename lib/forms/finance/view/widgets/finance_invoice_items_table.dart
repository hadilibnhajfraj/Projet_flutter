// lib/forms/finance/view/widgets/finance_invoice_items_table.dart
//
// Tableau des lignes d'une facture extraites par OCR — Reference/
// Designation/Unit/Diameter/Mesh size/Qty/P.U HT/Amount HT. Toute valeur
// absente s'affiche "—" (jamais 0/"" inventé) : voir
// FinanceInvoiceItemModel, dont tous les champs sont nullable.

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';

class FinanceInvoiceItemsTable extends StatelessWidget {
  final List<FinanceInvoiceItemModel> items;

  const FinanceInvoiceItemsTable({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
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
            dataRowMinHeight: 44,
            dataRowMaxHeight: 52,
            columnSpacing: 20,
            columns: [
              DataColumn(label: Text(t.translate('Reference'))),
              DataColumn(label: Text(t.translate('Designation'))),
              DataColumn(label: Text(t.translate('Unit'))),
              DataColumn(label: Text(t.translate('Diameter'))),
              DataColumn(label: Text(t.translate('Mesh size'))),
              DataColumn(label: Text(t.translate('Quantity')), numeric: true),
              DataColumn(label: Text(t.translate('P.U HT')), numeric: true),
              DataColumn(label: Text(t.translate('Amount HT')), numeric: true),
            ],
            rows: [
              for (final it in items)
                DataRow(cells: [
                  DataCell(Text(it.reference ?? '—')),
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(it.designation ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
                  // §CORRECTION EXTRACTION — SÉPARATION UNITÉ / DIAMÈTRE.
                  DataCell(Text(it.displayUnit ?? '—')),
                  DataCell(Text(it.displayDiameter ?? '—')),
                  DataCell(Text(it.meshSize ?? '—')),
                  DataCell(Text(it.quantity == null ? '—' : formatFinanceNumber(it.quantity!))),
                  DataCell(Text(it.unitPriceHT == null ? '—' : formatFinanceNumber(it.unitPriceHT!))),
                  DataCell(Text(it.amountHT == null ? '—' : formatFinanceNumber(it.amountHT!))),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
