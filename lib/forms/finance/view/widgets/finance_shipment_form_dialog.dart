// lib/forms/finance/view/widgets/finance_shipment_form_dialog.dart
//
// "+ New shipment" — SIMPLIFIÉ : ce modal ne contient plus que la zone
// "Supporting Documents" (Drag & Drop + Browse files + Scan document).
// Reference / Customer / Products / Quantity / Unit / Amount / Delivery
// information ont été retirés à la demande explicite de l'utilisateur.
//
// Lecture automatique du Bon de Livraison (OCR) : le backend LIT réellement
// le premier document (POST /finance/shipments, voir
// finance.service.js#processShipmentUpload — transaction atomique Shipment
// + lignes produit + documents, jamais l'un sans l'autre) et renvoie un
// Shipment déjà rempli de données réelles. Ce modal envoie tous les
// fichiers sélectionnés en UN SEUL appel, affiche la séquence "Document
// uploaded" → "Reading document..." → "Document analyzed", puis ferme et
// signale au parent d'ouvrir la fiche Shipment créée.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../model/finance_models.dart';
import '../../service/finance_service.dart';
import '../../theme/finance_theme.dart';
import 'finance_preview_dialog.dart';
import 'finance_upload_dropzone.dart';

// Renvoie le Shipment créé, ou `null` si l'utilisateur a annulé — laisse
// l'appelant décider quoi faire ensuite (ouvrir la fiche, rafraîchir).
Future<FinanceShipmentModel?> showNewShipmentDialog(BuildContext context) {
  return showDialog<FinanceShipmentModel?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog(
      insetPadding: EdgeInsets.all(24),
      child: SizedBox(width: 720, height: 620, child: _FinanceShipmentForm()),
    ),
  );
}

class _StagedShipmentFile {
  final FinancePickedFile picked;
  final DateTime addedAt = DateTime.now();
  _StagedShipmentFile(this.picked);
}

String _extensionOf(String filename) {
  final dot = filename.lastIndexOf('.');
  return dot == -1 ? '' : filename.substring(dot + 1).toLowerCase();
}

IconData _iconForFilename(String filename) {
  final ext = _extensionOf(filename);
  if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
  if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) return Icons.image_outlined;
  if (['xls', 'xlsx', 'csv'].contains(ext)) return Icons.grid_on_outlined;
  if (['doc', 'docx'].contains(ext)) return Icons.description_outlined;
  return Icons.insert_drive_file_outlined;
}

class _FinanceShipmentForm extends StatefulWidget {
  const _FinanceShipmentForm();

  @override
  State<_FinanceShipmentForm> createState() => _FinanceShipmentFormState();
}

enum _UploadStage { idle, uploading, uploaded, reading, extracting, analyzed }

class _FinanceShipmentFormState extends State<_FinanceShipmentForm> {
  final List<_StagedShipmentFile> _staged = [];
  bool _saving = false;
  _UploadStage _stage = _UploadStage.idle;
  double _progress = 0;
  String? _error;

  void _handleFilesSelected(List<FinancePickedFile> files) {
    setState(() {
      _staged.addAll(files.map((f) => _StagedShipmentFile(f)));
      _error = null;
    });
  }

  void _handleRemoveStaged(_StagedShipmentFile f) {
    if (_saving) return;
    setState(() => _staged.remove(f));
  }

  Future<void> _handleViewStaged(_StagedShipmentFile f) {
    return showLocalFilePreview(context, bytes: f.picked.bytes, filename: f.picked.filename);
  }

