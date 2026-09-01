// lib/forms/finance/view/widgets/finance_invoices_table.dart
//
// Table des factures — partagée par "Factured shipments - by facture" (§8,
// colonnes Invoice#/Date/Customer/Shipment#/Amount/Tax/Total) et
// "Paid factures" (§9, colonnes ...Invoice amount/Paid amount/Payment date/
// Payment method/Reference) via FinanceInvoiceTableMode. Aucun statut de
// facture n'est affiché (§CORRECTION OBLIGATOIRE — SUPPRESSION STATUT).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/application/common/safe_snack.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';
import 'finance_preview_dialog.dart';

enum FinanceInvoiceTableMode { factured, paid }

class FinanceInvoicesTable extends StatelessWidget {
  final List<FinanceInvoiceModel> invoices;
  final FinanceInvoiceTableMode mode;
  final ValueChanged<FinanceInvoiceModel> onView;
  final ValueChanged<FinanceInvoiceModel>? onDelete;
  // §CORRECTION — FACTURED SHIPMENTS / PAID INVOICES (2026-09-01) : "Invoice
  // date" éditable directement depuis ce tableau (§1 du ticket) — même
  // principe que "Order date"/"Delivery date" (OrderDateCell/
  // DeliveryDateCell) : `null` désactive l'édition (cellule en lecture
  // seule, comportement inchangé — utilisé par "Paid invoices", qui n'a pas
  // demandé cette fonctionnalité).
  final Future<FinanceInvoiceModel> Function(String id, DateTime newDate)? onInvoiceDateSave;
  final ValueChanged<FinanceInvoiceModel>? onInvoiceDateSaved;

  const FinanceInvoicesTable({
    super.key,
    required this.invoices,
    required this.onView,
    this.mode = FinanceInvoiceTableMode.factured,
    this.onDelete,
    this.onInvoiceDateSave,
    this.onInvoiceDateSaved,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (invoices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text(t.translate('Aucune donnée pour ces filtres'), style: tInter(fontSize: 13, color: kCrmTextSub))),
      );
    }
    final isPaid = mode == FinanceInvoiceTableMode.paid;

