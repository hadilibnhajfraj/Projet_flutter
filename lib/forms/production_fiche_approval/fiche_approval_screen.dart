// lib/forms/production_fiche_approval/fiche_approval_screen.dart
//
// Page « Production → Validation des fiches de production », deux vues :
//  - « Fiches en attente » : décisions du responsable logistique (« Accepter »
//    avec confirmation, « Refuser » avec motif obligatoire) ;
//  - « Historique des validations » : toutes les fiches (acceptées, refusées,
//    en attente), filtrables par période, producteur, type, machine, poste et
//    statut, avec validateur, date de décision et motif de refus.
// Les comptes de production y voient leurs propres fiches. Actualisation
// automatique ; une notification ouvre directement la fiche (initialFiche).
// Le statut affiché est toujours celui relu depuis le backend : aucune
// confirmation n'est affichée si l'appel échoue.

import 'dart:async';

import 'package:dash_master_toolkit/services/socket_service.dart';
import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

import 'fiche_approval_record.dart';
import 'fiche_approval_service.dart';
import 'fiche_approval_widgets.dart';

const _kStatusFilters = [
  ('all', 'Tous les statuts'),
  ('PENDING', 'En attente'),
  ('APPROVED', 'Acceptée'),
  ('REJECTED', 'Refusée'),
];

/// Largeur à partir de laquelle l'historique s'affiche en tableau (sinon cartes).
const double kFicheHistoryTableMinWidth = 1000;

class FicheApprovalScreen extends StatefulWidget {
  /// Injection pour les tests ; par défaut, API réelle.
  final FicheApprovalApi? api;
  /// Nouveau nombre de fiches en attente (badge du menu, responsable).
  final ValueChanged<int>? onPendingChanged;
  /// `promesh:<id>` / `probar:<id>` (lien d'une notification) : fiche ouverte
  /// directement.
  final String? initialFiche;
  /// Actualisation automatique (décisions prises ailleurs, nouvelles fiches) ;
  /// null : désactivée.
  final Duration? refreshInterval;

  const FicheApprovalScreen({
    super.key,
    this.api,
    this.onPendingChanged,
    this.initialFiche,
    this.refreshInterval = const Duration(seconds: 30),
  });

  @override
  State<FicheApprovalScreen> createState() => _FicheApprovalScreenState();
}

enum _View { pending, history }

class _FicheApprovalScreenState extends State<FicheApprovalScreen> {
  FicheApprovalApi get _api => widget.api ?? FicheApprovalService.instance;

  FicheApprovalPermissions? _perms;
  _View _view = _View.pending;
  List<FicheApprovalItem> _pending = const [];
  List<FicheApprovalItem> _history = const [];
  FicheApprovalCounts? _counts;
  bool _loading = true;
  String? _loadError;
  // Résultat de la dernière action (succès ou échec), affiché en haut.
  (String, bool)? _banner;
  Timer? _timer;
  Timer? _searchDebounce;
  int _loadSeq = 0;

  // Filtres (période, type, machine, poste, producteur, recherche : les deux
  // onglets et les compteurs ; statut : historique uniquement).
  String _status = 'all';
  DateTimeRange? _period;
  String? _creator;
  String? _type;
  String? _machine;
  String? _poste;
  final _search = TextEditingController();

  // Fiche créée, soumise de nouveau ou décidée par un autre responsable :
  // relecture immédiate (le backend refuse de toute façon une seconde décision).
  late final void Function(dynamic) _onRemoteUpdate = (_) {
    if (mounted && !_loading) _load(silent: true);
  };

  @override
  void initState() {
    super.initState();
    SocketService.instance.on('production-fiche-approval:updated', _onRemoteUpdate);
    _init();
  }

