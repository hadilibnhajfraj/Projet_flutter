import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/devis_api.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../../providers/api_client.dart';
class DevisFormSection extends StatefulWidget {
  final String projectId;
  final bool isEdit;

  // ✅ callback vers ProjectFormScreen pour remplir matricule
  final void Function(String matricule)? onMatriculeSaved;
final void Function(bool isValid)? onDevisValidityChanged;
  const DevisFormSection({
    super.key,
    required this.projectId,
    required this.isEdit,
    this.onMatriculeSaved,
        this.onDevisValidityChanged,
  });

  @override
  State<DevisFormSection> createState() => _DevisFormSectionState();
}

class _DevisFormSectionState extends State<DevisFormSection> {
  final _nameCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String? _matriculeExisting;

  // ✅ dropdown tab
  bool _devisOpen = false; // fermé par défaut

  List<Map<String, dynamic>> _devisList = [];
  Map<String, dynamic>? _selectedDevis;

  // ✅ multi files
  final List<Uint8List> _filesBytes = [];
  final List<String> _filesNames = [];

  @override
  void initState() {
    super.initState();
    _loadDevis();
  }

 Future<void> _loadDevis() async {
  setState(() => _loading = true);
  try {
    final list = await DevisApi.instance.listDevis(projectId: widget.projectId);
    final project = await DevisApi.instance.getProject(projectId: widget.projectId);

    setState(() {
      _devisList = list;
      _selectedDevis = list.isNotEmpty ? list.first : null;

      _matriculeExisting = (project["matriculeFiscale"] ?? "").toString().trim();

      // préremplir nom devis si existe
      if (_selectedDevis != null) {
        _nameCtrl.text = (_selectedDevis?["nomDevis"] ?? "").toString();
      }
    });

    // ✅ ✅ ICI EXACTEMENT (après setState)
    widget.onDevisValidityChanged?.call(list.isNotEmpty);

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
    final nomDevis = _nameCtrl.text.trim();
    if (nomDevis.isEmpty) {
      _toast("Validation", "Nom du devis est obligatoire");
      return;
    }

    if (_filesBytes.isEmpty || _filesNames.isEmpty) {
      _toast("Validation", "Choisis au moins 1 fichier (PDF/PNG/JPG)");
      return;
    }

    // ✅ Matricule obligatoire AVANT upload
    final alreadyHasMatricule = (_matriculeExisting ?? "").isNotEmpty;

    final matricule = await _askMatriculeRequired(
      initial: _matriculeExisting ?? "",
      readOnly: alreadyHasMatricule,
    );

    if (matricule == null || matricule.trim().isEmpty) {
      _toast("Validation", "Matricule fiscale est obligatoire");
      return; // ✅ stop : aucun upload
    }

    setState(() => _saving = true);
    try {
      // ✅ Sauver matricule seulement si pas existant
      if (!alreadyHasMatricule) {
        await DevisApi.instance.updateMatricule(
          projectId: widget.projectId,
          matriculeFiscale: matricule.trim(),
        );
        _matriculeExisting = matricule.trim();
        widget.onMatriculeSaved?.call(matricule.trim());
      }

      // ✅ Upload devis seulement si matricule OK
      await DevisApi.instance.uploadDevis(
        projectId: widget.projectId,
        nomDevis: nomDevis,
        filesBytes: _filesBytes,
        filenames: _filesNames,
      );

      _toast("Succès", "Matricule ✅ + Devis uploadé ✅");

      _filesBytes.clear();
      _filesNames.clear();
      await _loadDevis();
      setState(() {});
    } catch (e) {
      _toast("Erreur", e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _askMatriculeRequired({
    required String initial,
    required bool readOnly,
  }) async {
    final ctrl = TextEditingController(text: initial);

    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Matricule fiscale"),
        content: TextField(
          controller: ctrl,
          readOnly: readOnly,
          decoration: const InputDecoration(hintText: "Ex: 1234567/A/B/000"),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text("Valider"),
          ),
        ],
      ),
    );
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
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
  void _toast(String title, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$title : $msg")),
    );
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

    return Card(
      elevation: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ TAB "Devis" dropdown
            InkWell(
              onTap: () => setState(() => _devisOpen = !_devisOpen),
              borderRadius: BorderRadius.circular(10),
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
                      "Devis",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _devisOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down, size: 22),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ✅ contenu repliable
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _devisOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: "Nom du devis *"),
                  ),
                  const SizedBox(height: 12),

                  // ✅ fichiers existants + corbeille
                  if (_devisList.isNotEmpty) ...[
                    const Text("Fichiers existants :", style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final d in _devisList)
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
                                        await DevisApi.instance.deleteDevis(
                                          projectId: widget.projectId,
                                          devisId: d["id"].toString(),
                                        );
                                        _toast("Succès", "Fichier supprimé ✅");
                                        await _loadDevis();
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

                  // ✅ picker multi (corrigé)
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
                            _filesNames.isEmpty ? "Aucun fichier" : "${_filesNames.length} fichier(s) sélectionné(s)",
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
                                  style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ✅ publish
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