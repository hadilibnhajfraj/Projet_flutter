// lib/forms/finance/view/finance_import_screen.dart
//
// "Import" — sous-menu ajouté sous chaque page Finance (MODIFICATION CRM —
// AJOUTER UN SOUS-MENU IMPORT À CHAQUE MENU FINANCE). §PRIORITÉ ABSOLUE du
// ticket : réutiliser EXACTEMENT le même code/composant/logique/UI/upload
// que le module "Other" existant (scan/upload de document, Drag & Drop,
// Browse files, aucun OCR/extraction/mapping/création automatique de
// Purchase Order/Shipment/Invoice — voir finance.service.js#uploadOtherDocument/
// uploadImportDocument) — jamais une seconde implémentation d'upload.
//
// Ce widget EST ce composant commun unique (`FinanceImportScreen`,
// paramétré par `FinanceImportModule` — voir §2/§12 du ticket), utilisé pour
// les 5 destinations :
//   - Other                    → module: FinanceImportModule.other
//   - Inflow of raw materials  → module: FinanceImportModule.rawMaterials
//   - Shipment of products     → module: FinanceImportModule.shipments
//   - Factured shipments       → module: FinanceImportModule.facturedShipments
//   - Paid factures            → module: FinanceImportModule.paidInvoices
// Chaque module transmet son propre `apiSegment` (voir finance.routes.js) —
// le backend range chaque document sous le bon `module` FinanceDocument
// (`entityId` toujours NULL, jamais mélangé avec les pièces jointes réelles
// des Purchase Order/Shipment/Invoice existants ni entre les 5 destinations
// — voir migration 20260827000100 pour Paid factures/Factured shipments,
// qui partagent sinon la même table `finance_invoices`).

import 'dart:html' as html;

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/application/common/safe_snack.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../model/finance_models.dart';
import '../service/finance_service.dart';
import '../theme/finance_theme.dart';
import 'widgets/finance_other_documents_table.dart';
import 'widgets/finance_preview_dialog.dart';
import 'widgets/finance_upload_dropzone.dart';

// Chargement en une fois + filtrage/pagination CÔTÉ CLIENT — même convention
// que les autres écrans de liste Finance : aucun aller-retour réseau
// supplémentaire pendant la recherche/le filtrage.
const int _kFetchAllPageSize = 2000;
const int _kRowsPerPage = 50;

const List<String> _kFileTypes = ['PDF', 'IMAGE', 'WORD', 'EXCEL', 'OTHER'];

/// Les 5 destinations qui exposent ce composant commun — voir le header de
/// ce fichier. Ajouter un module ici + son entrée dans [FinanceImportModuleX]
/// suffit à brancher un nouveau sous-menu "Import", jamais besoin de
/// dupliquer l'écran.
enum FinanceImportModule { rawMaterials, shipments, facturedShipments, paidInvoices, other }

extension FinanceImportModuleX on FinanceImportModule {
  /// Segment d'API — voir les routes dédiées dans finance.routes.js.
  /// "other-documents" (module Other, route déjà existante, INCHANGÉE) vs.
  /// "xxx/import" pour les 4 nouveaux sous-menus.
  String get apiSegment => switch (this) {
        FinanceImportModule.rawMaterials => 'raw-materials/import',
        FinanceImportModule.shipments => 'shipments/import',
        FinanceImportModule.facturedShipments => 'invoices/import',
        FinanceImportModule.paidInvoices => 'paid-invoices/import',
        FinanceImportModule.other => 'other-documents',
      };

  /// Titre affiché en haut de l'écran (§18 du ticket) — "Other" garde son
  /// titre d'origine, inchangé (même écran qu'avant ce ticket).
  String get pageTitle => switch (this) {
        FinanceImportModule.rawMaterials => 'Import — Inflow of raw materials',
        FinanceImportModule.shipments => 'Import — Shipment of products',
        FinanceImportModule.facturedShipments => 'Import — Factured shipments',
        FinanceImportModule.paidInvoices => 'Import — Paid factures',
        FinanceImportModule.other => 'Other Documents',
      };

  String get pageDescription => switch (this) {
        FinanceImportModule.other => 'Scan and store documents without automatic data extraction.',
        _ => 'Scan and store documents for this section without automatic data extraction.',
      };