  @override
  void dispose() {
    SocketService.instance.off('production-fiche-approval:updated', _onRemoteUpdate);
    _timer?.cancel();
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final p = await _api.permissions();
      if (!mounted) return;
      setState(() => _perms = p);
      await _load();
      final every = widget.refreshInterval;
      if (every != null) _timer = Timer.periodic(every, (_) => _load(silent: true));
      await _openInitialFiche();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = FicheApprovalService.friendlyError(e);
        });
      }
    }
  }

  FicheApprovalFilters _filters({required String status}) => FicheApprovalFilters(
        status: status,
        from: _period?.start,
        to: _period?.end,
        creator: _creator,
        type: _type,
        machine: _machine,
        poste: _poste,
        search: _search.text,
      );

  bool get _hasFilters =>
      _status != 'all' || _period != null || _creator != null || _type != null || _machine != null || _poste != null || _search.text.trim().isNotEmpty;

  /// Relit les deux onglets et les compteurs depuis le backend. `silent` :
  /// actualisation automatique, sans indicateur de chargement.
  Future<void> _load({bool silent = false}) async {
    final seq = ++_loadSeq;
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final scope = _filters(status: 'all');
      final results = await Future.wait<Object>([
        _api.list(_filters(status: 'PENDING')),
        _api.list(_filters(status: _status)),
        _api.summary(scope),
      ]);
      if (!mounted || seq != _loadSeq) return; // réponse d'un chargement périmé
      final counts = results[2] as FicheApprovalCounts;
      setState(() {
        _pending = results[0] as List<FicheApprovalItem>;
        _history = results[1] as List<FicheApprovalItem>;
        _counts = counts;
        _loading = false;
        _loadError = null;
      });
      // Badge du menu : total réel, uniquement quand aucun filtre ne restreint.
      if (_perms?.canDecide == true && !scope.hasScopeFilters) widget.onPendingChanged?.call(counts.pending);
    } catch (e) {
      if (mounted && !silent && seq == _loadSeq) {
        setState(() {
          _loading = false;
          _loadError = FicheApprovalService.friendlyError(e);
        });
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _status = 'all';
      _period = null;
      _creator = null;
      _type = null;
      _machine = null;
      _poste = null;
      _search.clear();
    });
    _load();
  }

  Future<void> _openInitialFiche() async {
    final raw = widget.initialFiche;
    final sep = raw?.indexOf(':') ?? -1;
    if (raw == null || sep <= 0 || !mounted) return;
    await _openFiche(raw.substring(0, sep), raw.substring(sep + 1));
  }

  String t(String k) => faT(context, k);

  Future<void> _openFiche(String ficheType, String id) async {
    final message = await showDialog<(String, bool)>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FicheApprovalDetailDialog(api: _api, ficheType: ficheType, id: id),
    );
    if (!mounted) return;
    if (message != null) setState(() => _banner = message);
    await _load();
  }

  Future<void> _decide(FicheApprovalItem item, {required bool approve}) async {
    final result = approve ? await approveFicheFlow(context, _api, item) : await rejectFicheFlow(context, _api, item);
    if (!mounted || result == null) return;
    setState(() => _banner = result);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final narrow = box.maxWidth < 700;
          return SingleChildScrollView(
            padding: EdgeInsets.all(narrow ? 16 : 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _header(),
              const SizedBox(height: 20),
              if (_banner != null) ...[_bannerView(_banner!), const SizedBox(height: 16)],
              _kpis(box.maxWidth - (narrow ? 32 : 48)),
              const SizedBox(height: 20),
              _tabs(),
              const SizedBox(height: 16),
              _filtersBar(),
              const SizedBox(height: 16),
              _body(box.maxWidth - (narrow ? 32 : 48)),
            ]),
          );
        }),
      ),
    );
  }

  // ── En-tête ─────────────────────────────────────────────────────────────
  Widget _header() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kCrmPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.fact_check_outlined, color: kCrmPrimary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Validation des fiches de production'),
                style: tInter(fontSize: 22, fontWeight: FontWeight.w800, color: kCrmText)),
            const SizedBox(height: 4),
            Text(t('Suivi et traçabilité des décisions de validation'), style: tInter(fontSize: 13, color: kCrmTextSub)),
          ]),
        ),
        IconButton(
          key: const ValueKey('fiche-refresh'),
          tooltip: t('Actualiser'),
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, color: kCrmTextSub),
        ),
      ]);

  // ── Cartes KPI (compteurs backend, filtres appliqués) ───────────────────
  Widget _kpis(double width) {
    final c = _counts;
    final perRow = width >= 900 ? 4 : (width >= 300 ? 2 : 1);
    final w = (width - 12 * (perRow - 1)) / perRow;
    String v(int? n) => n == null ? '—' : '$n';
    final cards = [
      ('kpi-processed', t('Total des fiches traitées'), v(c?.processed), Icons.task_alt_rounded, kCrmPrimary),
      ('kpi-pending', t('Fiches en attente'), v(c?.pending), Icons.schedule_rounded, kFicheApprovalStatuses['PENDING']!.$2),
      ('kpi-approved', t('Fiches acceptées'), v(c?.approved), Icons.check_circle_rounded, kCrmSuccess),
      ('kpi-rejected', t('Fiches refusées'), v(c?.rejected), Icons.cancel_rounded, kCrmDanger),
    ];
    return Wrap(spacing: 12, runSpacing: 12, children: [
      for (final (key, label, value, icon, color) in cards)
        SizedBox(
          width: w,
          child: Container(
            key: ValueKey(key),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kCrmBorder)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(value, key: ValueKey('$key-value'), style: tInter(fontSize: 22, fontWeight: FontWeight.w800, color: kCrmText)),
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12, color: kCrmTextSub)),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }

  // ── Onglets ─────────────────────────────────────────────────────────────
  // Onglets : alignés à gauche sur écran large ; sur écran étroit, ils se
  // partagent toute la largeur (libellé sur deux lignes si nécessaire) pour
  // rester tous visibles et cliquables.
  Widget _tabs() => LayoutBuilder(builder: (context, box) {
        final narrow = box.maxWidth < 600;
        Widget tab(_View view, String key, String label, int count) {
          final selected = _view == view;
          final content = InkWell(
            key: ValueKey(key),
            onTap: () => setState(() => _view = view),
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
              margin: EdgeInsets.only(right: narrow ? 0 : 24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: selected ? kCrmPrimary : Colors.transparent, width: 2.5)),
              ),
              child: Row(mainAxisSize: narrow ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: tInter(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? kCrmText : kCrmTextSub)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: selected ? kCrmPrimary.withOpacity(0.12) : kCrmBorder.withOpacity(0.6), borderRadius: BorderRadius.circular(10)),
                  child: Text('$count',
                      key: ValueKey('$key-count'),
                      style: tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: selected ? kCrmPrimary : kCrmTextSub)),
                ),
              ]),
            ),
          );
          return narrow ? Expanded(child: content) : content;
        }

        return Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
          child: Row(children: [
            tab(_View.pending, 'view-pending', t('En attente'), _pending.length),
            tab(_View.history, 'view-history', t('Historique des validations'), _history.length),
          ]),
        );
      });

  Widget _bannerView((String, bool) b) {
    final (text, ok) = b;
    final color = ok ? kCrmSuccess : kCrmDanger;
    return Container(
      key: ValueKey(ok ? 'fiche-banner-success' : 'fiche-banner-error'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.5))),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: tInter(fontSize: 13, fontWeight: FontWeight.w600, color: color))),
        IconButton(onPressed: () => setState(() => _banner = null), icon: const Icon(Icons.close_rounded, size: 16)),
      ]),
    );
  }

  // ── Barre de filtres ────────────────────────────────────────────────────
  bool _filtersOpen = false;

  int get _activeFilters => [
        _status != 'all' && _view == _View.history,
        _period != null,
        _creator != null,
        _type != null,
        _machine != null,
        _poste != null,
        _search.text.trim().isNotEmpty,
      ].where((x) => x).length;

  /// Écran étroit : bouton « Filtres (n) » qui déplie le panneau.
  Widget _filtersBar() => LayoutBuilder(builder: (context, box) {
        final narrow = box.maxWidth < 600;
        if (!narrow) return _filtersPanel(fieldWidth: null);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          OutlinedButton.icon(
            key: const ValueKey('filters-toggle'),
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
            icon: Icon(_filtersOpen ? Icons.expand_less_rounded : Icons.tune_rounded, size: 18),
            label: Text(_activeFilters == 0 ? t('Filtres') : '${t('Filtres')} ($_activeFilters)'),
          ),
          if (_filtersOpen) ...[const SizedBox(height: 10), _filtersPanel(fieldWidth: box.maxWidth - 24)],
        ]);
      });

  Widget _filtersPanel({required double? fieldWidth}) {
    _fieldWidth = fieldWidth;
    final perms = _perms;
    String? none(String? v) => v == null || v.isEmpty ? null : v;
    void apply(VoidCallback change) {
      setState(change);
      _load();
    }

    return Container(
      key: const ValueKey('fiche-filters'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kCrmBorder)),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: fieldWidth ?? 260,
          child: TextField(
            key: const ValueKey('fiche-search'),
            controller: _search,
            onChanged: (_) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 400), _load);
            },
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              hintText: t('N° de fiche, producteur ou validateur'),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey('filter-period'),
          icon: const Icon(Icons.date_range_rounded, size: 16),
          label: Text(_period == null ? t('Période de production') : '${faDate(_period!.start)} → ${faDate(_period!.end)}'),
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2024),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _period,
            );
            if (picked != null) apply(() => _period = picked);
          },
        ),
        if (_period != null)
          IconButton(
            key: const ValueKey('filter-period-clear'),
            tooltip: t('Effacer la période'),
            icon: const Icon(Icons.clear_rounded, size: 18),
            onPressed: () => apply(() => _period = null),
          ),
        _dropdown('filter-type', t('Type'), _type, [
          (null, t('PROMESH et PROBAR')),
          ('promesh', 'PROMESH'),
          ('probar', 'PROBAR'),
        ], (v) => apply(() => _type = none(v))),
        _dropdown('filter-machine', t('Machine'), _machine, [
          (null, t('Toutes les machines')),
          for (final m in ['1', '2', '3', '4']) (m, '${t('Machine')} $m'),
        ], (v) => apply(() => _machine = none(v))),
        _dropdown('filter-poste', t('Poste'), _poste, [
          (null, t('Matin et Soir')),
          ('matin', t('Matin')),
          ('nuit', t('Soir')),
        ], (v) => apply(() => _poste = none(v))),
        if (_view == _View.history)
          _dropdown('filter-status', t('Statut'), _status, [
            for (final (code, label) in _kStatusFilters) (code, t(label)),
          ], (v) => apply(() => _status = v ?? 'all')),
        if (perms?.canViewAll == true)
          _dropdown('filter-creator', t('Producteur'), _creator, [
            (null, t('Tous les producteurs')),
            for (final c in perms!.creators) (c, c),
          ], (v) => apply(() => _creator = none(v))),
        TextButton.icon(
          key: const ValueKey('filter-reset'),
          onPressed: _hasFilters ? _resetFilters : null,
          icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
          label: Text(t('Réinitialiser les filtres')),
        ),
      ]),
    );
  }

  double? _fieldWidth;

  Widget _dropdown(String key, String label, String? value, List<(String?, String)> items, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: _fieldWidth ?? 190,
      child: DropdownButtonFormField<String?>(
        key: ValueKey(key),
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        items: [for (final (v, l) in items) DropdownMenuItem<String?>(value: v, child: Text(l, overflow: TextOverflow.ellipsis))],
        onChanged: onChanged,
      ),
    );
  }

  // ── Contenu : chargement, erreur, liste vide, données ───────────────────
  Widget _body(double width) {
    if (_loading) {
      return Padding(
        key: const ValueKey('fiche-loading'),
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(t('Chargement…'), style: tInter(fontSize: 13, color: kCrmTextSub)),
        ]),
      );
    }
    if (_loadError != null) {
      return _stateBox(
        key: 'fiche-error',
        icon: Icons.error_outline_rounded,
        color: kCrmDanger,
        text: '${t('Erreur :')} $_loadError',
        action: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 16), label: Text(t('Réessayer'))),
      );
    }
    final items = _view == _View.pending ? _pending : _history;
    if (items.isEmpty) {
      return _stateBox(
        key: 'fiche-empty',
        icon: _view == _View.pending ? Icons.inbox_outlined : Icons.history_rounded,
        color: kCrmTextSub,
        text: t(_hasFilters
            ? 'Aucune fiche ne correspond aux filtres.'
            : (_view == _View.pending ? 'Aucune fiche en attente de validation.' : 'Aucune fiche.')),
        action: _hasFilters ? TextButton(onPressed: _resetFilters, child: Text(t('Réinitialiser les filtres'))) : null,
      );
    }
    if (_view == _View.pending) return Column(children: [for (final i in items) _pendingCard(i)]);
    if (width >= kFicheHistoryTableMinWidth) return _historyTable(items);
    return Column(key: const ValueKey('history-cards'), children: [for (final i in items) _historyCard(i)]);
  }

  Widget _stateBox({required String key, required IconData icon, required Color color, required String text, Widget? action}) {
    return Container(
      key: ValueKey(key),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kCrmBorder)),
      child: Column(children: [
        Icon(icon, size: 36, color: color),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center, style: tInter(fontSize: 13.5, color: color == kCrmTextSub ? kCrmTextSub : color)),
        if (action != null) ...[const SizedBox(height: 12), action],
      ]),
    );
  }

  // Valeurs de décision : tirets tant que la fiche est en attente ; motif
  // uniquement pour une fiche refusée.
  String _validator(FicheApprovalItem i) => i.isPending ? '—' : (i.decidedByEmail ?? '—');
  String _decisionDate(FicheApprovalItem i) => i.isPending ? '—' : faDateTime(i.decidedAt);
  String _reason(FicheApprovalItem i) => i.isRejected ? (i.rejectionComment ?? '—') : '—';
  String _typeMachine(FicheApprovalItem i) => '${i.ficheTypeLabel} · ${t('Machine')} ${i.machine ?? '—'}';
  String _prodDate(FicheApprovalItem i) => i.dateProduction == null ? '—' : faDate(DateTime.tryParse(i.dateProduction!));

  // ── Historique : tableau (écran large) ──────────────────────────────────
  Widget _historyTable(List<FicheApprovalItem> items) {
    TextStyle cell([Color? c, FontWeight? w]) => tInter(fontSize: 12.5, color: c ?? kCrmText, fontWeight: w);
    // (libellé, largeur relative) — toutes les colonnes tiennent dans la page.
    const columns = [
      ('N° de fiche', 2.0),
      ('Type / machine', 2.0),
      ('Producteur', 2.3),
      ('Date de production', 1.5),
      ('Date de création', 1.6),
      ('Statut', 2.0),
      ('Validateur', 2.3),
      ('Date de décision', 1.6),
      ('Motif du refus', 2.4),
      ('Actions', 1.3),
    ];
    Widget row(List<Widget> cells, {Color? background, Key? key}) => Container(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: background, border: const Border(bottom: BorderSide(color: kCrmBorder))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            for (var c = 0; c < columns.length; c++)
              Expanded(
                flex: (columns[c].$2 * 10).round(),
                child: Padding(padding: const EdgeInsets.only(right: 10), child: Align(alignment: Alignment.centerLeft, child: cells[c])),
              ),
          ]),
        );
    Text txt(String v, {Key? key, Color? color, FontWeight? weight, int lines = 2}) =>
        Text(v, key: key, maxLines: lines, overflow: TextOverflow.ellipsis, style: cell(color, weight));

    return Container(
      key: const ValueKey('history-table'),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kCrmBorder)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        row([
          for (final (label, _) in columns)
            Text(t(label), maxLines: 2, style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmTextSub)),
        ], background: kCrmBg),
        for (final i in items)
          row(key: ValueKey('history-row-${i.id}'), [
            txt(i.reference, weight: FontWeight.w700),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              txt(_typeMachine(i)),
              txt(t(i.posteLabel ?? '—'), color: kCrmTextSub, lines: 1),
            ]),
            txt(i.creatorEmail ?? '—'),
            txt(_prodDate(i)),
            txt(faDateTime(i.createdAt)),
            FicheApprovalBadge(key: ValueKey('history-status-${i.id}'), status: i.status, compact: true, decisionWording: true),
            txt(_validator(i), key: ValueKey('history-validator-${i.id}')),
            txt(_decisionDate(i), key: ValueKey('history-date-${i.id}')),
            Tooltip(
              message: _reason(i),
              child: txt(_reason(i),
                  key: ValueKey('history-reason-${i.id}'),
                  lines: 3,
                  color: i.isRejected ? kCrmDanger : null,
                  weight: i.isRejected ? FontWeight.w600 : null),
            ),
            // Bouton compact : libellé complet en info-bulle et pour l'accessibilité.
            IconButton.outlined(
              key: ValueKey('history-open-${i.id}'),
              tooltip: t('Voir le détail'),
              onPressed: () => _openFiche(i.ficheType, i.id),
              icon: const Icon(Icons.visibility_outlined, size: 18, color: kCrmPrimary),
            ),
          ]),
      ]),
    );
  }

  // ── Historique : cartes (écran étroit) ──────────────────────────────────
  Widget _historyCard(FicheApprovalItem i) {
    Widget line(String label, String value, {Key? key, Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '${t(label)} : ', style: tInter(fontSize: 12.5, color: kCrmTextSub)),
              TextSpan(text: value, style: tInter(fontSize: 12.5, color: color ?? kCrmText, fontWeight: FontWeight.w600)),
            ]),
            key: key,
          ),
        );
    return Container(
      key: ValueKey('history-card-${i.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kCrmBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(i.reference, style: tInter(fontSize: 14.5, fontWeight: FontWeight.w800, color: kCrmText)),
          FicheApprovalBadge(key: ValueKey('history-status-${i.id}'), status: i.status, decisionWording: true),
        ]),
        line('Type / machine', '${_typeMachine(i)} · ${t(i.posteLabel ?? '—')}'),
        line('Producteur', i.creatorEmail ?? '—'),
        line('Date de production', _prodDate(i)),
        line('Date de création', faDateTime(i.createdAt)),
        line('Validateur', _validator(i)),
        line('Date de décision', _decisionDate(i)),
        line('Motif du refus', _reason(i), key: ValueKey('history-reason-${i.id}'), color: i.isRejected ? kCrmDanger : null),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: ValueKey('history-open-${i.id}'),
            onPressed: () => _openFiche(i.ficheType, i.id),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: Text(t('Voir le détail')),
          ),
        ),
      ]),
    );
  }

  // ── En attente : cartes avec actions ────────────────────────────────────
  Widget _pendingCard(FicheApprovalItem i) {
    final canDecide = _perms?.canDecide == true && i.isPending;
    String qty(double? v) => v == null ? '—' : NumberFormatter.short(v);
    return Container(
      key: ValueKey('fiche-card-${i.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kCrmBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(i.reference, style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: kCrmText)),
          _tag(i.ficheTypeLabel),
          FicheApprovalBadge(status: i.status, decisionWording: true),
          if (i.version > 1) Text('${t('Soumission n°')} ${i.version}', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 18, runSpacing: 6, children: [
          _info(Icons.person_outline_rounded, i.creatorEmail ?? '—'),
          _info(i.poste == 'matin' ? Icons.wb_sunny_rounded : Icons.nightlight_round, '${t('Poste')} ${t(i.posteLabel ?? '—')}'),
          _info(Icons.precision_manufacturing_outlined, '${t('Machine')} ${i.machine ?? '—'}'),
          _info(Icons.event_outlined, '${t('Production du')} ${_prodDate(i)}'),
          _info(Icons.schedule_rounded, '${t('Créée le')} ${faDateTime(i.createdAt)}'),
          _info(Icons.edit_note_rounded, t(i.saisieLabel ?? '—')),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 18, runSpacing: 6, children: [
          _info(Icons.speed_rounded, '${t(i.productionLabel)} : ${qty(i.productionValue)}${i.productionUnit == null ? '' : ' ${i.productionUnit}'}'),
          for (final (label, v) in i.dechets) _info(Icons.delete_outline_rounded, '${t(label)} : ${qty(v)}'),
        ]),
        if (i.rejectionComment != null) ...[
          const SizedBox(height: 10),
          Text(
            '${t('Motif du refus précédent :')} ${i.rejectionComment} (${faDateTime(i.rejectedAt)})',
            key: ValueKey('fiche-previous-reason-${i.id}'),
            style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmTextSub),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            key: ValueKey('fiche-open-${i.id}'),
            onPressed: () => _openFiche(i.ficheType, i.id),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: Text(t('Voir le détail')),
          ),
          if (canDecide) ...[
            FilledButton.icon(
              key: ValueKey('fiche-approve-${i.id}'),
              style: FilledButton.styleFrom(backgroundColor: kCrmSuccess),
              onPressed: () => _decide(i, approve: true),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text(t('Accepter')),
            ),
            FilledButton.icon(
              key: ValueKey('fiche-reject-${i.id}'),
              style: FilledButton.styleFrom(backgroundColor: kCrmDanger),
              onPressed: () => _decide(i, approve: false),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: Text(t('Refuser')),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _tag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: kCrmBorder)),
        child: Text(label, style: tInter(fontSize: 11, fontWeight: FontWeight.w700, color: kCrmTextSub)),
      );

  Widget _info(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: kCrmTextSub),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: tInter(fontSize: 12.5, color: kCrmText))),
      ]);
}

