// lib/forms/finance/view/finance_customer_shipments_screen.dart
//
// "Shipment of products to the customers" — table + "+ New shipment".

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../model/finance_models.dart';
import '../service/finance_service.dart';
import '../theme/finance_theme.dart';
import 'widgets/finance_shipment_detail_dialog.dart';
import 'widgets/finance_shipment_form_dialog.dart';
import 'widgets/finance_shipments_table.dart';

class FinanceCustomerShipmentsScreen extends StatefulWidget {
  const FinanceCustomerShipmentsScreen({super.key});

  @override
  State<FinanceCustomerShipmentsScreen> createState() => _FinanceCustomerShipmentsScreenState();
}

class _FinanceCustomerShipmentsScreenState extends State<FinanceCustomerShipmentsScreen> {
  bool _loading = true;
  String? _error;
  String _search = '';
  List<FinanceShipmentModel> _shipments = const [];
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
      final page = await FinanceService.instance.fetchShipments(search: _search, pageSize: 200);
      if (!mounted) return;
      setState(() {
        _shipments = page.items;
        _count = page.count;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewShipment() async {
    final created = await showNewShipmentDialog(context);
    if (created == null) return;
    await _load();
    if (!mounted) return;
    // "puis ouvrir/actualiser le Customer Shipment" — ouvre automatiquement
    // la fiche du Shipment qui vient d'être lu par OCR.
    showFinanceShipmentDetail(context, created, onChanged: _load);
  }

  // Suppression réelle côté backend (§AJOUTER LA SUPPRESSION DES DOCUMENTS
  // FINANCE) — confirmation via le Modal existant (AlertDialog, même
  // composant que partout ailleurs dans ce module), jamais window.confirm().
  Future<void> _handleDelete(FinanceShipmentModel shipment) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      // IMPORTANT : jamais le `context` de l'écran englobant ici — voir
      // finance_inflow_raw_materials_screen.dart#_handleDelete pour
      // l'explication complète (Navigator de branche go_router vs Navigator
      // racine sur lequel `showDialog` empile réellement ce dialogue).
      builder: (dialogContext) => AlertDialog(
        title: Text(t.translate('Delete this shipment?')),
        content: Text(t.translate('Are you sure you want to delete this shipment and its associated documents?')),
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
    try {
      await FinanceService.instance.deleteShipment(shipment.id);
      if (!mounted) return;
      setState(() {
        _shipments = _shipments.where((s) => s.id != shipment.id).toList();
        _count = _count > 0 ? _count - 1 : 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate('Shipment deleted successfully')), backgroundColor: kCrmSuccess),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
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
                  child: const Icon(Icons.local_shipping_outlined, size: 22, color: kFinanceColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.translate('Shipment of products to the customers'),
                        style: tInter(fontSize: 20, fontWeight: FontWeight.w800, color: kCrmText)),
                    const SizedBox(height: 2),
                    Text(t.translate('Manage customer shipments.'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  ]),
                ),
                ElevatedButton.icon(
                  onPressed: _openNewShipment,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(t.translate('New shipment')),
                  style: ElevatedButton.styleFrom(backgroundColor: kFinanceColor, foregroundColor: Colors.white),
                ),
              ]),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: Text('$_count ${t.translate('shipment(s)')}', style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
                ),
                SizedBox(
                  width: 240,
                  child: TextField(
                    onChanged: (v) {
                      _search = v;
                      _load();
                    },
                    style: tInter(fontSize: 13, color: kCrmText),
                    decoration: InputDecoration(
                      hintText: t.translate('Rechercher...'),
                      hintStyle: tInter(fontSize: 12.5, color: kCrmTextSub),
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
              const SizedBox(height: 14),
              if (_error != null)
                _buildError(t)
              else if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
              else
                FinanceShipmentsTable(
                  shipments: _shipments,
                  onView: (s) => showFinanceShipmentDetail(context, s, onChanged: _load),
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
