// lib/forms/finance/view/widgets/finance_purchase_order_detail_dialog.dart
//
// VIEW d'un Bon de Commande (Inflow of raw materials) : section "Purchase
// order details" + "Purchase order items" + "Totals" + "Documents". Le
// document est lu par OCR à l'upload (§CORRECTION — EXTRACTION AUTOMATIQUE
// DES BONS DE COMMANDE) — toute valeur absente s'affiche "—", jamais un nom
// de champ ni une valeur inventée.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';
import '../../service/finance_service.dart';
import 'finance_documents_table.dart';
import 'finance_preview_dialog.dart';
import 'finance_purchase_order_items_table.dart';

Future<void> showFinancePurchaseOrderDetail(BuildContext context, FinancePurchaseOrderModel preview) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(width: 800, height: 680, child: _PurchaseOrderDetailBody(preview: preview)),
    ),
  );
}

class _PurchaseOrderDetailBody extends StatefulWidget {
  final FinancePurchaseOrderModel preview;
  const _PurchaseOrderDetailBody({required this.preview});

  @override
  State<_PurchaseOrderDetailBody> createState() => _PurchaseOrderDetailBodyState();
}

class _PurchaseOrderDetailBodyState extends State<_PurchaseOrderDetailBody> {
  bool _loading = true;
  FinancePurchaseOrderModel? _order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final full = await FinanceService.instance.fetchRawMaterial(widget.preview.id);
      if (!mounted) return;
      setState(() => _order = full);
    } catch (_) {
      // repli sur les données déjà connues.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final order = _order ?? widget.preview;

    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          const Icon(Icons.inventory_2_outlined, color: kCrmPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(order.orderNumber ?? '—', style: tInter(fontSize: 15.5, fontWeight: FontWeight.w800, color: kCrmText)),
          ),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sectionTitle(t.translate('Purchase order details')),
                  _grid([
                    (t.translate('Order number'), order.orderNumber ?? '—'),
                    (t.translate('Customer'), order.displayCustomerName),
                    (t.translate('Order date'), _dateFmt(order.orderDate)),
                    if ((order.customerCode ?? '').isNotEmpty) (t.translate('Customer code'), order.customerCode!),
                    if ((order.customerAddress ?? '').isNotEmpty) (t.translate('Customer address'), order.customerAddress!),
                    if ((order.deliveryAddress ?? '').isNotEmpty) (t.translate('Delivery address'), order.deliveryAddress!),
                  ]),
                  const SizedBox(height: 20),
                  _sectionTitle(t.translate('Purchase order items')),
                  FinancePurchaseOrderItemsTable(items: order.items),
                  const SizedBox(height: 20),
                  _sectionTitle(t.translate('Totaux')),
                  _grid([
                    (t.translate('Total HT'), order.totalHT == null ? '—' : formatFinanceNumber(order.totalHT!)),
                  ]),
                  const SizedBox(height: 20),
                  _sectionTitle(t.translate('Documents')),
                  FinanceDocumentsTable(
                    documents: order.documents,
                    onView: (doc) => showFinanceDocumentPreview(context, doc),
                    showStatus: false,
                  ),
                ]),
              ),
      ),
    ]);
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText)),
      );

  Widget _grid(List<(String, String)> rows) {
    return Column(
      children: rows
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 170, child: Text(r.$1, style: tInter(fontSize: 11.5, color: kCrmTextSub))),
                  Expanded(child: Text(r.$2, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText))),
                ]),
              ))
          .toList(),
    );
  }

  String _dateFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d);
  }
}
