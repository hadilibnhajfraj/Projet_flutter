// lib/forms/finance/view/finance_factured_shipments_screen.dart
//
// "Factured shipments - by facture" (§8) — recherche (Invoice number /
// Customer / Shipment number, couverte par le même champ de recherche libre
// que le backend résout via invoiceNumber/customer.raisonSociale/
// shipment.reference) + filtres Date/Status.
//
// §CORRECTION — WORKFLOW OCR FACTURED SHIPMENTS (2026-08-31) : partition
// EXCLUSIVE entre le tableau principal et "Export", basée sur
// `FinanceInvoiceModel.isExtractionFailed` (donc sur
// `hasReliableInvoiceNumber`, exposé par le backend) — EXACTEMENT le même
// principe que `FinancePurchaseOrderModel.isExtractionFailed` (Inflow of
// raw materials, la référence explicite du ticket) : une facture reste dans
// le tableau principal dès qu'un numéro de facture fiable a été détecté,
// même si `status` est NEEDS_REVIEW pour une AUTRE raison secondaire — elle
// ne va dans "Export" que si AUCUN numéro fiable n'a été trouvé (OCR
// totalement en échec ou document sans rapport). Remplace l'ancien
// mécanisme "3 fetches (tous/NEEDS_REVIEW/OCR_FAILED) + exclusion par id",
// qui excluait à tort du tableau principal toute facture NEEDS_REVIEW,
// même avec un numéro parfaitement fiable — un seul fetch désormais,
// partition faite CÔTÉ CLIENT comme pour Shipments/Purchase Orders.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/application/common/safe_snack.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/widgets/responsive_dialog_box.dart';

