// lib/production_records/view/production_fiches_list_screen.dart
//
// « Fiches de production PROMESH / PROBAR » — liste d'UNE ligne, commune aux
// deux (même écran, paramétré par [type]) : en-tête (fil d'Ariane, titre,
// « + Nouvelle fiche »), cartes statistiques, recherche + filtres
// combinables, tableau (cartes sur petit écran), pagination.
//
// Données : GET /production-records/fiches (filtres, pagination et compteurs
// calculés par le backend, même portée de lecture que les listes par ligne).
// Aucune règle métier ici : les actions (voir, modifier, rapport, export,
// supprimer) sont fournies par l'écran de route de chaque ligne, qui réutilise
// ses fonctions existantes ; Modifier et Supprimer ne sont jamais proposés sur
// une fiche verrouillée (le backend revérifie). Statut de validation et
// verrouillage sont affichés séparément. Rafraîchi en temps réel quand une
// fiche est soumise ou décidée (événement Socket.IO existant).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/industrial/view/detail/fiche_detail_layout.dart' show FicheBadge, fdNumber, kFicheTitle, kFicheSubmitted;
import 'package:dash_master_toolkit/forms/industrial/view/poste_dashboard_layout.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/services/socket_service.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

import '../model/production_fiche_list.dart';
import '../service/production_fiches_service.dart';

const kFicheListPageSizes = [10, 20, 50, 100];

const kFicheListPeriods = <(String, String)>[
  ('all', 'Toutes les périodes'),
  ('today', "Aujourd'hui"),
  ('week', 'Cette semaine'),
  ('month', 'Ce mois'),
  ('quarter', 'Ce trimestre'),
  ('year', 'Cette année'),
  ('custom', 'Personnalisée'),
];

const kFicheListStatuses = <(String?, String)>[
  (null, 'Toutes'),
  ('PENDING', 'En attente'),
  ('APPROVED', 'Validée'),
  ('REJECTED', 'Refusée'),
  ('NONE', 'Hors circuit de validation'),
];

const kFicheListSorts = <(String, String)>[
  ('date_desc', 'Date décroissante'),
  ('date_asc', 'Date croissante'),
  ('quantite_desc', 'Quantité décroissante'),
];

const Color kFicheDraftColor = Color(0xFFA16207); // brouillon : jaune foncé (≠ verrouillée, gris)
const Color kFicheUnknownColor = Color(0xFF475569);

/// Statut de VALIDATION d'une fiche (indépendant du verrouillage). Mapping
/// explicite des valeurs backend ; toute valeur inattendue est affichée
/// « Statut inconnu » — jamais « Validée » par défaut.
({String label, Color color, IconData icon}) ficheListValidation(FicheListRow r) => switch (r.approval?.status) {
      'APPROVED' => (label: 'Validée', color: kPosteAccepted, icon: Icons.verified_outlined),
      'PENDING' => (label: 'En attente', color: kPostePending, icon: Icons.hourglass_top_rounded),
      'REJECTED' => (label: 'Refusée', color: kPosteRejected, icon: Icons.block_rounded),
      null => switch (r.statut) {
          'brouillon' => (label: 'Brouillon', color: kFicheDraftColor, icon: Icons.edit_note_rounded),
          // Saisie terminée avant / hors du circuit de validation.
          'validee' => (label: 'Hors circuit', color: kFicheSubmitted, icon: Icons.remove_circle_outline_rounded),
          _ => (label: 'Statut inconnu', color: kFicheUnknownColor, icon: Icons.help_outline_rounded),
        },
      _ => (label: 'Statut inconnu', color: kFicheUnknownColor, icon: Icons.help_outline_rounded),
    };

/// Droit d'écriture (modifier, supprimer) sur une fiche — MÊME règle que le
/// backend (assertOwnership des services PROMESH / PROBAR) : un compte
/// `responsable_logistique_achat` (comptes de production, responsables)
/// n'écrit que ses propres fiches ; les autres rôles autorisés ne sont pas
/// restreints. Le backend reste seul juge.
bool ficheCanWrite(FicheListRow r, {required String? role, required String? userId}) {
  if ((role ?? '').toLowerCase().trim() != 'responsable_logistique_achat') return true;
  return userId != null && userId.isNotEmpty && r.createdBy == userId;
}

/// [ficheCanWrite] pour le compte connecté.
bool ficheListCanWrite(FicheListRow r) => ficheCanWrite(r, role: AuthService().userRole, userId: AuthService().userId);

