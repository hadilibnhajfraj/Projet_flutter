// lib/forms/finance/view/widgets/finance_dashboard_recent_lists.dart
//
// "Recent Purchase Orders"/"Recent Customer Shipments"/"Recent Invoices"/
// "Paid Invoices" (§MODIFICATION — DASHBOARD FINANCE PROFESSIONNEL, §6-9) —
// aperçus condensés (5 dernières lignes, déjà triées/limitées CÔTÉ SERVEUR
// via pageSize=5 sur les endpoints Finance existants, §16-17 — aucune
// donnée recalculée ici) avec bouton "View all" vers la page complète
// correspondante.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/route/my_route.dart';

import '../../model/finance_models.dart';
import '../../theme/finance_theme.dart';

String _dateFmt(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat('dd/MM/yyyy').format(d);
}

String _customerName(FinanceCustomerRef? customer, String? customerName) {
  if ((customerName ?? '').isNotEmpty) return customerName!;
  if (customer != null) return customer.displayName;
  return '—';
}

// Chrome commun (titre + "View all") + DataTable défilable horizontalement —
// jamais de restructuration par ligne/carte, juste un tableau condensé.
class _MiniTableShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final String viewAllPath;
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final bool loading;
  final bool isEmpty;

  const _MiniTableShell({
    required this.title,
    required this.icon,
    required this.viewAllPath,
    required this.columns,
    required this.rows,
    required this.loading,
    required this.isEmpty,
  });

  // Hauteur MINIMALE (jamais maximale/fixe, §3) pour un alignement visuel
  // cohérent entre cartes voisines — le contenu reste toujours libre de
  // dépasser ce minimum, jamais compressé en-dessous.
  static const double _kMinCardHeight = 260;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: _kMinCardHeight),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kCrmBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(icon, size: 16, color: kFinanceColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: TextButton(
              onPressed: () => context.go(viewAllPath),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(t.translate('View all'), style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kFinanceColor)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(t.translate('Aucune donnée pour ces filtres'), style: tInter(fontSize: 12.5, color: kCrmTextSub))),
          )
        else
          // Scroll horizontal interne (§2) — la carte garde sa largeur, seul
          // le tableau défile quand il y a plus de colonnes que d'espace ;
          // aucune troncature de contenu (§5), aucune dépendance à une
          // hauteur calculée à l'avance (§1 : plus d'IntrinsicHeight ici).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTableTheme(
              data: DataTableThemeData(
                headingTextStyle: tInter(fontSize: 11, fontWeight: FontWeight.w800, color: kCrmTextSub),
                dataTextStyle: tInter(fontSize: 12, color: kCrmText),
                dividerThickness: 1,
              ),
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 48,
                columnSpacing: 18,
                columns: columns,
                rows: rows,
              ),
            ),
          ),
      ]),
    );
  }
}