import '../model/finance_models.dart';
import '../service/finance_service.dart';
import '../theme/finance_theme.dart';
import 'widgets/finance_documents_table.dart';
import 'widgets/finance_invoice_detail_dialog.dart';
import 'widgets/finance_invoice_upload_dialog.dart';
import 'widgets/finance_invoices_table.dart';
import 'widgets/finance_preview_dialog.dart';
import 'widgets/finance_upload_dropzone.dart';

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
  // §CORRECTION — SUPPRESSION FINANCE : empêche deux requêtes DELETE
  // simultanées sur la même facture (double-clic rapide sur 🗑) — un id déjà
  // en cours de suppression est ignoré silencieusement plutôt que de
  // déclencher un second appel réseau.
  final Set<String> _deletingIds = {};
  // §CORRECTION — FACTURED SHIPMENTS / PAID INVOICES (2026-09-01, §7 du
  // ticket) : empêche deux POST /payments simultanés sur la même facture
  // (double-clic rapide sur "Register Payment") — même principe que
  // `_deletingIds` ci-dessus.
  final Set<String> _payingIds = {};

  // §CORRECTION — WORKFLOW OCR FACTURED SHIPMENTS (2026-08-31) : partition
  // EXCLUSIVE — voir le commentaire en tête de fichier. `_validInvoices`
  // alimente le tableau principal, `_failedInvoices` alimente "Export" —
  // jamais les deux à la fois pour une même facture.
  List<FinanceInvoiceModel> get _validInvoices => _invoices.where((i) => !i.isExtractionFailed).toList();
  List<FinanceInvoiceModel> get _failedInvoices => _invoices.where((i) => i.isExtractionFailed).toList();

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
      setState(() => _invoices = page.items);
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

  // §CORRECTION — SIMPLIFICATION REGISTER PAYMENT (2026-08-31, §4-§7 du
  // ticket) : même dialogue/service que le bouton "Register payment" de la
  // fiche facture (finance_invoice_detail_dialog.dart) — jamais une
  // deuxième implémentation. Formulaire minimal : seuls method + document
  // sont envoyés (§2 du ticket), le backend déduit le reste (amount/
  // paidDate) exactement comme pour "New shipment"/"Upload invoice".
  //
  // Mise à jour IMMÉDIATE de l'état local (§7 du ticket : "ne pas demander
  // de F5") — la facture est retirée de `_invoices` dès la confirmation API,
  // SANS refetch réseau : comme `_invoices` alimente à la fois
  // `_validInvoices` ("Sage Documents") et `_failedInvoices` ("Scan
  // Documents"), elle disparaît instantanément des DEUX sections (§5 du
  // ticket — jamais présente dans les deux à la fois). Elle apparaîtra dans
  // "Paid invoices" à la prochaine visite de cet écran (fetchPaidInvoices,
  // déjà exécuté à CHAQUE initState de cette page — aucun changement
  // nécessaire là-bas, §6/§9 du ticket : réutilisation pure de l'existant).
  Future<void> _registerPaymentForInvoice(FinanceInvoiceModel invoice) async {
    // §7 du ticket : "ne jamais envoyer deux POST pour un seul clic" — un
    // paiement déjà en cours pour cette facture ignore silencieusement tout
    // nouveau clic (même widget déjà de-disabled côté table, voir
    // `_ExportDocumentsTable` ci-dessous, mais le garde-fou réel est ICI :
    // seule condition qui empêche réellement un second appel réseau).
    if (_payingIds.contains(invoice.id)) return;
    final preselected = kFinancePaymentMethods.contains(invoice.paymentMethod) ? invoice.paymentMethod : null;
    final result = await showRegisterPaymentDialog(context, preselectedMethod: preselected);
    if (result == null) return;
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    setState(() => _payingIds.add(invoice.id));
    try {
      await FinanceService.instance.registerPayment(invoice.id, method: result.method, document: result.document);
      if (!mounted) return;
      // La ligne n'est retirée QUE si le backend a confirmé l'enregistrement
      // (aucune exception ci-dessus) — jamais un simple retrait optimiste.
      // §9 du ticket : le message de succès n'est affiché QU'APRÈS cette
      // confirmation, jamais avant.
      setState(() => _invoices = _invoices.where((i) => i.id != invoice.id).toList());
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(t.translate('Payment registered successfully')), backgroundColor: kCrmSuccess),
      );
    } catch (e) {
      // §11/§8 du ticket : en cas d'échec, la facture reste dans "Scan
      // Documents" — `_invoices` n'est modifié QUE dans le bloc try
      // ci-dessus, donc rien n'a changé ici en cas d'erreur.
      if (!mounted) return;
      SafeSnack.messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      if (mounted) setState(() => _payingIds.remove(invoice.id));
    }
  }

  // §CORRECTION — FACTURED SHIPMENTS / PAID INVOICES (2026-09-01, §1 du
  // ticket) : "Invoice date" éditable depuis le tableau "Sage Documents". Le
  // PATCH réel se fait dans FinanceService (jamais un recalcul local) — ce
  // screen ne fait que transmettre l'appel et appliquer la facture mise à
  // jour renvoyée par le backend à `_invoices`, sans jamais recharger toute
  // la liste (même principe que _saveOrderDate/_saveDeliveryDate).
  Future<FinanceInvoiceModel> _saveInvoiceDate(String id, DateTime newDate) {
    return FinanceService.instance.updateInvoiceDate(id, newDate);
  }

  void _applyUpdatedInvoice(FinanceInvoiceModel updated) {
    if (!mounted) return;
    setState(() => _invoices = [for (final i in _invoices) if (i.id == updated.id) updated else i]);
    final t = AppLocalizations.of(context);
    SafeSnack.messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(t.translate('Date updated successfully')), backgroundColor: kCrmSuccess, duration: const Duration(seconds: 2)),
    );
  }

  // §MODIFICATION — FACTURED SHIPMENTS / SCAN DOCUMENTS (INCLUDE EXPORT) :
  // PLUSIEURS DOCUMENTS PAR LIGNE (2026-09-02) — même principe que
  // `_applyUpdatedInvoice` ci-dessus (met à jour `_invoices` avec la facture
  // renvoyée par le backend, jamais un rechargement complet — donc reflété
  // instantanément dans les DEUX sections "Sage Documents"/"Scan Documents",
  // §14 du ticket), mais SANS le message "Date updated successfully" (propre
  // à l'édition de date) : l'ajout/la suppression d'un document affiche son
  // propre message au bon endroit (voir
  // _AddInvoiceDocumentsDialogBody/_InvoiceDocumentsDialogBody plus bas).
  void _applyUpdatedInvoiceSilently(FinanceInvoiceModel updated) {
    if (!mounted) return;
    setState(() => _invoices = [for (final i in _invoices) if (i.id == updated.id) updated else i]);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // "Paid" retiré (§MODIFIER LE WORKFLOW PAYMENT / PAID FACTURES, §8) —
    // une facture payée n'appartient plus à cette liste (elle apparaît
    // automatiquement dans Paid Factures dès l'enregistrement du paiement),
    // ce filtre n'y renverrait donc plus jamais de résultat.
    //
    // §CORRECTION — WORKFLOW OCR FACTURED SHIPMENTS (2026-08-31) :
    // "Needs review"/"OCR failed" réintégrés — la partition tableau
    // principal/"Export" ne dépend plus de `status` mais de
    // `hasReliableInvoiceNumber` (voir _validInvoices/_failedInvoices) :
    // une facture NEEDS_REVIEW avec un numéro fiable reste dans le tableau
    // principal, donc ce filtre peut de nouveau renvoyer des résultats.
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
              // §CORRECTION — RENOMMAGE LIBELLÉS FACTURED SHIPMENTS
              // (2026-08-31, même principe que Inflow of raw materials/
              // Customer Shipments) : "N invoice(s)" → "Sage Documents"
              // (libellé fixe) — la partition exclusive tableau principal/
              // section dédiée (`_validInvoices`/`isExtractionFailed`,
              // basée sur hasReliableInvoiceNumber) est inchangée.
              Text(t.translate('Sage Documents'), style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
              const SizedBox(height: 14),
              if (_error != null)
                _buildError(t)
              else if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
              else ...[
                FinanceInvoicesTable(
                  invoices: _validInvoices,
                  mode: FinanceInvoiceTableMode.factured,
                  onView: (inv) => showFinanceInvoiceDetail(context, inv, onChanged: _load),
                  onDelete: _handleDelete,
                  onInvoiceDateSave: _saveInvoiceDate,
                  onInvoiceDateSaved: _applyUpdatedInvoice,
                ),
                if (_failedInvoices.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  // §CORRECTION — WORKFLOW OCR FACTURED SHIPMENTS
                  // (2026-08-31) : section "Export" (renommée depuis
                  // "Import" — même terminologie que Inflow of raw
                  // materials) — uniquement les factures sans numéro fiable
                  // détecté (voir _failedInvoices ci-dessus), sur la MÊME
                  // page que le tableau principal (jamais une page séparée,
                  // jamais un lien sidebar — voir sidebar_item_model.dart,
                  // inchangé).
                  Text(t.translate('Scan Documents (include export)'), style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: kCrmText)),
                  const SizedBox(height: 4),
                  Text(t.translate('These files could not be read automatically. You can still view or delete them.'),
                      style: tInter(fontSize: 12, color: kCrmTextSub)),
                  const SizedBox(height: 10),
                  _ExportDocumentsTable(
                    invoices: _failedInvoices,
                    onView: (doc) => showFinanceDocumentPreview(context, doc),
                    onDelete: _handleDelete,
                    onRegisterPayment: _registerPaymentForInvoice,
                    payingIds: _payingIds,
                    // §CORRECTION — INVOICE DATE ÉDITABLE DANS "SCAN
                    // DOCUMENTS" (2026-09-01) : mêmes callbacks que "Sage
                    // Documents" ci-dessus — même endpoint PATCH
                    // /invoices/:id, même mise à jour locale de `_invoices`
                    // (donc des DEUX sections à la fois), jamais une
                    // deuxième implémentation.
                    onInvoiceDateSave: _saveInvoiceDate,
                    onInvoiceDateSaved: _applyUpdatedInvoice,
                    // §MODIFICATION — FACTURED SHIPMENTS / SCAN DOCUMENTS
                    // (INCLUDE EXPORT) : PLUSIEURS DOCUMENTS PAR LIGNE
                    // (2026-09-02) — mêmes méthodes `FinanceService` que
                    // ci-dessus, appliquées au MÊME `_invoices` via
                    // `_applyUpdatedInvoiceSilently` (donc reflétées
                    // instantanément dans les DEUX sections, sans jamais
                    // recharger toute la page — §14 du ticket).
                    onAddDocuments: FinanceService.instance.addInvoiceDocuments,
                    onDeleteDocument: FinanceService.instance.deleteInvoiceDocument,
                    onInvoiceUpdated: _applyUpdatedInvoiceSilently,
                  ),
                ],
              ],
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

// §CORRECTION — WORKFLOW OCR FACTURED SHIPMENTS (2026-08-31) : table dédiée
// à la section "Export" — Document name/File type/File size/Upload date/
// Invoice date/Uploaded by/Actions (View/Delete), même structure que
// `_ShipmentsRequiringExtractionTable` (Customer Shipments) et la section
// "Export" de Inflow of raw materials. "View" ouvre l'aperçu du document
// brut (showFinanceDocumentPreview, déjà utilisé ailleurs) — jamais une
// deuxième implémentation de viewer. "Delete" réutilise le même
// _handleDelete que le tableau principal (suppression réelle de la
// facture, jamais un simple retrait de document isolé).
class _ExportDocumentsTable extends StatelessWidget {
  final List<FinanceInvoiceModel> invoices;
  final ValueChanged<FinanceDocumentModel> onView;
  final ValueChanged<FinanceInvoiceModel> onDelete;
  // §MODIFICATION — REGISTER PAYMENT DEPUIS SCAN DOCUMENTS (2026-08-31) :
  // permet de régler directement une facture depuis cette section, sans
  // passer par "View" — réutilise le MÊME dialogue/service que le bouton
  // "Register payment" de la fiche facture (showRegisterPaymentDialog +
  // FinanceService.registerPayment), jamais une deuxième implémentation.
  final ValueChanged<FinanceInvoiceModel> onRegisterPayment;
  // §CORRECTION — FACTURED SHIPMENTS / PAID INVOICES (2026-09-01, §7 du
  // ticket) : "pendant l'appel API, bouton disabled + loading" — le
  // garde-fou réel contre le double POST vit dans l'écran parent
  // (`_payingIds`, voir _registerPaymentForInvoice), ceci n'est QUE le
  // retour visuel correspondant.
  final Set<String> payingIds;
  // §CORRECTION — INVOICE DATE ÉDITABLE DANS "SCAN DOCUMENTS" (2026-09-01) :
  // mêmes callbacks que `FinanceInvoicesTable.onInvoiceDateSave`/
  // `onInvoiceDateSaved` ("Sage Documents") — le PATCH réel vit dans
  // FinanceService, jamais recalculé ici.
  final Future<FinanceInvoiceModel> Function(String id, DateTime newDate) onInvoiceDateSave;
  final ValueChanged<FinanceInvoiceModel> onInvoiceDateSaved;
  // §MODIFICATION — FACTURED SHIPMENTS / SCAN DOCUMENTS (INCLUDE EXPORT) :
  // PLUSIEURS DOCUMENTS PAR LIGNE (2026-09-02) — une ligne (une facture) peut
  // désormais avoir PLUSIEURS documents associés (jamais une nouvelle ligne
  // créée, §12 du ticket) : `onAddDocuments` ajoute N fichier(s) à la
  // facture EXISTANTE, `onDeleteDocument` supprime UN SEUL document sans
  // toucher aux autres (§6), `onInvoiceUpdated` répercute la facture à jour
  // (renvoyée par le backend) dans `_invoices` côté écran parent.
  final Future<FinanceInvoiceModel> Function(String invoiceId, List<FinancePickedFile> files) onAddDocuments;
  final Future<FinanceInvoiceModel> Function(String invoiceId, String documentId) onDeleteDocument;
  final ValueChanged<FinanceInvoiceModel> onInvoiceUpdated;

  const _ExportDocumentsTable({
    required this.invoices,
    required this.onView,
    required this.onDelete,
    required this.onRegisterPayment,
    required this.payingIds,
    required this.onInvoiceDateSave,
    required this.onInvoiceDateSaved,
    required this.onAddDocuments,
    required this.onDeleteDocument,
    required this.onInvoiceUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Une facture dont l'extraction a échoué peut, en théorie, n'avoir aucun
    // document rattaché (upload interrompu) — jamais affichée dans ce cas
    // plutôt que de deviner un nom de fichier.
    final entries = [for (final inv in invoices) if (inv.documents.isNotEmpty) (invoice: inv, doc: inv.documents.first)];

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text(t.translate('Aucun document'), style: tInter(fontSize: 13, color: kCrmTextSub))),
      );
    }
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
            columnSpacing: 22,
            columns: [
              DataColumn(label: Text(t.translate('Document name'))),
              DataColumn(label: Text(t.translate('File type'))),
              DataColumn(label: Text(t.translate('File size'))),
              DataColumn(label: Text(t.translate('Upload date'))),
              DataColumn(label: Text(t.translate('Invoice date'))),
              DataColumn(label: Text(t.translate('Uploaded by'))),
              DataColumn(label: Text(t.translate('Register Payment'))),
              DataColumn(label: Text(t.translate('Actions'))),
            ],
            rows: [
              for (final e in entries)
                DataRow(
                  color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.hovered) ? kCrmPrimary.withOpacity(0.04) : null),
                  onSelectChanged: (_) => onView(e.doc),
                  cells: [
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_iconFor(e.doc), size: 16, color: kCrmPrimary),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(e.doc.originalName,
                            style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      // §MODIFICATION — FACTURED SHIPMENTS / SCAN DOCUMENTS
                      // (INCLUDE EXPORT) : PLUSIEURS DOCUMENTS PAR LIGNE
                      // (2026-09-02, §1/§13 du ticket) — "+N" quand la ligne a
                      // plus d'un document, MÊME style de puce que
                      // `_ExportOrdersTable`/`_ShipmentsRequiringExtractionTable`
                      // — jamais une deuxième ligne créée pour ces fichiers
                      // supplémentaires.
                      if (e.invoice.documents.length > 1) ...[
                        const SizedBox(width: 4),
                        Text('+${e.invoice.documents.length - 1} ${t.translate('more')}',
                            style: tInter(fontSize: 11, color: kCrmTextSub)),
                      ],
                    ])),
                    DataCell(Text(e.doc.extension.toUpperCase().isEmpty ? '—' : e.doc.extension.toUpperCase())),
                    DataCell(Text(formatFinanceFileSize(e.doc.fileSize))),
                    DataCell(Text(_dateTimeFmt(e.doc.createdAt))),
                    // §CORRECTION — INVOICE DATE ÉDITABLE DANS "SCAN
                    // DOCUMENTS" (2026-09-01) : même widget PUBLIC
                    // `InvoiceDateCell` que "Sage Documents"
                    // (finance_invoices_table.dart) — jamais une deuxième
                    // implémentation. "Date not defined" si absente, crayon
                    // ✎, DatePicker → PATCH /invoices/:id existant → mise à
                    // jour immédiate de la ligne sans F5.
                    DataCell(
                      InvoiceDateCell(
                        key: ValueKey('export-invoice-date-${e.invoice.id}-${e.invoice.invoiceDate}'),
                        invoice: e.invoice,
                        onSave: onInvoiceDateSave,
                        onSaved: onInvoiceDateSaved,
                      ),
                    ),
                    DataCell(Text(e.doc.uploader?.email ?? '—')),
                    DataCell(Builder(builder: (context) {
                      // §7 du ticket : "pendant l'appel API → bouton disabled
                      // → loading" — `payingIds` (état du parent) pilote ce
                      // seul retour visuel, le vrai garde-fou anti-double-clic
                      // vit dans _registerPaymentForInvoice.
                      final isPaying = payingIds.contains(e.invoice.id);
                      return OutlinedButton.icon(
                        onPressed: isPaying ? null : () => onRegisterPayment(e.invoice),
                        icon: isPaying
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.payments_outlined, size: 15),
                        label: Text(t.translate('Register Payment'), style: tInter(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kFinanceColor,
                          side: const BorderSide(color: kFinanceColor),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      );
                    })),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      // §MODIFICATION — FACTURED SHIPMENTS / SCAN DOCUMENTS
                      // (INCLUDE EXPORT) : PLUSIEURS DOCUMENTS PAR LIGNE
                      // (2026-09-02, §2 du ticket) — "Upload" ajoute des
                      // fichiers à la MÊME facture (jamais une nouvelle
                      // ligne) ; réutilise TEL QUEL `FinanceUploadDropzone`
                      // (Drag & Drop OS + sélection multi-fichiers déjà en
                      // place) dans une modal dédiée, voir
                      // `_showAddInvoiceDocumentsDialog` plus bas.
                      Tooltip(
                        message: t.translate('Upload'),
                        child: IconButton(
                          icon: const Icon(Icons.upload_outlined, size: 18, color: kCrmPrimary),
                          onPressed: () => _showAddInvoiceDocumentsDialog(context, e.invoice, onAddDocuments, onInvoiceUpdated),
                        ),
                      ),
                      Tooltip(
                        message: t.translate('View'),
                        child: OutlinedButton.icon(
                          // §5 du ticket : un seul document → comportement
                          // actuel inchangé (aperçu direct) ; plusieurs
                          // documents → modal listant chacun individuellement
                          // avec son propre View (jamais un mélange des deux).
                          onPressed: () => e.invoice.documents.length > 1
                              ? _showInvoiceDocumentsDialog(context, e.invoice, onDeleteDocument, onInvoiceUpdated)
                              : onView(e.doc),
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
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: t.translate('Delete'),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kCrmDanger),
                        onPressed: () => onDelete(e.invoice),
                      ),
                    ])),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(FinanceDocumentModel doc) {
    if (doc.isPdf) return Icons.picture_as_pdf_outlined;
    if (doc.isImage) return Icons.image_outlined;
    if (['xls', 'xlsx', 'csv'].contains(doc.extension)) return Icons.grid_on_outlined;
    if (['doc', 'docx'].contains(doc.extension)) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _dateTimeFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy HH:mm').format(d);
  }
}

