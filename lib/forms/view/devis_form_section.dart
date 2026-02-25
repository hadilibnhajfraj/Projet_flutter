import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:dash_master_toolkit/constant/app_color.dart';
import '../../services/devis_api.dart';

class DevisFormSection extends StatefulWidget {
  final String projectId;
  final bool isEdit;

  // ✅ callback pour remplir automatiquement matricule dans ProjectFormScreen
  final ValueChanged<String>? onMatriculeSaved;

  const DevisFormSection({
    super.key,
    required this.projectId,
    required this.isEdit,
    this.onMatriculeSaved,
  });

  @override
  State<DevisFormSection> createState() => _DevisFormSectionState();
}

class _DevisFormSectionState extends State<DevisFormSection> {
  final _nameCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  Map<String, dynamic>? _devis;
  Uint8List? _fileBytes;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _loadDevis();
  }

  Future<void> _loadDevis() async {
    setState(() => _loading = true);
    try {
      final d = await DevisApi.instance.getDevisByProject(projectId: widget.projectId);
      setState(() {
        _devis = d;
        _nameCtrl.text = (d?["nomDevis"] ?? d?["devisName"] ?? d?["name"] ?? "").toString();
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["pdf", "png", "jpg", "jpeg"],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    final f = res.files.first;
    if (f.bytes == null) return;

    setState(() {
      _fileBytes = f.bytes!;
      _fileName = f.name;
    });
  }

  Future<void> _submit() async {
    final nomDevis = _nameCtrl.text.trim();
    if (nomDevis.isEmpty) {
      _toast("Validation", "Nom du devis est obligatoire");
      return;
    }

    // création => fichier obligatoire
    if (!widget.isEdit && (_fileBytes == null || _fileName == null)) {
      _toast("Validation", "Fichier (PDF/PNG/JPG) est obligatoire");
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.isEdit) {
        // ✅ update (nom + fichier optionnel)
        await DevisApi.instance.updateDevis(
          projectId: widget.projectId,
          nomDevis: nomDevis,
          bytes: _fileBytes,
          filename: _fileName,
        );
        _toast("Succès", "Devis mis à jour ✅");
      } else {
        // ✅ upload
        await DevisApi.instance.uploadDevis(
          projectId: widget.projectId,
          nomDevis: nomDevis,
          bytes: _fileBytes!,
          filename: _fileName!,
        );

        // ✅ popup matricule fiscale
        final matricule = await _askMatricule();
        if (matricule != null && matricule.trim().isNotEmpty) {
          final m = matricule.trim();
          await DevisApi.instance.updateMatricule(
            projectId: widget.projectId,
            matriculeFiscale: m,
          );

          // ✅ remonter au ProjectFormScreen
          widget.onMatriculeSaved?.call(m);
        }

        _toast("Succès", "Devis uploadé ✅");
      }

      await _loadDevis();
      setState(() {
        _fileBytes = null;
        _fileName = null;
      });
    } catch (e) {
      _toast("Erreur", e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _askMatricule() async {
    final c = TextEditingController();
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Matricule fiscale"),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: "Ex: 1234567/A/B/C"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Ignorer"),
          ),
          ElevatedButton(
            onPressed: () {
              if (c.text.trim().isEmpty) return; // obligatoire
              Navigator.pop(context, c.text.trim());
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  void _toast(String title, String msg) {
    if (!mounted) return;
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

    final existingFile = (_devis?["originalName"] ??
            _devis?["file_name"] ??
            _devis?["filename"] ??
            _devis?["fileName"] ??
            _devis?["fileUrl"])
        ?.toString();

    final hasExisting = existingFile != null && existingFile.trim().isNotEmpty;

    return Card(
      elevation: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Devis", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: "Nom du devis *"),
            ),
            const SizedBox(height: 12),

            // ✅ fichier existant affiché avec icône
            if (widget.isEdit && hasExisting && _fileBytes == null) ...[
              Row(
                children: [
                  const Icon(Icons.insert_drive_file, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      existingFile!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            InkWell(
              onTap: _saving ? null : _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorPrimary100.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 44, color: colorPrimary100.withOpacity(0.8)),
                    const SizedBox(height: 10),
                    Text(
                      "Drag & drop ou sélectionne un fichier",
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _saving ? null : _pickFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      ),
                      child: Text(_fileName == null ? "Upload file" : "Changer fichier"),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _fileName ?? (hasExisting ? "Fichier déjà existant" : "Aucun fichier"),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.isEdit ? "Publish (Update)" : "Publish"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}