// Formulaire projet — zone « Documents techniques – Notes de calcul ».
//   • Projet pas encore créé : documents + commentaires choisis localement
//     (facultatif), envoyés dans une note liée au projet dès sa création.
//   • Projet existant : notes du projet, leurs documents (consulter,
//     télécharger) et création d'une nouvelle note liée au projet.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

import '../model/calculation_note.dart';
import '../service/calculation_note_service.dart';
import 'calculation_note_form_dialog.dart';
import 'calculation_note_widgets.dart';
import 'calculation_notes_screen.dart';

/// Après la création d'un projet : enregistre les documents choisis dans une
/// note de calcul liée (demandeur = utilisateur connecté). Ne fait jamais
/// échouer la création du projet : renvoie la note, ou lève l'erreur pour un
/// simple avertissement.
Future<CalculationNoteDetail?> submitProjectCalculationNoteDrafts(String projectId, List<PendingNoteDocument> drafts, {CalculationNoteService? service}) async {
  if (drafts.isEmpty) return null;
  final svc = service ?? CalculationNoteService.instance;
  final options = await svc.options();
  final requesterId = options.currentUserId ?? AuthService().userId;
  if (requesterId == null) throw StateError('Utilisateur connecté inconnu.');
  final note = await svc.create(projectId: projectId, requesterId: requesterId, documents: drafts);
  drafts.clear();
  return note;
}

class ProjectCalculationNotesSection extends StatefulWidget {
  final String? projectId;
  final String? projectName;
  final List<PendingNoteDocument> drafts;
  final CalculationNoteService? service;
  final bool? readOnly;
  const ProjectCalculationNotesSection({super.key, required this.projectId, this.projectName, required this.drafts, this.service, this.readOnly});

  @override
  State<ProjectCalculationNotesSection> createState() => _ProjectCalculationNotesSectionState();
}

class _ProjectCalculationNotesSectionState extends State<ProjectCalculationNotesSection> {
  CalculationNoteService get _svc => widget.service ?? CalculationNoteService.instance;
  bool get _readOnly => widget.readOnly ?? AuthService().isReadOnly;
  List<CalculationNoteDetail>? _notes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProjectCalculationNotesSection old) {
    super.didUpdateWidget(old);
    if (old.projectId != widget.projectId) _load();
  }

  Future<void> _load() async {
    final id = widget.projectId;
    if (id == null) return;
    try {
      final page = await _svc.list(CalculationNoteFilters(projectId: id, limit: 50, sortBy: 'createdAt', ascending: false));
      final details = await Future.wait(page.data.map((n) => _svc.get(n.id)));
      if (mounted) setState(() => _notes = details);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _create() async {
    final note = await showCalculationNoteFormDialog(context, projectId: widget.projectId, projectName: widget.projectName, service: widget.service);
    if (note == null || !mounted) return;
    showNoteSnack(context, '${nt(context, 'Note de calcul créée')} : ${note.reference}');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return NoteCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        NoteSectionTitle(
          title: nt(context, 'Documents techniques – Notes de calcul'),
          icon: Icons.calculate_outlined,
          trailing: widget.projectId != null && !_readOnly
              ? OutlinedButton.icon(
                  key: const ValueKey('project-notes-add'),
                  onPressed: _create,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(nt(context, 'Ajouter une note de calcul')),
                  style: OutlinedButton.styleFrom(foregroundColor: kCrmPrimary, side: const BorderSide(color: kCrmPrimary)),
                )
              : null,
        ),
        const SizedBox(height: 10),
        if (widget.projectId == null) ..._drafts() else ..._existing(),
      ]),
    );
  }

  List<Widget> _drafts() => [
        Text(
          nt(context, 'Facultatif : les documents ajoutés ici seront enregistrés dans une note de calcul liée au projet dès sa création. Vous pourrez aussi les ajouter plus tard.'),
          style: tInter(fontSize: 12.5, color: kCrmTextSub),
        ),
        const SizedBox(height: 10),
        PendingNoteDocumentsEditor(documents: widget.drafts, enabled: !_readOnly, onChanged: () => setState(() {})),
      ];

  List<Widget> _existing() {
    if (_error != null) return [Text(noteErrorMessage(_error!), style: tInter(fontSize: 13, color: kCrmDanger))];
    final notes = _notes;
    if (notes == null) return const [Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))];
    if (notes.isEmpty) return [Text(nt(context, 'Aucune note de calcul pour ce projet.'), style: tInter(fontSize: 13, color: kCrmTextSub))];
    return [
      for (final n in notes) ...[
        Container(
          key: ValueKey('project-note-${n.id}'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.reference, style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmPrimary)),
                  Text(
                    '${nt(context, 'Demandeur')} : ${n.requester?.name ?? '—'} · ${nt(context, 'Créé par')} : ${n.creator?.name ?? '—'} · ${formatNoteDate(n.createdAt)}',
                    style: tInter(fontSize: 12, color: kCrmTextSub),
                  ),
                ]),
              ),
              TextButton.icon(
                onPressed: () => context.go(calculationNoteDetailRoute(n.id)),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(nt(context, 'Ouvrir')),
              ),
            ]),
            const SizedBox(height: 8),
            if (n.documents.isEmpty)
              Text(nt(context, 'Aucun document pour le moment.'), style: tInter(fontSize: 12.5, color: kCrmTextSub))
            else
              for (final d in n.documents) ...[NoteDocumentTile(doc: d), const SizedBox(height: 6)],
          ]),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}
