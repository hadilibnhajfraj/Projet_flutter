// lib/quality_control/view/quality_control_superadmin_screen.dart
//
// Tableau de bord Contrôle Qualité — SUPER ADMINISTRATEUR (consultation).
//
// TOUTES les fiches de contrôle qualité, quel que soit le contrôleur :
// indicateurs (GET /quality-control/admin/overview — comptés en base, sur la
// période choisie), répartition PROMESH / PROBAR, tableau global paginé et
// trié par le SERVEUR (GET /quality-control/admin/controls). Le détail d'une
// fiche s'ouvre dans l'écran existant (/quality-control/control/:id).
// Aucune écriture depuis cet écran ; accès : rôle superadmin (route +
// backend, 403 pour tout autre rôle).

import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import '../model/quality_control_admin.dart';
import '../model/quality_control_model.dart';
import '../quality_control_i18n.dart';
import '../quality_control_routes.dart';
import '../service/quality_control_service.dart';
import 'quality_control_widgets.dart';

class QualityControlSuperAdminScreen extends StatefulWidget {
  const QualityControlSuperAdminScreen({super.key});

  @override
  State<QualityControlSuperAdminScreen> createState() => _QualityControlSuperAdminScreenState();
}

class _QualityControlSuperAdminScreenState extends State<QualityControlSuperAdminScreen> {
  static const _pageSize = 20;
  static const _debounce = Duration(milliseconds: 350);

  final _iso = DateFormat('yyyy-MM-dd');
  final _searchCtrl = TextEditingController();
  Timer? _searchTimer;
  int _listSeq = 0;
  int _overviewSeq = 0;

  QcAdminOverview? _overview;
  String? _overviewError;
  QualityControlPage _page = const QualityControlPage();
  bool _loading = true;
  String? _error;

  int _pageIndex = 1;
  String _type = '';
  String _statusFilter = '';
  DateTime? _from;
  DateTime? _to;
  String _sort = QcAdminSort.date;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _loadOverview();
    _loadList();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String? get _fromIso => _from == null ? null : _iso.format(_from!);
  String? get _toIso => _to == null ? null : _iso.format(_to!);

  Future<void> _loadOverview() async {
    final seq = ++_overviewSeq;
    setState(() => _overviewError = null);
    try {
      final o = await QualityControlService.instance.fetchAdminOverview(from: _fromIso, to: _toIso);
      if (mounted && seq == _overviewSeq) setState(() => _overview = o);
    } catch (e) {
      if (mounted && seq == _overviewSeq) setState(() => _overviewError = e.toString());
    }
  }

