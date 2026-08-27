// lib/forms/finance/view/widgets/finance_shipment_detail_dialog.dart
//
// VIEW d'un Shipment — Bon de Livraison lu par OCR : SHIPMENT DETAILS
// (numéro/date/référence), CUSTOMER (nom/matricule fiscal/téléphone/
// adresse/gouvernorat/adresse siège), DELIVERY (camion/constructeur/
// chauffeur/date/adresse de livraison), PRODUCTS (tableau des lignes),
// TOTAL, DOCUMENT (bouton VIEW pour consulter le document original).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/widgets/responsive_dialog_box.dart';

import '../../model/finance_models.dart';
import '../../service/finance_service.dart';
import 'finance_documents_table.dart';
import 'finance_preview_dialog.dart';
import 'finance_shipment_items_table.dart';

Future<void> showFinanceShipmentDetail(BuildContext context, FinanceShipmentModel preview, {VoidCallback? onChanged}) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ResponsiveDialogBox(width: 800, height: 680, child: _ShipmentDetailBody(preview: preview, onChanged: onChanged)),
    ),
  );
}

class _ShipmentDetailBody extends StatefulWidget {
  final FinanceShipmentModel preview;
  final VoidCallback? onChanged;
  const _ShipmentDetailBody({required this.preview, this.onChanged});

  @override
  State<_ShipmentDetailBody> createState() => _ShipmentDetailBodyState();
}

class _ShipmentDetailBodyState extends State<_ShipmentDetailBody> {
  bool _loading = true;
  FinanceShipmentModel? _shipment;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final full = await FinanceService.instance.fetchShipment(widget.preview.id);
      if (!mounted) return;
      setState(() => _shipment = full);
    } catch (_) {
      // repli sur les données déjà connues (liste) si le GET échoue.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _customerDisplay(FinanceShipmentModel s) {
    if ((s.customerName ?? '').isNotEmpty) return s.customerName!;
    if (s.customer != null) return s.customer!.displayName;
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = _shipment ?? widget.preview;

    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          const Icon(Icons.local_shipping_outlined, color: kCrmPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(s.reference, style: tInter(fontSize: 15.5, fontWeight: FontWeight.w800, color: kCrmText)),
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
                  _sectionTitle(t.translate('Shipment details')),
                  _grid([
                    if ((s.shipmentNumber ?? '').isNotEmpty) (t.translate('Shipment #'), s.shipmentNumber!),
                    (t.translate('Delivery number'), s.reference),
                    (t.translate('Delivery date'), _dateFmt(s.shipmentDate)),
                    if ((s.customerReference ?? '').isNotEmpty) (t.translate('Reference'), s.customerReference!),
                  ]),
                  const SizedBox(height: 18),
                  _sectionTitle(t.translate('Customer')),
                  _grid([
                    if ((s.customerCode ?? '').isNotEmpty) (t.translate('Customer code'), s.customerCode!),
                    (t.translate('Customer'), _customerDisplay(s)),
                    if ((s.customerTaxId ?? '').isNotEmpty) (t.translate('Customer tax ID'), s.customerTaxId!),
                    if ((s.customerPhone ?? '').isNotEmpty) (t.translate('Customer phone'), s.customerPhone!),
                    if ((s.customerAddress ?? '').isNotEmpty) (t.translate('Adresse'), s.customerAddress!),
                    if ((s.customerGovernorate ?? '').isNotEmpty) (t.translate('Governorate'), s.customerGovernorate!),
                    if ((s.customerHeadOfficeAddress ?? '').isNotEmpty)
                      (t.translate('Head office address'), s.customerHeadOfficeAddress!),
                  ]),
                  const SizedBox(height: 18),
                  _sectionTitle(t.translate('Delivery')),
                  _grid([
                    if ((s.truckRegistration ?? '').isNotEmpty) (t.translate('Truck registration'), s.truckRegistration!),
                    if ((s.truckManufacturer ?? '').isNotEmpty) (t.translate('Manufacturer'), s.truckManufacturer!),
                    if ((s.driverName ?? '').isNotEmpty) (t.translate('Driver'), s.driverName!),
                    (t.translate('Delivery date'), _dateFmt(s.shipmentDate)),
                    if ((s.deliveryAddress ?? '').isNotEmpty) (t.translate('Delivery address'), s.deliveryAddress!),
                  ]),
                  const SizedBox(height: 18),
                  _sectionTitle(t.translate('Products')),
                  FinanceShipmentItemsTable(items: s.items),
                  const SizedBox(height: 18),
                  _sectionTitle(t.translate('Total')),
                  _grid([
                    (t.translate('Total quantity'), s.totalQuantity == null ? '—' : formatFinanceNumber(s.totalQuantity!)),
                  ]),
                  const SizedBox(height: 18),
                  _sectionTitle(t.translate('Documents')),
                  FinanceDocumentsTable(
                    documents: s.documents,
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
    if (rows.isEmpty) return Text('—', style: tInter(fontSize: 12.5, color: kCrmTextSub));
    return Column(
      children: rows
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
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