/// Format court d'une quantité (sans zéros inutiles).
abstract final class NumberFormatter {
  static String short(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// « Valider » : confirmation puis appel. Renvoie le message à afficher
/// (null si annulé). Succès annoncé uniquement après réponse du backend.
Future<(String, bool)?> approveFicheFlow(BuildContext context, FicheApprovalApi api, FicheApprovalItem item) async {
  String t(String k) => faT(context, k);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${t('Accepter la fiche')} ${item.reference} ?'),
      content: Text(t('La fiche passera au statut « Validée ». Cette décision sera enregistrée avec votre nom, la date et l\'heure.')),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t('Annuler'))),
        FilledButton(
          key: const ValueKey('confirm-approve'),
          style: FilledButton.styleFrom(backgroundColor: kCrmSuccess),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(t('Accepter')),
        ),
      ],
    ),
  );
  if (ok != true) return null;
  try {
    final saved = await api.approve(item);
    return ('${t('Fiche')} ${saved.reference} ${t('validée avec succès.')}', true);
  } catch (e) {
    return ('${t('La validation a échoué : la fiche reste en attente.')} ${FicheApprovalService.friendlyError(e)}', false);
  }
}

/// « Refuser » : motif obligatoire puis appel.
Future<(String, bool)?> rejectFicheFlow(BuildContext context, FicheApprovalApi api, FicheApprovalItem item) async {
  String t(String k) => faT(context, k);
  final comment = await showDialog<String>(context: context, builder: (_) => FicheRejectDialog(reference: item.reference));
  if (comment == null) return null;
  try {
    final saved = await api.reject(item, comment: comment);
    return ('${t('Fiche')} ${saved.reference} ${t('refusée. Le motif a été transmis à son créateur.')}', true);
  } catch (e) {
    return ('${t('Le refus a échoué : la fiche reste en attente.')} ${FicheApprovalService.friendlyError(e)}', false);
  }
}

