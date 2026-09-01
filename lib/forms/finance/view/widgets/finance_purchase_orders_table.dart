// lib/forms/finance/view/widgets/finance_purchase_orders_table.dart
//
// Table des Bons de Commande — "Inflow of raw materials" (§MODIFIER FINANCE
// → INFLOW OF RAW MATERIALS), UNE LIGNE PAR PRODUIT (pas une ligne par bon) :
// PO #/Order #/Order date/Customer/Customer code/Customer address/Reference/
// Designation/Unit/Quantity/P.U. HT/Actions. Alimentée UNIQUEMENT par les
// données déjà extraites/enregistrées (aucun nouvel OCR ici) — voir
// RawMaterialRow, construite côté écran par aplatissement order × items.
//
// "Amount HT" (§SUPPRIMER HT DE L'INTERFACE) n'est PLUS affiché ici — la
// donnée reste en base et dans l'export CSV, seulement retirée de cette vue.
//
// "PO #" (§IDENTIFICATION DES DIFFÉRENTS PURCHASE ORDERS) identifie le BON
// DE COMMANDE, jamais le produit — toutes les lignes d'un même bon partagent
// la même valeur. Les lignes d'un même PO sont en plus regroupées
// visuellement par alternance de fond (§7 : "au minimum afficher PO # sur
// chaque ligne" — la valeur est garantie sur chaque ligne dans tous les cas,
// l'alternance de fond est un plus, pas une restructuration du tableau).
//
// §MODIFICATION — INFLOW RAW MATERIALS : "Order date" devient éditable
// directement depuis cette table (§2-§7 du ticket) — voir OrderDateCell,
// qui gère elle-même son état (Normal/Saving/Erreur), au clic ouvre un
// `showDatePicker`, appelle `onOrderDateSave` (PATCH réel, jamais un
// recalcul local) puis remonte le Purchase Order mis à jour via
// `onOrderDateSaved` — jamais de rechargement complet de la page (§6).
//
// §MODIFICATION — INFLOW RAW MATERIALS / SECTION EXPORT : `OrderDateCell`
// est PUBLIQUE (pas de préfixe `_`) — réutilisée telle quelle par la section
// "Export" (ex-"Documents requiring extraction", voir
// finance_inflow_raw_materials_screen.dart) pour les bons de commande dont
// l'OCR a échoué. Même widget, même mécanisme PATCH, même
// `FinancePurchaseOrderModel` que ce tableau — une seule source de données
// (§5 du ticket), jamais une deuxième implémentation de cellule éditable.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/application/common/safe_snack.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';
import '../../theme/finance_theme.dart';

// Une ligne produit rattachée à SON bon de commande — les actions
// (View/Delete) restent au niveau du bon (§9 : "Conserver la possibilité de
// supprimer un Purchase Order"), jamais au niveau de la ligne produit.
class RawMaterialRow {
  final FinancePurchaseOrderModel order;
  final FinancePurchaseOrderItemModel item;
  const RawMaterialRow({required this.order, required this.item});
}

class FinancePurchaseOrdersTable extends StatelessWidget {
  final List<RawMaterialRow> rows;
  final ValueChanged<FinancePurchaseOrderModel> onView;
  final ValueChanged<FinancePurchaseOrderModel>? onDelete;
  // §MODIFICATION — INFLOW RAW MATERIALS : "Order date" éditable — `null`
  // désactive l'édition (cellule en lecture seule, comportement inchangé) ;
  // fourni par l'écran appelant, qui seul connaît l'API/le rafraîchissement
  // de sa propre liste (§11 — une seule source de vérité, jamais dupliquée
  // ici).
  final Future<FinancePurchaseOrderModel> Function(String id, DateTime newDate)? onOrderDateSave;
  final ValueChanged<FinancePurchaseOrderModel>? onOrderDateSaved;

