// lib/forms/finance/view/widgets/finance_dashboard_alerts.dart
//
// "Finance Alerts" (§MODIFICATION — DASHBOARD FINANCE PROFESSIONNEL, §10) —
// uniquement des informations réellement disponibles en base
// (FinanceDashboardAlertsModel, comptée côté backend, §16) : jamais un texte
// statique. Une alerte n'est affichée QUE si son compteur est > 0.

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';
import '../../theme/finance_theme.dart';

class FinanceDashboardAlerts extends StatelessWidget {
  final FinanceDashboardAlertsModel alerts;
  final bool loading;

  const FinanceDashboardAlerts({super.key, required this.alerts, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final items = <(IconData, Color, String)>[
      if (alerts.unpaidInvoices > 0)
        (Icons.hourglass_bottom_rounded, kCrmWarning, '${alerts.unpaidInvoices} ${t.translate('invoice(s) awaiting payment')}'),
      if (alerts.newPurchaseOrdersThisWeek > 0)
        (Icons.shopping_cart_outlined, kFinanceColor, '${alerts.newPurchaseOrdersThisWeek} ${t.translate('new purchase order(s) this week')}'),
      if (alerts.newShipmentsThisWeek > 0)
        (Icons.local_shipping_outlined, kFinanceColor, '${alerts.newShipmentsThisWeek} ${t.translate('new customer shipment(s) this week')}'),
      if (alerts.recentDocumentsCount > 0)
        (Icons.description_outlined, kCrmPrimary, '${alerts.recentDocumentsCount} ${t.translate('document(s) uploaded this week')}'),
    ];

    return Container(
      // Même hauteur MINIMALE que les cartes "Recent ..." voisines (§3) —
      // cohérence visuelle sans jamais forcer/compresser le contenu réel.
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kCrmBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.notifications_active_outlined, size: 16, color: kFinanceColor),
          const SizedBox(width: 8),
          Text(t.translate('Finance Alerts'), style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText)),
        ]),
        const SizedBox(height: 14),
        if (loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(t.translate('No alerts at the moment.'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
          )
        else
          // Espacement vertical généreux entre alertes (§7) — le texte
          // n'est jamais tronqué (pas de maxLines : il retombe à la ligne
          // si besoin plutôt que d'être coupé).
          Column(
            children: items
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: item.$2.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: Icon(item.$1, size: 15, color: item.$2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(item.$3, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText))),
                      ]),
                    ))
                .toList(),
          ),
      ]),
    );
  }
}
