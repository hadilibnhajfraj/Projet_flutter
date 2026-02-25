import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/bon_de_commande_api.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../../providers/api_client.dart';
class BonDeCommandeFormSection extends StatefulWidget {
  final String projectId;

  // ✅ Bloquer l’étape si devis pas validé
  final bool devisIsValid;

  const BonDeCommandeFormSection({
    super.key,
    required this.projectId,
    required this.devisIsValid,
  });

  @override
  State<BonDeCommandeFormSection> createState() => _BonDeCommandeFormSectionState();
}

class _BonDeCommandeFormSectionState extends State<BonDeCommandeFormSection> {
  final _nameCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  // ✅ dropdown tab
  bool _open = false;

  List<Map<String, dynamic>> _list = [];

  // ✅ multi files
  final List<Uint8List> _filesBytes = [];
  final List<String> _filesNames = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BonDeCommandeFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si devis devient valide => tu peux auto ouvrir si tu veux
    if (!oldWidget.devisIsValid && widget.devisIsValid) {
      // optionnel
      // setState(() => _open = true);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await BonDeCommandeApi.instance.listBonDeCommande(projectId: widget.projectId);
      setState(() {
        _list = list;

        // préremplir nom si déjà existant
        if (_list.isNotEmpty) {
          _nameCtrl.text = (_list.first["nomBonDeCommande"] ?? "").toString();
        }
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["pdf", "png", "jpg", "jpeg"],
      withData: true,
      allowMultiple: true,
    );

    if (res == null || res.files.isEmpty) return;

    _filesBytes.clear();
    _filesNames.clear();

    for (final f in res.files) {
      if (f.bytes == null) continue;
      _filesBytes.add(f.bytes!);
      _filesNames.add(f.name);
    }

    if (_filesBytes.isEmpty) return;
    setState(() {});
  }

  Future<void> _submit() async {
    if (!widget.devisIsValid) {
      _toast("Validation", "Veuillez d’abord valider l’étape Devis ✅");
      return;
    }

    final nom = _nameCtrl.text.trim();
    if (nom.isEmpty) {
      _toast("Validation", "Nom du bon de commande est obligatoire");
      return;
    }

    if (_filesBytes.isEmpty || _filesNames.isEmpty) {
      _toast("Validation", "Choisis au moins 1 fichier (PDF/PNG/JPG)");
      return;
    }

    setState(() => _saving = true);
    try {
      await BonDeCommandeApi.instance.uploadBonDeCommande(
        projectId: widget.projectId,
        nomBonDeCommande: nom,
        filesBytes: _filesBytes,
        filenames: _filesNames,
      );

      _toast("Succès", "Bon de commande uploadé ✅");

      _filesBytes.clear();
      _filesNames.clear();
      await _load();
      setState(() {});
    } catch (e) {
      _toast("Erreur", e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);

  // ✅ Sur Web: ouvre dans un nouvel onglet
  // ✅ Sur Mobile: ouvre dans navigateur (Chrome/Safari)
  final ok = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );

  if (!ok) {
    _toast("Erreur", "Impossible d'ouvrir le fichier");
  }
}
Future<void> _previewFile(Map<String, dynamic> d) async {
  final url = (d["fileUrl"] ?? "").toString().trim();
  final mime = (d["mimeType"] ?? "").toString().toLowerCase();
  final name = (d["originalName"] ?? "Fichier").toString();

  if (url.isEmpty) {
    _toast("Erreur", "Lien du fichier introuvable");
    return;
  }

  // ✅ URL absolue (si backend renvoie /uploads/...)
  final base = ApiClient.instance.dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
  final fullUrl = url.startsWith("http") ? url : "$base$url";

  final isImage = mime.contains("image/") ||
      url.toLowerCase().endsWith(".png") ||
      url.toLowerCase().endsWith(".jpg") ||
      url.toLowerCase().endsWith(".jpeg");

  final isPdf = mime.contains("pdf") || url.toLowerCase().endsWith(".pdf");

  if (isImage) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: InteractiveViewer(
                  child: Image.network(fullUrl, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }

  if (isPdf) {
    // ✅ Web + Mobile : ouvrir via url_launcher
    await _openUrl(fullUrl);
    return;
  }

  // autres types
  await _openUrl(fullUrl);
}
  Future<bool?> _confirmDelete({required String filename}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: Text("Supprimer \"$filename\" ?"),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }

  void _toast(String title, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$title : $msg")));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: LinearProgressIndicator(),
      );
    }

    final locked = !widget.devisIsValid;

    return Card(
      elevation: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ TAB dropdown + lock si devis pas validé
            InkWell(
              onTap: () {
                if (locked) {
                  _toast("Info", "Valide d’abord l’étape Devis ✅");
                  return;
                }
                setState(() => _open = !_open);
              },
              borderRadius: BorderRadius.circular(10),
              child: Opacity(
                opacity: locked ? 0.45 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Bon de commande",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (locked)
                        const Icon(Icons.lock, size: 18)
                      else
                        AnimatedRotation(
                          turns: _open ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 180),
                          child: const Icon(Icons.keyboard_arrow_down, size: 22),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: "Nom du bon de commande *"),
                  ),
                  const SizedBox(height: 12),

                  // ✅ fichiers existants + corbeille
                  if (_list.isNotEmpty) ...[
                    const Text("Fichiers existants :", style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final d in _list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (d["originalName"] ?? d["fileUrl"] ?? "").toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                              // 👁️ Preview
    IconButton(
      tooltip: "Voir",
      icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.deepPurple),
      onPressed: () => _previewFile(d),
    ),
                            IconButton(
                              tooltip: "Supprimer",
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      final ok = await _confirmDelete(
                                        filename: (d["originalName"] ?? "ce fichier").toString(),
                                      );
                                      if (ok != true) return;

                                      setState(() => _saving = true);
                                      try {
                                        await BonDeCommandeApi.instance.deleteBonDeCommande(
                                          projectId: widget.projectId,
                                          bdcId: d["id"].toString(),
                                        );
                                        _toast("Succès", "Fichier supprimé ✅");
                                        await _load();
                                      } catch (e) {
                                        _toast("Erreur", e.toString());
                                      } finally {
                                        if (mounted) setState(() => _saving = false);
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],

                  // ✅ picker multi
                  InkWell(
                    onTap: _saving ? null : _pickFiles,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.deepPurple.withOpacity(0.35), width: 2),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_upload_outlined, size: 44, color: Colors.deepPurple),
                          const SizedBox(height: 10),
                          Text(
                            "Sélectionne plusieurs fichiers (PDF/PNG/JPG)",
                            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _saving ? null : _pickFiles,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(_filesNames.isEmpty ? "Upload files" : "Changer fichiers"),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _filesNames.isEmpty
                                ? "Aucun fichier"
                                : "${_filesNames.length} fichier(s) sélectionné(s)",
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          if (_filesNames.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            for (final name in _filesNames.take(5))
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.attach_file, size: 16, color: Colors.deepPurple),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.grey.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_filesNames.length > 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "+ ${_filesNames.length - 5} autre(s) fichier(s)",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text("PUBLISH"),
                    ),
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}