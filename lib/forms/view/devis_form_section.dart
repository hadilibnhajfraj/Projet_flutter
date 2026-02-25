import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/devis_api.dart';

class DevisFormSection extends StatefulWidget {
  final String projectId;
  final bool isEdit;

  // ✅ callback vers ProjectFormScreen pour remplir matricule
  final void Function(String matricule)? onMatriculeSaved;

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

  List<Map<String, dynamic>> _devisList = [];
  Map<String, dynamic>? _selectedDevis; // for edit update

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
      setState(() {
        _devisList = list;
        _selectedDevis = list.isNotEmpty ? list.first : null;

        // prefill name from existing devis (if any)
        if (_selectedDevis != null) {
          _nameCtrl.text = (_selectedDevis?["nomDevis"] ?? "").toString();
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
      allowMultiple: true, // ✅ MULTI
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

    // ✅ en création ou ajout => au moins 1 fichier obligatoire
    if (_filesBytes.isEmpty || _filesNames.isEmpty) {
      _toast("Validation", "Choisis au moins 1 fichier (PDF/PNG/JPG)");
      return;
    }

    setState(() => _saving = true);
    try {
      // ✅ UPLOAD (supports multi)
      await DevisApi.instance.uploadDevis(
        projectId: widget.projectId,
        nomDevis: nomDevis,
        filesBytes: _filesBytes,
        filenames: _filesNames,
      );

      // ✅ popup matricule OBLIGATOIRE après publish
      final matricule = await _askMatriculeRequired();
      if (matricule == null || matricule.trim().isEmpty) {
        _toast("Validation", "Matricule fiscale est obligatoire");
        return;
      }

      await DevisApi.instance.updateMatricule(
        projectId: widget.projectId,
        matriculeFiscale: matricule.trim(),
      );

      // ✅ remplir auto dans ProjectFormScreen
     widget.onMatriculeSaved?.call(matricule.trim());

      _toast("Succès", "Devis uploadé ✅ + Matricule enregistré ✅");

      // refresh
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

  Future<String?> _askMatriculeRequired() async {
    final ctrl = TextEditingController();

    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Matricule fiscale"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: "Ex: 1234567/A/B/000"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // ❌ on interdit l'annulation (matricule obligatoire)
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text("Valider"),
          ),
        ],
      ),
    );
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

    final existingFiles = _devisList
        .map((d) => (d["originalName"] ?? d["fileUrl"] ?? "").toString())
        .where((x) => x.trim().isNotEmpty)
        .toList();

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

            // ✅ afficher devis existants
            if (existingFiles.isNotEmpty) ...[
              const Text("Fichiers existants :", style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final f in existingFiles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
            ],

            // ✅ picker multi
            InkWell(
              onTap: _saving ? null : _pickFiles,
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
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _saving ? null : _pickFiles,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      ),
                      child: Text(_filesNames.isEmpty ? "Upload files" : "Changer fichiers"),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _filesNames.isEmpty ? "Aucun fichier" : "${_filesNames.length} fichier(s) sélectionné(s)",
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
                    : const Text("PUBLISH"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}