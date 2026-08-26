// lib/forms/finance/view/widgets/finance_dashboard_chart.dart
//
// "Financial Overview" (§MODIFICATION — DASHBOARD FINANCE PROFESSIONNEL,
// §5) — évolution mensuelle des montants Purchase Orders/Invoices/Paid
// Invoices. Utilise `syncfusion_flutter_charts`, déjà une dépendance du
// projet (SfCartesianChart, même bibliothèque que
// lib/dashboard/finance/view/candlesticks_chart.dart) — aucune nouvelle
// dépendance ajoutée. Données 100% fournies par le backend
// (FinanceMonthlyPointModel, agrégées via GROUP BY, §16-17) — jamais
// recalculées ici.

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';
import '../../theme/finance_theme.dart';

class FinanceDashboardChart extends StatelessWidget {
  final List<FinanceMonthlyPointModel> points;
  final bool loading;

  const FinanceDashboardChart({super.key, required this.points, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final monthNames = [
      t.translate('Janvier'), t.translate('Février'), t.translate('Mars'), t.translate('Avril'),
      t.translate('Mai'), t.translate('Juin'), t.translate('Juillet'), t.translate('Août'),
      t.translate('Septembre'), t.translate('Octobre'), t.translate('Novembre'), t.translate('Décembre'),
    ];

    return Container(
      // Même padding que les autres cartes du Dashboard (§9 : uniformiser
      // le padding des cartes) — finance_dashboard_recent_lists.dart/
      // finance_dashboard_alerts.dart utilisent aussi 16.
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kCrmBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.translate('Financial Overview'), style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: kCrmText)),
        const SizedBox(height: 2),
        Text(t.translate('Monthly evolution of purchase orders, invoices and paid invoices.'),
            style: tInter(fontSize: 12, color: kCrmTextSub)),
        const SizedBox(height: 14),
        SizedBox(
          height: 300,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : points.isEmpty
                  ? Center(child: Text(t.translate('Aucune donnée pour ces filtres'), style: tInter(fontSize: 13, color: kCrmTextSub)))
                  : SfCartesianChart(
                      margin: EdgeInsets.zero,
                      plotAreaBorderWidth: 0,
                      legend: const Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      primaryXAxis: CategoryAxis(
                        majorGridLines: const MajorGridLines(width: 0),
                        labelStyle: tInter(fontSize: 11, color: kCrmTextSub),
                      ),
                      primaryYAxis: NumericAxis(
                        axisLine: const AxisLine(width: 0),
                        majorTickLines: const MajorTickLines(size: 0),
                        labelStyle: tInter(fontSize: 11, color: kCrmTextSub),
                      ),
                      series: <CartesianSeries<FinanceMonthlyPointModel, String>>[
                        LineSeries<FinanceMonthlyPointModel, String>(
                          name: t.translate('Purchase Orders'),
                          dataSource: points,
                          xValueMapper: (p, _) => p.monthLabel(monthNames),
                          yValueMapper: (p, _) => p.purchaseOrders,
                          color: kFinanceColor,
                          width: 2.5,
                          markerSettings: const MarkerSettings(isVisible: true),
                        ),
                        LineSeries<FinanceMonthlyPointModel, String>(
                          name: t.translate('Invoices'),
                          dataSource: points,
                          xValueMapper: (p, _) => p.monthLabel(monthNames),
                          yValueMapper: (p, _) => p.invoices,
                          color: kCrmPrimary,
                          width: 2.5,
                          markerSettings: const MarkerSettings(isVisible: true),
                        ),
                        LineSeries<FinanceMonthlyPointModel, String>(
                          name: t.translate('Paid Invoices'),
                          dataSource: points,
                          xValueMapper: (p, _) => p.monthLabel(monthNames),
                          yValueMapper: (p, _) => p.paidInvoices,
                          color: kCrmSuccess,
                          width: 2.5,
                          markerSettings: const MarkerSettings(isVisible: true),
                        ),
                      ],
                    ),
        ),
      ]),
    );
  }
}
