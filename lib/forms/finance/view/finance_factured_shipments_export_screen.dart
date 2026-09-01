// lib/forms/finance/view/finance_factured_shipments_export_screen.dart
//
// §MODIFICATION — FACTURED SHIPMENTS : IMPORT / EXPORT (2026-08-31).
// "Factured shipments - by facture" → "Export" (§3 du ticket) : liste les
// factures dont l'OCR a été extrait correctement — prêtes à être utilisées
// dans Factured Shipments. Réutilise EXACTEMENT le même tableau que la page
// principale (FinanceInvoicesTable, mode factured — mêmes colonnes Invoice
// #/Documents/Invoice date/Customer/Shipment #/Amount/Tax/Total/Actions),
// le même dialogue de détail et la même suppression — aucune nouvelle
// donnée inventée, aucun nouvel endpoint.
//
// "Extraction correcte" = tout ce qui n'est PAS NEEDS_REVIEW/OCR_FAILED
// (déjà listés dans "Import", voir finance_factured_shipments_import_screen.
// dart) — calculé en excluant ces deux buckets (mêmes deux appels
// FinanceService.fetchInvoices(status: ...) déjà utilisés par le dropdown
// de statut de la page principale) de la liste complète, plutôt que
// d'énumérer les statuts "bons" un par un : reste correct même si un
// nouveau statut métier est ajouté un jour (§7/§8 du ticket — "ne pas
// modifier la logique métier").

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/application/common/safe_snack.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../model/finance_models.dart';
import '../service/finance_service.dart';
import '../theme/finance_theme.dart';
import 'widgets/finance_invoice_detail_dialog.dart';
import 'widgets/finance_invoices_table.dart';

const int _kFetchAllPageSize = 2000;

class FinanceFacturedShipmentsExportScreen extends StatefulWidget {
  const FinanceFacturedShipmentsExportScreen({super.key});

  @override
  State<FinanceFacturedShipmentsExportScreen> createState() => _FinanceFacturedShipmentsExportScreenState();
}

class _FinanceFacturedShipmentsExportScreenState extends State<FinanceFacturedShipmentsExportScreen> {
  bool _loading = true;
  String? _error;
  List<FinanceInvoiceModel> _invoices = const [];
  // §CORRECTION — SUPPRESSION FINANCE : même garde-fou que sur les autres
  // écrans Finance (empêche deux DELETE simultanés sur la même facture).
  final Set<String> _deletingIds = {};

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
      final results = await Future.wait([
        FinanceService.instance.fetchInvoices(pageSize: _kFetchAllPageSize),
        FinanceService.instance.fetchInvoices(status: 'NEEDS_REVIEW', pageSize: _kFetchAllPageSize),
        FinanceService.instance.fetchInvoices(status: 'OCR_FAILED', pageSize: _kFetchAllPageSize),
      ]);
      if (!mounted) return;
      final needsInterventionIds = {
        for (final inv in results[1].items) inv.id,
        for (final inv in results[2].items) inv.id,
      };
      setState(() {
        _invoices = results[0].items.where((inv) => !needsInterventionIds.contains(inv.id)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Suppression réelle côté backend — même mécanisme/confirmation que
  // finance_factured_shipments_screen.dart#_handleDelete.
  Future<void> _handleDelete(FinanceInvoiceModel inv) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.translate('Delete this invoice?')),
        content: Text(t.translate('Are you sure you want to delete this invoice and its associated documents?')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(t.translate('Cancel'))),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.translate('Delete'), style: const TextStyle(color: kCrmDanger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_deletingIds.contains(inv.id)) return;
    _deletingIds.add(inv.id);
    try {
      await FinanceService.instance.deleteInvoice(inv.id);
      if (!mounted) return;
      setState(() => _invoices = _invoices.where((i) => i.id != inv.id).toList());
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(t.translate('Invoice deleted successfully')), backgroundColor: kCrmSuccess),
      );
    } catch (e) {
      if (!mounted) return;
      SafeSnack.messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      _deletingIds.remove(inv.id);
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
                  decoration: BoxDecoration(color: kFinanceColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.file_download_outlined, size: 22, color: kFinanceColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.translate('Export'), style: tInter(fontSize: 20, fontWeight: FontWeight.w800, color: kCrmText)),
                    const SizedBox(height: 2),
                    Text(t.translate('Documents successfully extracted, ready to be used in Factured Shipments.'),
                        style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  ]),
                ),
              ]),
              const SizedBox(height: 22),
              Text('${_invoices.length} ${t.translate('invoice(s)')}', style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
              const SizedBox(height: 14),
              if (_error != null)
                _buildError(t)
              else if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
              else
                FinanceInvoicesTable(
                  invoices: _invoices,
                  mode: FinanceInvoiceTableMode.factured,
                  onView: (inv) => showFinanceInvoiceDetail(context, inv, onChanged: _load),
                  onDelete: _handleDelete,
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
