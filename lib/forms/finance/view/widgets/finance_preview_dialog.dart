// lib/forms/finance/view/widgets/finance_preview_dialog.dart
//
// Action "VIEW" — aperçu EN LIGNE (jamais un simple téléchargement) :
//   • PDF    → PdfPreview (package:printing, déjà une dépendance de l'app —
//              jusqu'ici utilisé uniquement pour l'export/impression,
//              nouvelle utilisation ici en mode "affichage").
//   • Image  → Image.network.
//   • Autre  → fiche info + bouton "Ouvrir dans un nouvel onglet" (même
//              pattern launchUrl que project_timeline_screen.dart#_openFile
//              — aucun format ne peut être prévisualisé nativement par le
//              navigateur au-delà de PDF/image).

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/providers/api_client.dart';

import '../../model/finance_models.dart';
import '../../service/finance_service.dart';

Future<void> showFinanceDocumentPreview(BuildContext context, FinanceDocumentModel doc) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 900,
        height: 700,
        child: _FinancePreviewBody(doc: doc),
      ),
    ),
  );
}

class _FinancePreviewBody extends StatelessWidget {
  final FinanceDocumentModel doc;
  const _FinancePreviewBody({required this.doc});

  String get _absoluteUrl {
    final base = ApiClient.instance.dio.options.baseUrl;
    if (doc.fileUrl.startsWith('http')) return doc.fileUrl;
    return '$base${doc.fileUrl}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          const Icon(Icons.description_outlined, color: kCrmPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(doc.originalName,
                style: tInter(fontSize: 14.5, fontWeight: FontWeight.w800, color: kCrmText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
      Expanded(child: _buildContent(context, t)),
    ]);
  }

  Widget _buildContent(BuildContext context, AppLocalizations t) {
    if (doc.isPdf) {
      return PdfPreview(
        build: (format) => FinanceService.instance.fetchFileBytes(doc.fileUrl),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        useActions: true,
        pdfFileName: doc.originalName,
      );
    }
    if (doc.isImage) {
      return Container(
        color: kCrmBg,
        alignment: Alignment.center,
        child: InteractiveViewer(
          child: Image.network(_absoluteUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _unavailable(t)),
        ),
      );
    }
    return _fallbackInfo(context, t);
  }

  Widget _unavailable(AppLocalizations t) => Center(
        child: Text(t.translate('Aperçu indisponible'), style: tInter(fontSize: 13, color: kCrmTextSub)),
      );

  Widget _fallbackInfo(BuildContext context, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.insert_drive_file_outlined, size: 56, color: kCrmTextSub),
          const SizedBox(height: 16),
          Text(doc.originalName, style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: kCrmText), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            '${doc.extension.toUpperCase()} · ${formatFinanceFileSize(doc.fileSize)}',
            style: tInter(fontSize: 12.5, color: kCrmTextSub),
          ),
          const SizedBox(height: 8),
          Text(
            t.translate("Ce type de fichier ne peut pas être prévisualisé directement. Ouvrez-le dans un nouvel onglet."),
            style: tInter(fontSize: 12.5, color: kCrmTextSub),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(_absoluteUrl), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank'),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(t.translate('Open in new tab')),
          ),
        ]),
      ),
    );
  }
}

// Aperçu d'un fichier PAS ENCORE uploadé (bytes locaux, `dart:html`
// FileReader — voir finance_upload_dropzone.dart) — utilisé par le modal
// "New shipment" simplifié, dont la liste de documents sélectionnés n'a pas
// encore d'id/URL serveur tant que l'utilisateur n'a pas cliqué "Upload".
// Même logique PDF/Image/fallback que showFinanceDocumentPreview ci-dessus,
// sans dépendre d'un FinanceDocumentModel serveur.
Future<void> showLocalFilePreview(BuildContext context, {required Uint8List bytes, required String filename}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(width: 900, height: 700, child: _LocalPreviewBody(bytes: bytes, filename: filename)),
    ),
  );
}

class _LocalPreviewBody extends StatelessWidget {
  final Uint8List bytes;
  final String filename;
  const _LocalPreviewBody({required this.bytes, required this.filename});

  String get _extension {
    final dot = filename.lastIndexOf('.');
    return dot == -1 ? '' : filename.substring(dot + 1).toLowerCase();
  }

  bool get _isPdf => _extension == 'pdf';
  bool get _isImage => ['jpg', 'jpeg', 'png', 'webp'].contains(_extension);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          const Icon(Icons.description_outlined, color: kCrmPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(filename,
                style: tInter(fontSize: 14.5, fontWeight: FontWeight.w800, color: kCrmText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
      Expanded(child: _buildContent(context, t)),
    ]);
  }

  Widget _buildContent(BuildContext context, AppLocalizations t) {
    if (_isPdf) {
      return PdfPreview(
        build: (format) async => bytes,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        useActions: true,
        pdfFileName: filename,
      );
    }
    if (_isImage) {
      return Container(
        color: kCrmBg,
        alignment: Alignment.center,
        child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
      );
    }
    return _fallbackInfo(t);
  }

  Widget _fallbackInfo(AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.insert_drive_file_outlined, size: 56, color: kCrmTextSub),
          const SizedBox(height: 16),
          Text(filename, style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: kCrmText), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('${_extension.toUpperCase()} · ${formatFinanceFileSize(bytes.length)}', style: tInter(fontSize: 12.5, color: kCrmTextSub)),
          const SizedBox(height: 8),
          Text(
            t.translate('Ce type de fichier ne peut pas être prévisualisé directement. Téléchargez-le pour l\'ouvrir.'),
            style: tInter(fontSize: 12.5, color: kCrmTextSub),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _downloadBytes(bytes, filename),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(t.translate('Download')),
          ),
        ]),
      ),
    );
  }

  void _downloadBytes(Uint8List bytes, String name) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', name)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