  /// Préfixe du fichier Excel exporté (§17 — n'affecte pas Export CSV/Excel
  /// des autres écrans de liste Finance, uniquement celui de CET écran).
  String get exportFilePrefix => switch (this) {
        FinanceImportModule.rawMaterials => 'inflow-raw-materials-import',
        FinanceImportModule.shipments => 'shipment-import',
        FinanceImportModule.facturedShipments => 'factured-shipments-import',
        FinanceImportModule.paidInvoices => 'paid-invoices-import',
        FinanceImportModule.other => 'other-documents',
      };
}

class FinanceImportScreen extends StatefulWidget {
  final FinanceImportModule module;
  const FinanceImportScreen({super.key, required this.module});

  @override
  State<FinanceImportScreen> createState() => _FinanceImportScreenState();
}

class _FinanceImportScreenState extends State<FinanceImportScreen> {
  bool _loading = true;
  bool _uploading = false;
  bool _exporting = false;
  String? _error;
  List<FinanceDocumentModel> _documents = const [];
  // Empêche deux requêtes DELETE simultanées sur le même document (double-clic
  // rapide sur 🗑, même garde que les autres écrans Finance).
  final Set<String> _deletingIds = {};

  String _search = '';
  String? _typeFilter; // null = tous ; sinon un des `_kFileTypes`
  DateTime? _startDate;
  DateTime? _endDate;
  int _page = 1;

