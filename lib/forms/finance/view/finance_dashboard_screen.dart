// lib/forms/finance/view/finance_dashboard_screen.dart
//
// "Finance Dashboard" — KPI dynamiques (jamais de valeur statique) pour le
// module Finance PROBAR. Nom de classe "FinanceProbarDashboardScreen" (pas
// "FinanceDashboardScreen") pour éviter toute collision avec la classe déjà
// existante lib/dashboard/finance/view/finance_dashboard_screen.dart (un
// tableau de bord "Finance" générique hérité du template d'origine, sans
// rapport avec ce module).

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../model/finance_models.dart';
import '../service/finance_service.dart';
import 'widgets/finance_kpi_row.dart';

class FinanceProbarDashboardScreen extends StatefulWidget {
  const FinanceProbarDashboardScreen({super.key});

  @override
  State<FinanceProbarDashboardScreen> createState() => _FinanceProbarDashboardScreenState();
}

class _FinanceProbarDashboardScreenState extends State<FinanceProbarDashboardScreen> {
  bool _loading = true;
  String? _error;
  FinanceDashboardModel _dashboard = const FinanceDashboardModel();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await FinanceService.instance.fetchDashboard();
      if (!mounted) return;
      setState(() => _dashboard = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: kCrmPrimary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.account_balance_outlined, size: 22, color: kCrmPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.translate('Finance Dashboard'), style: tInter(fontSize: 21, fontWeight: FontWeight.w800, color: kCrmText)),
                    const SizedBox(height: 2),
                    Text(t.translate('Overview of raw materials, shipments and invoices.'),
                        style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  ]),
                ),
                IconButton(
                  tooltip: t.translate('Actualiser'),
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18, color: kCrmTextSub),
                  onPressed: _loading ? null : _load,
                ),
              ]),
              const SizedBox(height: 24),
              if (_error != null)
                _buildError(context, t)
              else
                FinanceKpiRow(dashboard: _dashboard, loading: _loading && _dashboard.shipments == 0),
            ]),
          ),
        ),
      ),
    );
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
          OutlinedButton(onPressed: _load, child: Text(t.translate('Réessayer'))),
        ]),
      ),
    );
  }
}