// §MODIFICATION — FACTURED SHIPMENTS / SCAN DOCUMENTS (INCLUDE EXPORT) :
// PLUSIEURS DOCUMENTS PAR LIGNE (2026-09-02, §5/§6 du ticket) — modal
// "Associated documents" : liste TOUS les documents de la facture, chacun
// avec son propre "View" (showFinanceDocumentPreview, réutilisé tel quel) et
// son propre "Delete" (jamais toute la ligne). Réutilise le widget
// `FinanceDocumentsTable` DÉJÀ existant (partagé avec les fiches détail
// Invoice/Shipment/Purchase Order) plutôt que d'écrire un second tableau de
// documents — même principe que `_OrderDocumentsDialogBody`/
// `_ShipmentDocumentsDialogBody` dans les écrans Inflow/Customer Shipments.
Future<void> _showInvoiceDocumentsDialog(
  BuildContext context,
  FinanceInvoiceModel invoice,
  Future<FinanceInvoiceModel> Function(String invoiceId, String documentId) onDeleteDocument,
  ValueChanged<FinanceInvoiceModel> onInvoiceUpdated,
) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ResponsiveDialogBox(
        width: 820,
        height: 560,
        child: _InvoiceDocumentsDialogBody(invoice: invoice, onDeleteDocument: onDeleteDocument, onInvoiceUpdated: onInvoiceUpdated),
      ),
    ),
  );
}