  Future<void> _submitUpload() async {
    if (_staged.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).translate('Add at least one document'));
      return;
    }
    setState(() {
      _saving = true;
      _stage = _UploadStage.uploading;
      _error = null;
      _progress = 0;
    });

    try {
      final shipment = await FinanceService.instance.createShipment(
        documents: _staged.map((f) => f.picked).toList(),
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            // Séquence "Document uploaded" → "Reading document..." →
            // "Extracting information..." : le transfert réseau se termine
            // bien avant la fin de l'OCR côté serveur, donc chaque étape
            // reste affichée quelques centaines de ms (perceptible) avant de
            // basculer — sans jamais bloquer l'attente de la vraie réponse
            // HTTP (si elle arrive plus tôt, la séquence s'arrête là où
            // elle en est et passe directement à "Document analyzed").
            if (p >= 1 && _stage == _UploadStage.uploading) {
              _stage = _UploadStage.uploaded;
              Future.delayed(const Duration(milliseconds: 700), () {
                if (mounted && _stage == _UploadStage.uploaded) {
                  setState(() => _stage = _UploadStage.reading);
                  Future.delayed(const Duration(milliseconds: 900), () {
                    if (mounted && _stage == _UploadStage.reading) setState(() => _stage = _UploadStage.extracting);
                  });
                }
              });
            }
          });
        },
      );
      if (!mounted) return;

      // "Document analyzed successfully" — état bref mais visible avant de
      // fermer, pour que les étapes annoncées soient réellement perceptibles.
      setState(() => _stage = _UploadStage.analyzed);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.translate('Shipment created successfully')} — ${shipment.reference}'),
          backgroundColor: kCrmSuccess,
        ),
      );
      Navigator.of(context).pop(shipment);
    } catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      setState(() {
        _saving = false;
        _stage = _UploadStage.idle;
        _error = '${t.translate('Erreur')} : $e';
      });
    }
  }

  String? _stageLabel(AppLocalizations t) {
    switch (_stage) {
      case _UploadStage.uploaded:
        return t.translate('Document uploaded');
      case _UploadStage.reading:
        return t.translate('Reading document...');
      case _UploadStage.extracting:
        return t.translate('Extracting information...');
      case _UploadStage.analyzed:
        return t.translate('Document analyzed successfully');
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          const Icon(Icons.local_shipping_outlined, color: kFinanceColor),
          const SizedBox(width: 10),
          Expanded(child: Text(t.translate('New shipment'), style: tInter(fontSize: 15.5, fontWeight: FontWeight.w800, color: kCrmText))),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: _saving ? null : () => Navigator.of(context).pop(null)),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.translate('Supporting documents'), style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
            const SizedBox(height: 8),
            FinanceUploadDropzone(onFilesSelected: _handleFilesSelected, busy: _saving),
            if (_staged.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildStagedList(t),
            ],
            if (_saving) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _stage == _UploadStage.uploading && _progress > 0 ? _progress : null,
                  minHeight: 6,
                  backgroundColor: kCrmBg,
                ),
              ),
              if (_stageLabel(t) != null) ...[
                const SizedBox(height: 8),
                Text(_stageLabel(t)!, style: tInter(fontSize: 12, color: kCrmTextSub)),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: tInter(fontSize: 12.5, color: kCrmDanger)),
            ],
          ]),
        ),
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: kCrmBorder))),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton(onPressed: _saving ? null : () => Navigator.of(context).pop(null), child: Text(t.translate('Annuler'))),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: (_saving || _staged.isEmpty) ? null : _submitUpload,
            style: ElevatedButton.styleFrom(backgroundColor: kFinanceColor, foregroundColor: Colors.white),
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(t.translate('Upload')),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildStagedList(AppLocalizations t) {
    return Container(
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < _staged.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: kCrmBorder),
          _buildStagedRow(t, _staged[i]),
        ],
      ]),
    );
  }

  Widget _buildStagedRow(AppLocalizations t, _StagedShipmentFile f) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Icon(_iconForFilename(f.picked.filename), size: 18, color: kCrmPrimary),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Text(f.picked.filename,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText)),
        ),
        Expanded(
          flex: 1,
          child: Text(_extensionOf(f.picked.filename).toUpperCase().isEmpty ? '—' : _extensionOf(f.picked.filename).toUpperCase(),
              style: tInter(fontSize: 11.5, color: kCrmTextSub)),
        ),
        Expanded(flex: 1, child: Text(formatFinanceFileSize(f.picked.bytes.length), style: tInter(fontSize: 11.5, color: kCrmTextSub))),
        Expanded(flex: 2, child: Text(DateFormat('dd/MM/yyyy HH:mm').format(f.addedAt), style: tInter(fontSize: 11.5, color: kCrmTextSub))),
        IconButton(
          tooltip: t.translate('View'),
          icon: const Icon(Icons.visibility_outlined, size: 18, color: kCrmPrimary),
          onPressed: () => _handleViewStaged(f),
        ),
        IconButton(
          tooltip: t.translate('Delete'),
          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kCrmDanger),
          onPressed: _saving ? null : () => _handleRemoveStaged(f),
        ),
      ]),
    );
  }
}
