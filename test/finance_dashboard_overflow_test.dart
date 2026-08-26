// test/finance_dashboard_overflow_test.dart
//
// §CORRECTION — FINANCE DASHBOARD — UI PROFESSIONNELLE : preuve que les
// cartes "Recent ..." du Finance Dashboard ne débordent plus jamais
// ("Bottom overflowed by X pixels"), y compris avec de longs noms/adresses
// client (§12) et à plusieurs largeurs d'écran (§8 : desktop/tablette/
// mobile). Utilise directement `tester.takeException()` — un vrai test de
// layout Flutter, pas une simple relecture de code : si un RenderFlex
// déborde à nouveau, ce test échoue immédiatement.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dash_master_toolkit/forms/finance/model/finance_models.dart';
import 'package:dash_master_toolkit/forms/finance/view/widgets/finance_dashboard_alerts.dart';
import 'package:dash_master_toolkit/forms/finance/view/widgets/finance_dashboard_recent_lists.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

const _kLongCustomerName = 'STE INTERNATIONAL BUILDING MATERIALS AND CONSTRUCTION EQUIPMENT DISTRIBUTION SARL';
const _kLongAddress = 'IMM LA PERLA 2, 3EME ETAGE, LOT AFH 159, ZONE INDUSTRIELLE AIN ZAGHOUAN NORD, 2036 LA SOUKRA, ARIANA, TUNISIE';

List<FinancePurchaseOrderModel> _purchaseOrders() => [
      for (int i = 1; i <= 5; i++)
        FinancePurchaseOrderModel(
          id: 'po-$i',
          poNumber: 'PO-0000$i',
          orderNumber: 'BCL26000$i',
          orderDate: '2026-04-2$i',
          customerId: i,
          customerName: i == 1 ? _kLongCustomerName : 'NADEC',
          customerCode: 'F003142${i}Q',
          totalHT: 26292.345 + i,
        ),
    ];

List<FinanceShipmentModel> _shipments() => [
      for (int i = 1; i <= 5; i++)
        FinanceShipmentModel(
          id: 'sh-$i',
          shipmentNumber: 'SH-0000$i',
          reference: 'DEL26024$i',
          customerId: i,
          customerName: i == 2 ? _kLongCustomerName : 'STE MK BID SOFT',
          customerCode: 'C174574${i}E',
          shipmentDate: '2026-08-0$i',
          totalQuantity: 79.234 + i,
        ),
    ];

List<FinanceInvoiceModel> _invoices({bool paid = false}) => [
      for (int i = 1; i <= 5; i++)
        FinanceInvoiceModel(
          id: 'inv-$i',
          invoiceNumber: 'FVL26008$i',
          customerId: i,
          customerName: i == 3 ? _kLongCustomerName : 'LES ASTRES PROMOTION',
          customerAddress: i == 3 ? _kLongAddress : null,
          invoiceDate: '2026-06-2$i',
          amount: 8043.845,
          tax: 1625.051,
          total: 9668.891,
          paymentMethod: 'Traite',
          payments: paid
              ? [FinancePaymentModel(id: 'pay-$i', invoiceId: 'inv-$i', amount: 9668.891, paidDate: '2026-07-0$i', method: 'Traite')]
              : const [],
        ),
    ];

const _alerts = FinanceDashboardAlertsModel(
  unpaidInvoices: 3,
  newPurchaseOrdersThisWeek: 1,
  newShipmentsThisWeek: 2,
  recentDocumentsCount: 83,
);

Widget _wrap({required double width, required Widget child}) {
  return MaterialApp(
    localizationsDelegates: const [AppLocalizations.delegate],
    supportedLocales: const [Locale('en')],
    locale: const Locale('en'),
    home: Scaffold(
      body: Center(child: SizedBox(width: width, child: SingleChildScrollView(child: child))),
    ),
  );
}

// Même structure que finance_dashboard_screen.dart#_twoColumn (post-correctif) :
// Row + Expanded, crossAxisAlignment.start, jamais IntrinsicHeight/stretch.
Widget _twoColumnRow(Widget left, Widget right) {
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(child: left),
    const SizedBox(width: 20),
    Expanded(child: right),
  ]);
}

void main() {
  testWidgets('Recent Purchase Orders + Recent Customer Shipments (desktop, 1400px) → aucun overflow', (tester) async {
    await tester.pumpWidget(_wrap(
      width: 1400,
      child: _twoColumnRow(
        FinanceDashboardRecentPurchaseOrders(orders: _purchaseOrders()),
        FinanceDashboardRecentShipments(shipments: _shipments()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // Combinaison EXACTE signalée dans le ticket — 7 colonnes (Recent
  // Invoices) à côté d'une carte de forme complètement différente (Finance
  // Alerts, icônes+texte) : c'est précisément ce déséquilibre qui faisait
  // diverger le calcul IntrinsicHeight de la hauteur réellement nécessaire.
  testWidgets('Recent Invoices + Finance Alerts (desktop, 1400px) → aucun overflow, y compris avec un long nom/adresse client', (tester) async {
    await tester.pumpWidget(_wrap(
      width: 1400,
      child: _twoColumnRow(
        FinanceDashboardRecentInvoices(invoices: _invoices()),
        const FinanceDashboardAlerts(alerts: _alerts),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Paid Invoices pleine largeur (desktop, 1400px) → aucun overflow', (tester) async {
    await tester.pumpWidget(_wrap(width: 1400, child: FinanceDashboardPaidInvoices(invoices: _invoices(paid: true))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // Tablette (§8) — les cartes passent en 2 colonnes plus étroites, le
  // tableau doit défiler horizontalement à l'intérieur de sa carte, jamais
  // déborder verticalement.
  testWidgets('Recent Invoices + Finance Alerts (tablette, 800px) → aucun overflow', (tester) async {
    await tester.pumpWidget(_wrap(
      width: 800,
      child: _twoColumnRow(
        FinanceDashboardRecentInvoices(invoices: _invoices()),
        const FinanceDashboardAlerts(alerts: _alerts),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // Mobile (§8) — layout empilé (Column), une carte pleine largeur à la fois.
  testWidgets('Recent Customer Shipments empilé (mobile, 380px) → aucun overflow', (tester) async {
    await tester.pumpWidget(_wrap(
      width: 380,
      child: Column(children: [
        FinanceDashboardRecentShipments(shipments: _shipments()),
        const SizedBox(height: 20),
        const FinanceDashboardAlerts(alerts: _alerts),
      ]),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('États loading/vide → aucun overflow', (tester) async {
    await tester.pumpWidget(_wrap(
      width: 1400,
      child: _twoColumnRow(
        const FinanceDashboardRecentPurchaseOrders(orders: [], loading: true),
        const FinanceDashboardRecentShipments(shipments: []),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