  const FinancePurchaseOrdersTable({
    super.key,
    required this.rows,
    required this.onView,
    this.onDelete,
    this.onOrderDateSave,
    this.onOrderDateSaved,
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

    // Index de groupe par PO (ordre de première apparition) — sert
    // uniquement à alterner le fond, jamais à réordonner `rows` (l'ordre
    // reste celui déjà trié/paginé par l'écran appelant).
    final groupIndex = <String, int>{};
    for (final r in rows) {
      groupIndex.putIfAbsent(r.order.id, () => groupIndex.length);
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
              DataColumn(label: Text(t.translate('PO #'))),
              DataColumn(label: Text(t.translate('Order #'))),
              DataColumn(label: Text(t.translate('Order date'))),
              DataColumn(label: Text(t.translate('Customer'))),
              DataColumn(label: Text(t.translate('Customer code'))),
              DataColumn(label: Text(t.translate('Customer address'))),
              DataColumn(label: Text(t.translate('Reference'))),
              DataColumn(label: Text(t.translate('Designation'))),
              DataColumn(label: Text(t.translate('Unit'))),
              DataColumn(label: Text(t.translate('Quantity')), numeric: true),
              DataColumn(label: Text(t.translate('P.U. HT')), numeric: true),
              DataColumn(label: Text(t.translate('Actions'))),
            ],
            rows: [
              for (final r in rows)
                DataRow(
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) return kCrmPrimary.withOpacity(0.04);
                    return groupIndex[r.order.id]!.isEven ? kCrmSurface : kCrmBg;
                  }),
                  onSelectChanged: (_) => onView(r.order),
                  cells: [
                    DataCell(Text(r.order.poNumber ?? '—', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kFinanceColor))),
                    DataCell(Text(r.order.orderNumber ?? '—', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText))),
                    DataCell(
                      onOrderDateSave == null
                          ? Text(_dateFmt(r.order.orderDate))
                          : OrderDateCell(
                              key: ValueKey('order-date-${r.order.id}'),
                              order: r.order,
                              onSave: onOrderDateSave!,
                              onSaved: onOrderDateSaved,
                            ),
                    ),
                    DataCell(Text(r.order.displayCustomerName)),
                    DataCell(Text(r.order.customerCode ?? '—')),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(r.order.customerAddress ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Text(r.item.reference ?? '—')),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(r.item.designation ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Text(r.item.unit ?? '—')),
                    DataCell(Text(r.item.quantity == null ? '—' : formatFinanceNumber(r.item.quantity!))),
                    DataCell(Text(r.item.unitPriceHT == null ? '—' : formatFinanceNumber(r.item.unitPriceHT!))),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      Tooltip(
                        message: t.translate('View'),
                        child: OutlinedButton.icon(
                          onPressed: () => onView(r.order),
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
                          onPressed: () => onDelete!(r.order),
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

  String _dateFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d);
  }
}

// §MODIFICATION — INFLOW RAW MATERIALS : cellule "Order date" éditable.
// États gérés localement (§7 du ticket) :
//   Normal          → date formatée "dd/MM/yyyy" + icône crayon
//   OCR absent      → "Date non définie" (reste cliquable/éditable)
//   Modification    → "Saving…" (indicateur inline, pas de rechargement)
//   Erreur          → revient à l'ancienne valeur (jamais mise à jour tant
//                     que le backend n'a pas confirmé) + SnackBar d'erreur
//   Succès          → `onSaved` remonte le Purchase Order à jour à l'écran
//                     parent, qui affiche la confirmation (§8 du ticket) —
//                     cette cellule elle-même n'a alors plus rien à faire,
//                     `widget.order` change à la prochaine reconstruction.
class OrderDateCell extends StatefulWidget {
  final FinancePurchaseOrderModel order;
  final Future<FinancePurchaseOrderModel> Function(String id, DateTime newDate) onSave;
  final ValueChanged<FinancePurchaseOrderModel>? onSaved;

  const OrderDateCell({super.key, required this.order, required this.onSave, this.onSaved});

  @override
  State<OrderDateCell> createState() => OrderDateCellState();
}

class OrderDateCellState extends State<OrderDateCell> {
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
    final current = widget.order.orderDate == null ? null : DateTime.tryParse(widget.order.orderDate!);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() => _saving = true);
    try {
      final updated = await widget.onSave(widget.order.id, picked);
      if (!mounted) return;
      widget.onSaved?.call(updated);
    } catch (e) {
      if (!mounted) return;
      // Échec → `widget.order` n'a jamais été modifié ici, l'ancienne valeur
      // reste donc affichée automatiquement (§6 du ticket — "restaurer
      // l'ancienne valeur si la sauvegarde échoue", rien à faire de plus).
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${t.translate('Failed to update order date')} : $e'), backgroundColor: kCrmDanger),
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

    final raw = widget.order.orderDate;
    final hasDate = raw != null && raw.isNotEmpty;
    final label = hasDate ? _dateFmt(raw) : t.translate('Date non définie');

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
