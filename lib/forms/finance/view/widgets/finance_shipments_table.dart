// lib/forms/finance/view/widgets/finance_shipments_table.dart
//
// Table "Customer Shipments" (§MODIFICATION — CUSTOMER SHIPMENTS), UNE LIGNE
// PAR PRODUIT (pas une ligne par bon) : Shipment #/Delivery number/Delivery
// date/Customer code/Customer/Customer tax ID/Head office address/Delivery
// address/Reference/Designation/Unit/Diameter/Mesh size/Quantity/Actions.
// Alimentée UNIQUEMENT par les données déjà extraites/enregistrées (aucun
// nouvel OCR ici) — voir CustomerShipmentRow, construite côté écran par
// aplatissement shipment × items.
//
// "Shipment #" = identifiant métier généré par l'application
// (FinanceShipmentModel.shipmentNumber, format "SH-00001") — jamais confondu
// avec "Delivery number" (FinanceShipmentModel.reference, le numéro de BL
// LU sur le document, ou un repli SHIP-{année}-NNNNNN si l'OCR est peu
// fiable) ni avec "Customer code" (§2 : trois informations indépendantes).
// Les lignes d'un même Shipment sont regroupées visuellement par alternance
// de fond (§4).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/application/common/safe_snack.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';
import '../../theme/finance_theme.dart';

// Une ligne produit rattachée à SON Customer Shipment — les actions
// (View/Delete) restent au niveau du bon, jamais au niveau de la ligne
// produit.
class CustomerShipmentRow {
  final FinanceShipmentModel shipment;
  final FinanceShipmentItemModel item;
  const CustomerShipmentRow({required this.shipment, required this.item});
}

class FinanceShipmentsTable extends StatelessWidget {
  final List<CustomerShipmentRow> rows;
  final ValueChanged<FinanceShipmentModel> onView;
  final ValueChanged<FinanceShipmentModel>? onDelete;
  // §CORRECTION — WORKFLOW OCR CUSTOMER SHIPMENTS (2026-08-31) : "Delivery
  // date" éditable directement depuis CE tableau — même principe que
  // "Order date" dans FinancePurchaseOrdersTable (Inflow of raw materials,
  // la référence du ticket) : un Shipment NEEDS_REVIEW à cause d'un SEUL
  // champ secondaire manquant (la date) reste un Shipment RÉEL, visible ici
  // avec sa date corrigible sur place — jamais banni vers "Scan" pour ce
  // seul motif (voir FinanceShipmentModel.isExtractionFailed, qui ne
  // dépend plus que de `status == OCR_FAILED`). `null` désactive l'édition
  // (cellule en lecture seule, comportement inchangé).
  final Future<FinanceShipmentModel> Function(String id, DateTime newDate)? onDeliveryDateSave;
  final ValueChanged<FinanceShipmentModel>? onDeliveryDateSaved;

  const FinanceShipmentsTable({
    super.key,
    required this.rows,
    required this.onView,
    this.onDelete,
    this.onDeliveryDateSave,
    this.onDeliveryDateSaved,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text(t.translate('Aucune donnée pour ces filtres'), style: tInter(fontSize: 13, color: kCrmTextSub))),
      );
    }

    // Index de groupe par Shipment (ordre de première apparition) — sert
    // uniquement à alterner le fond (§4), jamais à réordonner `rows`.
    final groupIndex = <String, int>{};
    for (final r in rows) {
      groupIndex.putIfAbsent(r.shipment.id, () => groupIndex.length);
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
            columnSpacing: 18,
            columns: [
              DataColumn(label: Text(t.translate('Shipment #'))),
              DataColumn(label: Text(t.translate('Delivery number'))),
              DataColumn(label: Text(t.translate('Delivery date'))),
              DataColumn(label: Text(t.translate('Customer code'))),
              DataColumn(label: Text(t.translate('Customer'))),
              DataColumn(label: Text(t.translate('Customer tax ID'))),
              DataColumn(label: Text(t.translate('Head office address'))),
              DataColumn(label: Text(t.translate('Delivery address'))),
              DataColumn(label: Text(t.translate('Reference'))),
              DataColumn(label: Text(t.translate('Designation'))),
              DataColumn(label: Text(t.translate('Unit'))),
              DataColumn(label: Text(t.translate('Diameter'))),
              DataColumn(label: Text(t.translate('Mesh size'))),
              DataColumn(label: Text(t.translate('Quantity')), numeric: true),
              DataColumn(label: Text(t.translate('Actions'))),
            ],
            rows: [
              for (final r in rows)
                DataRow(
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) return kCrmPrimary.withOpacity(0.04);
                    return groupIndex[r.shipment.id]!.isEven ? kCrmSurface : kCrmBg;
                  }),
                  onSelectChanged: (_) => onView(r.shipment),
                  cells: [
                    DataCell(Text(r.shipment.shipmentNumber ?? '—', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kFinanceColor))),
                    DataCell(Text(r.shipment.reference, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText))),
                    DataCell(
                      onDeliveryDateSave == null
                          ? Text(_dateFmt(r.shipment.shipmentDate))
                          : DeliveryDateCell(
                              // §CORRECTION — CUSTOMER SHIPMENTS / DELIVERY
                              // DATE (2026-08-31) : la Key inclut désormais
                              // `shipmentDate` en plus de l'id — force un
                              // Element/State totalement neuf à chaque
                              // changement de date (au lieu d'une simple
                              // mise à jour de `widget` sur le même State),
                              // par sécurité supplémentaire au-delà du
                              // `setState` déjà correct côté écran parent.
                              key: ValueKey('shipment-delivery-date-${r.shipment.id}-${r.shipment.shipmentDate}'),
                              shipment: r.shipment,
                              onSave: onDeliveryDateSave!,
                              onSaved: onDeliveryDateSaved,
                            ),
                    ),
                    DataCell(Text(r.shipment.customerCode ?? '—')),
                    DataCell(Text(_customerDisplay(r.shipment))),
                    DataCell(Text(r.shipment.customerTaxId ?? '—')),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(r.shipment.customerHeadOfficeAddress ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(r.shipment.deliveryAddress ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Text(r.item.reference ?? '—')),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(r.item.designation ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
                    )),
                    // §CORRECTION EXTRACTION — SÉPARATION UNITÉ / DIAMÈTRE :
                    // jamais `r.item.unit`/`r.item.diameter` bruts — voir
                    // FinanceShipmentItemModel.displayUnit/displayDiameter.
                    DataCell(Text(r.item.displayUnit ?? '—')),
                    DataCell(Text(r.item.displayDiameter ?? '—')),
                    DataCell(Text(r.item.meshSize ?? '—')),
                    DataCell(Text(r.item.quantity == null ? '—' : formatFinanceNumber(r.item.quantity!))),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      Tooltip(
                        message: t.translate('View'),
                        child: OutlinedButton.icon(
                          onPressed: () => onView(r.shipment),
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
                          onPressed: () => onDelete!(r.shipment),
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

  String _dateFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d);
  }
}

