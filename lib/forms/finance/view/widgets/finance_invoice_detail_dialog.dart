// lib/forms/finance/view/widgets/finance_invoice_detail_dialog.dart
//
// VIEW d'une facture (§8) : Invoice details → Invoice items → Totals
// (Subtotal HT/Taxes/Total TTC/Acompte/Net à payer) → Conditions de
// règlement/Date/Mode → Register payment + historique des paiements →
// Documents. Partagée par Factured Shipments et Paid Factures. AUCUN badge
// de statut (Needs review/Pending/Issued) n'est réintroduit dans ce header
// (§14) — le statut reste un détail interne, jamais affiché ici.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';
import '../../service/finance_service.dart';
import '../../theme/finance_theme.dart';
import 'finance_documents_table.dart';
import 'finance_invoice_items_table.dart';
import 'finance_preview_dialog.dart';
import 'finance_upload_dropzone.dart';

const List<String> kFinancePaymentMethods = ['Carte bancaire', 'Espèce', 'Chèque', 'Traite'];

Future<void> showFinanceInvoiceDetail(BuildContext context, FinanceInvoiceModel preview, {VoidCallback? onChanged}) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(width: 820, height: 720, child: _InvoiceDetailBody(preview: preview, onChanged: onChanged)),
    ),
  );
}

class _InvoiceDetailBody extends StatefulWidget {
  final FinanceInvoiceModel preview;
  final VoidCallback? onChanged;
  const _InvoiceDetailBody({required this.preview, this.onChanged});

  @override
  State<_InvoiceDetailBody> createState() => _InvoiceDetailBodyState();
}

