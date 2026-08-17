// lib/forms/finance/view/widgets/finance_kpi_row.dart
//
// Ligne de cartes KPI du Finance Dashboard — compose le KpiStatCard existant
// (industrial_theme.dart), aucun nouveau widget de carte. Grille équi-hauteur
// via IntrinsicHeight + Expanded (jamais de GridView/childAspectRatio, voir
// la même correction déjà appliquée dans production_summary_screen.dart —
// un ratio fixe peut devenir plus petit que le contenu réel et déborder).

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/por_promesh/view/widgets/shimmer_box.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';
import '../../theme/finance_theme.dart';

class FinanceKpiRow extends StatelessWidget {
  final FinanceDashboardModel dashboard;
  final bool loading;

  const FinanceKpiRow({super.key, required this.dashboard, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width;
    final columns = width < 700 ? 1 : (width < 1100 ? 2 : 4);

    final cards = <Widget>[
      KpiStatCard(
        icon: Icons.inventory_2_outlined,
        value: '${dashboard.rawMaterialDocuments}',
        label: t.translate('Raw material documents'),
        color: kFinanceColor,
      ),
      KpiStatCard(
        icon: Icons.local_shipping_outlined,
        value: '${dashboard.shipments}',
        label: t.translate('Shipments'),
        color: kFinanceColor,
      ),
      KpiStatCard(
        icon: Icons.receipt_long_outlined,
        value: '${dashboard.facturedShipments}',
        label: t.translate('Factured shipments'),
        color: kFinanceColor,
      ),
      KpiStatCard(
        icon: Icons.verified_outlined,
        value: '${dashboard.paidInvoices}',
        label: t.translate('Paid invoices'),
        color: kCrmSuccess,
      ),
      KpiStatCard(
        icon: Icons.request_quote_outlined,
        value: formatFinanceNumber(dashboard.totalInvoicedAmount),
        label: t.translate('Total invoiced amount'),
        color: kFinanceColor,
      ),
      KpiStatCard(
        icon: Icons.payments_outlined,
        value: formatFinanceNumber(dashboard.totalPaidAmount),
        label: t.translate('Total paid amount'),
        color: kCrmSuccess,
      ),
      KpiStatCard(
        icon: Icons.warning_amber_rounded,
        value: formatFinanceNumber(dashboard.outstandingAmount),
        label: t.translate('Outstanding amount'),
        color: dashboard.outstandingAmount > 0 ? kCrmWarning : kCrmSuccess,
      ),
    ];

    if (loading) {
      return KpiSkeletonGrid(count: cards.length, crossAxisCount: columns);
    }
    return _responsiveCardGrid(cards, columns);
  }
}

// Même helper que production_summary_screen.dart#_responsiveCardGrid —
// dupliqué ici volontairement (page indépendante, pas de dépendance croisée
// entre modules Production/Finance) plutôt que factorisé dans un fichier
// partagé qui n'existe pas encore.
Widget _responsiveCardGrid(List<Widget> cards, int columns, {double gap = 14}) {
  final rows = <Widget>[];
  for (int i = 0; i < cards.length; i += columns) {
    final rowItems = cards.skip(i).take(columns).toList();
    final rowChildren = <Widget>[];
    for (int j = 0; j < columns; j++) {
      if (j > 0) rowChildren.add(SizedBox(width: gap));
      rowChildren.add(Expanded(child: j < rowItems.length ? rowItems[j] : const SizedBox.shrink()));
    }
    rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: rowChildren)));
    if (i + columns < cards.length) rows.add(SizedBox(height: gap));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
}
