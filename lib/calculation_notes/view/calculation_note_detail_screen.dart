// Module « Notes de calcul » — détail d'une note (/notes-calcul/detail?id=).
// Projet, demandeur, créateur, référence, documents (commentaire, date,
// auteur, consultation, téléchargement) et historique. Modification et ajout
// de documents seulement si le backend indique canEdit (jamais pour le compte
// back-office ; le backend revérifie et refuse sinon).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

import '../model/calculation_note.dart';
import '../service/calculation_note_service.dart';
import 'calculation_note_widgets.dart';
import 'calculation_notes_screen.dart';
import 'note_dropzone.dart';

class CalculationNoteDetailScreen extends StatefulWidget {
  final int? noteId;
  final bool openEdit;
  final CalculationNoteService? service;
  final bool? readOnly;
  const CalculationNoteDetailScreen({super.key, required this.noteId, this.openEdit = false, this.service, this.readOnly});

  @override
  State<CalculationNoteDetailScreen> createState() => _CalculationNoteDetailScreenState();
}

class _CalculationNoteDetailScreenState extends State<CalculationNoteDetailScreen> {
  CalculationNoteService get _svc => widget.service ?? CalculationNoteService.instance;
  bool get _readOnly => widget.readOnly ?? AuthService().isReadOnly;
  CalculationNoteDetail? _note;
  Object? _error;
  bool _editOpened = false;

  bool get _canEdit => (_note?.canEdit ?? false) && !_readOnly;
  // Actions du workflow : celles que le backend autorise (can*), jamais pour
  // le compte back-office.
  // Décision : dès que le backend l'autorise — validateur désigné ou compte
  // back-office (seule écriture qui lui est ouverte, module Notes de calcul).
  bool get _canDecide => _note?.workflow.canDecide ?? false;
  bool get _canCancel => (_note?.workflow.canCancel ?? false) && !_readOnly;
  bool get _canResubmit => (_note?.canResubmit ?? false) && !_readOnly;
  bool _busy = false;
  // Documents complémentaires choisis par l'utilisateur affecté, pas encore envoyés.
  final List<PendingNoteDocument> _complementary = [];
  bool _sendingComplementary = false;

  Future<void> _sendComplementary() async {
    final n = _note!;
    if (_complementary.isEmpty || _sendingComplementary) return;
    setState(() => _sendingComplementary = true);
    try {
      final updated = await _svc.addComplementaryDocuments(n.id, List.of(_complementary));
      if (!mounted) return;
      final count = _complementary.length;
      setState(() {
        _note = updated;
        _complementary.clear();
      });
      showNoteSnack(context, '${nt(context, 'Documents complémentaires envoyés')} : $count');
      _loadExtras();
    } catch (e) {
      // Échec : les fichiers et leurs commentaires restent prêts à renvoyer.
      if (mounted) showNoteSnack(context, noteErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _sendingComplementary = false);
    }
  }
  // Historique des affectations et suivi des emails (chargés à part).
  List<NoteAssignmentEntry> _assignments = const [];
  List<NoteEmailStatus>? _emails;