/// Action secondaire proposée par l'écran de route (selon les droits).
class FicheListAction {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  /// null : action non proposée pour cette fiche (ex. fiche verrouillée).
  final Future<void> Function(FicheListRow row)? Function(FicheListRow row) handler;
  /// Liste relue après l'action (suppression…).
  final bool reloadAfter;
  /// Action d'écriture (Modifier, Supprimer) : proposée seulement si
  /// [ProductionFichesListScreen.canWrite] l'autorise pour la fiche.
  final bool requiresWrite;
  const FicheListAction(this.key, {required this.label, required this.icon, required this.color, required this.handler, this.reloadAfter = false, this.requiresWrite = false});
}

class ProductionFichesListScreen extends StatefulWidget {
  final String type; // promesh | probar
  final String lineLabel; // PROMESH | PROBAR
  final Color color;
  final String unit; // m² | ml (affiché si la ligne n'en fournit pas)
  final List<(String, String?)> breadcrumbs; // (libellé, route) — null : page courante
  final String newFicheRoute;
  final String Function(FicheListRow row) viewRoute;
  /// Bouton « Rapport » (export existant de la ligne) — null : aucun.
  final Future<void> Function(FicheListRow row)? onReport;
  final List<FicheListAction> actions;
  /// Droit d'écriture sur une fiche — même règle que le backend
  /// (assertOwnership) ; null : aucune restriction côté écran.
  final bool Function(FicheListRow row)? canWrite;
  final ProductionFichesApi? api;
  final bool realtime;

  const ProductionFichesListScreen({
    super.key,
    required this.type,
    required this.lineLabel,
    required this.color,
    required this.unit,
    required this.breadcrumbs,
    required this.newFicheRoute,
    required this.viewRoute,
    this.onReport,
    this.actions = const [],
    this.canWrite,
    this.api,
    this.realtime = true,
  });

  @override
  State<ProductionFichesListScreen> createState() => _ProductionFichesListScreenState();
}

