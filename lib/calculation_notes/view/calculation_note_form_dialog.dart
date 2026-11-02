// Formulaire « Nouvelle note de calcul » — depuis le menu « Notes de calcul »
// (projet au choix, ou créé sur place) ou depuis un projet (projet imposé).
// ID, référence, date et créateur sont attribués par le backend : rien n'est
// numéroté côté Flutter.

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

import '../model/calculation_note.dart';
import '../service/calculation_note_service.dart';
import 'calculation_note_widgets.dart';

/// Ouvre la création d'un projet (formulaire du module Projets) par-dessus le
/// formulaire de note ; renvoie le projet créé, ou null si abandonné.
typedef NoteProjectCreator = Future<NoteProject?> Function(BuildContext context);

Future<CalculationNoteDetail?> showCalculationNoteFormDialog(
  BuildContext context, {
  String? projectId,
  String? projectName,
  CalculationNoteService? service,
  NoteProjectCreator? createProject,
}) {
  return showDialog<CalculationNoteDetail>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CalculationNoteFormDialog(projectId: projectId, projectName: projectName, service: service, createProject: createProject),
  );
}

class CalculationNoteFormDialog extends StatefulWidget {
  final String? projectId;
  final String? projectName;
  final CalculationNoteService? service;
  final NoteProjectCreator? createProject;
  const CalculationNoteFormDialog({super.key, this.projectId, this.projectName, this.service, this.createProject});

  @override
  State<CalculationNoteFormDialog> createState() => _CalculationNoteFormDialogState();
}

class _CalculationNoteFormDialogState extends State<CalculationNoteFormDialog> {
  CalculationNoteService get _svc => widget.service ?? CalculationNoteService.instance;
  final _formKey = GlobalKey<FormState>();
  final _comment = TextEditingController();
  final List<PendingNoteDocument> _docs = [];
  CalculationNoteOptions? _options;
  Object? _loadError;
  String? _serverError;
  String? _info;
  String? _projectId;
  String? _requesterId;
  // « Affecter à » : utilisateur responsable (facultatif sauf règle serveur).
  String? _assigneeId;
  bool _saving = false;
  bool _creatingProject = false;