class _InvoiceDetailBodyState extends State<_InvoiceDetailBody> {
  bool _loading = true;
  FinanceInvoiceModel? _invoice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final full = await FinanceService.instance.fetchInvoice(widget.preview.id);
      if (!mounted) return;
      setState(() => _invoice = full);
    } catch (_) {
      // repli sur les données déjà connues.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerPayment() async {
    final inv = _invoice ?? widget.preview;
    final remaining = inv.total - inv.payments.fold(0.0, (s, p) => s + p.amount);
    final result = await showDialog<_PaymentInput>(
      context: context,
      builder: (_) => _RegisterPaymentDialog(suggestedAmount: remaining > 0 ? remaining : inv.total),
    );
    if (result == null) return;
    try {
      await FinanceService.instance.registerPayment(
        inv.id,
        amount: result.amount,
        paidDate: DateFormat('yyyy-MM-dd').format(result.date),
        method: result.method,
        reference: result.reference,
        chequeNumber: result.chequeNumber,
        bankName: result.bankName,
        chequeDate: result.chequeDate == null ? null : DateFormat('yyyy-MM-dd').format(result.chequeDate!),
        billOfExchangeNumber: result.billOfExchangeNumber,
        dueDate: result.dueDate == null ? null : DateFormat('yyyy-MM-dd').format(result.dueDate!),
        document: result.document,
      );
      // Recalcule le montant payé/reste à payer et actualise l'affichage de
      // la facture (§13) — la même réponse renvoyée par registerPayment
      // suffit, mais on repasse par _load() pour rester cohérent avec le
      // reste du dialog (invoice complète + documents) en un seul chemin.
      widget.onChanged?.call();
      await _load();
    } catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final inv = _invoice ?? widget.preview;
    final hasPaymentInfo = (inv.paymentCondition ?? '').isNotEmpty || (inv.paymentDate ?? '').isNotEmpty || (inv.paymentMethod ?? '').isNotEmpty;

    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          const Icon(Icons.receipt_long_outlined, color: kCrmPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inv.invoiceNumber, style: tInter(fontSize: 15.5, fontWeight: FontWeight.w800, color: kCrmText)),
            ]),
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
                  _sectionTitle(t.translate('Invoice details')),
                  _grid([
                    (t.translate('Invoice number'), inv.invoiceNumber),
                    (t.translate('Customer'), _customerDisplay(inv)),
                    (t.translate('Invoice date'), _dateFmt(inv.invoiceDate)),
                    if ((inv.customerCode ?? '').isNotEmpty) (t.translate('Customer code'), inv.customerCode!),
                    if ((inv.customerPhone ?? '').isNotEmpty) (t.translate('Customer phone'), inv.customerPhone!),
                    if ((inv.customerTaxId ?? '').isNotEmpty) (t.translate('Customer tax ID'), inv.customerTaxId!),
                    if ((inv.reference ?? '').isNotEmpty) (t.translate('Reference'), inv.reference!),
                    if ((inv.customerAddress ?? '').isNotEmpty) (t.translate('Adresse'), inv.customerAddress!),
                    if ((inv.customerGovernorate ?? '').isNotEmpty) (t.translate('Governorate'), inv.customerGovernorate!),
                    (t.translate('Shipment'), inv.shipment?.reference ?? '—'),
                  ]),
                  const SizedBox(height: 20),
                  _sectionTitle(t.translate('Invoice items')),
                  FinanceInvoiceItemsTable(items: inv.items),
                  const SizedBox(height: 20),
                  _sectionTitle(t.translate('Totaux')),
                  _grid([
                    (t.translate('Subtotal HT'), formatFinanceNumber(inv.amount)),
                    (t.translate('Tax'), formatFinanceNumber(inv.tax)),
                    (t.translate('Total TTC'), formatFinanceNumber(inv.total)),
                    if (inv.downPayment != null) (t.translate('Down payment'), formatFinanceNumber(inv.downPayment!)),
                    if (inv.netToPay != null) (t.translate('Net to pay'), formatFinanceNumber(inv.netToPay!)),
                  ]),
                  if (inv.taxes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _TaxesTable(taxes: inv.taxes),
                  ],
                  if (hasPaymentInfo || (inv.amountInWords ?? '').isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle(t.translate('Payment condition')),
                    _grid([
                      if ((inv.paymentCondition ?? '').isNotEmpty) (t.translate('Payment condition'), inv.paymentCondition!),
                      if ((inv.paymentDate ?? '').isNotEmpty) (t.translate('Payment date'), _dateFmt(inv.paymentDate)),
                      if ((inv.paymentMethod ?? '').isNotEmpty) (t.translate('Payment method'), inv.paymentMethod!),
                      if ((inv.amountInWords ?? '').isNotEmpty) (t.translate('Amount in words'), inv.amountInWords!),
                    ]),
                  ],
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _registerPayment,
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: Text(t.translate('Register payment')),
                    style: OutlinedButton.styleFrom(foregroundColor: kFinanceColor, side: const BorderSide(color: kFinanceColor)),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle(t.translate('Payment history')),
                  if (inv.payments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(t.translate('No payments registered yet'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                    )
                  else
                    _PaymentHistoryList(payments: inv.payments),
                  const SizedBox(height: 20),
                  _sectionTitle(t.translate('Documents')),
                  FinanceDocumentsTable(
                    documents: inv.documents,
                    onView: (doc) => showFinanceDocumentPreview(context, doc),
                    showStatus: false,
                  ),
                ]),
              ),
      ),
    ]);
  }

  String _customerDisplay(FinanceInvoiceModel inv) {
    if ((inv.customerName ?? '').isNotEmpty) return inv.customerName!;
    if (inv.customer != null) return inv.customer!.displayName;
    return '—';
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

// Détail des taxes (§STRUCTURE DES TAXES) — nombre de lignes dynamique, une
// cellule vide (rate/amount null) reste vide, jamais un "0" inventé.
class _TaxesTable extends StatelessWidget {
  final List<FinanceInvoiceTaxModel> taxes;
  const _TaxesTable({required this.taxes});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTableTheme(
          data: DataTableThemeData(
            headingRowColor: WidgetStateProperty.all(kCrmBg),
            headingTextStyle: tInter(fontSize: 11, fontWeight: FontWeight.w800, color: kCrmTextSub),
            dataTextStyle: tInter(fontSize: 12, color: kCrmText),
            dividerThickness: 1,
          ),
          child: DataTable(
            headingRowHeight: 38,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 44,
            columnSpacing: 26,
            columns: [
              DataColumn(label: Text(t.translate('Code'))),
              DataColumn(label: Text(t.translate('Base'))),
              DataColumn(label: Text(t.translate('Rate'))),
              DataColumn(label: Text(t.translate('Tax'))),
            ],
            rows: [
              for (final tax in taxes)
                DataRow(cells: [
                  DataCell(Text(tax.code ?? '—')),
                  DataCell(Text(tax.base == null ? '—' : formatFinanceNumber(tax.base!))),
                  DataCell(Text(tax.rate == null ? '—' : '${formatFinanceNumber(tax.rate!)}%')),
                  DataCell(Text(tax.amount == null ? '—' : formatFinanceNumber(tax.amount!))),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

// Historique des paiements (§13 : "afficher l'historique des paiements") —
// un paiement Chèque/Traite affiche ses champs spécifiques + le document
// justificatif associé, jamais mélangé aux modes qui n'en ont pas.
class _PaymentHistoryList extends StatelessWidget {
  final List<FinancePaymentModel> payments;
  const _PaymentHistoryList({required this.payments});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      children: payments
          .map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kCrmBorder)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(formatFinanceNumber(p.amount), style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
                    const SizedBox(width: 10),
                    if ((p.method ?? '').isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: kFinanceColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(p.method!, style: tInter(fontSize: 10.5, fontWeight: FontWeight.w700, color: kFinanceColor)),
                      ),
                    const Spacer(),
                    Text(_dateFmt(p.paidDate), style: tInter(fontSize: 11.5, color: kCrmTextSub)),
                  ]),
                  if ((p.chequeNumber ?? '').isNotEmpty || (p.bankName ?? '').isNotEmpty || (p.chequeDate ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 16, runSpacing: 4, children: [
                      if ((p.chequeNumber ?? '').isNotEmpty) _miniField(t.translate('Cheque number'), p.chequeNumber!),
                      if ((p.bankName ?? '').isNotEmpty) _miniField(t.translate('Bank name'), p.bankName!),
                      if ((p.chequeDate ?? '').isNotEmpty) _miniField(t.translate('Cheque date'), _dateFmt(p.chequeDate)),
                    ]),
                  ],
                  if ((p.billOfExchangeNumber ?? '').isNotEmpty || (p.bankName ?? '').isNotEmpty || (p.dueDate ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 16, runSpacing: 4, children: [
                      if ((p.billOfExchangeNumber ?? '').isNotEmpty) _miniField(t.translate('Bill of exchange number'), p.billOfExchangeNumber!),
                      if (p.billOfExchangeNumber != null && (p.bankName ?? '').isNotEmpty) _miniField(t.translate('Bank name'), p.bankName!),
                      if ((p.dueDate ?? '').isNotEmpty) _miniField(t.translate('Due date'), _dateFmt(p.dueDate)),
                    ]),
                  ],
                  if (p.documents.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => showFinanceDocumentPreview(context, p.documents.first),
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: Text(t.translate('View'), style: tInter(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kCrmPrimary,
                        side: const BorderSide(color: kCrmBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ]),
              ))
          .toList(),
    );
  }

  Widget _miniField(String label, String value) {
    return RichText(
      text: TextSpan(children: [
        TextSpan(text: '$label: ', style: tInter(fontSize: 11, color: kCrmTextSub)),
        TextSpan(text: value, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: kCrmText)),
      ]),
    );
  }

  String _dateFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d);
  }
}