class _ProductionFichesListScreenState extends State<ProductionFichesListScreen> {
  late final ProductionFichesApi _api = widget.api ?? ProductionFichesService.instance;
  FicheListFilters _filters = const FicheListFilters();
  FicheListPage? _page;
  int? _allFiches; // total sans aucun filtre (dernier chargement non filtré)
  bool _loading = false;
  String? _error;
  int _seq = 0;
  Timer? _searchDebounce;
  Timer? _realtimeDebounce;
  final _searchController = TextEditingController();
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    if (widget.realtime) SocketService.instance.on('production-fiche-approval:updated', _onRealtime);
    _load();
  }

  @override
  void dispose() {
    if (widget.realtime) SocketService.instance.off('production-fiche-approval:updated', _onRealtime);
    _searchDebounce?.cancel();
    _realtimeDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onRealtime(dynamic _) {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final f = _filters;
    if (f.period == 'custom' && (f.start == null || f.end == null)) return; // attend les deux dates
    if (f.period == 'custom' && f.start!.isAfter(f.end!)) {
      setState(() => _error = 'La date de début doit précéder la date de fin.');
      return;
    }
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.fetch(widget.type, f);
      if (!mounted || seq != _seq) return; // réponse d'un chargement périmé
      setState(() {
        _page = page;
        if (!f.isFiltered) _allFiches = page.total;
      });
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  /// Nouveau filtre : retour à la page 1 et un seul appel.
  void _apply(FicheListFilters f) {
    setState(() => _filters = f.copyWith(page: 1));
    _load();
  }

  void _onSearch(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (v.trim() != _filters.search.trim()) _apply(_filters.copyWith(search: v));
    });
  }

  void _reset() {
    _searchController.clear();
    _apply(FicheListFilters(limit: _filters.limit, sort: _filters.sort));
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _filters.start : _filters.end) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    _apply(start ? _filters.copyWith(start: picked) : _filters.copyWith(end: picked));
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() => _busy.add(key));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  // ── Construction ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _header(),
                  _stats(),
                  _filtersBar(),
                  _list(),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final crumbs = [
      for (var i = 0; i < widget.breadcrumbs.length; i++) ...[
        if (i > 0) const Icon(Icons.chevron_right_rounded, size: 14, color: kCrmTextSub),
        widget.breadcrumbs[i].$2 == null
            ? Text(pdT(context, widget.breadcrumbs[i].$1), style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kFicheTitle))
            : InkWell(
                onTap: () => context.go(widget.breadcrumbs[i].$2!),
                child: Text(pdT(context, widget.breadcrumbs[i].$1), style: tInter(fontSize: 12, color: kCrmTextSub)),
              ),
      ],
    ];
    return Container(
      key: const ValueKey('fiches-header'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(key: const ValueKey('fiches-breadcrumbs'), spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: crumbs),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.description_outlined, color: widget.color, size: 22),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(pdT(context, 'Fiches de production ${widget.lineLabel}'), key: const ValueKey('fiches-title'), style: tInter(fontSize: 20, fontWeight: FontWeight.w900, color: kFicheTitle)),
                Text(pdT(context, 'Gestion et suivi des fiches : validation, verrouillage, production et exports.'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
              ]),
            ),
          ]),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              key: const ValueKey('fiches-refresh'),
              onPressed: _loading ? null : _load,
              style: OutlinedButton.styleFrom(foregroundColor: kCrmText, side: const BorderSide(color: kCrmBorder), minimumSize: const Size(0, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
              icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(pdT(context, 'Actualiser')),
            ),
            FilledButton.icon(
              key: const ValueKey('fiches-new'),
              onPressed: () => context.go(widget.newFicheRoute),
              style: FilledButton.styleFrom(backgroundColor: widget.color, minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(pdT(context, 'Nouvelle fiche'), style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ]),
        ]),
      ]),
    );
  }

  Widget _stats() {
    final s = _page?.summary;
    final rate = s?.validationRate;
    return PosteKpiGrid(
      loading: s == null && _loading,
      skeletonCount: 5,
      items: [
        PosteKpi('total', icon: Icons.description_outlined, label: 'Total des fiches', value: s == null ? '—' : '${s.total}', caption: s == null ? null : pdTf(context, 'dont {0} hors circuit', [s.none]), color: widget.color),
        PosteKpi('approved', icon: Icons.verified_outlined, label: 'Fiches validées', value: s == null ? '—' : '${s.approved}', color: kPosteAccepted),
        PosteKpi('pending', icon: Icons.hourglass_top_rounded, label: 'En attente de validation', value: s == null ? '—' : '${s.pending}', color: kPostePending),
        PosteKpi('rejected', icon: Icons.block_rounded, label: 'Fiches refusées', value: s == null ? '—' : '${s.rejected}', color: kPosteRejected),
        PosteKpi(
          'rate',
          icon: Icons.percent_rounded,
          label: 'Taux de validation',
          value: rate == null ? '—' : '${NumberFormat('#,##0.#', 'fr_FR').format(rate)} %',
          caption: s == null ? null : (rate == null ? pdT(context, 'Aucune fiche soumise à validation') : pdTf(context, 'sur {0} fiche(s) soumise(s)', [s.submitted])),
          color: kFicheSubmitted,
        ),
      ],
    );
  }

  Widget _filtersBar() {
    final f = _filters;
    Widget dateChip(bool start) {
      final v = start ? f.start : f.end;
      return InkWell(
        key: ValueKey('fiches-date-${start ? 'start' : 'end'}'),
        onTap: () => _pickDate(start),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_outlined, size: 15, color: kCrmTextSub),
            const SizedBox(width: 6),
            Text('${pdT(context, start ? 'Du' : 'Au')} ${v == null ? '—' : DateFormat('dd/MM/yyyy').format(v)}', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText)),
          ]),
        ),
      );
    }

    return Container(
      key: const ValueKey('fiches-filters'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: SizedBox(
              height: 38,
              child: TextField(
                key: const ValueKey('fiches-search'),
                controller: _searchController,
                onChanged: _onSearch,
                style: tInter(fontSize: 12.5, color: kCrmText),
                decoration: InputDecoration(
                  hintText: pdT(context, 'Rechercher : numéro de fiche, opérateur, machine…'),
                  hintStyle: tInter(fontSize: 12.5, color: kCrmTextSub),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  filled: true,
                  fillColor: kCrmSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: kCrmBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: kCrmBorder)),
                ),
              ),
            ),
          ),
          PosteFilterDropdown<String>(
            fieldKey: const ValueKey('fiches-filter-period'),
            label: 'Période',
            value: f.period,
            items: kFicheListPeriods,
            onChanged: (v) => _apply(v == 'custom' ? f.copyWith(period: v) : f.copyWith(period: v, clear: {'start', 'end'})),
          ),
          if (f.period == 'custom') ...[dateChip(true), dateChip(false)],
          PosteFilterDropdown<String?>(
            fieldKey: const ValueKey('fiches-filter-machine'),
            label: 'Machine',
            value: f.machine,
            items: [(null, 'Toutes'), for (final m in ['1', '2', '3', '4']) (m, 'Machine $m')],
            onChanged: (v) => _apply(v == null ? f.copyWith(clear: {'machine'}) : f.copyWith(machine: v)),
          ),
          PosteFilterDropdown<String?>(
            fieldKey: const ValueKey('fiches-filter-poste'),
            label: 'Poste',
            value: f.poste,
            items: const [(null, 'Tous'), ('matin', 'Matin'), ('nuit', 'Soir')],
            onChanged: (v) => _apply(v == null ? f.copyWith(clear: {'poste'}) : f.copyWith(poste: v)),
          ),
          PosteFilterDropdown<String?>(
            fieldKey: const ValueKey('fiches-filter-status'),
            label: 'Statut',
            value: f.approval,
            items: kFicheListStatuses,
            onChanged: (v) => _apply(v == null ? f.copyWith(clear: {'approval'}) : f.copyWith(approval: v)),
          ),
          PosteFilterDropdown<String>(
            fieldKey: const ValueKey('fiches-filter-sort'),
            label: 'Tri',
            value: f.sort,
            items: kFicheListSorts,
            onChanged: (v) => _apply(f.copyWith(sort: v)),
          ),
          TextButton.icon(
            key: const ValueKey('fiches-reset'),
            onPressed: f.isFiltered ? _reset : null,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
            label: Text(pdT(context, 'Réinitialiser')),
          ),
        ]),
        if (f.period == 'custom' && (f.start == null || f.end == null))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(pdT(context, 'Choisissez une date de début et une date de fin.'), style: tInter(fontSize: 11.5, color: kCrmTextSub)),
          ),
      ]),
    );
  }

  Widget _list() {
    final p = _page;
    final f = _filters;
    final count = p == null
        ? ''
        : f.isFiltered && _allFiches != null
            ? pdTf(context, '{0} résultat(s) sur {1} fiche(s)', [p.total, _allFiches!])
            : pdTf(context, '{0} fiche(s)', [p.total]);
    return Container(
      key: const ValueKey('fiches-list'),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.list_alt_rounded, size: 18, color: widget.color),
          const SizedBox(width: 8),
          Expanded(child: Text(count, key: const ValueKey('fiches-count'), style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kFicheTitle))),
          if (_loading && p != null) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 10),
        if (_error != null)
          Container(
            key: const ValueKey('fiches-error'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kPosteRejected.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: kPosteRejected.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 18, color: kPosteRejected),
              const SizedBox(width: 8),
              Expanded(child: Text('${pdT(context, 'Impossible de charger les fiches')} : $_error', style: tInter(fontSize: 12.5, color: kPosteRejected))),
              TextButton(onPressed: _load, child: Text(pdT(context, 'Réessayer'))),
            ]),
          )
        else if (p == null && _loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 36), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (p == null || p.rows.isEmpty)
          Padding(
            key: const ValueKey('fiches-empty'),
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(children: [
              Icon(Icons.inbox_outlined, size: 34, color: kCrmTextSub.withValues(alpha: 0.55)),
              const SizedBox(height: 8),
              Text(pdT(context, f.isFiltered ? 'Aucune fiche ne correspond à ces filtres' : 'Aucune fiche de production pour le moment'), style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: kCrmText)),
              if (f.isFiltered) TextButton(onPressed: _reset, child: Text(pdT(context, 'Réinitialiser les filtres'))),
            ]),
          )
        else
          LayoutBuilder(builder: (context, c) => c.maxWidth >= 1000 ? _table(p.rows) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final r in p.rows) _rowCard(r)])),
        if (p != null && p.rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: PostePagination(
              page: p.page,
              totalPages: p.totalPages,
              pageSize: f.limit,
              pageSizes: kFicheListPageSizes,
              onPageSize: (v) => _apply(f.copyWith(limit: v)),
              onPrevious: p.page > 1 && !_loading
                  ? () {
                      setState(() => _filters = f.copyWith(page: p.page - 1));
                      _load();
                    }
                  : null,
              onNext: p.page < p.totalPages && !_loading
                  ? () {
                      setState(() => _filters = f.copyWith(page: p.page + 1));
                      _load();
                    }
                  : null,
            ),
          ),
      ]),
    );
  }

  // ── Fiche : badges, valeurs, actions ──────────────────────────────────

  Widget _badges(FicheListRow r) {
    final v = ficheListValidation(r);
    return Wrap(spacing: 4, runSpacing: 4, children: [
      FicheBadge(label: v.label, color: v.color, icon: v.icon),
      if (r.isLocked) const FicheBadge(label: 'Verrouillée', color: kPosteNeutral, icon: Icons.lock_rounded),
    ]);
  }

  String _qty(FicheListRow r) => r.quantite == null ? '—' : '${fdNumber(r.quantite)} ${r.unite.isEmpty ? widget.unit : r.unite}';
  String _date(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    return d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);
  }

  String _dateTime(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d);

  /// [compact] (tableau) : « Rapport » en icône avec infobulle.
  /// Action réellement disponible pour la fiche (verrouillage + droits).
  bool _allowed(FicheListAction a, FicheListRow r) => a.handler(r) != null && (!a.requiresWrite || (widget.canWrite?.call(r) ?? true));

  List<Widget> _actions(FicheListRow r, {bool compact = false}) {
    final menu = [
      for (final a in widget.actions)
        if (_allowed(a, r)) a,
    ];
    final busy = _busy.contains(r.id);
    return [
      TextButton.icon(
        key: ValueKey('fiche-view-${r.id}'),
        onPressed: () => context.go(widget.viewRoute(r)),
        style: TextButton.styleFrom(foregroundColor: widget.color, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
        icon: const Icon(Icons.visibility_outlined, size: 16),
        label: Text(pdT(context, compact ? 'Voir' : 'Voir les détails')),
      ),
      if (widget.onReport != null && compact)
        IconButton(
          key: ValueKey('fiche-report-${r.id}'),
          tooltip: pdT(context, 'Rapport'),
          visualDensity: VisualDensity.compact,
          onPressed: busy ? null : () => _run(r.id, () => widget.onReport!(r)),
          icon: busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined, size: 18, color: kCrmSecondary),
        )
      else if (widget.onReport != null)
        TextButton.icon(
          key: ValueKey('fiche-report-${r.id}'),
          onPressed: busy ? null : () => _run(r.id, () => widget.onReport!(r)),
          style: TextButton.styleFrom(foregroundColor: kCrmSecondary, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
          icon: busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: Text(pdT(context, 'Rapport')),
        ),
      if (menu.isNotEmpty)
        PopupMenuButton<FicheListAction>(
          key: ValueKey('fiche-menu-${r.id}'),
          tooltip: pdT(context, 'Plus d\'actions'),
          icon: const Icon(Icons.more_vert_rounded, size: 19, color: kCrmTextSub),
          onSelected: (a) => _run(r.id, () async {
            await a.handler(r)!(r);
            if (a.reloadAfter && mounted) await _load();
          }),
          itemBuilder: (_) => [
            for (final a in menu)
              PopupMenuItem<FicheListAction>(
                key: ValueKey('fiche-action-${a.key}-${r.id}'),
                value: a,
                child: Row(children: [
                  Icon(a.icon, size: 17, color: a.color),
                  const SizedBox(width: 10),
                  Text(pdT(context, a.label), style: tInter(fontSize: 13, color: kCrmText)),
                ]),
              ),
          ],
        ),
    ];
  }

  Widget _cell(int flex, Widget child) => Expanded(flex: flex, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Align(alignment: Alignment.centerLeft, child: child)));
  Text _v(String t, {bool strong = false, Color? color}) => Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w500, color: color ?? kCrmText));

  Widget _table(List<FicheListRow> rows) {
    const columns = <(String, int)>[('Numéro de fiche', 4), ('Statut', 4), ('Date de production', 3), ('Créée le', 3), ('Machine', 2), ('Poste', 2), ('Producteur', 4), ('Quantité produite', 3), ('Validateur', 4), ('Actions', 4)];
    return Column(key: const ValueKey('fiches-table'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kCrmBorder)),
        child: Row(children: [
          for (final (label, flex) in columns) _cell(flex, Text(pdT(context, label).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: kCrmTextSub, letterSpacing: 0.5))),
        ]),
      ),
      for (final r in rows)
        Container(
          key: ValueKey('fiche-row-${r.id}'),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _cell(4, _v(r.numero ?? '—', strong: true, color: widget.color)),
              _cell(4, _badges(r)),
              _cell(3, _v(_date(r.date))),
              _cell(3, _v(_dateTime(r.createdAt))),
              _cell(2, _v(r.machine == null ? '—' : '${pdT(context, 'Machine')} ${r.machine}')),
              _cell(2, _v(pdT(context, pdPosteLabel(r.poste)))),
              _cell(4, _producer(r)),
              _cell(3, _v(_qty(r), strong: true)),
              _cell(4, Tooltip(message: r.approval?.decidedByEmail ?? '', child: _v(_short(r.approval?.decidedByEmail)))),
              _cell(4, Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: _actions(r, compact: true))),
            ]),
            _rejection(r),
          ]),
        ),
    ]);
  }

  Widget _rowCard(FicheListRow r) {
    return Container(
      key: ValueKey('fiche-row-${r.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kCrmBorder))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [_v(r.numero ?? '—', strong: true, color: widget.color), _badges(r)]),
        const SizedBox(height: 4),
        Text(
          '${_date(r.date)} · ${r.machine == null ? '—' : '${pdT(context, 'Machine')} ${r.machine}'} · ${pdT(context, pdPosteLabel(r.poste))} · ${r.operateur ?? '—'}',
          style: tInter(fontSize: 12, color: kCrmTextSub),
        ),
        Text('${pdT(context, 'Quantité produite')} : ${_qty(r)} · ${pdT(context, 'Créée le')} ${_dateTime(r.createdAt)}', style: tInter(fontSize: 12, color: kCrmTextSub)),
        Text(
          '${pdT(context, 'Producteur')} : ${_short(r.creatorEmail)}'
          '${r.approval?.decidedByEmail == null ? '' : ' · ${pdT(context, 'Validateur')} : ${_short(r.approval!.decidedByEmail)}'}',
          style: tInter(fontSize: 12, color: kCrmTextSub),
        ),
        _rejection(r),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: _actions(r)),
      ]),
    );
  }

  /// « production_1 » depuis « production_1@cbi-tunisia.com ».
  String _short(String? email) {
    if (email == null || email.isEmpty) return '—';
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  /// Producteur (compte créateur) et opérateur saisi sur la fiche.
  Widget _producer(FicheListRow r) => Tooltip(
        message: r.creatorEmail ?? '',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _v(_short(r.creatorEmail), strong: true),
          if ((r.operateur ?? '').isNotEmpty) Text('${pdT(context, 'Opérateur')} : ${r.operateur}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11, color: kCrmTextSub)),
        ]),
      );

  /// Fiche refusée : motif, décideur et date ; « Corriger la fiche »
  /// seulement si le workflow l'autorise (modification permise par le
  /// verrouillage ET par les droits — sinon aucune proposition).
  Widget _rejection(FicheListRow r) {
    final a = r.approval;
    if (a?.status != 'REJECTED') return const SizedBox.shrink();
    final edit = widget.actions.where((x) => x.key == 'edit' && _allowed(x, r)).firstOrNull;
    return Container(
      key: ValueKey('fiche-rejection-${r.id}'),
      margin: const EdgeInsets.only(top: 6, left: 6, right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: kPosteRejected.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: kPosteRejected.withValues(alpha: 0.25))),
      child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Icon(Icons.info_outline_rounded, size: 15, color: kPosteRejected),
        Text(
          '${pdT(context, 'Motif du refus')} : ${(a!.rejectionComment ?? '').trim().isEmpty ? '—' : a.rejectionComment!.trim()}'
          '${a.decidedByEmail == null ? '' : ' · ${_short(a.decidedByEmail)}'}${a.decidedAt == null ? '' : ' · ${_dateTime(a.decidedAt)}'}',
          style: tInter(fontSize: 12, fontWeight: FontWeight.w600, color: kPosteRejected),
        ),
        if (edit != null)
          TextButton.icon(
            key: ValueKey('fiche-correct-${r.id}'),
            onPressed: () => _run(r.id, () => edit.handler(r)!(r)),
            style: TextButton.styleFrom(foregroundColor: kPosteRejected, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 28)),
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: Text(pdT(context, 'Corriger la fiche')),
          ),
      ]),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCrmBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      );
}