class FicheRejectDialog extends StatefulWidget {
  final String reference;
  const FicheRejectDialog({super.key, required this.reference});

  @override
  State<FicheRejectDialog> createState() => _FicheRejectDialogState();
}

class _FicheRejectDialogState extends State<FicheRejectDialog> {
  final _comment = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String k) => faT(context, k);
    return AlertDialog(
      title: Text('${t('Refuser la fiche')} ${widget.reference}'),
      content: SizedBox(
        width: 460,
        child: TextField(
          key: const ValueKey('fiche-reject-comment'),
          controller: _comment,
          autofocus: true,
          maxLength: 2000,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: t('Motif du refus (obligatoire)'),
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t('Annuler'))),
        FilledButton(
          key: const ValueKey('confirm-fiche-reject'),
          style: FilledButton.styleFrom(backgroundColor: kCrmDanger),
          onPressed: () {
            final text = _comment.text.trim();
            if (text.isEmpty) {
              setState(() => _error = t('Le motif du refus est obligatoire.'));
              return;
            }
            Navigator.of(context).pop(text);
          },
          child: Text(t('Refuser')),
        ),
      ],
    );
  }
}

/// Détail complet d'une fiche : informations, quantités, sections, tableaux,
/// historique des décisions et actions autorisées. Se ferme en renvoyant le
/// message de la dernière action réussie ou échouée.
class FicheApprovalDetailDialog extends StatefulWidget {
  final FicheApprovalApi api;
  final String ficheType;
  final String id;
  const FicheApprovalDetailDialog({super.key, required this.api, required this.ficheType, required this.id});