  String get _apiSegment => widget.module.apiSegment;

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
      final page = await FinanceService.instance.fetchImportDocuments(_apiSegment, pageSize: _kFetchAllPageSize);
      if (!mounted) return;
      setState(() => _documents = page.items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fileTypeOf(FinanceDocumentModel d) {
    if (d.isPdf) return 'PDF';
    if (d.isImage) return 'IMAGE';
    final mime = d.mimeType.toLowerCase();
    if (mime.contains('word') || ['doc', 'docx'].contains(d.extension)) return 'WORD';
    if (mime.contains('excel') || mime.contains('spreadsheet') || ['xls', 'xlsx', 'csv'].contains(d.extension)) return 'EXCEL';
    return 'OTHER';
  }

  String _fileTypeLabel(AppLocalizations t, String type) {
    switch (type) {
      case 'PDF':
        return 'PDF';
      case 'IMAGE':
        return t.translate('Image');
      case 'WORD':
        return t.translate('Word');
      case 'EXCEL':
        return t.translate('Excel');
      default:
        return t.translate('Other');
    }
  }

  List<FinanceDocumentModel> get _filtered {
    final term = _search.trim().toLowerCase();
    return _documents.where((d) {
      if (term.isNotEmpty) {
        final haystack = [d.displayName, d.originalName, _fileTypeOf(d), d.uploader?.email]
            .where((v) => v != null)
            .map((v) => v!.toLowerCase())
            .join(' ');
        if (!haystack.contains(term)) return false;
      }
      if (_typeFilter != null && _fileTypeOf(d) != _typeFilter) return false;
      if (_startDate != null || _endDate != null) {
        final created = d.createdAt == null ? null : DateTime.tryParse(d.createdAt!);
        if (created == null) return false;
        final local = created.toLocal();
        final day = DateTime(local.year, local.month, local.day);
        if (_startDate != null && day.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) return false;
        if (_endDate != null && day.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day))) return false;
      }
      return true;
    }).toList();
  }

  int get _pageCount => (_filtered.length / _kRowsPerPage).ceil().clamp(1, 1 << 30);

  List<FinanceDocumentModel> get _pageRows {
    final start = (_page - 1) * _kRowsPerPage;
    if (start >= _filtered.length) return const [];
    return _filtered.skip(start).take(_kRowsPerPage).toList();
  }

  void _resetFilters() {
    setState(() {
      _search = '';
      _typeFilter = null;
      _startDate = null;
      _endDate = null;
      _page = 1;
    });
  }

  // Upload Document / Scan Document — un simple dépôt de fichier, enregistré
  // tel quel dès la sélection (pas d'étape "Upload" séparée puisqu'il n'y a
  // rien à extraire/valider avant l'envoi) — EXACTEMENT le comportement
  // "Other" (voir header du fichier).
  Future<void> _handleFilesSelected(List<FinancePickedFile> files) async {
    setState(() => _uploading = true);
    var successCount = 0;
    String? lastError;
    for (final file in files) {
      try {
        await FinanceService.instance.uploadImportDocument(_apiSegment, file);
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
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${t.translate('Erreur')} : $lastError'), backgroundColor: kCrmDanger),
      );
    } else if (successCount > 0) {
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(successCount == 1
              ? t.translate('Document uploaded successfully')
              : '$successCount ${t.translate('documents uploaded successfully')}'),
          backgroundColor: kCrmSuccess,
        ),
      );
    }
  }

  // PDF → viewer existant, image → affichage direct, autres formats →
  // téléchargement — comportement déjà fourni par showFinanceDocumentPreview
  // (réutilisé tel quel, jamais recréé).
  Future<void> _handleView(FinanceDocumentModel doc) => showFinanceDocumentPreview(context, doc);

  // Modifie UNIQUEMENT displayName.
  Future<void> _handleRename(FinanceDocumentModel doc) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController(text: doc.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.translate('Edit name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 255,
          decoration: InputDecoration(labelText: t.translate('Document name')),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(t.translate('Cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: kFinanceColor, foregroundColor: Colors.white),
            child: Text(t.translate('Save')),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == doc.displayName) return;

    try {
      final updated = await FinanceService.instance.renameImportDocument(_apiSegment, doc.id, newName);
      if (!mounted) return;
      setState(() => _documents = [for (final d in _documents) if (d.id == doc.id) updated else d]);
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(t.translate('Document renamed successfully')), backgroundColor: kCrmSuccess),
      );
    } catch (e) {
      if (!mounted) return;
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger),
      );
    }
  }

  // Suppression réelle (DB + fichier physique, voir
  // finance.service.js#deleteImportDocument) — jamais un simple retrait
  // optimiste, la ligne n'est retirée qu'après confirmation backend.
  Future<void> _handleDelete(FinanceDocumentModel doc) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      // IMPORTANT : jamais le `context` de l'écran englobant ici — voir
      // finance_inflow_raw_materials_screen.dart#_handleDelete pour
      // l'explication complète (Navigator de branche go_router vs Navigator
      // racine sur lequel `showDialog` empile réellement ce dialogue).
      builder: (dialogContext) => AlertDialog(
        title: Text(t.translate('Delete document?')),
        content: Text(t.translate('This document will be permanently deleted.')),
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
    if (_deletingIds.contains(doc.id)) return;
    _deletingIds.add(doc.id);
    try {
      await FinanceService.instance.deleteImportDocument(_apiSegment, doc.id);
      if (!mounted) return;
      setState(() => _documents = _documents.where((d) => d.id != doc.id).toList());
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(t.translate('Document deleted successfully')), backgroundColor: kCrmSuccess),
      );
    } catch (e) {
      if (!mounted) return;
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger),
      );
    } finally {
      _deletingIds.remove(doc.id);
    }
  }

  // Uniquement les métadonnées (jamais le contenu binaire du document) —
  // §17 : n'affecte jamais les Export CSV/Excel des autres écrans Finance.
  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      final rows = _filtered;
      final excelFile = xl.Excel.createExcel();
      const sheetName = 'Import';
      final sheet = excelFile[sheetName];
      excelFile.setDefaultSheet(sheetName);

      const headers = ['Document name', 'Original name', 'File type', 'Size', 'Uploaded by', 'Upload date', 'Updated date'];
      for (int col = 0; col < headers.length; col++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          ..value = headers[col]
          ..cellStyle = xl.CellStyle(bold: true, backgroundColorHex: '#EEF2FF', fontColorHex: '#1E293B');
      }

      for (int ri = 0; ri < rows.length; ri++) {
        final d = rows[ri];
        final values = <dynamic>[
          d.displayName,
          d.originalName,
          _fileTypeOf(d),
          formatFinanceFileSize(d.fileSize),
          d.uploader?.email ?? '',
          _dateFmt(d.createdAt),
          _dateFmt(d.updatedAt),
        ];
        for (int col = 0; col < values.length; col++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: ri + 1)).value = values[col];
        }
      }

      const widths = <int, double>{0: 34, 1: 30, 2: 12, 3: 12, 4: 26, 5: 14, 6: 14};
      for (int col = 0; col < headers.length; col++) {
        sheet.setColWidth(col, widths[col] ?? 16);
      }

      final bytes = excelFile.encode();
      if (bytes == null) throw Exception('Échec de la génération du fichier Excel');
      final fileName = '${widget.module.exportFilePrefix}-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
      _downloadBytes(bytes, fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

      if (!mounted) return;
      final t = AppLocalizations.of(context);
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${t.translate('Export terminé')} · $fileName'), backgroundColor: kCrmSuccess),
      );
    } catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      SafeSnack.messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${t.translate('Erreur')} : $e'), backgroundColor: kCrmDanger),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _downloadBytes(List<int> bytes, String name, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', name)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _dateFmt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd/MM/yyyy').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final filteredRows = _filtered;
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // §16 : Row + Wrap — le bouton Export passe sous le titre sur
              // mobile plutôt que de forcer une largeur trop étroite (voir
              // aussi §RESPONSIVE — MISSION CRM RESPONSIVE, même règle que
              // les autres écrans Finance).
              LayoutBuilder(builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 560;
                final header = Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: kFinanceColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.folder_outlined, size: 22, color: kFinanceColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.translate(widget.module.pageTitle),
                          style: tInter(fontSize: 21, fontWeight: FontWeight.w800, color: kCrmText)),
                      const SizedBox(height: 2),
                      Text(t.translate(widget.module.pageDescription), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                    ]),
                  ),
                ]);
                final exportBtn = ElevatedButton.icon(
                  onPressed: _exporting || filteredRows.isEmpty ? null : _exportExcel,
                  icon: _exporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(t.translate('Export Excel')),
                  style: ElevatedButton.styleFrom(backgroundColor: kFinanceColor, foregroundColor: Colors.white),
                );
                if (isNarrow) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    header,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: exportBtn),
                  ]);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: header), exportBtn]);
              }),
              const SizedBox(height: 22),
              FinanceUploadDropzone(onFilesSelected: _handleFilesSelected, busy: _uploading),
              const SizedBox(height: 26),
              // ── Recherche + filtres ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
                child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(
                    width: 260,
                    child: _filterField(
                      hint: t.translate('Search documents'),
                      icon: Icons.search_rounded,
                      value: _search,
                      onChanged: (v) => setState(() {
                        _search = v;
                        _page = 1;
                      }),
                    ),
                  ),
                  _typeChip(t, null, t.translate('All types')),
                  for (final type in _kFileTypes) _typeChip(t, type, _fileTypeLabel(t, type)),
                  _datePickerChip(
                    label: t.translate('Date début'),
                    value: _startDate,
                    onPicked: (d) => setState(() {
                      _startDate = d;
                      _page = 1;
                    }),
                  ),
                  _datePickerChip(
                    label: t.translate('Date fin'),
                    value: _endDate,
                    onPicked: (d) => setState(() {
                      _endDate = d;
                      _page = 1;
                    }),
                  ),
                  TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: kCrmTextSub),
                    label: Text(t.translate('Réinitialiser'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Text('${filteredRows.length} ${t.translate('line(s)')}', style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
              const SizedBox(height: 14),
              if (_error != null)
                _buildError(t)
              else if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
              else ...[
                FinanceOtherDocumentsTable(
                  documents: _pageRows,
                  onView: _handleView,
                  onRename: _handleRename,
                  onDelete: _handleDelete,
                ),
                if (filteredRows.length > _kRowsPerPage) ...[
                  const SizedBox(height: 14),
                  _buildPagination(t),
                ],
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _typeChip(AppLocalizations t, String? type, String label) {
    final selected = _typeFilter == type;
    return ChoiceChip(
      label: Text(label, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : kCrmText)),
      selected: selected,
      selectedColor: kFinanceColor,
      backgroundColor: kCrmBg,
      side: BorderSide(color: selected ? kFinanceColor : kCrmBorder),
      onSelected: (_) => setState(() {
        _typeFilter = type;
        _page = 1;
      }),
    );
  }

  Widget _filterField({required String hint, IconData? icon, required String value, required ValueChanged<String> onChanged}) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      style: tInter(fontSize: 13, color: kCrmText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: tInter(fontSize: 12, color: kCrmTextSub),
        prefixIcon: icon == null ? null : Icon(icon, size: 18, color: kCrmTextSub),
        isDense: true,
        filled: true,
        fillColor: kCrmBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmBorder)),
      ),
    );
  }

  Widget _datePickerChip({required String label, required DateTime? value, required ValueChanged<DateTime> onPicked}) {
    return InkWell(
      onTap: () async {
        final picked =
            await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: kCrmTextSub),
          const SizedBox(width: 6),
          Text(value == null ? label : DateFormat('dd/MM/yyyy').format(value),
              style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText)),
        ]),
      ),
    );
  }

  Widget _buildPagination(AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: _page > 1 ? () => setState(() => _page--) : null),
        Text('${t.translate('Page')} $_page / $_pageCount', style: tInter(fontSize: 12.5, color: kCrmTextSub)),
        IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: _page < _pageCount ? () => setState(() => _page++) : null),
      ]),
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