  Future<void> _loadList() async {
    final seq = ++_listSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    final (_, _, state, status) = kQcAdminStatusFilters.firstWhere((f) => f.$1 == _statusFilter);
    try {
      final page = await QualityControlService.instance.fetchAdminControls(
        page: _pageIndex,
        limit: _pageSize,
        search: _searchCtrl.text,
        productionType: _type,
        state: state,
        status: status,
        from: _fromIso,
        to: _toIso,
        sort: _sort,
        ascending: _ascending,
      );
      // Réponse obsolète (filtre modifié entre-temps) : ignorée.
      if (mounted && seq == _listSeq) setState(() => _page = page);
    } catch (e) {
      if (mounted && seq == _listSeq) setState(() => _error = e.toString());
    } finally {
      if (mounted && seq == _listSeq) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => Future.wait([_loadOverview(), _loadList()]);

  void _reloadList() {
    _pageIndex = 1;
    _loadList();
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_debounce, _reloadList);
    setState(() {}); // bouton d'effacement
  }

  void _setType(String v) {
    setState(() => _type = v);
    _reloadList();
  }

  void _setSort(String key) {
    setState(() {
      if (_sort == key) {
        _ascending = !_ascending;
      } else {
        _sort = key;
        // Dates : plus récentes d'abord ; texte : ordre alphabétique.
        _ascending = !(key == QcAdminSort.date || key == QcAdminSort.updatedAt);
      }
    });
    _reloadList();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _from != null && _to != null ? DateTimeRange(start: _from!, end: _to!) : null,
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    _loadOverview();
    _reloadList();
  }

  bool get _hasFilters => _type.isNotEmpty || _statusFilter.isNotEmpty || _from != null || _searchCtrl.text.trim().isNotEmpty;

  void _reset() {
    _searchTimer?.cancel();
    final periodChanged = _from != null;
    setState(() {
      _searchCtrl.clear();
      _type = '';
      _statusFilter = '';
      _from = null;
      _to = null;
    });
    if (periodChanged) _loadOverview();
    _reloadList();
  }

  String get _periodLabel {
    final f = DateFormat('dd/MM/yyyy');
    return _from == null || _to == null ? 'Toutes les périodes' : '${f.format(_from!)} → ${f.format(_to!)}';
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    return QcPage(
      onRefresh: _refresh,
      children: [
        QcPageHeader(
          crumbs: const [('Tableau de bord', null), ('Contrôle Qualité', null)],
          title: 'Tableau de bord Contrôle Qualité',
          subtitle: 'Toutes les fiches de contrôle qualité, tous contrôleurs confondus (consultation).',
          icon: Icons.verified_user_outlined,
          actions: [
            OutlinedButton.icon(
              key: const ValueKey('qc-admin-refresh'),
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Actualiser'),
            ),
          ],
        ),
        _filters(),
        _kpis(),
        _byProduct(),
        _tableSection(),
      ],
    );
  }

  // ── Filtres ────────────────────────────────────────────────────────────

  Widget _filters() {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: kCrmBorder));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: qcCardDecoration(),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: TextField(
            key: const ValueKey('qc-admin-search'),
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            onSubmitted: (_) {
              _searchTimer?.cancel();
              _reloadList();
            },
            style: tInter(fontSize: 13, color: kCrmText),
            decoration: InputDecoration(
              isDense: true,
              hintText: qcT('Numéro de fiche (QC-…)'),
              hintStyle: tInter(fontSize: 12.5, color: kCrmTextSub),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: qcT('Effacer'),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        _reloadList();
                      },
                    ),
              filled: true,
              fillColor: kCrmBg,
              border: border,
              enabledBorder: border,
            ),
          ),
        ),
        _segmented<String>(
          key: const ValueKey('qc-admin-filter-product'),
          value: _type,
          options: [('', 'Tous les produits'), ('PROMESH', 'PROMESH'), ('PROBAR', 'PROBAR')],
          colorOf: (v) => v.isEmpty ? kCrmText : productionTypeColor(v),
          onChanged: _setType,
        ),
        _segmented<String>(
          key: const ValueKey('qc-admin-filter-status'),
          value: _statusFilter,
          options: [for (final f in kQcAdminStatusFilters) (f.$1, f.$2)],
          colorOf: (v) => switch (v) {
            'conformes' || 'validated' => kQcConformeText,
            'nonConformes' => kQcNonConformeText,
            'draft' => kQcAVerifierText,
            _ => kCrmText,
          },
          onChanged: (v) {
            setState(() => _statusFilter = v);
            _reloadList();
          },
        ),
        OutlinedButton.icon(
          key: const ValueKey('qc-admin-filter-period'),
          onPressed: _pickRange,
          style: OutlinedButton.styleFrom(foregroundColor: kCrmText, side: const BorderSide(color: kCrmBorder)),
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(_from == null ? 'Période' : _periodLabel),
        ),
        if (_hasFilters)
          TextButton.icon(
            key: const ValueKey('qc-admin-reset'),
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Réinitialiser'),
          ),
      ]),
    );
  }

  Widget _segmented<T>({
    Key? key,
    required T value,
    required List<(T, String)> options,
    required Color Function(T v) colorOf,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
      child: Wrap(children: [
        for (final (v, label) in options)
          InkWell(
            onTap: () => onChanged(v),
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: v == value ? kCrmSurface : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                boxShadow: v == value ? const [BoxShadow(color: Color(0x140F172A), blurRadius: 4, offset: Offset(0, 1))] : null,
              ),
              child: Text(label,
                  style: tInter(fontSize: 12, fontWeight: v == value ? FontWeight.w700 : FontWeight.w500, color: v == value ? colorOf(v) : kCrmTextSub)),
            ),
          ),
      ]),
    );
  }

  // ── Indicateurs ────────────────────────────────────────────────────────

  String? _value(int Function(QcAdminCounts c) of) => _overview == null ? null : qcFormatInt(of(_overview!.totals));

  String? _share(int Function(QcAdminCounts c) of) {
    final t = _overview?.totals;
    if (t == null || t.total == 0) return null;
    return '${(of(t) * 100 / t.total).round()} % du total';
  }

  Widget _kpis() {
    if (_overviewError != null) {
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: QcErrorBanner(_overviewError!, onRetry: _loadOverview));
    }
    final tiles = [
      QcKpiTile(
        key: const ValueKey('qc-admin-kpi-total'),
        icon: Icons.fact_check_outlined,
        label: 'Fiches de contrôle qualité',
        value: _value((c) => c.total),
        caption: _periodLabel,
      ),
      QcKpiTile(
        key: const ValueKey('qc-admin-kpi-validated'),
        icon: Icons.verified_rounded,
        label: 'Fiches validées',
        value: _value((c) => c.validated),
        caption: _share((c) => c.validated),
        color: kQcConformeText,
      ),
      QcKpiTile(
        key: const ValueKey('qc-admin-kpi-pending'),
        icon: Icons.schedule_rounded,
        label: 'En attente (brouillons)',
        value: _value((c) => c.pending),
        caption: _share((c) => c.pending),
        color: kQcAVerifierText,
      ),
      QcKpiTile(
        key: const ValueKey('qc-admin-kpi-nonconformes'),
        icon: Icons.cancel_rounded,
        label: 'Non conformes',
        value: _value((c) => c.nonConformes),
        caption: _share((c) => c.nonConformes),
        color: kQcNonConformeText,
      ),
      QcKpiTile(
        key: const ValueKey('qc-admin-kpi-conformes'),
        icon: Icons.check_circle_rounded,
        label: 'Conformes',
        value: _value((c) => c.conformes),
        caption: _share((c) => c.conformes),
        color: kQcConformeText,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: qcGrid(tiles, columns: qcColumnsFor(210, max: 5)),
    );
  }

  Widget _byProduct() {
    final lines = _overview?.byProduct ?? const <QcAdminLineCounts>[];
    return QcSection(
      icon: Icons.pie_chart_outline_rounded,
      title: 'Répartition par produit',
      subtitle: 'Fiches par ligne de production · $_periodLabel',
      children: [
        // Erreur de l'API : jamais présentée comme « aucune fiche ».
        if (_overviewError != null)
          const QcEmptyState('Répartition indisponible : les indicateurs n\'ont pas pu être chargés.', icon: Icons.cloud_off_rounded)
        else if (_overview == null)
          const QcSkeletonRows(rows: 2, height: 56)
        else if (lines.isEmpty)
          const QcEmptyState('Aucune fiche sur cette période', icon: Icons.pie_chart_outline_rounded)
        else
          qcGrid([for (final l in lines) _lineCard(l)], columns: qcColumnsFor(320, max: 2)),
      ],
    );
  }

  Widget _lineCard(QcAdminLineCounts l) {
    final color = productionTypeColor(l.type);
    final selected = _type == l.type;
    final segments = [
      (l.conformes, kQcConformeText, 'Conformes'),
      (l.nonConformes, kQcNonConformeText, 'Non conformes'),
      (l.pending, kQcAVerifierText, 'En attente'),
    ];
    return InkWell(
      key: ValueKey('qc-admin-product-${l.type}'),
      borderRadius: BorderRadius.circular(kQcRadius),
      // Filtre le tableau sur ce produit (second appui : tous les produits).
      onTap: () => _setType(selected ? '' : l.type),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: qcCardDecoration(border: selected ? color : null),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            QcLineChip(l.type),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${qcFormatInt(l.total)} fiche${l.total > 1 ? 's' : ''}',
                  style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: kCrmText)),
            ),
            Text('${qcFormatInt(l.validated)} validée${l.validated > 1 ? 's' : ''}', style: tInter(fontSize: 12, color: kCrmTextSub)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: l.total == 0
                  ? Container(color: kCrmBorder)
                  : Row(children: [
                      for (final (n, c, _) in segments)
                        if (n > 0) Expanded(flex: n, child: Container(color: c)),
                    ]),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 4, children: [
            for (final (n, c, label) in segments)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Text('$label : ${qcFormatInt(n)}', style: tInter(fontSize: 12, color: kCrmText)),
              ]),
          ]),
        ]),
      ),
    );
  }

  // ── Tableau global ─────────────────────────────────────────────────────

  Widget _tableSection() => QcSection(
        icon: Icons.table_rows_outlined,
        title: 'Toutes les fiches de contrôle qualité',
        subtitle: _error != null
            ? 'Données indisponibles'
            : _loading && _page.items.isEmpty
                ? 'Chargement…'
                : '${qcFormatInt(_page.total)} fiche(s)',
        trailing: _loading && _page.items.isNotEmpty
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : null,
        children: [
          if (_error != null)
            QcErrorBanner(_error!, onRetry: _loadList)
          else
            _QcAdminTable(
              controls: _page.items,
              loading: _loading,
              sort: _sort,
              ascending: _ascending,
              onSort: _setSort,
              emptyText: _hasFilters ? 'Aucune fiche pour ces critères' : 'Aucune fiche de contrôle qualité',
            ),
          if (_error == null && _page.totalPages > 1) _pager(),
        ],
      );

  Widget _pager() {
    final first = (_page.page - 1) * _pageSize + 1;
    final last = (first + _page.items.length - 1).clamp(first, _page.total);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
        Text('$first–$last sur ${qcFormatInt(_page.total)}', style: tInter(fontSize: 12, color: kCrmTextSub)),
        const SizedBox(width: 8),
        Text('Page ${_page.page} / ${_page.totalPages}', key: const ValueKey('qc-admin-page'), style: tInter(fontSize: 12, color: kCrmTextSub)),
        IconButton(
          key: const ValueKey('qc-admin-prev'),
          tooltip: qcT('Page précédente'),
          visualDensity: VisualDensity.compact,
          onPressed: _pageIndex > 1 && !_loading
              ? () {
                  _pageIndex--;
                  _loadList();
                }
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          key: const ValueKey('qc-admin-next'),
          tooltip: qcT('Page suivante'),
          visualDensity: VisualDensity.compact,
          onPressed: _pageIndex < _page.totalPages && !_loading
              ? () {
                  _pageIndex++;
                  _loadList();
                }
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ]),
    );
  }
}

