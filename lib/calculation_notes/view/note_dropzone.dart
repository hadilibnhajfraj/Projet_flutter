// Grande zone de dépôt des notes de calcul : glisser-déposer un ou plusieurs
// fichiers, ou cliquer pour parcourir. Bordure en pointillés, animation au
// survol et pendant le glisser. Formats refusés signalés (le backend
// revérifie de toute façon le contenu réel de chaque fichier).

import 'dart:typed_data';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

import '../model/calculation_note.dart';
import '../service/note_drop_listener.dart';
import 'calculation_note_widgets.dart';

class NoteDropzone extends StatefulWidget {
  final ValueChanged<List<PendingNoteDocument>> onFiles;
  final bool enabled;
  /// Sélecteur de fichiers (remplaçable dans les tests).
  final Future<List<PendingNoteDocument>> Function() pickFiles;
  const NoteDropzone({super.key, required this.onFiles, this.enabled = true, this.pickFiles = pickNoteDocuments});

  @override
  State<NoteDropzone> createState() => NoteDropzoneState();
}

class NoteDropzoneState extends State<NoteDropzone> {
  final _zoneKey = GlobalKey();
  NoteDropListener? _listener;
  bool _hover = false;
  bool _dragOver = false;

  @override
  void initState() {
    super.initState();
    _listener = NoteDropListener(onDragOver: _onDragOver, onDrop: _onDrop);
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  bool _inside(Offset p) {
    final box = _zoneKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(p);
  }

  void _onDragOver(Offset p) {
    if (!mounted) return;
    final over = widget.enabled && _inside(p);
    if (over != _dragOver) setState(() => _dragOver = over);
  }

  void _onDrop(Offset p, List<NoteDroppedFile> files) {
    if (!mounted) return;
    final inside = _inside(p);
    if (_dragOver) setState(() => _dragOver = false);
    if (!inside || !widget.enabled) return;
    acceptFiles([for (final f in files) (name: f.name, bytes: f.bytes)]);
  }

  /// Fichiers déposés : formats acceptés ajoutés, les autres signalés.
  void acceptFiles(List<({String name, Uint8List bytes})> files) {
    final ok = <PendingNoteDocument>[];
    final rejected = <String>[];
    for (final f in files) {
      final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
      if (kNoteAllowedExtensions.contains(ext)) {
        ok.add(PendingNoteDocument(name: f.name, bytes: f.bytes));
      } else {
        rejected.add(f.name);
      }
    }
    if (rejected.isNotEmpty) {
      showNoteSnack(context, '${nt(context, 'Format non accepté')} : ${rejected.join(', ')}', error: true);
    }
    if (ok.isNotEmpty) widget.onFiles(ok);
  }

  Future<void> _browse() async {
    final picked = await widget.pickFiles();
    if (!mounted || picked.isEmpty) return;
    widget.onFiles(picked);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (_dragOver || _hover);
    final color = _dragOver ? kCrmSuccess : kCrmPrimary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        key: const ValueKey('note-dropzone'),
        onTap: widget.enabled ? _browse : null,
        child: AnimatedScale(
          scale: _dragOver ? 1.015 : 1,
          duration: const Duration(milliseconds: 160),
          child: Container(
            key: _zoneKey,
            child: DottedBorder(
              color: active ? color : kCrmBorder,
              strokeWidth: active ? 2 : 1.4,
              dashPattern: const [8, 6],
              borderType: BorderType.RRect,
              radius: const Radius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
                decoration: BoxDecoration(
                  color: active ? color.withValues(alpha: 0.06) : kCrmBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: color.withValues(alpha: active ? 0.16 : 0.08), shape: BoxShape.circle),
                    child: Icon(_dragOver ? Icons.file_download_done_rounded : Icons.cloud_upload_outlined, size: 32, color: color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    nt(context, _dragOver ? 'Relâchez pour ajouter les documents' : 'Glissez-déposez vos documents ici ou cliquez pour parcourir vos fichiers'),
                    textAlign: TextAlign.center,
                    style: tInter(fontSize: 14, fontWeight: FontWeight.w700, color: kCrmText),
                  ),
                  const SizedBox(height: 4),
                  Text(nt(context, 'Formats acceptés : PDF, DOC, DOCX, XLS, XLSX.'), textAlign: TextAlign.center, style: tInter(fontSize: 12, color: kCrmTextSub)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
