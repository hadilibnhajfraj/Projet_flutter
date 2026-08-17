// lib/forms/finance/view/finance_paid_invoices_screen.dart
//
// "Paid factures" (§9) — uniquement les factures payées (status=PAID
// toujours imposé côté serveur, jamais par le client).

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../model/finance_models.dart';
import '../service/finance_service.dart';
import 'widgets/finance_invoice_detail_dialog.dart';
import 'widgets/finance_invoices_table.dart';

class FinancePaidInvoicesScreen extends StatefulWidget {
  const FinancePaidInvoicesScreen({super.key});

  @override
  State<FinancePaidInvoicesScreen> createState() => _FinancePaidInvoicesScreenState();
}

class _FinancePaidInvoicesScreenState extends State<FinancePaidInvoicesScreen> {
  bool _loading = true;
  String? _error;
  String _search = '';
  List<FinanceInvoiceModel> _invoices = const [];
  int _count = 0;

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
      final page = await FinanceService.instance.fetchPaidInvoices(search: _search, pageSize: 200);
      if (!mounted) return;
      setState(() {
        _invoices = page.items;
        _count = page.count;
      });
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
                  decoration: BoxDecoration(color: kCrmSuccess.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.verified_outlined, size: 22, color: kCrmSuccess),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.translate('Paid factures'), style: tInter(fontSize: 20, fontWeight: FontWeight.w800, color: kCrmText)),
                    const SizedBox(height: 2),
                    Text(t.translate('Invoices that have been fully paid.'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  ]),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    onChanged: (v) {
                      _search = v;
                      _load();
                    },
                    style: tInter(fontSize: 13, color: kCrmText),
                    decoration: InputDecoration(
                      hintText: t.translate('Invoice number / Customer / Shipment number'),
                      hintStyle: tInter(fontSize: 12, color: kCrmTextSub),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kCrmTextSub),
                      isDense: true,
                      filled: true,
                      fillColor: kCrmSurface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmBorder)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 22),
              Text('$_count ${t.translate('invoice(s)')}', style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
              const SizedBox(height: 14),
              if (_error != null)
                _buildError(t)
              else if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
              else
                FinanceInvoicesTable(
                  invoices: _invoices,
                  mode: FinanceInvoiceTableMode.paid,
                  onView: (inv) => showFinanceInvoiceDetail(context, inv, onChanged: _load),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildError(AppLocalizations t) {
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