  @override
  State<FicheApprovalDetailDialog> createState() => _FicheApprovalDetailDialogState();
}

class _FicheApprovalDetailDialogState extends State<FicheApprovalDetailDialog> {
  FicheApprovalItem? _item;
  String? _error;
  (String, bool)? _message;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final item = await widget.api.detail(widget.ficheType, widget.id);
      if (mounted) setState(() {
        _item = item;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = FicheApprovalService.friendlyError(e));
    }
  }

  Future<void> _decide({required bool approve}) async {
    final item = _item!;
    final res = approve ? await approveFicheFlow(context, widget.api, item) : await rejectFicheFlow(context, widget.api, item);
    if (res == null || !mounted) return;
    setState(() => _message = res);
    await _fetch();
  }

  String t(String k) => faT(context, k);

  @override
  Widget build(BuildContext context) {
    final i = _item;
    final size = MediaQuery.of(context).size;
    return Dialog(
      key: const ValueKey('fiche-detail-dialog'),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 860, maxHeight: size.height * 0.9),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(children: [
              Expanded(
                child: Text(i == null ? t('Fiche de production') : '${i.ficheTypeLabel} — ${i.reference}',
                    style: tInter(fontSize: 17, fontWeight: FontWeight.w800, color: kCrmText)),
              ),
              IconButton(
                key: const ValueKey('fiche-detail-close'),
                tooltip: t('Fermer'),
                onPressed: () => Navigator.of(context).pop(_message),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _error != null
                  ? Text('${t('Erreur :')} $_error', style: tInter(fontSize: 13, color: kCrmDanger))
                  : i == null
                      ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                      : _content(i),
            ),
          ),
          if (i != null && (i.canDecide || i.canResubmit)) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
                if (i.canDecide) ...[
                  FilledButton.icon(
                    key: const ValueKey('detail-reject'),
                    style: FilledButton.styleFrom(backgroundColor: kCrmDanger),
                    onPressed: () => _decide(approve: false),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(t('Refuser')),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('detail-approve'),
                    style: FilledButton.styleFrom(backgroundColor: kCrmSuccess),
                    onPressed: () => _decide(approve: true),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(t('Accepter')),
                  ),
                ],
                if (i.canResubmit)
                  FicheResubmitButton(
                    api: widget.api,
                    ficheType: i.ficheType,
                    ficheId: i.id,
                    onResubmitted: (_) {
                      setState(() => _message = (t('Fiche soumise de nouveau au responsable logistique.'), true));
                      _fetch();
                    },
                  ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _content(FicheApprovalItem i) {
    final (msg, ok) = _message ?? ('', true);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_message != null) ...[
        Text(msg,
            key: ValueKey(ok ? 'detail-success' : 'detail-error'),
            style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: ok ? kCrmSuccess : kCrmDanger)),
        const SizedBox(height: 12),
      ],
      FicheApprovalNotice(
        decisionWording: true,
        approval: FicheApproval(
          status: i.status,
          version: i.version,
          decidedAt: i.decidedAt,
          decidedByEmail: i.decidedByEmail,
          rejectedAt: i.rejectedAt,
          rejectionComment: i.rejectionComment,
        ),
      ),
      const SizedBox(height: 16),
      _section(t('Fiche'), [
        (t('Numéro'), i.reference),
        (t('Type'), i.ficheTypeLabel),
        (t('Créée le'), faDateTime(i.createdAt)),
        (t('Créée par'), i.creatorEmail ?? '—'),
        (t('Poste'), t(i.posteLabel ?? '—')),
        (t('Machine'), i.machine ?? '—'),
        (t('Saisie'), t(i.saisieLabel ?? '—')),
        (t('Statut actuel'), t(kFicheDecisionLabels[i.status] ?? 'Statut inconnu')),
      ]),
      for (final s in i.sections) _section(t(s.title), [for (final (l, v) in s.rows) (t(l), v)]),
      for (final tb in i.tables) _table(tb),
      const SizedBox(height: 8),
      Text(t('Historique de validation'), style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText)),
      const SizedBox(height: 8),
      for (final h in i.history)
        Padding(
          key: ValueKey('history-${h.version}-${h.toStatus}'),
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FicheApprovalBadge(status: h.toStatus, compact: true, decisionWording: true),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${faDateTime(h.createdAt)} — ${h.changedByEmail ?? '—'} (${t('soumission n°')} ${h.version})'
                '${h.comment == null ? '' : ' : ${h.comment}'}',
                style: tInter(fontSize: 12.5, color: kCrmText),
              ),
            ),
          ]),
        ),
    ]);
  }

  Widget _section(String title, List<(String, String)> rows) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText)),
          const SizedBox(height: 6),
          Wrap(spacing: 24, runSpacing: 6, children: [
            for (final (l, v) in rows)
              SizedBox(
                width: 250,
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$l : ', style: tInter(fontSize: 12.5, color: kCrmTextSub)),
                  TextSpan(text: v, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText)),
                ])),
              ),
          ]),
        ]),
      );

  Widget _table(FicheDetailTable tb) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t(tb.title), style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 40,
              headingRowColor: WidgetStateProperty.all(kCrmBg),
              columns: [for (final c in tb.columns) DataColumn(label: Text(t(c), style: tInter(fontSize: 12, fontWeight: FontWeight.w700)))],
              rows: [
                for (final r in tb.rows)
                  DataRow(cells: [for (final c in r) DataCell(Text(c.isEmpty ? '—' : c, style: tInter(fontSize: 12)))]),
              ],
            ),
          ),
        ]),
      );
}
