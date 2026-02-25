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
  String? _matriculeExisting;
bool _devisOpen = true; // pour le dropdown

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
    final project = await DevisApi.instance.getProject(projectId: widget.projectId);

    setState(() {
      _devisList = list;
      _selectedDevis = list.isNotEmpty ? list.first : null;
      _matriculeExisting = (project["matriculeFiscale"] ?? "").toString().trim();

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

  if (_filesBytes.isEmpty || _filesNames.isEmpty) {
    _toast("Validation", "Choisis au moins 1 fichier (PDF/PNG/JPG)");
    return;
  }

  // ✅ 1) Matricule obligatoire AVANT upload
  final alreadyHasMatricule = (_matriculeExisting ?? "").isNotEmpty;

  final matricule = await _askMatriculeRequired(
    initial: _matriculeExisting ?? "",
    readOnly: alreadyHasMatricule, // ✅ si existe => non modifiable
  );

  if (matricule == null || matricule.trim().isEmpty) {
    _toast("Validation", "Matricule fiscale est obligatoire");
    return; // ✅ stop : rien n’est uploadé
  }

  setState(() => _saving = true);
  try {
    // ✅ 2) Sauvegarder le matricule seulement si pas déjà existant
    if (!alreadyHasMatricule) {
      await DevisApi.instance.updateMatricule(
        projectId: widget.projectId,
        matriculeFiscale: matricule.trim(),
      );
      _matriculeExisting = matricule.trim();
      widget.onMatriculeSaved?.call(matricule.trim());
    }

    // ✅ 3) Puis upload devis (seulement si matricule OK)
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
        readOnly: readOnly, // ✅ non modifiable si déjà existe
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
            foregroundColor: Colors.blue, // ✅ texte bleu
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

          // ✅ corbeille
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
                      await _loadDevis(); // refresh
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

        // ✅ bouton avec texte blanc + loader blanc
        ElevatedButton(
          onPressed: _saving ? null : _pickFiles,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white, // ✅ texte + icône blanc
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // ✅ loader blanc
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

        // ✅ optionnel: afficher la liste des fichiers choisis
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

            SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: _saving ? null : _submit,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.deepPurple, // couleur du bouton
      foregroundColor: Colors.white,      // ✅ texte + icône en blanc
    ),
    child: _saving
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              // optionnel: pour que le loader soit blanc aussi
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : const Text("PUBLISH"),
  ),
),
          ],
        ),
      ),
    );
  }
}