class _PaymentInput {
  final double amount;
  final DateTime date;
  final String method;
  final String? reference;
  final String? chequeNumber;
  final String? bankName;
  final DateTime? chequeDate;
  final String? billOfExchangeNumber;
  final DateTime? dueDate;
  final FinancePickedFile? document;
  const _PaymentInput({
    required this.amount,
    required this.date,
    required this.method,
    this.reference,
    this.chequeNumber,
    this.bankName,
    this.chequeDate,
    this.billOfExchangeNumber,
    this.dueDate,
    this.document,
  });
}

class _RegisterPaymentDialog extends StatefulWidget {
  final double suggestedAmount;
  const _RegisterPaymentDialog({required this.suggestedAmount});

  @override
  State<_RegisterPaymentDialog> createState() => _RegisterPaymentDialogState();
}

class _RegisterPaymentDialogState extends State<_RegisterPaymentDialog> {
  late final _amount = TextEditingController(text: widget.suggestedAmount.toStringAsFixed(2));
  final _reference = TextEditingController();
  final _chequeNumber = TextEditingController();
  final _bankName = TextEditingController();
  final _billOfExchangeNumber = TextEditingController();
  String _method = kFinancePaymentMethods.first;
  DateTime _date = DateTime.now();
  DateTime? _methodDate; // Cheque date (Chèque) ou Due date (Traite) selon le mode.
  FinancePickedFile? _document;

