import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../controller/project_form_controller.dart';
import '../../services/project_api.dart';
import 'package:dash_master_toolkit/constant/app_color.dart';
import 'package:dash_master_toolkit/widgets/common_app_widget.dart';

class ProjectCommentScreen extends StatefulWidget {
  final String projectId;
  final String? projectName;

  const ProjectCommentScreen({
    super.key,
    required this.projectId,
    this.projectName,
  });

  @override
  State<ProjectCommentScreen> createState() => _ProjectCommentScreenState();
}

class _ProjectCommentScreenState extends State<ProjectCommentScreen> {
  late final ProjectFormController c;

  bool _loading = true;
  bool _sending = false;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    c = Get.isRegistered<ProjectFormController>()
        ? Get.find<ProjectFormController>()
        : Get.put(ProjectFormController());

    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await c.loadProject(widget.projectId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur chargement : $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) {
    return inputDecoration(context, hintText: hint);
  }

  Widget _roField(String title, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            enabled: false,                 // ✅ non editable
            readOnly: true,
            maxLines: maxLines,
            decoration: _dec(title).copyWith(
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final txt = _commentCtrl.text.trim();
    if (txt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le commentaire est vide")),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await ProjectApi.instance.addComment(widget.projectId, txt);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Commentaire envoyé ✅")),
      );
      context.pop(); // retour
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur envoi : $e")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colorWhite,
      appBar: AppBar(
        title: Text("Commenter ${widget.projectName ?? c.nomProjet.text}"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Tous les champs en lecture seule
                    _roField("Nom du Projet", c.nomProjet),
                    _roField("Date de Démarrage", c.dateDemarrage),
                    _roField("Statut du Projet", c.statut),
                    _roField("Type + Adresse Chantier", c.typeAdresseChantier),

                    _roField("Ingénieur Responsable", c.ingenieurResponsable),
                    _roField("Téléphone Ingénieur", c.telephoneIngenieur),

                    _roField("Architecte", c.architecte),
                    _roField("Téléphone Architecte", c.telephoneArchitecte),

                    _roField("Entreprise", c.entreprise),
                    _roField("Promoteur", c.promoteur),
                    _roField("Bureau d’étude", c.bureauEtude),
                    _roField("Bureau de contrôle", c.bureauControle),

                    _roField("Entreprise Fluide", c.entrepriseFluide),
                    _roField("Entreprise Électricité", c.entrepriseElectricite),

                    _roField("Localisation (Adresse)", c.localisationAdresse),

                    const SizedBox(height: 10),

                    // ✅ Seul champ editable
                    Text("Votre commentaire", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _commentCtrl,
                      maxLines: 4,
                      decoration: _dec("Votre commentaire"),
                    ),

                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _sending ? null : _send,
                        child: _sending
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text("Envoyer"),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
