// Module « Notes de calcul » — liste (/notes-calcul).
// Indicateurs, recherche (référence, projet), filtres (demandeur, période),
// tri (date, référence), pagination. Les actions d'écriture n'apparaissent
// que si le backend indique canEdit, jamais pour le compte back-office (qui
// est de toute façon refusé en 403 par le backend).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

import '../model/calculation_note.dart';
import '../service/calculation_note_service.dart';
import 'calculation_note_form_dialog.dart';
import 'calculation_note_widgets.dart';

const kCalculationNotesRoute = '/notes-calcul';
String calculationNoteDetailRoute(int id, {bool edit = false}) => '$kCalculationNotesRoute/detail?id=$id${edit ? '&edit=1' : ''}';
const kCalculationNotesValidationRoute = '$kCalculationNotesRoute/validation';

class CalculationNotesScreen extends StatefulWidget {
  final CalculationNoteService? service;
  final bool? readOnly;
  /// Création d'un projet depuis le formulaire de note (fournie par la route).
  final NoteProjectCreator? createProject;
  /// « Validation des notes de calcul » : notes soumises au validateur
  /// connecté (le backend refuse cette liste à tout autre compte).
  final bool validationMode;
  const CalculationNotesScreen({super.key, this.service, this.readOnly, this.createProject, this.validationMode = false});

  @override
  State<CalculationNotesScreen> createState() => _CalculationNotesScreenState();
}

class _CalculationNotesScreenState extends State<CalculationNotesScreen> {
  CalculationNoteService get _svc => widget.service ?? CalculationNoteService.instance;
  bool get _readOnly => widget.readOnly ?? AuthService().isReadOnly;

  final _reference = TextEditingController();
  final _project = TextEditingController();
  Timer? _debounce;
  late CalculationNoteFilters _filters = CalculationNoteFilters(status: widget.validationMode ? kNoteStatusPending : null);
  CalculationNotePage? _page;
  List<NoteUser> _requesters = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _svc.options().then((o) {
      if (mounted) setState(() => _requesters = o.requesters);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _reference.dispose();
    _project.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = widget.validationMode ? await _svc.validationQueue(_filters) : await _svc.list(_filters);
      if (mounted) setState(() => _page = p);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(CalculationNoteFilters f) {
    _filters = f;
    _load();
  }

  CalculationNoteFilters _copy({String? reference, String? project, Object? requesterId = _keep, Object? status = _keep, Object? from = _keep, Object? to = _keep, String? sortBy, bool? ascending, int? page}) {
    final f = _filters;
    return CalculationNoteFilters(
      reference: reference ?? f.reference,
      project: project ?? f.project,
      requesterId: requesterId == _keep ? f.requesterId : requesterId as String?,
      status: status == _keep ? f.status : status as String?,
      from: from == _keep ? f.from : from as DateTime?,
      to: to == _keep ? f.to : to as DateTime?,
      sortBy: sortBy ?? f.sortBy,
      ascending: ascending ?? f.ascending,
      page: page ?? 1,
      limit: f.limit,
    );
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _apply(_copy(reference: _reference.text, project: _project.text)));
  }

  void _sort(String by) {
    final asc = _filters.sortBy == by ? !_filters.ascending : by == 'reference';
    _apply(_copy(sortBy: by, ascending: asc, page: _filters.page));
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _filters.from != null && _filters.to != null ? DateTimeRange(start: _filters.from!, end: _filters.to!) : null,
    );
    if (r != null) _apply(_copy(from: r.start, to: r.end));
  }

  void _reset() {
    _reference.clear();
    _project.clear();
    _apply(CalculationNoteFilters(sortBy: _filters.sortBy, ascending: _filters.ascending, limit: _filters.limit));
  }

  Future<void> _create() async {
    final note = await showCalculationNoteFormDialog(context, service: widget.service, createProject: widget.createProject);
    if (note == null || !mounted) return;
    showNoteSnack(context, '${nt(context, 'Note de calcul créée')} : ${note.reference}');
    _load();
  }

  void _open(CalculationNoteSummary n, {bool edit = false}) => context.go(calculationNoteDetailRoute(n.id, edit: edit));

  // Décisions (validateur) : le backend revérifie le validateur, le statut et
  // la soumission ; un refus exige un motif.
  Future<void> _validate(CalculationNoteSummary n) async {
    if (!await confirmNoteValidation(context, n.reference)) return;
    await _decide(() => _svc.validate(n.id, submissionVersion: n.workflow.submissionVersion), 'Note validée');
  }

  Future<void> _reject(CalculationNoteSummary n) async {
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
    await _decide(() => _svc.reject(n.id, motif, submissionVersion: n.workflow.submissionVersion), 'Note refusée');
  }