class _InvoiceDocumentsDialogBody extends StatefulWidget {
  final FinanceInvoiceModel invoice;
  final Future<FinanceInvoiceModel> Function(String invoiceId, String documentId) onDeleteDocument;
  final ValueChanged<FinanceInvoiceModel> onInvoiceUpdated;

  const _InvoiceDocumentsDialogBody({required this.invoice, required this.onDeleteDocument, required this.onInvoiceUpdated});

  @override
  State<_InvoiceDocumentsDialogBody> createState() => _InvoiceDocumentsDialogBodyState();
}

class _InvoiceDocumentsDialogBodyState extends State<_InvoiceDocumentsDialogBody> {
  late List<FinanceDocumentModel> _documents;
  // Même principe que Register Payment (§7 du ticket précédent) : jamais
  // deux suppressions simultanées du même document sur un double-clic rapide.
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _documents = widget.invoice.documents;
  }

  Future<void> _handleDelete(FinanceDocumentModel doc) async {
    if (_deletingIds.contains(doc.id)) return;
    setState(() => _deletingIds.add(doc.id));
    final t = AppLocalizations.of(context);
    try {
      final updated = await widget.onDeleteDocument(widget.invoice.id, doc.id);
      if (!mounted) return;
      // §6 du ticket : seul CE document disparaît de la modal, les autres
      // restent — `updated.documents` (renvoyé par le backend) fait foi,
      // jamais un simple retrait optimiste côté client.
      setState(() => _documents = updated.documents);
      widget.onInvoiceUpdated(updated);
    } catch (e) {
      if (!mounted) return;
      SafeSnack.messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      if (mounted) setState(() => _deletingIds.remove(doc.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          const Icon(Icons.folder_copy_outlined, color: kCrmPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t.translate('Associated documents'),
                style: tInter(fontSize: 14.5, fontWeight: FontWeight.w800, color: kCrmText)),
          ),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FinanceDocumentsTable(
            documents: _documents,
            onView: (doc) => showFinanceDocumentPreview(context, doc),
            onDelete: _handleDelete,
            showStatus: false,
          ),
        ),
      ),
    ]);
  }
}

