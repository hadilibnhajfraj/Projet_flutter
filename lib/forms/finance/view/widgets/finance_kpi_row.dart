// lib/forms/finance/view/widgets/finance_kpi_row.dart
//
// 4 cartes KPI du Finance Dashboard : Purchase Orders/Customer Shipments/
// Invoices/Paid Invoices — compose le KpiStatCard existant
// (industrial_theme.dart), aucun nouveau widget de carte. Grille équi-hauteur
// via IntrinsicHeight + Expanded (jamais de GridView/childAspectRatio, voir
// la même correction déjà appliquée dans production_summary_screen.dart — un
// ratio fixe peut devenir plus petit que le contenu réel et déborder).
// Responsive : 1/2/4 colonnes selon la largeur d'écran (mobile/tablette/
// desktop).
//
// §MODIFICATION — FINANCE DASHBOARD : les 4 cartes montant (Total
// Purchases/Total Invoiced/Total Paid/Outstanding) ont été retirées de cet
// affichage — UNIQUEMENT l'affichage : `FinanceDashboardModel` continue de
// recevoir ces champs depuis /finance/dashboard (aucune route/calcul
// backend modifié), ils restent simplement inutilisés par ce widget. La
// grille est construite dynamiquement à partir de `cards.length` (voir
// `_responsiveCardGrid` plus bas) — retirer des cartes ici réduit
// automatiquement le nombre de lignes et l'espace vertical occupé, sans
// laisser de ligne/espace vide à la place des anciennes cartes.

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
        icon: Icons.shopping_cart_outlined,
        value: '${dashboard.purchaseOrders}',
        label: t.translate('Purchase Orders'),
        color: kFinanceColor,
      ),
      KpiStatCard(
        icon: Icons.local_shipping_outlined,
        value: '${dashboard.customerShipments}',
        label: t.translate('Customer Shipments'),
        color: kFinanceColor,
      ),
      KpiStatCard(
        icon: Icons.receipt_long_outlined,
        value: '${dashboard.invoices}',
        label: t.translate('Invoices'),
        color: kFinanceColor,
      ),
      KpiStatCard(
        icon: Icons.verified_outlined,
        value: '${dashboard.paidInvoices}',
        label: t.translate('Paid Invoices'),
        color: kCrmSuccess,
      ),
    ];

    if (loading) {
      return KpiSkeletonGrid(count: cards.length);
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