  Future<void> _decide(Future<CalculationNoteDetail> Function() action, String success) async {
    try {
      final d = await action();
      if (!mounted) return;
      showNoteSnack(context, '${nt(context, success)} : ${d.reference}');
    } catch (e) {
      if (mounted) showNoteSnack(context, noteErrorMessage(e), error: true);
    }
    _load();
  }

  Future<void> _download(CalculationNoteSummary n) async {
    try {
      final d = await _svc.get(n.id);
      if (!mounted) return;
      if (d.documents.length == 1) return downloadNoteDocument(context, d.documents.first);
      await showDialog(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('${nt(ctx, 'Télécharger')} — ${d.reference}'),
          children: [
            for (final doc in d.documents)
              SimpleDialogOption(
                onPressed: () => downloadNoteDocument(ctx, doc),
                child: Row(children: [
                  NoteFileIcon(extension: doc.extension, size: 28),
                  const SizedBox(width: 10),
                  Expanded(child: Text(doc.originalName, overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.download_rounded, size: 18, color: kCrmSuccess),
                ]),
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showNoteSnack(context, noteErrorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _page;
    return Container(
      color: kCrmBg,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        _header(),
        const SizedBox(height: 16),
        _stats(p),
        if ((p?.byCreator ?? const []).isNotEmpty) ...[const SizedBox(height: 12), _byCreator(p!)],
        const SizedBox(height: 16),
        _filtersCard(),
        const SizedBox(height: 16),
        NoteCard(
          padding: EdgeInsets.zero,
          child: _error != null
              ? Padding(padding: const EdgeInsets.all(24), child: Text(noteErrorMessage(_error!), style: tInter(color: kCrmDanger)))
              : p == null
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  : Column(children: [
                      if (_loading) const LinearProgressIndicator(minHeight: 2),
                      p.data.isEmpty ? _empty() : LayoutBuilder(builder: (c, box) => box.maxWidth >= 900 ? _table(p) : _cards(p)),
                      _pagination(p),
                    ]),
        ),
      ]),
    );
  }

  Widget _header() => Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kCrmPrimary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.calculate_outlined, color: kCrmPrimary),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nt(context, widget.validationMode ? 'Validation des notes de calcul' : 'Notes de calcul'),
                    style: tInter(fontSize: 22, fontWeight: FontWeight.w800, color: kCrmText)),
                Text(nt(context, widget.validationMode ? 'Notes de calcul soumises à votre validation' : 'Documents techniques associés aux projets'),
                    style: tInter(fontSize: 13, color: kCrmTextSub)),
              ]),
            ),
          ]),
          if (!_readOnly && !widget.validationMode)
            ElevatedButton.icon(
              key: const ValueKey('notes-new'),
              onPressed: _create,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(nt(context, 'Nouvelle note de calcul')),
              style: ElevatedButton.styleFrom(backgroundColor: kCrmPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            ),
        ],
      );

  Widget _stats(CalculationNotePage? p) {
    final s = p?.summary ?? const {};
    final cards = widget.validationMode
        ? [
            for (final st in kNoteStatusLabels.keys) (nt(context, kNoteStatusLabels[st]!), s[st], noteStatusIcon(st), noteStatusColor(st)),
          ]
        : [
            (nt(context, 'Notes de calcul'), s['total'], Icons.folder_open_rounded, kCrmPrimary),
            for (final st in kNoteStatusLabels.keys) (nt(context, kNoteStatusLabels[st]!), s[st], noteStatusIcon(st), noteStatusColor(st)),
            (nt(context, 'Documents joints'), s['documents'], Icons.attach_file_rounded, kCrmSuccess),
            (nt(context, 'Mes notes'), s['mine'], Icons.person_outline_rounded, kCrmSecondary),
          ];
    return LayoutBuilder(builder: (c, box) {
      final per = cards.length > 4 ? (box.maxWidth >= 1100 ? 7 : box.maxWidth >= 700 ? 4 : 2) : (box.maxWidth >= 900 ? 4 : 2);
      final w = (box.maxWidth - 12 * (per - 1)) / per;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final (label, value, icon, color) in cards)
          SizedBox(
            width: w,
            child: NoteCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(value == null ? '—' : '$value', style: tInter(fontSize: 20, fontWeight: FontWeight.w800, color: kCrmText)),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12, color: kCrmTextSub)),
                  ]),
                ),
              ]),
            ),
          ),
      ]);
    });
  }

  // Nombre de notes par créateur (même périmètre que la liste).
  Widget _byCreator(CalculationNotePage p) => NoteCard(
        key: const ValueKey('notes-by-creator'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(nt(context, 'Notes par créateur'), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: kCrmTextSub)),
          for (final c in p.byCreator)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: kCrmBorder)),
              child: Text('${c.user.name} · ${c.count}', style: tInter(fontSize: 12, color: kCrmText)),
            ),
        ]),
      );

  Widget _filtersCard() {
    final f = _filters;
    final period = f.from == null ? nt(context, 'Toute période') : '${formatNoteDate(f.from)} → ${formatNoteDate(f.to)}';
    InputDecoration deco(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), border: const OutlineInputBorder(), isDense: true);
    return NoteCard(
      child: LayoutBuilder(builder: (c, box) {
        final w = box.maxWidth >= 1000 ? (box.maxWidth - 36) / 4 : box.maxWidth >= 560 ? (box.maxWidth - 12) / 2 : box.maxWidth;
        return Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: w, child: TextField(key: const ValueKey('notes-search-reference'), controller: _reference, onChanged: (_) => _onSearchChanged(), decoration: deco(nt(context, 'Référence'), Icons.tag_rounded))),
          SizedBox(width: w, child: TextField(key: const ValueKey('notes-search-project'), controller: _project, onChanged: (_) => _onSearchChanged(), decoration: deco(nt(context, 'Projet'), Icons.folder_outlined))),
          SizedBox(
            width: w,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('notes-filter-requester-${f.requesterId}'),
              initialValue: f.requesterId,
              isExpanded: true,
              menuMaxHeight: 420,
              decoration: deco(nt(context, 'Demandeur'), Icons.person_search_outlined),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(nt(context, 'Tous les demandeurs'))),
                for (final u in _requesters) DropdownMenuItem<String?>(value: u.id, child: Text(u.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => _apply(_copy(requesterId: v)),
            ),
          ),
          SizedBox(
            width: w,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('notes-filter-status-${f.status}'),
              initialValue: f.status,
              isExpanded: true,
              decoration: deco(nt(context, 'Statut'), Icons.flag_outlined),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(nt(context, 'Tous les statuts'))),
                for (final e in kNoteStatusLabels.entries) DropdownMenuItem<String?>(value: e.key, child: Text(nt(context, e.value))),
              ],
              onChanged: (v) => _apply(_copy(status: v)),
            ),
          ),
          SizedBox(
            width: w,
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('notes-filter-period'),
                  onPressed: _pickPeriod,
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(period, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
              IconButton(tooltip: nt(context, 'Réinitialiser les filtres'), onPressed: _reset, icon: const Icon(Icons.filter_alt_off_outlined)),
            ]),
          ),
        ]);
      }),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          const Icon(Icons.description_outlined, size: 44, color: kCrmTextSub),
          const SizedBox(height: 10),
          Text(nt(context, 'Aucune note de calcul'), style: tInter(fontSize: 15, fontWeight: FontWeight.w700, color: kCrmText)),
        ]),
      );

  Widget _sortHeader(String label, String by, int flex) {
    final active = _filters.sortBy == by;
    return Expanded(
      flex: flex,
      child: InkWell(
        key: ValueKey('notes-sort-$by'),
        onTap: () => _sort(by),
        child: Row(children: [
          Flexible(child: Text(label, style: tInter(fontSize: 12, fontWeight: FontWeight.w800, color: active ? kCrmPrimary : kCrmTextSub))),
          Icon(active ? (_filters.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded, size: 14, color: active ? kCrmPrimary : kCrmTextSub),
        ]),
      ),
    );
  }

  Widget _head(String label, int flex) => Expanded(flex: flex, child: Text(label, style: tInter(fontSize: 12, fontWeight: FontWeight.w800, color: kCrmTextSub)));
  Widget _cell(String text, int flex, {bool strong = false, int lines = 1}) => Expanded(
        flex: flex,
        child: Text(text, maxLines: lines, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: strong ? FontWeight.w700 : FontWeight.w400, color: strong ? kCrmText : kCrmText)),
      );

  List<Widget> _actions(CalculationNoteSummary n) => [
        IconButton(visualDensity: VisualDensity.compact, key: ValueKey('note-view-${n.id}'), tooltip: nt(context, 'Consulter'), icon: const Icon(Icons.visibility_outlined, size: 19, color: kCrmPrimary), onPressed: () => _open(n)),
        if (n.documentsCount > 0)
          IconButton(visualDensity: VisualDensity.compact, key: ValueKey('note-download-${n.id}'), tooltip: nt(context, 'Télécharger'), icon: const Icon(Icons.download_rounded, size: 19, color: kCrmSuccess), onPressed: () => _download(n)),
        if (n.canEdit && !_readOnly)
          IconButton(visualDensity: VisualDensity.compact, key: ValueKey('note-edit-${n.id}'), tooltip: nt(context, 'Modifier'), icon: const Icon(Icons.edit_outlined, size: 19, color: kCrmInfo), onPressed: () => _open(n, edit: true)),
        // Validateur désigné ou back-office (canDecide calculé par le backend).
        if (n.workflow.canDecide) ...[
          IconButton(
            visualDensity: VisualDensity.compact,
            key: ValueKey('note-validate-${n.id}'),
            tooltip: nt(context, 'Valider la note'),
            icon: Icon(Icons.check_circle_rounded, size: 20, color: noteStatusColor(kNoteStatusValidated)),
            onPressed: () => _validate(n),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            key: ValueKey('note-reject-${n.id}'),
            tooltip: nt(context, 'Refuser la note'),
            icon: Icon(Icons.cancel_rounded, size: 20, color: noteStatusColor(kNoteStatusRejected)),
            onPressed: () => _reject(n),
          ),
        ],
      ];

  Widget _docsBadge(int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: (count > 0 ? kCrmSuccess : kCrmTextSub).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.attach_file_rounded, size: 13, color: count > 0 ? kCrmSuccess : kCrmTextSub),
          Text('$count', style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: count > 0 ? kCrmSuccess : kCrmTextSub)),
        ]),
      );

  Widget _table(CalculationNotePage p) => Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
          child: Row(children: [
            _sortHeader(nt(context, 'Référence'), 'reference', 3),
            _head(nt(context, 'Projet'), 4),
            _head(nt(context, 'Demandeur'), 3),
            _head(nt(context, 'Créé par'), 3),
            _sortHeader(nt(context, 'Date'), 'createdAt', 2),
            _head(nt(context, 'Documents'), 2),
            _head(nt(context, widget.validationMode ? 'Observations générales' : 'Commentaire'), 4),
            _head(nt(context, 'Statut'), 3),
            SizedBox(width: 200, child: Text(nt(context, 'Actions'), textAlign: TextAlign.right, style: tInter(fontSize: 12, fontWeight: FontWeight.w800, color: kCrmTextSub))),
          ]),
        ),
        for (final n in p.data)
          InkWell(
            key: ValueKey('note-row-${n.id}'),
            onTap: () => _open(n),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
              child: Row(children: [
                Expanded(flex: 3, child: Text(n.reference, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmPrimary))),
                _cell(n.project?.nomProjet ?? '—', 4, strong: true),
                _cell(n.requester?.name ?? '—', 3),
                _cell(n.creator?.name ?? '—', 3),
                _cell(formatNoteDate(n.createdAt), 2),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _docsBadge(n.documentsCount))),
                _cell((widget.validationMode ? n.observations : n.commentaire) ?? '—', 4, lines: 2),
                Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: NoteStatusBadge(status: n.workflow.status, dense: true))),
                SizedBox(width: 200, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: _actions(n))),
              ]),
            ),
          ),
      ]);

  Widget _cards(CalculationNotePage p) => Column(children: [
        for (final n in p.data)
          InkWell(
            key: ValueKey('note-row-${n.id}'),
            onTap: () => _open(n),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(n.reference, style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmPrimary))),
                  Flexible(child: NoteStatusBadge(status: n.workflow.status, dense: true)),
                  const SizedBox(width: 6),
                  _docsBadge(n.documentsCount),
                ]),
                const SizedBox(height: 4),
                Text(n.project?.nomProjet ?? '—', style: tInter(fontSize: 13.5, fontWeight: FontWeight.w700, color: kCrmText)),
                const SizedBox(height: 4),
                Text('${nt(context, 'Demandeur')} : ${n.requester?.name ?? '—'} · ${nt(context, 'Créé par')} : ${n.creator?.name ?? '—'}', style: tInter(fontSize: 12, color: kCrmTextSub)),
                Text(formatNoteDate(n.createdAt), style: tInter(fontSize: 12, color: kCrmTextSub)),
                if (n.commentaire != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(n.commentaire!, maxLines: 2, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, color: kCrmText))),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: _actions(n)),
              ]),
            ),
          ),
      ]);

  Widget _pagination(CalculationNotePage p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Text('${p.total} ${nt(context, 'note(s)')} · ${nt(context, 'Page')} ${p.page} / ${p.totalPages}',
                key: const ValueKey('notes-pagination'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
          ),
          IconButton(
            key: const ValueKey('notes-prev'),
            onPressed: p.page > 1 ? () => _apply(_copy(page: p.page - 1)) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            key: const ValueKey('notes-next'),
            onPressed: p.page < p.totalPages ? () => _apply(_copy(page: p.page + 1)) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
      );
}

const Object _keep = Object();