  bool get _needsDocument => _method == 'Chèque' || _method == 'Traite';

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _chequeNumber.dispose();
    _bankName.dispose();
    _billOfExchangeNumber.dispose();
    super.dispose();
  }

  Future<void> _pickDate(DateTime initial, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => onPicked(picked));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.translate('Register payment')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '${t.translate('Amount')} *', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _pickDate(_date, (d) => _date = d),
              child: InputDecorator(
                decoration: InputDecoration(labelText: t.translate('Payment date'), border: const OutlineInputBorder()),
                child: Text(DateFormat('dd/MM/yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            // Dropdown FERMÉ — EXACTEMENT ces 4 valeurs (§9), jamais un champ
            // libre.
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: InputDecoration(labelText: '${t.translate('Payment method')} *', border: const OutlineInputBorder()),
              items: kFinancePaymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _method = v;
                  _methodDate = null;
                  _document = null;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: _reference, decoration: InputDecoration(labelText: t.translate('Payment reference'), border: const OutlineInputBorder())),
            if (_method == 'Chèque') ...[
              const SizedBox(height: 16),
              TextField(controller: _chequeNumber, decoration: InputDecoration(labelText: t.translate('Cheque number'), border: const OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _bankName, decoration: InputDecoration(labelText: t.translate('Bank name'), border: const OutlineInputBorder())),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _pickDate(_methodDate ?? DateTime.now(), (d) => _methodDate = d),
                child: InputDecorator(
                  decoration: InputDecoration(labelText: t.translate('Cheque date'), border: const OutlineInputBorder()),
                  child: Text(_methodDate == null ? '—' : DateFormat('dd/MM/yyyy').format(_methodDate!)),
                ),
              ),
            ],
            if (_method == 'Traite') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _billOfExchangeNumber,
                decoration: InputDecoration(labelText: t.translate('Bill of exchange number'), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(controller: _bankName, decoration: InputDecoration(labelText: t.translate('Bank name'), border: const OutlineInputBorder())),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _pickDate(_methodDate ?? DateTime.now(), (d) => _methodDate = d),
                child: InputDecorator(
                  decoration: InputDecoration(labelText: t.translate('Due date'), border: const OutlineInputBorder()),
                  child: Text(_methodDate == null ? '—' : DateFormat('dd/MM/yyyy').format(_methodDate!)),
                ),
              ),
            ],
            if (_needsDocument) ...[
              const SizedBox(height: 16),
              Text(t.translate('Supporting document'), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kCrmText)),
              const SizedBox(height: 4),
              Text(t.translate('Document required for this payment method'), style: tInter(fontSize: 11, color: kCrmTextSub)),
              const SizedBox(height: 10),
              if (_document != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
                  child: Row(children: [
                    const Icon(Icons.description_outlined, size: 16, color: kFinanceColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_document!.filename, style: tInter(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => setState(() => _document = null),
                    ),
                  ]),
                )
              else
                FinanceUploadDropzone(
                  onFilesSelected: (files) {
                    if (files.isNotEmpty) setState(() => _document = files.first);
                  },
                ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.translate('Annuler'))),
        ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
            if (amount == null || amount <= 0) return;
            Navigator.of(context).pop(_PaymentInput(
              amount: amount,
              date: _date,
              method: _method,
              reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
              chequeNumber: _method == 'Chèque' && _chequeNumber.text.trim().isNotEmpty ? _chequeNumber.text.trim() : null,
              bankName: (_method == 'Chèque' || _method == 'Traite') && _bankName.text.trim().isNotEmpty ? _bankName.text.trim() : null,
              chequeDate: _method == 'Chèque' ? _methodDate : null,
              billOfExchangeNumber: _method == 'Traite' && _billOfExchangeNumber.text.trim().isNotEmpty ? _billOfExchangeNumber.text.trim() : null,
              dueDate: _method == 'Traite' ? _methodDate : null,
              document: _needsDocument ? _document : null,
            ));
          },
          style: ElevatedButton.styleFrom(backgroundColor: kFinanceColor, foregroundColor: Colors.white),
          child: Text(t.translate('Confirmer')),
        ),
      ],
    );
  }
}