// §CORRECTION — WORKFLOW OCR CUSTOMER SHIPMENTS (2026-08-31) : cellule
// "Delivery date" éditable — PUBLIQUE (pas de préfixe `_`), réutilisée à
// l'identique par ce tableau principal ET par la section "Scan"
// (finance_customer_shipments_screen.dart) — même widget, même mécanisme
// PUT (FinanceService.updateShipmentDeliveryDate), même
// FinanceShipmentModel, une seule source de données, jamais une deuxième
// implémentation. Même comportement que OrderDateCell
// (finance_purchase_orders_table.dart, Inflow of raw materials) : Normal
// (date + crayon) / "Date not defined" si absente / "Saving..." pendant
// l'appel / restauration de l'ancienne valeur + SnackBar en cas d'échec /
// `onSaved` remonte le Shipment à jour à l'écran parent.
class DeliveryDateCell extends StatefulWidget {
  final FinanceShipmentModel shipment;
  final Future<FinanceShipmentModel> Function(String id, DateTime newDate) onSave;
  final ValueChanged<FinanceShipmentModel>? onSaved;

  const DeliveryDateCell({super.key, required this.shipment, required this.onSave, this.onSaved});

  @override
  State<DeliveryDateCell> createState() => DeliveryDateCellState();
}

class DeliveryDateCellState extends State<DeliveryDateCell> {
  bool _saving = false;

  String _dateFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d);
  }

  Future<void> _pick() async {
    if (_saving) return;
    final t = AppLocalizations.of(context);
    final current = widget.shipment.shipmentDate == null ? null : DateTime.tryParse(widget.shipment.shipmentDate!);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() => _saving = true);
    try {
      final updated = await widget.onSave(widget.shipment.id, picked);
      if (!mounted) return;
      widget.onSaved?.call(updated);
    } catch (e) {
      if (!mounted) return;
      // Échec → `widget.shipment` n'a jamais été modifié ici, l'ancienne
      // valeur reste donc affichée automatiquement.
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${t.translate('Failed to update delivery date')} : $e'), backgroundColor: kCrmDanger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (_saving) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 6),
        Text(t.translate('Saving...'), style: tInter(fontSize: 12, color: kCrmTextSub)),
      ]);
    }

    final raw = widget.shipment.shipmentDate;
    final hasDate = raw != null && raw.isNotEmpty;
    final label = hasDate ? _dateFmt(raw) : t.translate('Date not defined');

    return InkWell(
      onTap: _pick,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: tInter(
                fontSize: 12.5,
                fontStyle: hasDate ? FontStyle.normal : FontStyle.italic,
                color: hasDate ? kCrmText : kCrmTextSub,
              )),
          const SizedBox(width: 4),
          Icon(Icons.edit_outlined, size: 13, color: kCrmTextSub.withOpacity(0.7)),
        ]),
      ),
    );
  }
}