/// Tableau des fiches : colonnes triables (tri appliqué par le serveur),
/// défilement horizontal sous la largeur minimale (tablette / mobile) —
/// même présentation que le tableau de l'Historique.
class _QcAdminTable extends StatefulWidget {
  final List<QualityControlModel> controls;
  final bool loading;
  final String sort;
  final bool ascending;
  final ValueChanged<String> onSort;
  final String emptyText;

  const _QcAdminTable({
    required this.controls,
    required this.loading,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.emptyText,
  });

  @override
  State<_QcAdminTable> createState() => _QcAdminTableState();
}

class _QcAdminTableState extends State<_QcAdminTable> {
  static const _minWidth = 1080.0;
  static const _actionsWidth = 72.0;
  final _hScroll = ScrollController();
  final _updated = DateFormat('dd/MM/yyyy HH:mm');

  // (libellé, flex, clé de tri)
  static const _columns = <(String, int, String)>[
    ('N° de fiche', 16, QcAdminSort.reference),
    ('Produit', 14, QcAdminSort.product),
    ('Date de contrôle', 14, QcAdminSort.date),
    ('Responsable', 15, QcAdminSort.controller),
    ('Résultat', 13, QcAdminSort.result),
    ('Statut', 11, QcAdminSort.state),
    ('Dernière modification', 15, QcAdminSort.updatedAt),
  ];

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context);
    if (widget.loading && widget.controls.isEmpty) return const QcSkeletonRows(rows: 5, height: 36);
    if (widget.controls.isEmpty) return QcEmptyState(widget.emptyText, icon: Icons.fact_check_outlined);
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth < _minWidth ? _minWidth : c.maxWidth;
      final table = SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(),
          for (final control in widget.controls) _row(control),
        ]),
      );
      if (c.maxWidth >= _minWidth) return table;
      return Scrollbar(
        controller: _hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 10),
          child: table,
        ),
      );
    });
  }

  Widget _cell(int flex, Widget child) => Expanded(
        flex: flex,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Align(alignment: Alignment.centerLeft, child: child)),
      );

  Widget _header() => Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          for (final (label, flex, key) in _columns) _cell(flex, _sortHeader(label, key)),
          SizedBox(width: _actionsWidth, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _headerText('Actions', active: false))),
        ]),
      );

  Widget _sortHeader(String label, String key) {
    final active = widget.sort == key;
    return InkWell(
      key: ValueKey('qc-admin-sort-$key'),
      onTap: () => widget.onSort(key),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: _headerText(label, active: active)),
          const SizedBox(width: 4),
          Icon(
            active ? (widget.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded,
            size: 14,
            color: active ? kQualityControlColor : kCrmTextSub.withValues(alpha: 0.6),
          ),
        ]),
      ),
    );
  }

  Widget _headerText(String label, {required bool active}) => Text(label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tInter(fontSize: 10.5, fontWeight: FontWeight.w700, color: active ? kCrmText : kCrmTextSub, letterSpacing: 0.5));

  Widget _row(QualityControlModel c) {
    final text = tInter(fontSize: 12.5, color: kCrmText);
    void open() => context.go(QcPaths.control(c.id));
    var i = 0;
    Widget next(Widget child) => _cell(_columns[i++].$2, child);
    return InkWell(
      key: ValueKey('qc-admin-row-${c.id}'),
      onTap: open,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
        child: Row(children: [
          next(Text(c.reference.isEmpty ? '—' : c.reference,
              overflow: TextOverflow.ellipsis,
              style: text.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]))),
          next(Row(mainAxisSize: MainAxisSize.min, children: [
            QcLineChip(c.productionType, dense: true),
            if (c.machineLabel != null) ...[
              const SizedBox(width: 6),
              Flexible(child: Text(c.machineLabel!, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12, color: kCrmTextSub))),
            ],
          ])),
          next(Text(qcDateTime(c.controlDate, c.controlTime), style: text)),
          next(Tooltip(message: c.controllerEmail, child: Text(qcControllerLabel(c.controllerEmail), overflow: TextOverflow.ellipsis, style: text))),
          // Résultat : celui de la fiche validée ; brouillon = à vérifier.
          next(QcStatusBadge(c.isValidated ? c.status : 'EN_ATTENTE', dense: true)),
          next(QcStatusBadge(c.isValidated ? 'VALIDE' : 'BROUILLON', dense: true)),
          next(Text(c.updatedAt == null ? '—' : _updated.format(c.updatedAt!.toLocal()), style: text)),
          SizedBox(
            width: _actionsWidth,
            child: IconButton(
              key: ValueKey('qc-admin-open-${c.id}'),
              tooltip: qcT('Voir le détail'),
              visualDensity: VisualDensity.compact,
              onPressed: open,
              icon: const Icon(Icons.visibility_outlined, size: 18, color: kCrmTextSub),
            ),
          ),
        ]),
      ),
    );
  }
}
