// lib/forms/finance/view/finance_dashboard_screen.dart
//
// "Finance Dashboard" (§MODIFICATION — DASHBOARD FINANCE PROFESSIONNEL POUR
// UN UTILISATEUR SPÉCIFIQUE) — KPI dynamiques, évolution mensuelle,
// activité récente (Purchase Orders/Shipments/Invoices/Paid Invoices),
// alertes, filtres et export Excel, tous alimentés par les APIs Finance
// existantes/étendues (jamais de valeur statique, §16). L'accès est déjà
// contrôlé côté BACKEND (rôle finance_probar → requireRole + moduleAccessGuard,
// voir finance.routes.js) — ce fichier ne fait qu'AFFICHER ce que l'API
// autorise, il n'invente aucune logique d'autorisation frontend (§1).
//
// Nom de classe "FinanceProbarDashboardScreen" (pas "FinanceDashboardScreen")
// pour éviter toute collision avec la classe déjà existante
// lib/dashboard/finance/view/finance_dashboard_screen.dart (un tableau de
// bord "Finance" générique hérité du template d'origine, sans rapport avec
// ce module).

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

import '../model/finance_models.dart';
import '../service/finance_excel_utils.dart' as xlutil;
import '../service/finance_service.dart';
import '../theme/finance_theme.dart';
import 'widgets/finance_dashboard_alerts.dart';
import 'widgets/finance_dashboard_chart.dart';
import 'widgets/finance_dashboard_filters.dart';
import 'widgets/finance_dashboard_recent_lists.dart';
import 'widgets/finance_kpi_row.dart';

const String _kDennisEmail = 'dennisredfeather@gmail.com';

// Espacement uniforme entre sections du Dashboard (§CORRECTION — FINANCE
// DASHBOARD — UI PROFESSIONNELLE, §9) — une seule valeur partagée par tous
// les gaps de niveau section, au lieu de valeurs ad hoc (18/20/22/16...).
const double _kSectionGap = 20;

class FinanceProbarDashboardScreen extends StatefulWidget {
  const FinanceProbarDashboardScreen({super.key});

  @override
  State<FinanceProbarDashboardScreen> createState() => _FinanceProbarDashboardScreenState();
}

class _FinanceProbarDashboardScreenState extends State<FinanceProbarDashboardScreen> {
  bool _loadingKpis = true;
  bool _loadingRecent = true;
  bool _exportingExcel = false;
  String? _error;

  FinanceDashboardModel _dashboard = const FinanceDashboardModel();
  List<FinanceMonthlyPointModel> _monthly = const [];
  List<FinancePurchaseOrderModel> _recentPurchaseOrders = const [];
  List<FinanceShipmentModel> _recentShipments = const [];
  List<FinanceInvoiceModel> _recentInvoices = const [];
  List<FinanceInvoiceModel> _recentPaidInvoices = const [];

  // Filtres (§11) — appliqués aux KPI/graphique ; les listes "Recent" restent
  // l'activité la plus récente toutes données confondues (rechargées une
  // seule fois, §17 : éviter les requêtes inutiles à chaque changement de
  // filtre).
  FinanceDateRangePreset _preset = FinanceDateRangePreset.all;
  DateTime? _customStart;
  DateTime? _customEnd;
  String _customer = '';
  String? _paymentMethod;
  String? _documentType;

  @override
  void initState() {
    super.initState();
    _loadKpisAndChart();
    _loadRecentLists();
  }

  (String?, String?) _resolveDateRange() {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    switch (_preset) {
      case FinanceDateRangePreset.all:
        return (null, null);
      case FinanceDateRangePreset.today:
        return (fmt.format(now), fmt.format(now));
      case FinanceDateRangePreset.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return (fmt.format(start), fmt.format(now));
      case FinanceDateRangePreset.thisMonth:
        return (fmt.format(DateTime(now.year, now.month, 1)), fmt.format(now));
      case FinanceDateRangePreset.thisYear:
        return (fmt.format(DateTime(now.year, 1, 1)), fmt.format(now));
      case FinanceDateRangePreset.custom:
        return (_customStart == null ? null : fmt.format(_customStart!), _customEnd == null ? null : fmt.format(_customEnd!));
    }
  }