  bool get _locked => widget.projectId != null;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final o = await _svc.options();
      if (!mounted) return;
      setState(() {
        _options = o;
        _requesterId ??= o.requesters.any((u) => u.id == o.currentUserId) ? o.currentUserId : null;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  // Projet créé dans la fenêtre secondaire : liste actualisée depuis le
  // backend puis nouveau projet sélectionné. Le reste du formulaire (demandeur,
  // observations, documents) n'est pas touché.
  Future<void> _createProject() async {
    final creator = widget.createProject;
    if (creator == null || _creatingProject) return;
    setState(() => _creatingProject = true);
    try {
      final created = await creator(context);
      if (created == null || !mounted) return;
      CalculationNoteOptions? fresh;
      try {
        fresh = await _svc.options();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        final base = fresh ?? _options!;
        final projects = [
          ...base.projects,
          if (!base.projects.any((p) => p.id == created.id)) created,
        ];
        _options = CalculationNoteOptions(projects: projects, requesters: base.requesters, currentUserId: base.currentUserId);
        _projectId = created.id;
        _serverError = null;
        _info = '${nt(context, 'Projet créé et sélectionné')} : ${created.nomProjet}';
      });
    } finally {
      if (mounted) setState(() => _creatingProject = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return; // pas de double soumission
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      final note = await _svc.create(projectId: _projectId!, requesterId: _requesterId!, assignedToUserId: _assigneeId, commentaire: _comment.text, documents: _docs);
      if (mounted) Navigator.of(context).pop(note);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _serverError = noteErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _creatingProject;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _header(busy),
            Flexible(child: _body()),
            _footer(busy),
          ]),
        ),
      ),
    );
  }

  Widget _header(bool busy) => Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 12, 18),
        decoration: const BoxDecoration(color: kCrmSurface, border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kCrmPrimary, kCrmSecondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calculate_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nt(context, 'Nouvelle note de calcul'), style: tInter(fontSize: 18, fontWeight: FontWeight.w800, color: kCrmText)),
              const SizedBox(height: 2),
              Text(nt(context, 'Créer une note de calcul et associer les documents techniques'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
            ]),
          ),
          IconButton(
            key: const ValueKey('note-form-close'),
            tooltip: nt(context, 'Fermer'),
            icon: const Icon(Icons.close_rounded),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
          ),
        ]),
      );

  Widget _banner(String text, {required bool error}) => Container(
        key: ValueKey(error ? 'note-form-error' : 'note-form-info'),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: (error ? kCrmDanger : kCrmSuccess).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: (error ? kCrmDanger : kCrmSuccess).withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, size: 18, color: error ? kCrmDanger : kCrmSuccess),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: tInter(fontSize: 13, color: kCrmText))),
        ]),
      );

  Widget _section({required String title, required IconData icon, required Widget child, String? subtitle}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kCrmBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: kCrmPrimary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: kCrmPrimary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: tInter(fontSize: 14.5, fontWeight: FontWeight.w800, color: kCrmText))),
          ]),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 6, left: 38), child: Text(subtitle, style: tInter(fontSize: 12, color: kCrmTextSub))),
          const SizedBox(height: 16),
          child,
        ]),
      );

  Widget _readOnly(String label, String value, {Key? key}) => NoteFieldLabel(
        label: label,
        child: TextFormField(
          key: key,
          initialValue: value,
          readOnly: true,
          enableInteractiveSelection: false,
          style: tInter(fontSize: 13.5, color: kCrmTextSub),
          decoration: noteInputDecoration(readOnly: true, suffixIcon: const Icon(Icons.lock_outline_rounded, size: 16, color: kCrmTextSub)),
        ),
      );

  Widget _body() {
    if (_loadError != null) {
      return Padding(padding: const EdgeInsets.all(24), child: _banner(noteErrorMessage(_loadError!), error: true));
    }
    final o = _options;
    if (o == null) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));

    final now = DateTime.now();
    final me = o.requesters.where((u) => u.id == o.currentUserId).firstOrNull;
    // Projet imposé (création depuis un projet) : affiché même hors des choix
    // (le backend revérifie les droits à l'enregistrement).
    final projects = [
      ...o.projects,
      if (_locked && !o.projects.any((p) => p.id == widget.projectId)) NoteProject(id: widget.projectId!, nomProjet: widget.projectName ?? widget.projectId!),
    ];
    final canCreateProject = !_locked && widget.createProject != null;

    return Container(
      color: kCrmBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_serverError != null) _banner(_serverError!, error: true),
          if (_info != null && _serverError == null) _banner(_info!, error: false),
          _section(
            title: nt(context, 'Informations générales'),
            icon: Icons.info_outline_rounded,
            child: LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth >= 820 ? 4 : box.maxWidth >= 520 ? 2 : 1;
              const gap = 14.0;
              double w(int span) {
                final s = span > cols ? cols : span;
                return (box.maxWidth - gap * (cols - 1)) / cols * s + gap * (s - 1);
              }

              // Demandeur et « Affecter à » côte à côte dès deux colonnes.
              final half = cols == 1 ? box.maxWidth : (box.maxWidth - gap) / 2;
              return Wrap(spacing: gap, runSpacing: 14, children: [
                SizedBox(width: w(1), child: _readOnly(nt(context, 'ID de la note'), nt(context, 'Généré automatiquement'), key: const ValueKey('note-form-id'))),
                SizedBox(width: w(1), child: _readOnly(nt(context, 'Numéro de référence'), 'NC-${now.year}-XXXX', key: const ValueKey('note-form-reference'))),
                SizedBox(width: w(1), child: _readOnly(nt(context, 'Date de création'), formatNoteDate(now))),
                SizedBox(width: w(1), child: _readOnly(nt(context, 'Créé par'), me?.name ?? '—', key: const ValueKey('note-form-creator'))),
                SizedBox(
                  width: w(4),
                  child: NoteFieldLabel(
                    label: nt(context, 'Projet'),
                    required: true,
                    child: NoteSearchSelectField(
                      key: const ValueKey('note-form-project'),
                      title: nt(context, 'Choisir un projet'),
                      value: _projectId,
                      hint: nt(context, 'Rechercher un projet…'),
                      icon: Icons.folder_outlined,
                      enabled: !_locked && !_saving,
                      options: [for (final p in projects) NoteSelectOption(id: p.id, label: p.nomProjet, subtitle: p.entreprise)],
                      requiredMessage: nt(context, 'Sélectionnez un projet.'),
                      actionLabel: canCreateProject ? nt(context, '+ Créer un nouveau projet') : null,
                      onAction: _createProject,
                      onChanged: (v) => setState(() {
                        _projectId = v;
                        _info = null;
                      }),
                    ),
                  ),
                ),
                if (canCreateProject)
                  SizedBox(
                    width: w(4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const ValueKey('note-form-create-project'),
                        onPressed: busy ? null : _createProject,
                        icon: _creatingProject
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: Text(nt(context, '+ Créer un nouveau projet')),
                      ),
                    ),
                  ),
                SizedBox(
                  width: half,
                  child: NoteFieldLabel(
                    label: nt(context, 'Demandeur'),
                    required: true,
                    child: NoteSearchSelectField(
                      key: const ValueKey('note-form-requester'),
                      title: nt(context, 'Choisir un demandeur'),
                      value: _requesterId,
                      hint: nt(context, 'Rechercher un utilisateur…'),
                      icon: Icons.person_search_outlined,
                      enabled: !_saving,
                      options: [for (final u in o.requesters) NoteSelectOption(id: u.id, label: u.name, subtitle: u.name == u.email ? null : u.email)],
                      requiredMessage: nt(context, 'Sélectionnez un demandeur.'),
                      onChanged: (v) => setState(() => _requesterId = v),
                    ),
                  ),
                ),
                SizedBox(
                  width: half,
                  child: NoteFieldLabel(
                    label: nt(context, 'Affecter à'),
                    required: o.assigneeRequired,
                    child: NoteSearchSelectField(
                      key: const ValueKey('note-form-assignee'),
                      title: nt(context, 'Affecter la note à un collaborateur'),
                      value: _assigneeId,
                      hint: nt(context, 'Rechercher par nom, prénom ou email…'),
                      icon: Icons.person_add_alt_1_outlined,
                      enabled: !_saving,
                      options: [for (final u in o.assignees) NoteSelectOption(id: u.id, label: u.name, subtitle: u.details)],
                      requiredMessage: o.assigneeRequired ? nt(context, 'Sélectionnez l’utilisateur affecté.') : null,
                      onClear: () => setState(() => _assigneeId = null),
                      clearTooltip: nt(context, 'Retirer l’affectation'),
                      onChanged: (v) => setState(() => _assigneeId = v),
                    ),
                  ),
                ),
                SizedBox(
                  width: w(4),
                  child: NoteFieldLabel(
                    label: nt(context, 'Observations générales'),
                    child: TextFormField(
                      key: const ValueKey('note-form-comment'),
                      controller: _comment,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 4000,
                      decoration: noteInputDecoration(hint: nt(context, 'Contexte, hypothèses générales, remarques…')).copyWith(counterText: ''),
                    ),
                  ),
                ),
              ]);
            }),
          ),
          const SizedBox(height: 16),
          _section(
            title: '${nt(context, 'Documents techniques')}${_docs.isEmpty ? '' : ' (${_docs.length})'}',
            icon: Icons.attach_file_rounded,
            subtitle: nt(context, 'Facultatif : les documents peuvent être ajoutés plus tard.'),
            child: PendingNoteDocumentsEditor(documents: _docs, enabled: !_saving, onChanged: () => setState(() {})),
          ),
        ]),
      ),
    );
  }

  bool get busy => _saving || _creatingProject;

  Widget _footer(bool busy) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(color: kCrmSurface, border: Border(top: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          Expanded(
            child: Text(nt(context, 'Les champs marqués * sont obligatoires.'), style: tInter(fontSize: 12, color: kCrmTextSub)),
          ),
          OutlinedButton(
            key: const ValueKey('note-form-cancel'),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), side: const BorderSide(color: kCrmBorder), foregroundColor: kCrmText),
            child: Text(nt(context, 'Annuler')),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            key: const ValueKey('note-form-submit'),
            onPressed: busy || _options == null ? null : _submit,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_saving ? nt(context, 'Enregistrement…') : nt(context, 'Créer la note de calcul')),
            style: ElevatedButton.styleFrom(
              backgroundColor: kCrmPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: kCrmPrimary.withValues(alpha: 0.55),
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.12)),
            ),
          ),
        ]),
      );
}
