// lib/forms/finance/view/finance_inflow_raw_materials_screen.dart
//
// "Inflow of raw materials" — dépôt (Drag & Drop + Scan document) d'un Bon
// de Commande, lu automatiquement par OCR à l'upload (§CORRECTION —
// EXTRACTION AUTOMATIQUE DES BONS DE COMMANDE : numéro, client, adresse de
// livraison, lignes produit, total HT) et consultation des bons extraits.

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../model/finance_models.dart';
import '../service/finance_service.dart';
import '../theme/finance_theme.dart';
import 'widgets/finance_documents_table.dart';
import 'widgets/finance_preview_dialog.dart';
import 'widgets/finance_purchase_order_detail_dialog.dart';
import 'widgets/finance_purchase_orders_table.dart';
import 'widgets/finance_upload_dropzone.dart';

class FinanceInflowRawMaterialsScreen extends StatefulWidget {
  const FinanceInflowRawMaterialsScreen({super.key});

  @override
  State<FinanceInflowRawMaterialsScreen> createState() => _FinanceInflowRawMaterialsScreenState();
}

class _FinanceInflowRawMaterialsScreenState extends State<FinanceInflowRawMaterialsScreen> {
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  String _search = '';
  List<FinancePurchaseOrderModel> _orders = const [];

  // Un document dont l'OCR a échoué (aucun numéro détecté) n'est pas un
  // Purchase Order valide — voir FinancePurchaseOrderModel.isExtractionFailed.
  List<FinancePurchaseOrderModel> get _validOrders => _orders.where((o) => !o.isExtractionFailed).toList();
  List<FinancePurchaseOrderModel> get _failedOrders => _orders.where((o) => o.isExtractionFailed).toList();

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
      final page = await FinanceService.instance.fetchRawMaterials(search: _search, pageSize: 200);
      if (!mounted) return;
      setState(() => _orders = page.items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // "Inflow of raw materials" upload = 1 fichier = 1 Bon de Commande, lu
  // indépendamment par OCR (même principe que "Upload invoice") — une boucle
  // par fichier sélectionné, le dropzone peut recevoir plusieurs fichiers.
  Future<void> _handleFilesSelected(List<FinancePickedFile> files) async {
    setState(() => _uploading = true);
    var successCount = 0;
    String? lastError;
    FinancePurchaseOrderModel? lastOrder;
    for (final file in files) {
      try {
        lastOrder = await FinanceService.instance.uploadRawMaterial(file);
        successCount++;
      } catch (e) {
        lastError = e.toString();
      }
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    if (successCount > 0) await _load();
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    if (lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.translate('Erreur')} : $lastError'), backgroundColor: kCrmDanger),
      );
    } else if (successCount == 1 && lastOrder != null) {
      // Un seul fichier traité : ouvre directement la fiche extraite, comme
      // "Upload invoice" le fait déjà pour les factures.
      showFinancePurchaseOrderDetail(context, lastOrder);
    } else if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successCount == 1 ? t.translate('Document déposé') : t.translate('Documents déposés')),
          backgroundColor: kCrmSuccess,
        ),
      );
    }
  }

  Future<void> _handleView(FinancePurchaseOrderModel order) async {
    await showFinancePurchaseOrderDetail(context, order);
  }

  // Suppression réelle côté backend (§AJOUTER LA SUPPRESSION DES DOCUMENTS
  // FINANCE) — confirmation via le Modal existant (AlertDialog), jamais
  // window.confirm().
  Future<void> _handleDelete(FinancePurchaseOrderModel order) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      // IMPORTANT : ne JAMAIS utiliser le `context` de l'écran englobant pour
      // fermer ce dialogue — avec la navigation par shell/branches de
      // go_router, ce `context` peut résoudre vers le Navigator INTERNE de la
      // branche courante (qui n'a qu'UNE seule page), pas vers le Navigator
      // racine sur lequel `showDialog` a réellement empilé ce dialogue.
      // `Navigator.of(context).pop()` viderait alors la pile de la branche
      // ("You have popped the last page off of the stack"). Utiliser
      // systématiquement le contexte PROPRE du builder du dialogue.
      builder: (dialogContext) => AlertDialog(
        title: Text(t.translate('Delete this purchase order?')),
        content: Text(t.translate('Are you sure you want to delete this purchase order and its associated documents?')),
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
      await FinanceService.instance.deleteRawMaterial(order.id);
      if (!mounted) return;
      setState(() => _orders = _orders.where((o) => o.id != order.id).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate('Purchase order deleted successfully')), backgroundColor: kCrmSuccess),
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
                  child: const Icon(Icons.inventory_2_outlined, size: 22, color: kFinanceColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.translate('Inflow of raw materials'), style: tInter(fontSize: 21, fontWeight: FontWeight.w800, color: kCrmText)),
                    const SizedBox(height: 2),
                    Text(t.translate('Deposit and review raw material documents.'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  ]),
                ),
              ]),
              const SizedBox(height: 22),
              FinanceUploadDropzone(onFilesSelected: _handleFilesSelected, busy: _uploading),
              const SizedBox(height: 26),
              Row(children: [
                Expanded(
                  child: Text('${_validOrders.length} ${t.translate('purchase order(s)')}',
                      style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
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
                      hintText: t.translate('Order number / Customer'),
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
              else ...[
                // Un document dont l'OCR a échoué (numéro/client/produits/
                // total tous absents) n'est PAS un Purchase Order valide —
                // ne jamais l'afficher avec "Order # = —" dans le tableau
                // principal (§CORRIGER LES PROBLÈMES ACTUELS DU MODULE
                // FINANCE). Il reste consultable/supprimable séparément.
                FinancePurchaseOrdersTable(orders: _validOrders, onView: _handleView, onDelete: _handleDelete),
                if (_failedOrders.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(t.translate('Documents requiring extraction'),
                      style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: kCrmText)),
                  const SizedBox(height: 4),
                  Text(t.translate('These files could not be read automatically. You can still view or delete them.'),
                      style: tInter(fontSize: 12, color: kCrmTextSub)),
                  const SizedBox(height: 10),
                  FinanceDocumentsTable(
                    documents: [for (final o in _failedOrders) if (o.documents.isNotEmpty) o.documents.first],
                    onView: (doc) => showFinanceDocumentPreview(context, doc),
                    onDelete: (doc) {
                      final order = _failedOrders.firstWhere((o) => o.documents.isNotEmpty && o.documents.first.id == doc.id);
                      _handleDelete(order);
                    },
                    showStatus: false,
                  ),
                ],
              ],
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
