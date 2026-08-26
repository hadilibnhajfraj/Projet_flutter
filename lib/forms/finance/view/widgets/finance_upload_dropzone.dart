// lib/forms/finance/view/widgets/finance_upload_dropzone.dart
//
// Zone d'upload professionnelle : vrai Drag & Drop OS (dart:html natif —
// aucune nouvelle dépendance pubspec, décision explicite de l'utilisateur)
// + bouton "Browse files" + bouton "Scan document" (même sélecteur
// fichier/caméra, aucun scanner matériel simulé — un navigateur ne peut de
// toute façon pas piloter un scanner physique).
//
// IMPORTANT — cette interaction (drag & drop réel) est NOUVELLE dans cette
// base de code : aucun écran existant n'implémentait de vraie zone de dépôt
// (seul un `DottedBorder` décoratif existait, voir devis_upload_screen.dart,
// sans logique drag/drop). Les événements `dragover`/`drop` sont écoutés au
// niveau de la fenêtre (`html.window`) car Flutter Web ne peut pas attacher
// d'écouteur DOM directement à un widget — la zone "active" est déterminée
// en comparant les coordonnées de la souris aux bornes réelles du widget
// (RenderBox), une technique robuste qui NE nécessite PAS d'enregistrer de
// platform view (évite toute dépendance à l'API `dart:ui_web` spécifique à
// la version de Flutter).

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../../service/finance_service.dart';
import '../../theme/finance_theme.dart';

// Miroir exact de ALLOWED_EXT côté backend (financeDocumentUpload.middleware.js)
// — garder synchronisé si la liste change côté serveur.
const kFinanceAllowedExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'jpg', 'jpeg', 'png', 'webp', 'txt'];

class FinanceUploadDropzone extends StatefulWidget {
  final ValueChanged<List<FinancePickedFile>> onFilesSelected;
  final bool busy;

  const FinanceUploadDropzone({super.key, required this.onFilesSelected, this.busy = false});

  @override
  State<FinanceUploadDropzone> createState() => _FinanceUploadDropzoneState();
}

class _FinanceUploadDropzoneState extends State<FinanceUploadDropzone> {
  final _zoneKey = GlobalKey();
  bool _dragOver = false;

  StreamSubscription<html.MouseEvent>? _dragOverSub;
  StreamSubscription<html.MouseEvent>? _dropSub;

  @override
  void initState() {
    super.initState();
    _dragOverSub = html.window.onDragOver.listen(_handleDragOver);
    _dropSub = html.window.onDrop.listen(_handleDrop);
  }

  @override
  void dispose() {
    _dragOverSub?.cancel();
    _dropSub?.cancel();
    super.dispose();
  }