  Future<void> _loadExtras() async {
    final n = _note;
    if (n == null) return;
    try {
      final a = await _svc.assignments(n.id);
      final e = n.canManageNotifications ? await _svc.emailNotifications(n.id) : null;
      if (mounted) {
        setState(() {
          _assignments = a;
          _emails = e;
        });
      }
    } catch (_) {
      // Informations complémentaires : la note reste consultable.
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.noteId == null) {
      _error = 'Note de calcul introuvable.';
      return;
    }
    try {
      final n = await _svc.get(widget.noteId!);
      if (!mounted) return;
      setState(() => _note = n);
      _loadExtras();
      if (widget.openEdit && !_editOpened && _canEdit) {
        _editOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _editInfo());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(Future<CalculationNoteDetail> Function() action, String success) async {
    try {
      final n = await action();
      if (!mounted) return;
      setState(() => _note = n);
      showNoteSnack(context, success);
      _loadExtras();
    } catch (e) {
      if (mounted) showNoteSnack(context, noteErrorMessage(e), error: true);
    }
  }

  // Modification / retrait de l'affectation (droits revérifiés par le backend).
  Future<void> _editAssignment() async {
    final n = _note!;
    CalculationNoteOptions options;
    try {
      options = await _svc.options();
    } catch (e) {
      if (mounted) showNoteSnack(context, noteErrorMessage(e), error: true);
      return;
    }
    if (!mounted) return;
    String? selected = n.workflow.assignedTo?.id;
    final result = await showDialog<(bool, String?)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('${nt(ctx, 'Affectation')} — ${n.reference}'),
          content: SizedBox(
            width: 540,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              NoteFieldLabel(
                label: nt(ctx, 'Affecter à'),
                required: options.assigneeRequired,
                child: NoteSearchSelectField(
                  key: const ValueKey('note-assign-field'),
                  title: nt(ctx, 'Affecter la note à un collaborateur'),
                  value: selected,
                  hint: nt(ctx, 'Rechercher par nom, prénom ou email…'),
                  icon: Icons.person_add_alt_1_outlined,
                  options: [for (final u in options.assignees) NoteSelectOption(id: u.id, label: u.name, subtitle: u.details)],
                  onClear: options.assigneeRequired ? null : () => setD(() => selected = null),
                  clearTooltip: nt(ctx, 'Retirer l’affectation'),
                  onChanged: (v) => setD(() => selected = v),
                ),
              ),
              const SizedBox(height: 10),
              Text(nt(ctx, 'Le nouvel utilisateur sera informé par email ; l’ancien sera informé du retrait.'), style: tInter(fontSize: 12, color: kCrmTextSub)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(nt(ctx, 'Annuler'))),
            ElevatedButton(
              key: const ValueKey('note-assign-save'),
              onPressed: selected == n.workflow.assignedTo?.id ? null : () => Navigator.of(ctx).pop((true, selected)),
              child: Text(nt(ctx, 'Enregistrer')),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _workflow(() => _svc.setAssignment(n.id, result.$2), nt(context, 'Affectation mise à jour'));
  }

  Future<void> _resendEmails() async {
    final n = _note!;
    try {
      final count = await _svc.resendFailedEmails(n.id);
      if (!mounted) return;
      showNoteSnack(context, '${nt(context, 'Envois relancés')} : $count');
    } catch (e) {
      if (mounted) showNoteSnack(context, noteErrorMessage(e), error: true);
    }
    _loadExtras();
  }

  Future<void> _editInfo() async {
    final n = _note!;
    CalculationNoteOptions options;
    try {
      options = await _svc.options();
    } catch (e) {
      if (mounted) showNoteSnack(context, noteErrorMessage(e), error: true);
      return;
    }
    if (!mounted) return;
    String? requesterId = n.requester?.id;
    final comment = TextEditingController(text: n.commentaire ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('${nt(ctx, 'Modifier')} — ${n.reference}'),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('note-edit-requester'),
                initialValue: options.requesters.any((u) => u.id == requesterId) ? requesterId : null,
                isExpanded: true,
                menuMaxHeight: 420,
                decoration: InputDecoration(labelText: nt(ctx, 'Demandeur'), border: const OutlineInputBorder(), isDense: true),
                items: [for (final u in options.requesters) DropdownMenuItem(value: u.id, child: Text(u.name, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setD(() => requesterId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('note-edit-comment'),
                controller: comment,
                minLines: 3,
                maxLines: 6,
                maxLength: 4000,
                decoration: InputDecoration(labelText: nt(ctx, 'Observations générales'), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 4),
              Text(nt(ctx, 'Le projet et la référence ne sont pas modifiables.'), style: tInter(fontSize: 12, color: kCrmTextSub)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(nt(ctx, 'Annuler'))),
            ElevatedButton(key: const ValueKey('note-edit-save'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(nt(ctx, 'Enregistrer'))),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await _run(() => _svc.update(n.id, requesterId: requesterId, commentaire: comment.text.trim()), nt(context, 'Note de calcul mise à jour'));
    }
  }

  Future<void> _workflow(Future<CalculationNoteDetail> Function() action, String success) async {
    if (_busy) return; // pas de double décision depuis l'interface
    setState(() => _busy = true);
    try {
      await _run(action, success);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Statut éventuellement changé par quelqu'un d'autre (409) : relecture.
    if (mounted) _load();
  }

  Future<void> _validate() async {
    final n = _note!;
    if (!await confirmNoteValidation(context, n.reference) || !mounted) return;
    await _workflow(() => _svc.validate(n.id, submissionVersion: n.workflow.submissionVersion), nt(context, 'Note validée'));
  }

  Future<void> _reject() async {
    final n = _note!;
    final motif = await askNoteReason(
      context,
      title: '${nt(context, 'Refuser la note')} ${n.reference}',
      label: nt(context, 'Motif du refus'),
      confirmLabel: nt(context, 'Refuser la note'),
      color: noteStatusColor(kNoteStatusRejected),
      keyPrefix: 'note-reject',
      intro: nt(context, 'Le créateur et le demandeur recevront ce motif.'),
    );
    if (motif == null || !mounted) return;
    await _workflow(() => _svc.reject(n.id, motif, submissionVersion: n.workflow.submissionVersion), nt(context, 'Note refusée'));
  }

  Future<void> _cancel() async {
    final n = _note!;
    final motif = await askNoteReason(
      context,
      title: '${nt(context, 'Annuler la note')} ${n.reference}',
      label: nt(context, 'Motif de l’annulation'),
      confirmLabel: nt(context, 'Annuler la note'),
      color: noteStatusColor(kNoteStatusCancelled),
      keyPrefix: 'note-cancel',
      intro: nt(context, 'Le validateur sera informé. Une note annulée ne peut plus être modifiée.'),
    );
    if (motif == null || !mounted) return;
    await _workflow(() => _svc.cancel(n.id, motif), nt(context, 'Note annulée'));
  }

  Future<void> _resubmit() async {
    final n = _note!;
    await _workflow(() => _svc.resubmit(n.id), nt(context, 'Note soumise de nouveau au validateur'));
  }

  Future<void> _addDocuments() async {
    final docs = <PendingNoteDocument>[];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(nt(ctx, 'Ajouter des documents')),
          content: SizedBox(width: 560, child: SingleChildScrollView(child: PendingNoteDocumentsEditor(documents: docs, onChanged: () => setD(() {})))),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(nt(ctx, 'Annuler'))),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(nt(ctx, 'Enregistrer'))),
          ],
        ),
      ),
    );
    if (ok == true && docs.isNotEmpty && mounted) {
      await _run(() => _svc.addDocuments(_note!.id, docs), nt(context, 'Documents ajoutés'));
    }
  }

  Future<void> _editDocComment(NoteDocument doc) async {
    final comment = TextEditingController(text: doc.commentaire ?? '');
    String? type = doc.documentType;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(doc.originalName, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: 540,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            NoteFieldLabel(
              label: nt(ctx, 'Type de document'),
              child: DropdownButtonFormField<String?>(
                initialValue: type,
                isExpanded: true,
                decoration: noteInputDecoration(),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(nt(ctx, 'Non précisé'))),
                  for (final e in kNoteDocumentTypes.entries) DropdownMenuItem<String?>(value: e.key, child: Text(nt(ctx, e.value))),
                ],
                onChanged: (v) => type = v,
              ),
            ),
            const SizedBox(height: 12),
            NoteFieldLabel(
              label: nt(ctx, 'Commentaire du document'),
              child: TextField(key: const ValueKey('doc-edit-comment'), controller: comment, minLines: 3, maxLines: 6, maxLength: 4000, decoration: noteInputDecoration().copyWith(counterText: '')),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(nt(ctx, 'Annuler'))),
          ElevatedButton(key: const ValueKey('doc-edit-save'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(nt(ctx, 'Enregistrer'))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _run(
        () => _svc.updateDocument(_note!.id, doc.id, commentaire: comment.text.trim(), documentType: type ?? ''),
        nt(context, 'Document mis à jour'),
      );
    }
  }

  Widget _info(String label, String value, {Key? key, double width = 240}) => SizedBox(
        width: width,
        child: Column(key: key, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: kCrmTextSub)),
          const SizedBox(height: 3),
          Text(value, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w600, color: kCrmText)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final n = _note;
    return Container(
      color: kCrmBg,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          TextButton.icon(
            onPressed: () => context.go(kCalculationNotesRoute),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(nt(context, 'Retour aux notes de calcul')),
          ),
        ]),
        const SizedBox(height: 8),
        if (_error != null)
          NoteCard(child: Text(noteErrorMessage(_error!), style: tInter(color: kCrmDanger)))
        else if (n == null)
          const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
        else ...[
          _headerCard(n),
          const SizedBox(height: 16),
          _workflowCard(n),
          const SizedBox(height: 16),
          _assignmentCard(n),
          if (_emails != null) ...[
            const SizedBox(height: 16),
            _emailsCard(_emails!),
          ],
          const SizedBox(height: 16),
          _documentsCard(n),
          const SizedBox(height: 16),
          _complementaryCard(n),
          const SizedBox(height: 16),
          _historyCard(n),
        ],
      ]),
    );
  }

  // Validation : validateur, transmission, décision ou annulation, et
  // actions autorisées (décision pour le validateur ; annulation / nouvelle
  // soumission pour le créateur).
  Widget _workflowCard(CalculationNoteDetail n) {
    final w = n.workflow;
    final color = noteStatusColor(w.status);
    Widget line(String label, String value, {Key? key}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text.rich(
            key: key,
            TextSpan(children: [
              TextSpan(text: '$label : ', style: tInter(fontSize: 13, color: kCrmTextSub)),
              TextSpan(text: value, style: tInter(fontSize: 13, fontWeight: FontWeight.w600, color: kCrmText)),
            ]),
          ),
        );
    String who(NoteUser? u, DateTime? d) => '${u?.name ?? '—'} · ${formatNoteDate(d, withTime: true)}';
    return Container(
      key: const ValueKey('note-workflow-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(noteStatusIcon(w.status), color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(nt(context, 'Validation de la note'), style: tInter(fontSize: 14.5, fontWeight: FontWeight.w800, color: kCrmText))),
          NoteStatusBadge(status: w.status),
        ]),
        line(nt(context, 'Validateur'), w.validator == null ? '—' : '${w.validator!.name} (${w.validator!.email})'),
        line(nt(context, 'Transmise le'), formatNoteDate(w.submittedAt, withTime: true) + (w.submissionVersion > 1 ? ' · ${nt(context, 'soumission')} n° ${w.submissionVersion}' : '')),
        if (w.status == kNoteStatusValidated) line(nt(context, 'Validée par'), who(w.decidedBy, w.decidedAt)),
        if (w.status == kNoteStatusRejected) ...[
          line(nt(context, 'Refusée par'), who(w.decidedBy, w.decidedAt)),
          line(nt(context, 'Motif du refus'), w.decisionComment ?? '—', key: const ValueKey('note-decision-comment')),
        ],
        if (w.status == kNoteStatusValidated && w.decisionComment != null) line(nt(context, 'Commentaire du validateur'), w.decisionComment!),
        if (w.status == kNoteStatusCancelled) ...[
          line(nt(context, 'Annulée par'), who(w.cancelledBy, w.cancelledAt)),
          line(nt(context, 'Motif de l’annulation'), w.cancellationReason ?? '—', key: const ValueKey('note-cancellation-reason')),
        ],
        if (w.status == kNoteStatusPending && !_canDecide)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(nt(context, 'En attente de la décision du validateur. La note n’est pas encore validée.'), style: tInter(fontSize: 12.5, color: color)),
          ),
        if (_canDecide || _canCancel || _canResubmit) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (_canDecide)
              ElevatedButton.icon(
                key: const ValueKey('note-detail-validate'),
                onPressed: _busy ? null : _validate,
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(nt(context, 'Valider la note')),
                style: ElevatedButton.styleFrom(backgroundColor: noteStatusColor(kNoteStatusValidated), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
              ),
            if (_canDecide)
              ElevatedButton.icon(
                key: const ValueKey('note-detail-reject'),
                onPressed: _busy ? null : _reject,
                icon: const Icon(Icons.cancel_rounded, size: 18),
                label: Text(nt(context, 'Refuser la note')),
                style: ElevatedButton.styleFrom(backgroundColor: noteStatusColor(kNoteStatusRejected), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
              ),
            if (_canResubmit)
              ElevatedButton.icon(
                key: const ValueKey('note-detail-resubmit'),
                onPressed: _busy ? null : _resubmit,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(nt(context, 'Soumettre de nouveau')),
                style: ElevatedButton.styleFrom(backgroundColor: kCrmPrimary, foregroundColor: Colors.white),
              ),
            if (_canCancel)
              OutlinedButton.icon(
                key: const ValueKey('note-detail-cancel'),
                onPressed: _busy ? null : _cancel,
                icon: const Icon(Icons.block_rounded, size: 18),
                label: Text(nt(context, 'Annuler la note')),
                style: OutlinedButton.styleFrom(foregroundColor: noteStatusColor(kNoteStatusCancelled)),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _assignmentCard(CalculationNoteDetail n) {
    final a = n.workflow.assignedTo;
    final canAssign = n.canAssign && !_readOnly;
    return NoteCard(
      key: const ValueKey('note-assignment-card'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        NoteSectionTitle(
          title: nt(context, 'Affectation'),
          icon: Icons.assignment_ind_outlined,
          trailing: canAssign
              ? OutlinedButton.icon(
                  key: const ValueKey('note-detail-assign'),
                  onPressed: _busy ? null : _editAssignment,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                  label: Text(nt(context, 'Modifier l’affectation')),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: kCrmPrimary.withValues(alpha: 0.12),
            child: Icon(a == null ? Icons.person_off_outlined : Icons.person_rounded, size: 18, color: kCrmPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: a == null
                ? Text(nt(context, 'Aucun utilisateur affecté'), key: const ValueKey('note-assignee-none'), style: tInter(fontSize: 13, color: kCrmTextSub))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.name, key: const ValueKey('note-assignee-name'), style: tInter(fontSize: 14, fontWeight: FontWeight.w700, color: kCrmText)),
                    Text(a.details, style: tInter(fontSize: 12, color: kCrmTextSub)),
                    if (n.workflow.assignedAt != null)
                      Text('${nt(context, 'Affectée le')} ${formatNoteDate(n.workflow.assignedAt, withTime: true)} ${nt(context, 'par')} ${n.workflow.assignedBy?.name ?? '—'}',
                          style: tInter(fontSize: 11.5, color: kCrmTextSub)),
                  ]),
          ),
        ]),
        if (_assignments.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(nt(context, 'Historique des affectations'), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kCrmTextSub)),
          for (final e in _assignments)
            Padding(
              key: ValueKey('note-assignment-${e.action}-${e.createdAt?.millisecondsSinceEpoch}'),
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${formatNoteDate(e.createdAt, withTime: true)} · ${e.from?.name ?? nt(context, 'Aucun')} → ${e.to?.name ?? nt(context, 'Aucun')} · ${nt(context, 'par')} ${e.by?.name ?? '—'}',
                style: tInter(fontSize: 12.5, color: kCrmText),
              ),
            ),
        ],
      ]),
    );
  }

  static const _emailStatusLabels = {'PENDING': 'En attente d’envoi', 'RETRYING': 'Nouvelle tentative programmée', 'SENT': 'Envoyé', 'FAILED': 'Échec d’envoi', 'CANCELLED': 'Annulé'};

  Widget _emailsCard(List<NoteEmailStatus> emails) {
    final failed = emails.where((e) => e.status == 'FAILED').length;
    Color color(String st) => switch (st) { 'SENT' => kCrmSuccess, 'FAILED' => kCrmDanger, 'RETRYING' || 'PENDING' => kCrmWarning, _ => kCrmTextSub };
    return NoteCard(
      key: const ValueKey('note-emails-card'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        NoteSectionTitle(
          title: nt(context, 'Notifications email'),
          icon: Icons.mark_email_read_outlined,
          trailing: failed > 0 && !_readOnly
              ? ElevatedButton.icon(
                  key: const ValueKey('note-emails-resend'),
                  onPressed: _resendEmails,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text('${nt(context, 'Relancer les envois en échec')} ($failed)'),
                  style: ElevatedButton.styleFrom(backgroundColor: kCrmDanger, foregroundColor: Colors.white),
                )
              : null,
        ),
        const SizedBox(height: 10),
        if (emails.isEmpty) Text(nt(context, 'Aucun email pour le moment.'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
        for (final e in emails)
          Padding(
            key: ValueKey('note-email-${e.id}'),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.circle, size: 9, color: color(e.status)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.subject, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText)),
                  Text(
                    '${e.to} · ${nt(context, _emailStatusLabels[e.status] ?? e.status)}${e.sentAt != null ? ' · ${formatNoteDate(e.sentAt, withTime: true)}' : ''}${e.lastErrorMessage != null && e.status != 'SENT' ? ' · ${e.lastErrorMessage}' : ''}',
                    style: tInter(fontSize: 11.5, color: e.status == 'FAILED' ? kCrmDanger : kCrmTextSub),
                  ),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _headerCard(CalculationNoteDetail n) {
    final p = n.project;
    return NoteCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Icon(Icons.calculate_outlined, color: kCrmPrimary, size: 28),
          Text(n.reference, key: const ValueKey('note-detail-reference'), style: tInter(fontSize: 22, fontWeight: FontWeight.w800, color: kCrmText)),
          NoteStatusBadge(status: n.workflow.status),
          if (!_canEdit)
            Container(
              key: const ValueKey('note-detail-readonly'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF0E7490).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
              child: Text(nt(context, 'Consultation uniquement'), style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0E7490))),
            ),
          if (_canEdit)
            OutlinedButton.icon(
              key: const ValueKey('note-detail-edit'),
              onPressed: _editInfo,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(nt(context, 'Modifier les informations')),
            ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 24, runSpacing: 16, children: [
          _info(nt(context, 'ID de la note'), '${n.id}'),
          _info(nt(context, 'Projet'), p == null ? '—' : [p.nomProjet, if (p.entreprise != null) p.entreprise!].join(' — '), key: const ValueKey('note-detail-project'), width: 360),
          _info(nt(context, 'Statut du projet'), p?.statut ?? '—'),
          if (p?.adresse != null) _info(nt(context, 'Adresse'), p!.adresse!, width: 360),
          _info(nt(context, 'Demandeur'), n.requester == null ? '—' : '${n.requester!.name}\n${n.requester!.email}', key: const ValueKey('note-detail-requester')),
          _info(nt(context, 'Créé par'), n.creator == null ? '—' : '${n.creator!.name}\n${n.creator!.email}', key: const ValueKey('note-detail-creator')),
          _info(nt(context, 'Affecté à'), n.workflow.assignedTo == null ? nt(context, 'Aucun') : '${n.workflow.assignedTo!.name}\n${n.workflow.assignedTo!.email}', key: const ValueKey('note-detail-assignee')),
          _info(nt(context, 'Date de création'), formatNoteDate(n.createdAt, withTime: true)),
          _info(nt(context, 'Dernière modification'), formatNoteDate(n.updatedAt, withTime: true)),
        ]),
        if (n.commentaire != null) ...[
          const SizedBox(height: 16),
          _info(nt(context, 'Observations générales'), n.commentaire!, width: 900),
        ],
      ]),
    );
  }

  // Documents transmis (création + ajouts des éditeurs) — séparés des
  // documents complémentaires de l'utilisateur affecté.
  Widget _documentsCard(CalculationNoteDetail n) {
    final docs = n.documents.where((d) => !d.isComplementary).toList();
    return NoteCard(
        key: const ValueKey('note-initial-documents'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          NoteSectionTitle(
            title: '${nt(context, 'Documents techniques transmis')} (${docs.length})',
            icon: Icons.attach_file_rounded,
            trailing: _canEdit
                ? ElevatedButton.icon(
                    key: const ValueKey('note-detail-add-docs'),
                    onPressed: _addDocuments,
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: Text(nt(context, 'Ajouter des documents')),
                    style: ElevatedButton.styleFrom(backgroundColor: kCrmPrimary, foregroundColor: Colors.white),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            Text(nt(context, 'Aucun document pour le moment.'), style: tInter(fontSize: 13, color: kCrmTextSub))
          else
            for (final d in docs) ...[
              NoteDocumentTile(doc: d, onEditComment: _canEdit ? () => _editDocComment(d) : null),
              const SizedBox(height: 8),
            ],
        ]),
      );
  }

  // « Documents complémentaires – Réponse de l'utilisateur affecté » : visible
  // de tous les lecteurs de la note ; zone de dépôt pour l'utilisateur affecté
  // seulement (le backend le revérifie).
  Widget _complementaryCard(CalculationNoteDetail n) {
    final docs = n.documents.where((d) => d.isComplementary).toList();
    final canDrop = n.canAddComplementary && !_readOnly;
    if (docs.isEmpty && !canDrop && n.workflow.assignedTo == null) return const SizedBox.shrink();
    return NoteCard(
      key: const ValueKey('note-complementary-card'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        NoteSectionTitle(title: '${nt(context, 'Documents complémentaires – Réponse de l’utilisateur affecté')} (${docs.length})', icon: Icons.reply_all_rounded),
        if (n.workflow.assignedTo != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 26),
            child: Text('${nt(context, 'Utilisateur affecté')} : ${n.workflow.assignedTo!.name}', style: tInter(fontSize: 12, color: kCrmTextSub)),
          ),
        const SizedBox(height: 12),
        if (docs.isEmpty)
          Text(nt(context, 'Aucun document complémentaire pour le moment.'), style: tInter(fontSize: 13, color: kCrmTextSub))
        else
          for (final d in docs) ...[NoteDocumentTile(doc: d), const SizedBox(height: 8)],
        if (canDrop) ...[
          const SizedBox(height: 8),
          NoteDropzone(
            enabled: !_sendingComplementary,
            onFiles: (files) => setState(() => _complementary.addAll(files)),
          ),
          if (_complementary.isNotEmpty) ...[
            const SizedBox(height: 12),
            PendingNoteDocumentsEditor(
              documents: _complementary,
              enabled: !_sendingComplementary,
              showAddTile: false,
              onChanged: () => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                key: const ValueKey('note-complementary-send'),
                onPressed: _sendingComplementary ? null : _sendComplementary,
                icon: _sendingComplementary
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text('${nt(context, 'Envoyer les documents')} (${_complementary.length})'),
                style: ElevatedButton.styleFrom(backgroundColor: kCrmPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
              ),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _historyCard(CalculationNoteDetail n) => NoteCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          NoteSectionTitle(title: nt(context, 'Historique'), icon: Icons.history_rounded),
          const SizedBox(height: 10),
          for (final h in n.history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 8, color: kCrmPrimary)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(noteHistoryLabel(context, h), style: tInter(fontSize: 13, fontWeight: FontWeight.w600, color: kCrmText)),
                    Text('${formatNoteDate(h.createdAt, withTime: true)} · ${h.user?.name ?? '—'}', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
                  ]),
                ),
              ]),
            ),
        ]),
      );
}