// §MODIFICATION — FACTURED SHIPMENTS / SCAN DOCUMENTS (INCLUDE EXPORT) :
// PLUSIEURS DOCUMENTS PAR LIGNE (2026-09-02, §2/§3/§4/§15 du ticket) — modal
// "Add documents" : réutilise TEL QUEL `FinanceUploadDropzone` (même Drag &
// Drop OS + sélection multi-fichiers déjà en place pour "Upload invoice",
// voir finance_invoice_upload_dialog.dart) — seul le callback change : les
// fichiers sont ajoutés à la facture EXISTANTE (`onAddDocuments`), jamais une
// nouvelle facture créée.
Future<void> _showAddInvoiceDocumentsDialog(
  BuildContext context,
  FinanceInvoiceModel invoice,
  Future<FinanceInvoiceModel> Function(String invoiceId, List<FinancePickedFile> files) onAddDocuments,
  ValueChanged<FinanceInvoiceModel> onInvoiceUpdated,
) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ResponsiveDialogBox(
        width: 640,
        height: 420,
        child: _AddInvoiceDocumentsDialogBody(invoice: invoice, onAddDocuments: onAddDocuments, onInvoiceUpdated: onInvoiceUpdated),
      ),
    ),
  );
}

class _AddInvoiceDocumentsDialogBody extends StatefulWidget {
  final FinanceInvoiceModel invoice;
  final Future<FinanceInvoiceModel> Function(String invoiceId, List<FinancePickedFile> files) onAddDocuments;
  final ValueChanged<FinanceInvoiceModel> onInvoiceUpdated;