  Future<void> _loadKpisAndChart() async {
    setState(() {
      _loadingKpis = true;
      _error = null;
    });
    try {
      final (startDate, endDate) = _resolveDateRange();
      final results = await Future.wait([
        FinanceService.instance.fetchDashboard(
          startDate: startDate,
          endDate: endDate,
          customer: _customer.trim().isEmpty ? null : _customer.trim(),
          paymentMethod: _paymentMethod,
        ),
        FinanceService.instance.fetchDashboardMonthly(
          startDate: startDate,
          endDate: endDate,
          customer: _customer.trim().isEmpty ? null : _customer.trim(),
          paymentMethod: _paymentMethod,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = results[0] as FinanceDashboardModel;
        _monthly = results[1] as List<FinanceMonthlyPointModel>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingKpis = false);
    }
  }

  Future<void> _loadRecentLists() async {
    setState(() => _loadingRecent = true);
    try {
      final results = await Future.wait([
        FinanceService.instance.fetchRawMaterials(pageSize: 5),
        FinanceService.instance.fetchShipments(pageSize: 5),
        FinanceService.instance.fetchInvoices(pageSize: 5),
        FinanceService.instance.fetchPaidInvoices(pageSize: 5),
      ]);
      if (!mounted) return;
      setState(() {
        _recentPurchaseOrders = (results[0] as FinancePagedResult<FinancePurchaseOrderModel>).items;
        _recentShipments = (results[1] as FinancePagedResult<FinanceShipmentModel>).items;
        _recentInvoices = (results[2] as FinancePagedResult<FinanceInvoiceModel>).items;
        _recentPaidInvoices = (results[3] as FinancePagedResult<FinanceInvoiceModel>).items;
      });
    } catch (_) {
      // Best-effort — un échec des aperçus "Recent" ne doit pas empêcher
      // l'affichage des KPI/graphique déjà chargés avec succès.
    } finally {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadKpisAndChart(), _loadRecentLists()]);
  }

  void _resetFilters() {
    setState(() {
      _preset = FinanceDateRangePreset.all;
      _customStart = null;
      _customEnd = null;
      _customer = '';
      _paymentMethod = null;
      _documentType = null;
    });
    _loadKpisAndChart();
  }

  // ── Export Excel (§12) — PAS de CSV. Respecte les filtres actifs pour les
  // feuilles KPI/Monthly Trend (§16-17 : données déjà chargées, aucune
  // ré-extraction) ; les feuilles "Recent" restent l'aperçu des 5 derniers
  // enregistrements toutes données confondues, explicitement libellées ainsi.
  Future<void> _exportExcel() async {
    setState(() => _exportingExcel = true);
    try {
      final excelFile = xl.Excel.createExcel();
      const sheetName = 'KPIs';
      final kpiSheet = excelFile[sheetName];
      excelFile.setDefaultSheet(sheetName);

      void header(xl.Sheet sheet, List<String> cells, int row) {
        for (int c = 0; c < cells.length; c++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
            ..value = cells[c]
            ..cellStyle = xl.CellStyle(bold: true, backgroundColorHex: '#EEF2FF', fontColorHex: '#1E293B');
        }
      }

      void writeRow(xl.Sheet sheet, List<dynamic> values, int row) {
        for (int c = 0; c < values.length; c++) {
          final v = values[c];
          if (v == null) continue;
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row)).value = v is double ? v : v.toString();
        }
      }

      // ── Feuille KPIs ────────────────────────────────────────────────────
      header(kpiSheet, const ['Metric', 'Value'], 0);
      final kpiRows = <(String, dynamic)>[
        ('Purchase Orders', _dashboard.purchaseOrders),
        ('Customer Shipments', _dashboard.customerShipments),
        ('Invoices', _dashboard.invoices),
        ('Paid Invoices', _dashboard.paidInvoices),
        ('Total Purchases', _dashboard.totalPurchases),
        ('Total Invoiced', _dashboard.totalInvoiced),
        ('Total Paid', _dashboard.totalPaid),
        ('Outstanding', _dashboard.outstanding),
      ];
      for (int i = 0; i < kpiRows.length; i++) {
        writeRow(kpiSheet, [kpiRows[i].$1, kpiRows[i].$2], i + 1);
      }
      kpiSheet.setColWidth(0, 22);
      kpiSheet.setColWidth(1, 18);

      // ── Feuille Monthly Trend ───────────────────────────────────────────
      final monthlySheet = excelFile['Monthly Trend'];
      header(monthlySheet, const ['Month', 'Purchase Orders', 'Invoices', 'Paid Invoices'], 0);
      for (int i = 0; i < _monthly.length; i++) {
        final m = _monthly[i];
        writeRow(monthlySheet, [m.month, m.purchaseOrders, m.invoices, m.paidInvoices], i + 1);
      }
      for (int c = 0; c < 4; c++) {
        monthlySheet.setColWidth(c, 16);
      }

      // ── Feuilles "Recent" (5 derniers, toutes données confondues) ───────
      final poSheet = excelFile['Recent Purchase Orders'];
      header(poSheet, const ['Order #', 'Order date', 'Customer', 'Customer code', 'Total'], 0);
      for (int i = 0; i < _recentPurchaseOrders.length; i++) {
        final o = _recentPurchaseOrders[i];
        writeRow(poSheet, [o.orderNumber ?? '', o.orderDate ?? '', o.displayCustomerName, o.customerCode ?? '', o.totalHT], i + 1);
      }

      final shSheet = excelFile['Recent Shipments'];
      header(shSheet, const ['Shipment #', 'Delivery number', 'Delivery date', 'Customer', 'Customer code', 'Total quantity'], 0);
      for (int i = 0; i < _recentShipments.length; i++) {
        final s = _recentShipments[i];
        writeRow(
          shSheet,
          [s.shipmentNumber ?? '', s.reference, s.shipmentDate ?? '', s.customer?.displayName ?? s.customerName ?? '', s.customerCode ?? '', s.totalQuantity],
          i + 1,
        );
      }

      final invSheet = excelFile['Recent Invoices'];
      header(invSheet, const ['Invoice number', 'Invoice date', 'Customer', 'Subtotal HT', 'Tax', 'Total TTC', 'Payment method'], 0);
      for (int i = 0; i < _recentInvoices.length; i++) {
        final inv = _recentInvoices[i];
        writeRow(
          invSheet,
          [inv.invoiceNumber, inv.invoiceDate ?? '', inv.customer?.displayName ?? inv.customerName ?? '', inv.amount, inv.tax, inv.total, inv.paymentMethod ?? ''],
          i + 1,
        );
      }

      final paidSheet = excelFile['Paid Invoices'];
      header(paidSheet, const ['Invoice number', 'Customer', 'Invoice date', 'Payment method', 'Amount', 'Payment date'], 0);
      for (int i = 0; i < _recentPaidInvoices.length; i++) {
        final inv = _recentPaidInvoices[i];
        final lastPayment = inv.payments.isEmpty ? null : (List.of(inv.payments)..sort((a, b) => (a.paidDate ?? '').compareTo(b.paidDate ?? ''))).last;
        writeRow(
          paidSheet,
          [inv.invoiceNumber, inv.customer?.displayName ?? inv.customerName ?? '', inv.invoiceDate ?? '', lastPayment?.method ?? inv.paymentMethod ?? '', inv.total, lastPayment?.paidDate ?? ''],
          i + 1,
        );
      }

      var bytes = excelFile.encode();
      if (bytes == null) throw Exception('Échec de la génération du fichier Excel');
      bytes = xlutil.freezeHeaderAndAddAutoFilter(bytes, sheetName: sheetName, rowCount: kpiRows.length + 1, colCount: 2);

      final fileName = 'finance-dashboard-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
      xlutil.downloadBytes(bytes, fileName, mimeType: xlutil.kXlsxMimeType);

      if (!mounted) return;
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.translate('Export terminé')} · $fileName'), backgroundColor: kCrmSuccess),
      );
    } catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 900;
    final isDennis = (AuthService().userEmail ?? '').trim().toLowerCase() == _kDennisEmail;

    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── En-tête ──────────────────────────────────────────────────
              Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: kCrmPrimary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.account_balance_outlined, size: 22, color: kCrmPrimary),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.translate('Finance Dashboard'), style: tInter(fontSize: 21, fontWeight: FontWeight.w800, color: kCrmText)),
                    const SizedBox(height: 2),
                    Text(
                      '${isDennis ? t.translate('Welcome back, Dennis') : t.translate('Finance Overview')} · ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                      style: tInter(fontSize: 12.5, color: kCrmTextSub),
                    ),
                  ]),
                ]),
              ]),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: t.translate('Actualiser'),
                    icon: (_loadingKpis || _loadingRecent)
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded, size: 18, color: kCrmTextSub),
                    onPressed: (_loadingKpis || _loadingRecent) ? null : _refreshAll,
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: _exportingExcel ? null : _exportExcel,
                    icon: _exportingExcel
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.file_download_outlined, size: 18),
                    label: Text(t.translate('Export Excel')),
                    style: ElevatedButton.styleFrom(backgroundColor: kFinanceColor, foregroundColor: Colors.white),
                  ),
                ]),
              ),
              const SizedBox(height: _kSectionGap),
              // ── Filtres (§11) ────────────────────────────────────────────
              FinanceDashboardFilters(
                preset: _preset,
                customStart: _customStart,
                customEnd: _customEnd,
                customer: _customer,
                paymentMethod: _paymentMethod,
                documentType: _documentType,
                onPresetChanged: (p) {
                  setState(() => _preset = p);
                  _loadKpisAndChart();
                },
                onCustomStartChanged: (d) {
                  setState(() => _customStart = d);
                  _loadKpisAndChart();
                },
                onCustomEndChanged: (d) {
                  setState(() => _customEnd = d);
                  _loadKpisAndChart();
                },
                onCustomerChanged: (v) {
                  _customer = v;
                  _loadKpisAndChart();
                },
                onPaymentMethodChanged: (v) {
                  setState(() => _paymentMethod = v);
                  _loadKpisAndChart();
                },
                // "Document type" n'a pas de sens pour les KPI de comptage
                // (Purchase Orders/Invoices ne sont pas "typés" par format de
                // fichier) — conservé côté UI pour une utilisation future
                // (ex. filtrer l'alerte "documents uploadés"), sans forcer un
                // refetch KPI/graphique inapplicable.
                onDocumentTypeChanged: (v) {
                  setState(() => _documentType = v);
                },
                onReset: _resetFilters,
              ),
              const SizedBox(height: _kSectionGap),
              if (_error != null)
                _buildError(context, t)
              else ...[
                // ── KPI Cards (§4) ──────────────────────────────────────────
                FinanceKpiRow(dashboard: _dashboard, loading: _loadingKpis && _dashboard.invoices == 0),
                const SizedBox(height: _kSectionGap),
                // ── Financial Overview (§5) ─────────────────────────────────
                FinanceDashboardChart(points: _monthly, loading: _loadingKpis && _monthly.isEmpty),
                const SizedBox(height: _kSectionGap),
                // ── Recent Purchase Orders / Recent Customer Shipments (§6-7) ─
                _twoColumn(
                  wide,
                  FinanceDashboardRecentPurchaseOrders(orders: _recentPurchaseOrders, loading: _loadingRecent),
                  FinanceDashboardRecentShipments(shipments: _recentShipments, loading: _loadingRecent),
                ),
                const SizedBox(height: _kSectionGap),
                // ── Recent Invoices / Finance Alerts (§8, §10) ────────────────
                _twoColumn(
                  wide,
                  FinanceDashboardRecentInvoices(invoices: _recentInvoices, loading: _loadingRecent),
                  FinanceDashboardAlerts(alerts: _dashboard.alerts, loading: _loadingKpis),
                ),
                const SizedBox(height: _kSectionGap),
                // ── Paid Invoices (§9) ─────────────────────────────────────
                FinanceDashboardPaidInvoices(invoices: _recentPaidInvoices, loading: _loadingRecent),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  // Responsive (§14) : 2 colonnes côte à côte en desktop/laptop, empilées en
  // tablette/mobile — jamais un débordement horizontal.
  //
  // §CORRECTION — FINANCE DASHBOARD — UI PROFESSIONNELLE §1/§3 : ceci
  // utilisait IntrinsicHeight + CrossAxisAlignment.stretch pour forcer les
  // deux cartes à EXACTEMENT la même hauteur. C'était la cause réelle des
  // "Bottom overflowed by 4.0/8.0 pixels" — IntrinsicHeight calcule la
  // hauteur "intrinsèque" d'une carte contenant un DataTable via une passe
  // de layout à blanc, puis force cette même hauteur en deuxième passe ;
  // pour un DataTable (dividers/Material internes), la hauteur réellement
  // nécessaire diverge de quelques pixels de cette estimation — d'où
  // l'overflow, systématiquement du côté de la carte la plus dense en
  // colonnes (Recent Customer Shipments/Recent Invoices, exactement les
  // deux signalées). Un `crossAxisAlignment: start` normal laisse chaque
  // carte se dimensionner à SON propre contenu (jamais de hauteur forcée
  // plus petite que le contenu réel) — plus de calcul de hauteur "à
  // l'aveugle", donc plus de décalage possible. `_MiniTableShell`/
  // `FinanceDashboardAlerts` gardent une hauteur MINIMALE (jamais maximale)
  // pour un alignement visuellement cohérent (§3) sans jamais risquer un
  // débordement si le contenu réel dépasse ce minimum.
  Widget _twoColumn(bool wide, Widget left, Widget right) {
    if (!wide) {
      return Column(children: [left, const SizedBox(height: _kSectionGap), right]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: left),
      const SizedBox(width: _kSectionGap),
      Expanded(child: right),
    ]);
  }

  Widget _buildError(BuildContext context, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: kCrmDanger, size: 36),
          const SizedBox(height: 8),
          Text('${t.translate('Erreur de chargement :')} $_error', textAlign: TextAlign.center, style: tInter(fontSize: 13, color: kCrmTextSub)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _refreshAll, child: Text(t.translate('Réessayer'))),
        ]),
      ),
    );
  }
}