  Rect? _zoneRect() {
    final box = _zoneKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  bool _isOverZone(html.MouseEvent event) {
    final rect = _zoneRect();
    if (rect == null) return false;
    return rect.contains(Offset(event.client.x.toDouble(), event.client.y.toDouble()));
  }

  void _handleDragOver(html.MouseEvent event) {
    // §CORRECTION URGENTE — ERREUR FLUTTER LORS DE L'UPLOAD D'UNE FACTURE :
    // ces handlers sont abonnés à `html.window` (portée PAGE ENTIÈRE, pas au
    // widget) pour toute la durée de vie du State — `dispose()` désabonne,
    // mais un événement déjà en file d'attente au moment où le widget passe
    // par `deactivate()` (retiré de l'arbre, ex. fermeture du dialog "Upload
    // invoice") peut encore s'exécuter avant que `dispose()` ne tourne. Sans
    // ce garde, `setState()`/`_zoneRect()` (qui interroge le RenderObject de
    // ce widget) tomberait exactement sur "Looking up a deactivated widget's
    // ancestor is unsafe".
    if (!mounted) return;
    // Nécessaire pour autoriser le "drop" — un navigateur refuse l'événement
    // drop si dragover n'appelle pas preventDefault().
    event.preventDefault();
    final over = _isOverZone(event);
    if (over != _dragOver) setState(() => _dragOver = over);
  }

  Future<void> _handleDrop(html.MouseEvent event) async {
    if (!mounted) return;
    event.preventDefault();
    final over = _isOverZone(event);
    if (_dragOver) setState(() => _dragOver = false);
    if (!over || widget.busy) return;

    final files = event.dataTransfer.files ?? const <html.File>[];
    if (files.isEmpty) return;

    final picked = <FinancePickedFile>[];
    for (final file in files) {
      final bytes = await _readFileBytes(file);
      // Le dialog parent peut avoir été fermé pendant la lecture asynchrone
      // d'un des fichiers déposés (FileReader) — jamais notifier le parent
      // via `widget.onFilesSelected` après démontage.
      if (!mounted) return;
      if (bytes != null) picked.add(FinancePickedFile(bytes: bytes, filename: file.name));
    }
    if (picked.isEmpty) return;
    _notifyFilesSelected(picked);
  }

  Future<Uint8List?> _readFileBytes(html.File file) {
    final completer = Completer<Uint8List?>();
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      completer.complete(result is Uint8List ? result : null);
    });
    reader.onError.listen((_) => completer.complete(null));
    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  Future<void> _browseFiles() async {
    // Le sélecteur de fichiers natif du navigateur reste ouvert un temps
    // INDÉTERMINÉ (contrôlé par l'utilisateur) — exactement le genre d'écart
    // asynchrone pendant lequel le dialog "Upload invoice" englobant peut
    // avoir été fermé (bouton Annuler/X, ou l'utilisateur a navigué
    // ailleurs). Sans ce garde, `widget.onFilesSelected(picked)` déclenche
    // `setState()` côté parent (_FinanceInvoiceUploadFormState) sur un State
    // démonté → "Looking up a deactivated widget's ancestor is unsafe" /
    // "setState() called after dispose()".
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: kFinanceAllowedExtensions,
    );
    if (!mounted) return;
    if (result == null) return;
    final picked = result.files
        .where((f) => f.bytes != null)
        .map((f) => FinancePickedFile(bytes: f.bytes!, filename: f.name))
        .toList();
    if (picked.isEmpty) return;
    _notifyFilesSelected(picked);
  }

  // §CORRECTION — BUG LIFECYCLE DU POPUP "UPLOAD INVOICE" : le retour du
  // sélecteur de fichiers natif du navigateur (fermeture de la fenêtre OS,
  // le focus qui revient sur l'onglet) arrive dans un micro-tâche qui peut
  // chevaucher une passe de build/layout Flutter encore en cours — appeler
  // `widget.onFilesSelected` (qui déclenche un `setState()` insérant pour la
  // toute première fois la liste "Supporting documents", avec ses nouveaux
  // `IconButton`/`Tooltip`) exactement à ce moment est ce qui produit
  // "Looking up a deactivated widget's ancestor is unsafe / the state of the
  // widget's element tree is no longer stable". Reporter l'appel après la
  // fin du frame en cours (`addPostFrameCallback`) laisse l'arbre se
  // stabiliser avant d'y insérer de nouveaux widgets — revérifier `mounted`
  // à l'intérieur du callback, le widget ayant pu être démonté entre-temps.
  void _notifyFilesSelected(List<FinancePickedFile> picked) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onFilesSelected(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final active = _dragOver && !widget.busy;

    return Container(
      key: _zoneKey,
      width: double.infinity,
      child: DottedBorder(
        color: active ? kFinanceColor : kCrmBorder,
        strokeWidth: active ? 2 : 1.4,
        dashPattern: const [8, 6],
        borderType: BorderType.RRect,
        radius: const Radius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: active ? kFinanceColor.withOpacity(0.06) : kCrmBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_upload_outlined, size: 44, color: active ? kFinanceColor : kCrmTextSub),
            const SizedBox(height: 14),
            Text(t.translate('Drag & drop your files here'),
                style: tInter(fontSize: 15.5, fontWeight: FontWeight.w800, color: kCrmText)),
            const SizedBox(height: 6),
            Text(t.translate('or click to browse'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
            const SizedBox(height: 10),
            Text(
              t.translate('Supported: PDF, Excel, Word, images and other documents'),
              style: tInter(fontSize: 11.5, color: kCrmTextSub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
              ElevatedButton.icon(
                onPressed: widget.busy ? null : _browseFiles,
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(t.translate('Browse files')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kFinanceColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.busy ? null : _browseFiles,
                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                label: Text(t.translate('Scan document')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kFinanceColor,
                  side: const BorderSide(color: kFinanceColor),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
            if (widget.busy) ...[
              const SizedBox(height: 18),
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
            ],
          ]),
        ),
      ),
    );
  }
}