class FinanceDashboardRecentPurchaseOrders extends StatelessWidget {
  final List<FinancePurchaseOrderModel> orders;
  final bool loading;
  const FinanceDashboardRecentPurchaseOrders({super.key, required this.orders, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _MiniTableShell(
      title: t.translate('Recent Purchase Orders'),
      icon: Icons.shopping_cart_outlined,
      viewAllPath: MyRoute.financeInflowRawMaterialsScreen,
      loading: loading,
      isEmpty: orders.isEmpty,
      columns: [
        DataColumn(label: Text(t.translate('Order #'))),
        DataColumn(label: Text(t.translate('Order date'))),
        DataColumn(label: Text(t.translate('Customer'))),
        DataColumn(label: Text(t.translate('Customer code'))),
        DataColumn(label: Text(t.translate('Total')), numeric: true),
      ],
      rows: [
        for (final o in orders)
          DataRow(cells: [
            DataCell(Text(o.orderNumber ?? '—')),
            DataCell(Text(_dateFmt(o.orderDate))),
            DataCell(Text(_customerName(o.customer, o.customerName))),
            DataCell(Text(o.customerCode ?? '—')),
            DataCell(Text(o.totalHT == null ? '—' : formatFinanceNumber(o.totalHT!))),
          ]),
      ],
    );
  }
}

class FinanceDashboardRecentShipments extends StatelessWidget {
  final List<FinanceShipmentModel> shipments;
  final bool loading;
  const FinanceDashboardRecentShipments({super.key, required this.shipments, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _MiniTableShell(
      title: t.translate('Recent Customer Shipments'),
      icon: Icons.local_shipping_outlined,
      viewAllPath: MyRoute.financeCustomerShipmentsScreen,
      loading: loading,
      isEmpty: shipments.isEmpty,
      columns: [
        DataColumn(label: Text(t.translate('Shipment #'))),
        DataColumn(label: Text(t.translate('Delivery number'))),
        DataColumn(label: Text(t.translate('Delivery date'))),
        DataColumn(label: Text(t.translate('Customer'))),
        DataColumn(label: Text(t.translate('Customer code'))),
        DataColumn(label: Text(t.translate('Total quantity')), numeric: true),
      ],
      rows: [
        for (final s in shipments)
          DataRow(cells: [
            DataCell(Text(s.shipmentNumber ?? '—')),
            DataCell(Text(s.reference)),
            DataCell(Text(_dateFmt(s.shipmentDate))),
            DataCell(Text(_customerName(s.customer, s.customerName))),
            DataCell(Text(s.customerCode ?? '—')),
            DataCell(Text(s.totalQuantity == null ? '—' : formatFinanceNumber(s.totalQuantity!))),
          ]),
      ],
    );
  }
}

class FinanceDashboardRecentInvoices extends StatelessWidget {
  final List<FinanceInvoiceModel> invoices;
  final bool loading;
  const FinanceDashboardRecentInvoices({super.key, required this.invoices, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _MiniTableShell(
      title: t.translate('Recent Invoices'),
      icon: Icons.receipt_long_outlined,
      viewAllPath: MyRoute.financeFacturedShipmentsScreen,
      loading: loading,
      isEmpty: invoices.isEmpty,
      columns: [
        DataColumn(label: Text(t.translate('Invoice number'))),
        DataColumn(label: Text(t.translate('Invoice date'))),
        DataColumn(label: Text(t.translate('Customer'))),
        DataColumn(label: Text(t.translate('Subtotal HT')), numeric: true),
        DataColumn(label: Text(t.translate('Tax')), numeric: true),
        DataColumn(label: Text(t.translate('Total TTC')), numeric: true),
        DataColumn(label: Text(t.translate('Payment method'))),
      ],
      rows: [
        for (final i in invoices)
          DataRow(cells: [
            DataCell(Text(i.invoiceNumber)),
            DataCell(Text(_dateFmt(i.invoiceDate))),
            DataCell(Text(_customerName(i.customer, i.customerName))),
            DataCell(Text(formatFinanceNumber(i.amount))),
            DataCell(Text(formatFinanceNumber(i.tax))),
            DataCell(Text(formatFinanceNumber(i.total))),
            DataCell(Text(i.paymentMethod ?? '—')),
          ]),
      ],
    );
  }
}

class FinanceDashboardPaidInvoices extends StatelessWidget {
  final List<FinanceInvoiceModel> invoices;
  final bool loading;
  const FinanceDashboardPaidInvoices({super.key, required this.invoices, this.loading = false});

  FinancePaymentModel? _lastPayment(FinanceInvoiceModel inv) {
    if (inv.payments.isEmpty) return null;
    final sorted = [...inv.payments]..sort((a, b) => (a.paidDate ?? '').compareTo(b.paidDate ?? ''));
    return sorted.last;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _MiniTableShell(
      title: t.translate('Paid Invoices'),
      icon: Icons.verified_outlined,
      viewAllPath: MyRoute.financePaidInvoicesScreen,
      loading: loading,
      isEmpty: invoices.isEmpty,
      columns: [
        DataColumn(label: Text(t.translate('Invoice number'))),
        DataColumn(label: Text(t.translate('Customer'))),
        DataColumn(label: Text(t.translate('Invoice date'))),
        DataColumn(label: Text(t.translate('Payment method'))),
        DataColumn(label: Text(t.translate('Amount')), numeric: true),
        DataColumn(label: Text(t.translate('Payment date'))),
      ],
      rows: [
        for (final i in invoices)
          DataRow(cells: [
            DataCell(Text(i.invoiceNumber)),
            DataCell(Text(_customerName(i.customer, i.customerName))),
            DataCell(Text(_dateFmt(i.invoiceDate))),
            DataCell(Text(_lastPayment(i)?.method ?? i.paymentMethod ?? '—')),
            DataCell(Text(formatFinanceNumber(i.total))),
            DataCell(Text(_dateFmt(_lastPayment(i)?.paidDate))),
          ]),
      ],
    );
  }
}