    return Container(
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTableTheme(
          data: DataTableThemeData(
            headingRowColor: WidgetStateProperty.all(kCrmBg),
            headingTextStyle: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: kCrmTextSub),
            dataTextStyle: tInter(fontSize: 12.5, color: kCrmText),
            dividerThickness: 1,
          ),
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 56,
            columnSpacing: 20,
            columns: [
              DataColumn(label: Text(t.translate('Invoice #'))),
              DataColumn(label: Text(t.translate('Documents'))),
              DataColumn(label: Text(t.translate('Invoice date'))),
              DataColumn(label: Text(t.translate('Customer'))),
              DataColumn(label: Text(t.translate('Shipment #'))),
              if (!isPaid) ...[
                DataColumn(label: Text(t.translate('Amount')), numeric: true),
                DataColumn(label: Text(t.translate('Tax')), numeric: true),
                DataColumn(label: Text(t.translate('Total')), numeric: true),
              ] else ...[
                // Colonnes minimales requises pour Paid Factures (§9) :
                // Payment method/Payment date/Amount HT/Tax/Total TTC/
                // Payment document (View).
                DataColumn(label: Text(t.translate('Payment method'))),
                DataColumn(label: Text(t.translate('Payment date'))),
                DataColumn(label: Text(t.translate('Amount HT')), numeric: true),
                DataColumn(label: Text(t.translate('Tax')), numeric: true),
                DataColumn(label: Text(t.translate('Total TTC')), numeric: true),
                DataColumn(label: Text(t.translate('Payment document'))),
              ],
              DataColumn(label: Text(t.translate('Actions'))),
            ],
            rows: [
              for (final inv in invoices)
                DataRow(
                  color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.hovered) ? kCrmPrimary.withOpacity(0.04) : null),
                  onSelectChanged: (_) => onView(inv),
                  cells: [
                    DataCell(Text(inv.invoiceNumber, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText))),
                    DataCell(_documentsCell(context, inv)),
                    DataCell(
                      onInvoiceDateSave == null
                          ? Text(_dateFmt(inv.invoiceDate))
                          : InvoiceDateCell(
                              key: ValueKey('invoice-date-${inv.id}-${inv.invoiceDate}'),
                              invoice: inv,
                              onSave: onInvoiceDateSave!,
                              onSaved: onInvoiceDateSaved,
                            ),
                    ),
                    DataCell(Text(inv.customer?.displayName ?? '—')),
                    DataCell(Text(inv.shipment?.reference ?? '—')),
                    if (!isPaid) ...[
                      DataCell(Text(formatFinanceNumber(inv.amount))),
                      DataCell(Text(formatFinanceNumber(inv.tax))),
                      DataCell(Text(formatFinanceNumber(inv.total))),
                    ] else ...[
                      DataCell(Text(_lastPayment(inv)?.method ?? '—')),
                      DataCell(Text(_dateFmt(_lastPayment(inv)?.paidDate))),
                      DataCell(Text(formatFinanceNumber(inv.amount))),
                      DataCell(Text(formatFinanceNumber(inv.tax))),
                      DataCell(Text(formatFinanceNumber(inv.total))),
                      DataCell(_paymentDocumentCell(context, inv)),
                    ],
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      Tooltip(
                        message: t.translate('View'),
                        child: OutlinedButton.icon(
                          onPressed: () => onView(inv),
                          icon: const Icon(Icons.visibility_outlined, size: 15),
                          label: Text(t.translate('View'), style: tInter(fontSize: 12, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kCrmPrimary,
                            side: const BorderSide(color: kCrmBorder),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      if (onDelete != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: t.translate('Delete'),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kCrmDanger),
                          onPressed: () => onDelete!(inv),
                        ),
                      ],
                    ])),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _documentsCell(BuildContext context, FinanceInvoiceModel inv) {
    final t = AppLocalizations.of(context);
    if (inv.documents.isEmpty) return Text('—', style: tInter(fontSize: 12.5, color: kCrmTextSub));
    final first = inv.documents.first;
    final extra = inv.documents.length - 1;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_docIcon(first), size: 15, color: kCrmPrimary),
      const SizedBox(width: 6),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(first.originalName, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, color: kCrmText)),
      ),
      if (extra > 0) ...[
        const SizedBox(width: 4),
        Text('+$extra ${t.translate('more')}', style: tInter(fontSize: 11, color: kCrmTextSub)),
      ],
    ]);
  }

  IconData _docIcon(FinanceDocumentModel doc) {
    if (doc.isPdf) return Icons.picture_as_pdf_outlined;
    if (doc.isImage) return Icons.image_outlined;
    if (['xls', 'xlsx', 'csv'].contains(doc.extension)) return Icons.grid_on_outlined;
    if (['doc', 'docx'].contains(doc.extension)) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  // Justificatif du paiement (§9 : "Le justificatif doit être consultable
  // avec 'View'") — celui du DERNIER paiement enregistré, pas les documents
  // de la facture elle-même (colonne "Documents" ci-dessus, inchangée).
  Widget _paymentDocumentCell(BuildContext context, FinanceInvoiceModel inv) {
    final t = AppLocalizations.of(context);
    final doc = _lastPayment(inv)?.documents.firstOrNull;
    if (doc == null) return Text('—', style: tInter(fontSize: 12.5, color: kCrmTextSub));
    return OutlinedButton.icon(
      onPressed: () => showFinanceDocumentPreview(context, doc),
      icon: const Icon(Icons.visibility_outlined, size: 14),
      label: Text(t.translate('View'), style: tInter(fontSize: 12, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: kCrmPrimary,
        side: const BorderSide(color: kCrmBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  FinancePaymentModel? _lastPayment(FinanceInvoiceModel inv) {
    if (inv.payments.isEmpty) return null;
    final sorted = [...inv.payments]..sort((a, b) => (a.paidDate ?? '').compareTo(b.paidDate ?? ''));
    return sorted.last;
  }

  String _dateFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d);
  }
}

// §CORRECTION — FACTURED SHIPMENTS / PAID INVOICES (2026-09-01) : cellule
// "Invoice date" éditable — PUBLIQUE, même comportement que
// OrderDateCell/DeliveryDateCell (Normal (date + crayon) / "Date not
// defined" si absente / "Saving..." pendant l'appel / restauration de
// l'ancienne valeur + SnackBar en cas d'échec / `onSaved` remonte la
// facture à jour à l'écran parent) — jamais une deuxième implémentation.
class InvoiceDateCell extends StatefulWidget {
  final FinanceInvoiceModel invoice;
  final Future<FinanceInvoiceModel> Function(String id, DateTime newDate) onSave;
  final ValueChanged<FinanceInvoiceModel>? onSaved;

  const InvoiceDateCell({super.key, required this.invoice, required this.onSave, this.onSaved});

  @override
  State<InvoiceDateCell> createState() => InvoiceDateCellState();
}

class InvoiceDateCellState extends State<InvoiceDateCell> {
  bool _saving = false;

  String _dateFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d);
  }

  Future<void> _pick() async {
    if (_saving) return;
    final t = AppLocalizations.of(context);
    final current = widget.invoice.invoiceDate == null ? null : DateTime.tryParse(widget.invoice.invoiceDate!);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() => _saving = true);
    try {
      final updated = await widget.onSave(widget.invoice.id, picked);
      if (!mounted) return;
      widget.onSaved?.call(updated);
    } catch (e) {
      if (!mounted) return;
      // Échec → `widget.invoice` n'a jamais été modifié ici, l'ancienne
      // valeur reste donc affichée automatiquement.
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${t.translate('Failed to update invoice date')} : $e'), backgroundColor: kCrmDanger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (_saving) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 6),
        Text(t.translate('Saving...'), style: tInter(fontSize: 12, color: kCrmTextSub)),
      ]);
    }

    final raw = widget.invoice.invoiceDate;
    final hasDate = raw != null && raw.isNotEmpty;
    final label = hasDate ? _dateFmt(raw) : t.translate('Date not defined');

    return InkWell(
      onTap: _pick,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: tInter(
                fontSize: 12.5,
                fontStyle: hasDate ? FontStyle.normal : FontStyle.italic,
                color: hasDate ? kCrmText : kCrmTextSub,
              )),
          const SizedBox(width: 4),
          Icon(Icons.edit_outlined, size: 13, color: kCrmTextSub.withOpacity(0.7)),
        ]),
      ),
    );
  }
}
