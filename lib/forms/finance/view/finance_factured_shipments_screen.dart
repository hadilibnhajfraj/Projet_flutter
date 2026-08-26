// lib/forms/finance/view/finance_factured_shipments_screen.dart
//
// "Factured shipments - by facture" (§8) — recherche (Invoice number /
// Customer / Shipment number, couverte par le même champ de recherche libre
// que le backend résout via invoiceNumber/customer.raisonSociale/
// shipment.reference) + filtres Date/Status.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/application/common/safe_snack.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../model/finance_models.dart';
import '../service/finance_service.dart';
import '../theme/finance_theme.dart';
import 'widgets/finance_invoice_detail_dialog.dart';
import 'widgets/finance_invoice_upload_dialog.dart';
import 'widgets/finance_invoices_table.dart';

class FinanceFacturedShipmentsScreen extends StatefulWidget {
  const FinanceFacturedShipmentsScreen({super.key});

  @override
  State<FinanceFacturedShipmentsScreen> createState() => _FinanceFacturedShipmentsScreenState();
}

class _FinanceFacturedShipmentsScreenState extends State<FinanceFacturedShipmentsScreen> {
  bool _loading = true;
  String? _error;
  String _search = '';
  String? _status;
  DateTime? _startDate;
  DateTime? _endDate;
  List<FinanceInvoiceModel> _invoices = const [];
  int _count = 0;
  // §CORRECTION — SUPPRESSION FINANCE : empêche deux requêtes DELETE
  // simultanées sur la même facture (double-clic rapide sur 🗑) — un id déjà
  // en cours de suppression est ignoré silencieusement plutôt que de
  // déclencher un second appel réseau.
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
      final page = await FinanceService.instance.fetchInvoices(
        search: _search,
        status: _status,
        startDate: _startDate == null ? null : DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: _endDate == null ? null : DateFormat('yyyy-MM-dd').format(_endDate!),
        pageSize: 200,
      );
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

  Future<void> _openUploadInvoice() async {
    final invoices = await showUploadInvoiceDialog(context);
    if (invoices == null || invoices.isEmpty) return;
    await _load();
    if (!mounted) return;
    if (invoices.length == 1) {
      // "Ouvrir automatiquement la fiche Invoice" après un upload réussi —
      // uniquement quand un seul fichier a été traité (sinon, la liste
      // rafraîchie suffit, pas de spam de N dialogues).
      showFinanceInvoiceDetail(context, invoices.first, onChanged: _load);
    }
  }

  // Suppression réelle côté backend (§AJOUTER LA SUPPRESSION DES DOCUMENTS
  // FINANCE) — confirmation via le Modal existant (AlertDialog), jamais
  // window.confirm().
  Future<void> _handleDelete(FinanceInvoiceModel inv) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      // IMPORTANT : jamais le `context` de l'écran englobant ici — voir
      // finance_inflow_raw_materials_screen.dart#_handleDelete pour
      // l'explication complète (Navigator de branche go_router vs Navigator
      // racine sur lequel `showDialog` empile réellement ce dialogue).
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
    if (_deletingIds.contains(inv.id)) return; // suppression déjà en cours pour cette facture
    _deletingIds.add(inv.id);
    try {
      await FinanceService.instance.deleteInvoice(inv.id);
      if (!mounted) return;
      // La ligne n'est retirée QUE si le backend a confirmé la suppression
      // (aucune exception ci-dessus) — jamais un simple retrait optimiste.
      setState(() {
        _invoices = _invoices.where((i) => i.id != inv.id).toList();
        _count = _count > 0 ? _count - 1 : 0;
      });
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
    // "Paid" retiré (§MODIFIER LE WORKFLOW PAYMENT / PAID FACTURES, §8) —
    // une facture payée n'appartient plus à cette liste (elle apparaît
    // automatiquement dans Paid Factures dès l'enregistrement du paiement),
    // ce filtre n'y renverrait donc plus jamais de résultat.
    const statuses = [
      (null, 'Toutes'),
      ('EXTRACTED', 'Extracted'),
      ('NEEDS_REVIEW', 'Needs review'),
      ('OCR_FAILED', 'OCR failed'),
      ('ISSUED', 'Issued'),
      ('PARTIALLY_PAID', 'Partially paid'),
      ('OVERDUE', 'Overdue'),
      ('CANCELLED', 'Cancelled'),
    ];

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
                  child: const Icon(Icons.receipt_long_outlined, size: 22, color: kFinanceColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.translate('Factured shipments - by facture'), style: tInter(fontSize: 20, fontWeight: FontWeight.w800, color: kCrmText)),
                    const SizedBox(height: 2),
                    Text(t.translate('Shipments that have been invoiced.'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  ]),
                ),
                ElevatedButton.icon(
                  onPressed: _openUploadInvoice,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(t.translate('Upload invoice')),
                  style: ElevatedButton.styleFrom(backgroundColor: kFinanceColor, foregroundColor: Colors.white),
                ),
              ]),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
                child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
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
                        fillColor: kCrmBg,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmBorder)),
                      ),
                    ),
                  ),
                  _dropdown<String?>(
                    value: _status,
                    items: statuses.map((s) => (s.$1, t.translate(s.$2))).toList(),
                    onChanged: (v) => setState(() {
                      _status = v;
                      _load();
                    }),
                  ),
                  _datePickerChip(
                    label: t.translate('Date début'),
                    value: _startDate,
                    onPicked: (d) => setState(() {
                      _startDate = d;
                      _load();
                    }),
                  ),
                  _datePickerChip(
                    label: t.translate('Date fin'),
                    value: _endDate,
                    onPicked: (d) => setState(() {
                      _endDate = d;
                      _load();
                    }),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _search = '';
                      _status = null;
                      _startDate = null;
                      _endDate = null;
                      _load();
                    }),
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: kCrmTextSub),
                    label: Text(t.translate('Réinitialiser'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Text('$_count ${t.translate('invoice(s)')}', style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
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

  Widget _dropdown<T>({required T value, required List<(T, String)> items, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.expand_more_rounded, size: 18, color: kCrmTextSub),
          style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText),
          items: [for (final item in items) DropdownMenuItem<T>(value: item.$1, child: Text(item.$2))],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _datePickerChip({required String label, required DateTime? value, required ValueChanged<DateTime> onPicked}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: kCrmTextSub),
          const SizedBox(width: 6),
          Text(value == null ? label : DateFormat('dd/MM/yyyy').format(value), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText)),
        ]),
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