  const _AddInvoiceDocumentsDialogBody({required this.invoice, required this.onAddDocuments, required this.onInvoiceUpdated});

  @override
  State<_AddInvoiceDocumentsDialogBody> createState() => _AddInvoiceDocumentsDialogBodyState();
}

class _AddInvoiceDocumentsDialogBodyState extends State<_AddInvoiceDocumentsDialogBody> {
  bool _busy = false;

  // §15 du ticket : un seul clic → une seule opération d'upload — le bouton
  // du dropzone est lui-même désactivé pendant `_busy` (voir
  // `FinanceUploadDropzone.busy`), donc aucun double-envoi possible tant que
  // la première requête n'est pas terminée.
  Future<void> _handleFilesSelected(List<FinancePickedFile> files) async {
    setState(() => _busy = true);
    final t = AppLocalizations.of(context);
    try {
      final updated = await widget.onAddDocuments(widget.invoice.id, files);
      if (!mounted) return;
      widget.onInvoiceUpdated(updated);
      Navigator.of(context).pop();
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(files.length == 1 ? t.translate('Document déposé') : t.translate('Documents déposés')),
          backgroundColor: kCrmSuccess,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      SafeSnack.messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          const Icon(Icons.upload_file_outlined, color: kCrmPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t.translate('Add documents'),
                style: tInter(fontSize: 14.5, fontWeight: FontWeight.w800, color: kCrmText)),
          ),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: _busy ? null : () => Navigator.of(context).pop()),
        ]),
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FinanceUploadDropzone(onFilesSelected: _handleFilesSelected, busy: _busy),
        ),
      ),
    ]);
  }
}
