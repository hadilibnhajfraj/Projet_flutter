// lib/production_records/view/production_records_screen.dart
//
// "Fiches de production" — vue centralisée en LECTURE des fiches PROMESH et
// PROBAR (voir GET /production-records, backend
// modules/production-records/). Aucune nouvelle donnée : projette les
// fiches PorPromesh et IndustrialRecord (module='probar') existantes.
//
// Design ERP : tableau professionnel, une seule action par ligne (Voir),
// détail complet dans un drawer latéral (jamais un simple rappel des
// colonnes déjà visibles) — voir _RecordDetailDrawer.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/por_promesh/view/widgets/shimmer_box.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

import '../model/production_record_model.dart';
import '../service/production_records_service.dart';

const _kPageSizes = [20, 50, 100];

const _kPeriods = <(String?, String)>[
  (null, 'Toutes les périodes'),
  ('today', "Aujourd'hui"),
  ('week', 'Cette semaine'),
  ('month', 'Ce mois'),
  ('quarter', 'Ce trimestre'),
  ('year', 'Cette année'),
  ('custom', 'Personnalisée'),
];

const _kSortFields = <(String, String)>[
  ('date', 'Date'),
  ('machine', 'Machine'),
  ('poste', 'Poste'),
  ('type', 'Type'),
  ('quantite', 'Quantité'),
  ('statut', 'Statut'),
];

class ProductionRecordsScreen extends StatefulWidget {
  const ProductionRecordsScreen({super.key});

  @override
  State<ProductionRecordsScreen> createState() => _ProductionRecordsScreenState();
}

class _ProductionRecordsScreenState extends State<ProductionRecordsScreen> {
  bool _loading = true;
  String? _error;

  String? _type; // null | 'probar' | 'promesh'
  String? _period;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _machineFilter;
  String? _posteFilter;
  // §MODIFICATION — ADMIN > PRODUCTION RECORDS — FILTRE PAR UTILISATEUR :
  // `null` = "All users". Le dropdown lui-même n'est affiché que pour un
  // rôle Admin (§10) — pour les autres rôles ce filtre n'a aucun effet
  // (déjà owner-scoped côté backend), donc jamais affiché pour eux.
  String? _createdBy;
  List<ProductionRecordCreator> _creators = const [];
  String _search = '';
  Timer? _searchDebounce;

  String _sortField = 'date';
  bool _sortAsc = false;

  int _page = 1;
  int _pageSize = 20;

  ProductionRecordPage _pageData = const ProductionRecordPage();
  ProductionRecordFilters _filters = const ProductionRecordFilters();

  bool get _isAdmin => AuthService().isAdmin;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    if (_isAdmin) _loadCreators();
    _loadList();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      final f = await ProductionRecordsService.instance.fetchFilters();
      if (!mounted) return;
      setState(() => _filters = f);
    } catch (_) {
      // Best-effort — les dropdowns retombent sur "Toutes/Tous" uniquement.
    }
  }

  Future<void> _loadList() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ProductionRecordsService.instance.fetchPage(
        type: _type,
        period: _period,
        startDate: _period == 'custom' && _customStart != null ? DateFormat('yyyy-MM-dd').format(_customStart!) : null,
        endDate: _period == 'custom' && _customEnd != null ? DateFormat('yyyy-MM-dd').format(_customEnd!) : null,
        machineId: _machineFilter,
        poste: _posteFilter,
        createdBy: _createdBy,
        search: _search,
        sort: '${_sortField}_${_sortAsc ? 'asc' : 'desc'}',
        page: _page,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() => _pageData = page);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // §MODIFICATION — ADMIN > PRODUCTION RECORDS — FILTRE PAR UTILISATEUR (§3) :
  // best-effort — si l'appel échoue, le dropdown retombe simplement sur
  // "All users" uniquement (même tolérance que _loadFilters).
  Future<void> _loadCreators() async {
    try {
      final creators = await ProductionRecordsService.instance.fetchCreators();
      if (!mounted) return;
      setState(() => _creators = creators);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _refreshAll() => Future.wait([_loadFilters(), if (_isAdmin) _loadCreators(), _loadList()]);

  void _onFilterChanged() {
    _page = 1;
    _loadList();
  }

  void _onSearchChanged(String value) {
    _search = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _onFilterChanged);
  }

  void _resetFilters() {
    setState(() {
      _type = null;
      _period = null;
      _customStart = null;
      _customEnd = null;
      _machineFilter = null;
      _posteFilter = null;
      _createdBy = null; // §12 : "Created by" -> "All users"
      _search = '';
      _sortField = 'date';
      _sortAsc = false;
      _page = 1;
    });
    _loadList();
  }

  void _openDetail(ProductionRecordModel item) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'detail',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim, secondaryAnim) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final width = MediaQuery.of(context).size.width;
        final drawerWidth = width < 700 ? width : (width * 0.42).clamp(420.0, 640.0);
        return Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: SizedBox(
              width: drawerWidth,
              height: double.infinity,
              child: _RecordDetailDrawer(compositeId: item.id, preview: item),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final isTablet = width >= 700 && width < 1100;

    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildStatsRow(context, isMobile),
              const SizedBox(height: 24),
              _buildProductionTotalsRow(context, isMobile),
              const SizedBox(height: 24),
              _buildTypeFilter(context),
              const SizedBox(height: 14),
              _buildFilterBar(context),
              const SizedBox(height: 18),
              _buildListHeader(context),
              const SizedBox(height: 12),
              if (_error != null)
                _buildError(context)
              else ...[
                _buildList(context, isMobile, isTablet),
                const SizedBox(height: 16),
                _buildPagination(context),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(children: [
      Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: kCrmPrimary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.receipt_long_outlined, size: 22, color: kCrmPrimary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.translate('Fiches de production'), style: tInter(fontSize: 21, fontWeight: FontWeight.w800, color: kCrmText)),
          const SizedBox(height: 2),
          Text(
            t.translate('Consultez et filtrez les fiches de production créées par les machines PROBAR et PROMESH.'),
            style: tInter(fontSize: 12.5, color: kCrmTextSub),
          ),
        ]),
      ),
    ]);
  }

  // ── STATISTIQUES ──────────────────────────────────────────────────────

  Widget _buildStatsRow(BuildContext context, bool isMobile) {
    final t = AppLocalizations.of(context);
    final crossAxisCount = isMobile ? 2 : 5;
    if (_loading && _pageData.statistics.total == 0) {
      return KpiSkeletonGrid(count: 5, crossAxisCount: crossAxisCount);
    }
    final s = _pageData.statistics;
    final cards = [
      KpiStatCard(icon: Icons.description_outlined, value: '${s.total}', label: t.translate('Total des fiches'), color: kCrmPrimary),
      KpiStatCard(icon: Icons.factory_outlined, value: '${s.probar}', label: t.translate('Fiches PROBAR'), color: kProbarColor),
      KpiStatCard(icon: Icons.factory_outlined, value: '${s.promesh}', label: t.translate('Fiches PROMESH'), color: kPromeshColor),
      KpiStatCard(icon: Icons.calendar_view_week_rounded, value: '${s.thisWeek}', label: t.translate('Cette semaine'), color: kCrmInfo),
      KpiStatCard(icon: Icons.calendar_month_rounded, value: '${s.thisMonth}', label: t.translate('Ce mois'), color: kCrmSuccess),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: isMobile ? 1.3 : 1.5,
      children: cards,
    );
  }

  // ── KPI INDUSTRIELS (Quantité / Diamètre / Taille de maille) ──────────
  //
  // Contrairement à _buildStatsRow ci-dessus (cartes globales, indépendantes
  // des filtres), ces KPI sont RECALCULÉS à chaque changement de filtre
  // (Type/Période/Machine/Poste) — voir productionTotals dans _loadList(),
  // rempli par la même requête GET /production-records déjà appelée à
  // chaque changement de filtre, sans appel réseau supplémentaire.
  //
  // Uniquement les fiches VALIDÉES comptent comme production réelle (voir
  // backend getProductionTotals — même règle que la validation manuelle/
  // automatique). `null` (côté non sélectionné par le filtre Type) masque
  // les cartes correspondantes ; `0` (aucune fiche validée ne correspond)
  // affiche "0", jamais "—" ni "null".
  Widget _buildProductionTotalsRow(BuildContext context, bool isMobile) {
    final t = AppLocalizations.of(context);
    final totals = _pageData.productionTotals;
    final probar = totals.probar;
    final promesh = totals.promesh;

    if (probar == null && promesh == null) return const SizedBox.shrink();

    final cards = <Widget>[
      if (probar != null)
        KpiStatCard(
          icon: Icons.inventory_2_outlined,
          value: '${_formatNumber(probar.quantity)} ${probar.quantityUnite}',
          label: '${t.translate('Quantité produite')} · PROBAR',
          color: kProbarColor,
        ),
      if (promesh != null)
        KpiStatCard(
          icon: Icons.inventory_2_outlined,
          value: '${_formatNumber(promesh.quantity)} ${promesh.quantityUnite}',
          label: '${t.translate('Quantité produite')} · PROMESH',
          color: kPromeshColor,
        ),
      if (probar != null)
        KpiStatCard(
          icon: Icons.circle_outlined,
          value: '${_formatNumber(probar.diameter)} ${probar.diameterUnite}',
          label: '${t.translate('Diamètre produit')} · PROBAR',
          color: kProbarColor,
        ),
      if (promesh != null)
        KpiStatCard(
          icon: Icons.circle_outlined,
          value: '${_formatNumber(promesh.diameter)} ${promesh.diameterUnite}',
          label: '${t.translate('Diamètre produit')} · PROMESH',
          color: kPromeshColor,
        ),
      if (promesh != null && promesh.meshSize != null)
        KpiStatCard(
          icon: Icons.grid_4x4_rounded,
          value: '${_formatNumber(promesh.meshSize!)} ${promesh.meshSizeUnite ?? 'mm'}',
          label: '${t.translate('Taille de maille produite')} · PROMESH',
          color: kPromeshColor,
        ),
    ];

    final crossAxisCount = isMobile ? 2 : cards.length.clamp(1, 5);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t.translate('Totaux de production'), style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText)),
      const SizedBox(height: 4),
      Text(t.translate('Fiches validées uniquement'), style: tInter(fontSize: 11.5, color: kCrmTextSub)),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: isMobile ? 1.3 : 1.5,
        children: cards,
      ),
    ]);
  }

  // Format professionnel des grands nombres : "1250" -> "1 250" (séparateur
  // espace, décimales conservées seulement si non nulles). N'affiche jamais
  // NaN/Infinity (retombe sur "0").
  String _formatNumber(double value) {
    if (!value.isFinite) return '0';
    final isNegative = value < 0;
    final absValue = value.abs();
    final intPart = absValue.truncate();
    final decimals = absValue - intPart;
    final intStr = intPart.toString();
    final grouped = StringBuffer();
    for (var i = 0; i < intStr.length; i++) {
      if (i > 0 && (intStr.length - i) % 3 == 0) grouped.write(' ');
      grouped.write(intStr[i]);
    }
    var result = grouped.toString();
    if (decimals > 0.001) {
      var decStr = decimals.toStringAsFixed(2).substring(2);
      decStr = decStr.replaceFirst(RegExp(r'0$'), '');
      if (decStr.isNotEmpty) result += ',$decStr';
    }
    return isNegative ? '-$result' : result;
  }

  // ── FILTRE TYPE (segmenté) ───────────────────────────────────────────

  Widget _buildTypeFilter(BuildContext context) {
    final t = AppLocalizations.of(context);
    Widget seg(String? value, String label, Color color) {
      final active = _type == value;
      return InkWell(
        onTap: () => setState(() {
          _type = value;
          _onFilterChanged();
        }),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.12) : kCrmSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? color : kCrmBorder, width: active ? 1.4 : 1),
          ),
          child: Text(t.translate(label), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? color : kCrmTextSub)),
        ),
      );
    }

    return Wrap(spacing: 10, runSpacing: 10, children: [
      seg(null, 'Toutes', kCrmPrimary),
      seg('probar', 'PROBAR', kProbarColor),
      seg('promesh', 'PROMESH', kPromeshColor),
    ]);
  }

  // ── RECHERCHE + FILTRES ───────────────────────────────────────────────

  Widget _buildFilterBar(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCrmBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          onChanged: _onSearchChanged,
          style: tInter(fontSize: 13, color: kCrmText),
          decoration: InputDecoration(
            hintText: t.translate('Rechercher une fiche...'),
            hintStyle: tInter(fontSize: 13, color: kCrmTextSub),
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: kCrmTextSub),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            filled: true,
            fillColor: kCrmBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmBorder)),
            focusedBorder:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmPrimary, width: 1.4)),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _dropdown<String?>(
            icon: Icons.event_outlined,
            value: _period,
            items: [for (final p in _kPeriods) (p.$1, t.translate(p.$2))],
            onChanged: (v) => setState(() {
              _period = v;
              _onFilterChanged();
            }),
          ),
          _dropdown<String?>(
            icon: Icons.precision_manufacturing_outlined,
            value: _machineFilter,
            items: [
              (null, t.translate('Toutes les machines')),
              for (final m in _filters.machines) (m, 'Machine $m'),
            ],
            onChanged: (v) => setState(() {
              _machineFilter = v;
              _onFilterChanged();
            }),
          ),
          _dropdown<String?>(
            icon: Icons.schedule_outlined,
            value: _posteFilter,
            items: [
              (null, t.translate('Tous les postes')),
              for (final p in _filters.postes) (p, p == 'matin' ? t.translate('Matin') : (p == 'nuit' ? t.translate('Nuit') : p)),
            ],
            onChanged: (v) => setState(() {
              _posteFilter = v;
              _onFilterChanged();
            }),
          ),
          // §MODIFICATION — ADMIN > PRODUCTION RECORDS — FILTRE PAR
          // UTILISATEUR (§2/§10) : "All users" — visible UNIQUEMENT pour un
          // rôle Admin (les autres rôles sont déjà owner-scoped côté
          // backend, ce filtre n'aurait aucun effet pour eux).
          if (_isAdmin)
            _dropdown<String?>(
              icon: Icons.person_outline_rounded,
              value: _createdBy,
              items: [
                (null, t.translate('All users')),
                for (final c in _creators) (c.id, c.displayLabel),
              ],
              onChanged: (v) => setState(() {
                _createdBy = v;
                _onFilterChanged();
              }),
            ),
          _dropdown<String>(
            icon: Icons.sort_rounded,
            value: _sortField,
            items: [for (final s in _kSortFields) (s.$1, t.translate(s.$2))],
            onChanged: (v) => setState(() {
              _sortField = v!;
              _onFilterChanged();
            }),
          ),
          InkWell(
            onTap: () => setState(() {
              _sortAsc = !_sortAsc;
              _onFilterChanged();
            }),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
              child: Icon(_sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16, color: kCrmTextSub),
            ),
          ),
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh_rounded, size: 16, color: kCrmTextSub),
            label: Text(t.translate('Réinitialiser'), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmTextSub)),
          ),
        ]),
        if (_period == 'custom') ...[
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _datePickerChip(
              label: t.translate('Date début'),
              value: _customStart,
              onPicked: (d) => setState(() {
                _customStart = d;
                _onFilterChanged();
              }),
            ),
            _datePickerChip(
              label: t.translate('Date fin'),
              value: _customEnd,
              onPicked: (d) => setState(() {
                _customEnd = d;
                _onFilterChanged();
              }),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _datePickerChip({required String label, required DateTime? value, required ValueChanged<DateTime> onPicked}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: kCrmTextSub),
          const SizedBox(width: 6),
          Text(
            value == null ? label : DateFormat('dd/MM/yyyy').format(value),
            style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText),
          ),
        ]),
      ),
    );
  }

  Widget _dropdown<T>({
    required IconData icon,
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T?> onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kCrmBorder)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.expand_more_rounded, size: 18, color: kCrmTextSub),
          style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText),
          selectedItemBuilder: (context) => [
            for (final item in items)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 14, color: kCrmTextSub),
                const SizedBox(width: 6),
                Text(item.$2, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText)),
              ]),
          ],
          items: [for (final item in items) DropdownMenuItem<T>(value: item.$1, child: Text(item.$2))],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── EN-TÊTE LISTE ─────────────────────────────────────────────────────

  Widget _buildListHeader(BuildContext context) {
    final total = _pageData.pagination.total;
    return Row(children: [
      Expanded(
        child: Text('$total fiche${total > 1 ? 's' : ''}', style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
      ),
      IconButton(
        tooltip: AppLocalizations.of(context).translate('Actualiser'),
        icon: _loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh_rounded, size: 18, color: kCrmTextSub),
        onPressed: _loading ? null : _refreshAll,
      ),
    ]);
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: kCrmDanger, size: 36),
          const SizedBox(height: 8),
          Text('${AppLocalizations.of(context).translate('Erreur de chargement :')} $_error',
              textAlign: TextAlign.center, style: tInter(fontSize: 13, color: kCrmTextSub)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadList, child: Text(AppLocalizations.of(context).translate('Réessayer'))),
        ]),
      ),
    );
  }

  // ── LISTE (CARTES / TABLEAU) ─────────────────────────────────────────

  Widget _buildList(BuildContext context, bool isMobile, bool isTablet) {
    if (_loading) return const FicheCardSkeletonList(count: 4);
    final items = _pageData.items;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
            child: Text(AppLocalizations.of(context).translate('Aucune fiche pour ces filtres'),
                style: tInter(fontSize: 13, color: kCrmTextSub))),
      );
    }

    if (isMobile) {
      return Column(children: [
        for (final item in items) ...[
          _RecordCard(item: item, onView: () => _openDetail(item)),
          const SizedBox(height: 12),
        ],
      ]);
    }

    return _RecordTable(items: items, compact: isTablet, onView: _openDetail);
  }

  // ── PAGINATION ────────────────────────────────────────────────────────

  Widget _buildPagination(BuildContext context) {
    final t = AppLocalizations.of(context);
    final totalPages = _pageData.pagination.totalPages;
    final page = _pageData.pagination.page;
    return Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text('${t.translate('Par page')} :', style: tInter(fontSize: 12.5, color: kCrmTextSub)),
      _dropdown<int>(
        icon: Icons.list_alt_rounded,
        value: _pageSize,
        items: [for (final s in _kPageSizes) (s, s.toString())],
        onChanged: (v) => setState(() {
          _pageSize = v!;
          _onFilterChanged();
        }),
      ),
      const SizedBox(width: 12),
      IconButton(
        icon: const Icon(Icons.chevron_left_rounded),
        onPressed: page > 1
            ? () => setState(() {
                  _page--;
                  _loadList();
                })
            : null,
      ),
      Text('${t.translate('Page')} $page ${t.translate('sur')} $totalPages', style: tInter(fontSize: 12.5, color: kCrmTextSub)),
      IconButton(
        icon: const Icon(Icons.chevron_right_rounded),
        onPressed: page < totalPages
            ? () => setState(() {
                  _page++;
                  _loadList();
                })
            : null,
      ),
    ]);
  }
}

// ── BADGES ──────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;
  final bool small;
  const _TypeBadge({required this.type, this.small = false});

  @override
  Widget build(BuildContext context) {
    final isProbar = type == 'probar';
    final color = isProbar ? kProbarColor : kPromeshColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(isProbar ? 'PROBAR' : 'PROMESH',
          style: tInter(fontSize: small ? 9.5 : 10.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3)),
    );
  }
}

// Badge de statut piloté par la donnée réelle : seules "brouillon"/"validee"
// existent aujourd'hui côté backend (voir productionRecords.dto.js) — tout
// autre statut futur retombe sur un badge neutre plutôt que d'être ignoré.
class _StatusBadge extends StatelessWidget {
  final String statut;
  const _StatusBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final Color color;
    final String label;
    switch (statut) {
      case 'validee':
        color = kCrmSuccess;
        label = t.translate('Validée');
      case 'brouillon':
        color = kCrmWarning;
        label = t.translate('Brouillon');
      default:
        color = kCrmTextSub;
        label = statut.isEmpty ? '—' : statut;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: tInter(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// §MODIFICATION — ADMIN > PRODUCTION RECORDS — FILTRE PAR UTILISATEUR (§8) :
// partie locale de l'email affichée dans le tableau ("production_1"),
// email complet au survol (Tooltip) — jamais l'inverse (l'email complet en
// double dans une cellule déjà étroite). §15 : "Unknown" pour une fiche sans
// créateur connu (données historiques), jamais un nom inventé.
class _CreatorCell extends StatelessWidget {
  final String? shortLabel;
  final String? email;
  const _CreatorCell({required this.shortLabel, required this.email});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (shortLabel == null) {
      return Text(t.translate('Unknown'), style: tInter(fontSize: 12.5, color: kCrmTextSub));
    }
    return Tooltip(
      message: email ?? shortLabel!,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.person_outline_rounded, size: 13, color: kCrmTextSub),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(shortLabel!,
              style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

// ── BOUTON "VOIR" (seule action de la ligne) ──────────────────────────

class _ViewButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.visibility_outlined, size: 15),
      label: Text(t.translate('Voir'), style: tInter(fontSize: 12, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: kCrmPrimary,
        side: const BorderSide(color: kCrmBorder),
        backgroundColor: kCrmSurface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── TABLEAU (DESKTOP / TABLETTE) — style ERP ──────────────────────────

class _RecordTable extends StatelessWidget {
  final List<ProductionRecordModel> items;
  final bool compact;
  final ValueChanged<ProductionRecordModel> onView;

  const _RecordTable({required this.items, required this.compact, required this.onView});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final columns = <DataColumn>[
      DataColumn(label: Text(t.translate('N° fiche'))),
      DataColumn(label: Text(t.translate('Type'))),
      DataColumn(label: Text(t.translate('Machine'))),
      DataColumn(label: Text(t.translate('Poste'))),
      DataColumn(label: Text(t.translate('Date'))),
      if (!compact) DataColumn(label: Text(t.translate('Heure début'))),
      if (!compact) DataColumn(label: Text(t.translate('Heure fin'))),
      DataColumn(label: Text(t.translate('Opérateur'))),
      DataColumn(label: Text(t.translate('Quantité')), numeric: true),
      DataColumn(label: Text(t.translate('Diamètre')), numeric: true),
      DataColumn(label: Text(t.translate('Statut'))),
      // §MODIFICATION — ADMIN > PRODUCTION RECORDS — FILTRE PAR UTILISATEUR
      // (§8) : "production_1" de préférence, email complet au survol.
      DataColumn(label: Text(t.translate('Created by'))),
      DataColumn(label: Text('Actions')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCrmBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTableTheme(
          data: DataTableThemeData(
            headingRowColor: WidgetStateProperty.all(kCrmBg),
            headingTextStyle: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: kCrmTextSub),
            dataTextStyle: tInter(fontSize: 12.5, color: kCrmText),
            dividerThickness: 1,
          ),
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 56,
            columnSpacing: 22,
            columns: columns,
            rows: [
              for (final item in items)
                DataRow(
                  color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.hovered) ? kCrmPrimary.withOpacity(0.04) : null),
                  onSelectChanged: (_) => onView(item),
                  cells: [
                    DataCell(Text(item.numero ?? '—', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText))),
                    DataCell(_TypeBadge(type: item.type, small: true)),
                    DataCell(Text(item.machine == null ? '—' : 'Machine ${item.machine}')),
                    DataCell(Text(item.poste == 'matin' ? t.translate('Matin') : (item.poste == 'nuit' ? t.translate('Nuit') : '—'))),
                    DataCell(Text(item.date ?? '—')),
                    if (!compact) DataCell(Text(item.heureDebut ?? '—')),
                    if (!compact) DataCell(Text(item.heureFin ?? '—')),
                    DataCell(Text(item.operateur ?? '—')),
                    DataCell(Text(item.quantite == null ? '—' : '${item.quantite} ${item.quantiteUnite}')),
                    DataCell(Text(item.diametre == null || item.diametre!.isEmpty ? '—' : '${item.diametre} ${item.diametreUnite}')),
                    DataCell(_StatusBadge(statut: item.statut)),
                    DataCell(_CreatorCell(shortLabel: item.creatorShortLabel, email: item.creatorEmail)),
                    DataCell(_ViewButton(onTap: () => onView(item))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CARTE (MOBILE) ────────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  final ProductionRecordModel item;
  final VoidCallback onView;
  const _RecordCard({required this.item, required this.onView});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final color = item.isProbar ? kProbarColor : kPromeshColor;
    return Container(
      decoration: BoxDecoration(
        color: kCrmSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCrmBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _TypeBadge(type: item.type),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.numero ?? '—',
                    style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              _StatusBadge(statut: item.statut),
            ]),
            const SizedBox(height: 10),
            _row(Icons.precision_manufacturing_outlined,
                '${item.machine == null ? '—' : 'Machine ${item.machine}'} · ${item.poste == 'matin' ? t.translate('Matin') : (item.poste == 'nuit' ? t.translate('Nuit') : '—')}'),
            _row(Icons.event_outlined, '${item.date ?? '—'}${item.heureDebut != null ? ' · ${item.heureDebut}' : ''}'),
            if (item.operateur != null) _row(Icons.person_outline_rounded, item.operateur!),
            // §MODIFICATION — ADMIN > PRODUCTION RECORDS — FILTRE PAR
            // UTILISATEUR (§8) — cohérence avec le tableau desktop.
            _row(Icons.badge_outlined, '${t.translate('Created by')} : ${item.creatorShortLabel ?? t.translate('Unknown')}'),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.speed_rounded, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                item.quantite == null
                    ? '${t.translate('Quantité')} : —'
                    : '${t.translate('Quantité')} : ${item.quantite} ${item.quantiteUnite}',
                style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmText),
              ),
            ]),
            if (item.diametre != null && item.diametre!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.circle_outlined, size: 12, color: color),
                const SizedBox(width: 6),
                Text('${t.translate('Diamètre')} : ${item.diametre} ${item.diametreUnite}',
                    style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmText)),
              ]),
            ],
            if (item.isPromesh && item.tailleMaille != null && item.tailleMaille!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.grid_4x4_rounded, size: 12, color: color),
                const SizedBox(width: 6),
                Text('${t.translate('Taille de maille pour ProMesh')} : ${item.tailleMaille}',
                    style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmText)),
              ]),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onView,
                icon: Icon(Icons.visibility_outlined, size: 16, color: color),
                label: Text(t.translate('Voir les détails'), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: color.withOpacity(0.4))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 12.5, color: kCrmTextSub),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: tInter(fontSize: 12, color: kCrmTextSub), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

// ── DÉTAIL (DRAWER LATÉRAL) ───────────────────────────────────────────

class _RecordDetailDrawer extends StatefulWidget {
  final String compositeId;
  final ProductionRecordModel preview;
  const _RecordDetailDrawer({required this.compositeId, required this.preview});

  @override
  State<_RecordDetailDrawer> createState() => _RecordDetailDrawerState();
}

class _RecordDetailDrawerState extends State<_RecordDetailDrawer> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ProductionRecordsService.instance.fetchDetail(widget.compositeId);
      if (!mounted) return;
      setState(() => _d = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers de rendu "jamais undefined/null à l'écran" ────────────────
  String _s(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    return s.isEmpty ? '—' : s;
  }

  String? _sOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String _dateFmt(dynamic iso, {bool withTime = false}) {
    final v = _sOrNull(iso);
    if (v == null) return '—';
    final d = DateTime.tryParse(v);
    if (d == null) return v;
    return DateFormat(withTime ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final type = (_d?['type'] ?? widget.preview.type).toString();
    final color = type == 'probar' ? kProbarColor : kPromeshColor;

    return Material(
      color: kCrmSurface,
      elevation: 8,
      child: SafeArea(
        child: Column(children: [
          _buildHeader(context, type, color),
          Expanded(
            child: _loading
                ? _buildLoading(t)
                : _error != null
                    ? _buildError(context, t)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final twoCol = constraints.maxWidth >= 460;
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _buildInfoSection(t, twoCol),
                            const SizedBox(height: 18),
                            _buildProductionSection(t, twoCol, color),
                            const SizedBox(height: 18),
                            _buildTechnicalSection(t, color),
                            const SizedBox(height: 18),
                            _buildTimelineSection(t, color),
                            const SizedBox(height: 18),
                            _buildStatusSection(t, twoCol),
                            const SizedBox(height: 18),
                            _buildAttachmentsSection(t),
                          ]);
                        }),
                      ),
          ),
          _buildFooter(context, t),
        ]),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String type, Color color) {
    final t = AppLocalizations.of(context);
    final numero = _s(_d?['numero'] ?? widget.preview.numero);
    final statut = (_d?['statut'] ?? widget.preview.statut).toString();
    final machine = _d?['machine'] ?? widget.preview.machine;
    final poste = _d?['poste'] ?? widget.preview.poste;
    final date = _d?['date'] ?? widget.preview.date;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.18))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _TypeBadge(type: type),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t.translate('Détails de la fiche'),
                style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmTextSub)),
          ),
          IconButton(icon: const Icon(Icons.close_rounded, color: kCrmTextSub), onPressed: () => Navigator.of(context).pop()),
        ]),
        const SizedBox(height: 4),
        Text(numero, style: tInter(fontSize: 19, fontWeight: FontWeight.w900, color: kCrmText)),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 8, children: [
          _headerStat(Icons.precision_manufacturing_outlined, machine == null ? '—' : 'Machine $machine'),
          _headerStat(Icons.schedule_outlined,
              poste == 'matin' ? t.translate('Matin') : (poste == 'nuit' ? t.translate('Nuit') : '—')),
          _headerStat(Icons.event_outlined, _s(date)),
          _StatusBadge(statut: statut),
        ]),
      ]),
    );
  }

  Widget _headerStat(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: kCrmTextSub),
      const SizedBox(width: 5),
      Text(text, style: tInter(fontSize: 12, fontWeight: FontWeight.w600, color: kCrmText)),
    ]);
  }

  Widget _buildLoading(AppLocalizations t) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(strokeWidth: 2.4),
        const SizedBox(height: 14),
        Text(t.translate('Chargement…'), style: tInter(fontSize: 12.5, color: kCrmTextSub)),
      ]),
    );
  }

  Widget _buildError(BuildContext context, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: kCrmDanger, size: 36),
          const SizedBox(height: 10),
          Text('${t.translate('Erreur :')} $_error', textAlign: TextAlign.center, style: tInter(fontSize: 12.5, color: kCrmTextSub)),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 16), label: Text(t.translate('Réessayer'))),
        ]),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kCrmBorder))),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: kCrmBorder)),
          child: Text(t.translate('Fermer'), style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: kCrmText)),
        ),
      ),
    );
  }

  // ── Sections ────────────────────────────────────────────────────────

  Widget _buildInfoSection(AppLocalizations t, bool twoCol) {
    final d = _d ?? {};
    final type = (d['type'] ?? widget.preview.type).toString();
    final rows = <(String, String)>[
      (t.translate('Numéro de fiche'), _s(d['numero'] ?? widget.preview.numero)),
      (t.translate('Type'), type == 'probar' ? 'PROBAR' : 'PROMESH'),
      (t.translate('Machine'), (d['machine'] ?? widget.preview.machine) == null ? '—' : 'Machine ${d['machine'] ?? widget.preview.machine}'),
      (t.translate('Poste'), _posteLabel(t, d['poste'] ?? widget.preview.poste)),
      (t.translate('Opérateur'), _s(d['operateur'] ?? widget.preview.operateur)),
      (t.translate('Date'), _s(d['date'] ?? widget.preview.date)),
      (t.translate('Heure début'), _s(d['heureDebut'])),
      (t.translate('Heure fin'), _s(d['heureFin'])),
      (t.translate('Statut'), t.translate((d['statut'] ?? widget.preview.statut) == 'validee' ? 'Validée' : 'Brouillon')),
      (t.translate('Créé le'), _dateFmt(d['createdAt'], withTime: true)),
      (t.translate('Date de modification'), _dateFmt(d['updatedAt'], withTime: true)),
      // §MODIFICATION — ADMIN > PRODUCTION RECORDS — FILTRE PAR UTILISATEUR
      // (§9/§15) : "Unknown" explicite pour une fiche historique sans
      // créateur connu — jamais un simple "—" ambigu ni un nom inventé.
      (t.translate('Created by'), _sOrNull((d['creator'] as Map?)?['email']) ?? t.translate('Unknown')),
    ];
    return _SectionCard(icon: Icons.badge_outlined, title: t.translate('Informations générales'), color: kCrmPrimary, child: _grid(rows, twoCol));
  }

  Widget _buildProductionSection(AppLocalizations t, bool twoCol, Color color) {
    final d = _d ?? {};
    final type = (d['type'] ?? widget.preview.type).toString();
    final quantite = d['quantite'] ?? widget.preview.quantite;
    final quantiteUnite = (d['quantiteUnite'] ?? widget.preview.quantiteUnite).toString();
    final diametre = d['diametre'] ?? widget.preview.diametre;
    final diametreUnite = (d['diametreUnite'] ?? widget.preview.diametreUnite).toString();

    final rows = <(String, String)>[];
    if (type == 'probar') {
      rows.add((t.translate('Quantité en mètres pour ProBar'), quantite == null ? '—' : '$quantite $quantiteUnite'));
      rows.add((t.translate('Diamètre'), diametre == null || diametre.toString().isEmpty ? '—' : '$diametre $diametreUnite'));
    } else {
      rows.add((t.translate('Quantité en m² pour ProMesh'), quantite == null ? '—' : '$quantite $quantiteUnite'));
      rows.add((t.translate('Taille de maille pour ProMesh'), _s(d['tailleMaille'] ?? widget.preview.tailleMaille)));
      rows.add((t.translate('Diamètre'), diametre == null || diametre.toString().isEmpty ? '—' : '$diametre $diametreUnite'));
    }
    return _SectionCard(
        icon: Icons.speed_rounded, title: t.translate('Données de production'), color: color, child: _grid(rows, twoCol));
  }

  Widget _buildTechnicalSection(AppLocalizations t, Color color) {
    final d = _d;
    if (d == null) return const SizedBox.shrink();
    final type = (d['type'] ?? widget.preview.type).toString();
    final tech = d['technicalData'] as Map<String, dynamic>?;
    if (tech == null) return const SizedBox.shrink();

    final blocks = <Widget>[];
    if (type == 'probar') {
      _addGroup(blocks, t, t.translate('Personnel'), tech['personnel'] as Map?, _probarPersonnelLabels);
      _addGroup(blocks, t, t.translate('Contrôle machine'), tech['controleMachine'] as Map?, _probarMachineLabels);
      _addMesuresQualite(blocks, t, tech['mesuresQualite'] as Map?);
      _addDynamicList(blocks, t, t.translate('Contrôles qualité'), tech['controlesQualite'] as List?);
      _addSimpleFields(blocks, t, {
        t.translate('Note'): tech['note'],
        "Signature": tech['signatureChefEquipe'],
        t.translate('Commentaires'): tech['justificationControleProcess'],
      });
    } else {
      _addSimpleFields(blocks, t, {
        'Air': tech['air'],
        t.translate('Niveau bain eau'): tech['niveauBainEau'],
        t.translate('Température eau'): tech['temperatureEau'],
        t.translate('Température pistons'): tech['temperaturePistons'],
        t.translate('État pistons'): tech['etatPistons'],
        t.translate('Fluide visuel'): tech['fluideVisuel'],
        t.translate('État disque de coupe'): tech['etatDisqueCoupe'],
        t.translate('Diamètre maille 3'): tech['diametreMaille3'],
      });
      _addDynamicList(blocks, t, t.translate('Contrôles qualité'), tech['controlesQualite'] as List?);
      _addDynamicList(blocks, t, t.translate('Paramètres process'), tech['processControl'] as List?);
      _addDynamicList(blocks, t, t.translate('Arrêts machine'), tech['arretsMachine'] as List?);
      _addDynamicList(blocks, t, t.translate('Consommations'), tech['consommations'] as List?);
    }

    if (blocks.isEmpty) return const SizedBox.shrink();
    return _SectionCard(
      icon: Icons.tune_rounded,
      title: t.translate('Paramètres techniques'),
      color: color,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks),
    );
  }

  static const _probarPersonnelLabels = {
    'responsable1': 'Responsable 1',
    'responsable2': 'Responsable 2',
    'operateur1': 'Opérateur 1',
    'operateur2': 'Opérateur 2',
    'aideOperateur': 'Aide Opérateur',
    'manoeuvre': 'Manœuvre',
    'stagiaire1': 'Stagiaire 1',
    'stagiaire2': 'Stagiaire 2',
  };

  static const _probarMachineLabels = {
    'air': 'Air',
    'niveauBainEau': 'Niveau bain eau',
    'temperatureEau': 'Température eau',
    'temperatureDemandee': 'Température demandée',
    'etatPistons': 'État pistons',
    'fluideVisuel': 'Fluide visuel',
    'etatDisqueCoupe': 'État disque de coupe',
    'etatAtelier': 'État atelier',
    'zoneStockage': 'Zone stockage',
    'bobine': 'Bobine',
    'resistance': 'Résistance',
    'four': 'Four',
    'fourZone1': 'Four zone 1',
    'fourZone2': 'Four zone 2',
    'fourZone3': 'Four zone 3',
    'nombreBobines': 'Nombre de bobines',
    'bainEauFiltre': 'Bain eau filtré',
    'machineCeinture': 'Machine ceinture',
    'machineBobinage': 'Machine bobinage',
    'bainResine': 'Bain résine',
    'justification': 'Justification',
  };

  void _addGroup(List<Widget> blocks, AppLocalizations t, String title, Map? data, Map<String, String> labels) {
    if (data == null) return;
    final entries = <(String, String)>[];
    for (final e in labels.entries) {
      final v = _sOrNull(data[e.key]);
      if (v != null) entries.add((t.translate(e.value), v));
    }
    if (entries.isEmpty) return;
    blocks.add(_TechGroupTitle(title: title));
    blocks.add(_grid(entries, true));
    blocks.add(const SizedBox(height: 14));
  }

  void _addMesuresQualite(List<Widget> blocks, AppLocalizations t, Map? mesures) {
    if (mesures == null) return;
    final lignes = <Widget>[];
    for (final key in ['ligne1', 'ligne2', 'ligne3', 'ligne4']) {
      final l = mesures[key] as Map?;
      if (l == null) continue;
      final parts = <String>[];
      if (_sOrNull(l['hauteur']) != null) parts.add('H: ${l['hauteur']}');
      if (_sOrNull(l['largeur']) != null) parts.add('L: ${l['largeur']}');
      if (_sOrNull(l['maille']) != null) parts.add('Maille: ${l['maille']}');
      if (_sOrNull(l['diametre']) != null) parts.add('Ø: ${l['diametre']}');
      if (parts.isEmpty) continue;
      lignes.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('${key.replaceFirst('ligne', 'Ligne ')} — ${parts.join(' · ')}',
            style: tInter(fontSize: 12, color: kCrmText)),
      ));
    }
    final temp = _sOrNull(mesures['temperature']);
    if (temp != null) {
      lignes.add(Text('${t.translate('Température')} : $temp', style: tInter(fontSize: 12, color: kCrmText)));
    }
    if (lignes.isEmpty) return;
    blocks.add(_TechGroupTitle(title: t.translate('Mesures qualité')));
    blocks.addAll(lignes);
    blocks.add(const SizedBox(height: 14));
  }

  void _addSimpleFields(List<Widget> blocks, AppLocalizations t, Map<String, dynamic> fields) {
    final entries = <(String, String)>[];
    fields.forEach((label, value) {
      final v = _sOrNull(value);
      if (v != null) entries.add((label, v));
    });
    if (entries.isEmpty) return;
    blocks.add(_grid(entries, true));
    blocks.add(const SizedBox(height: 14));
  }

  void _addDynamicList(List<Widget> blocks, AppLocalizations t, String title, List? items) {
    if (items == null || items.isEmpty) return;
    final rows = <Widget>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final parts = <String>[];
      raw.forEach((k, v) {
        final s = _sOrNull(v);
        if (s != null && k != 'id') parts.add('$k: $s');
      });
      if (parts.isEmpty) continue;
      rows.add(Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(8)),
        child: Text(parts.join(' · '), style: tInter(fontSize: 11.5, color: kCrmText)),
      ));
    }
    if (rows.isEmpty) return;
    blocks.add(_TechGroupTitle(title: title));
    blocks.addAll(rows);
    blocks.add(const SizedBox(height: 14));
  }

  Widget _buildTimelineSection(AppLocalizations t, Color color) {
    final d = _d ?? {};
    final type = (d['type'] ?? widget.preview.type).toString();
    final steps = <(IconData, String, String)>[
      (Icons.add_circle_outline_rounded, t.translate('Créé le'), _dateFmt(d['createdAt'], withTime: true)),
      (Icons.play_circle_outline_rounded, t.translate('Heure début'), _s(d['heureDebut'])),
      (Icons.stop_circle_outlined, t.translate('Heure fin'), _s(d['heureFin'])),
      (
        Icons.verified_outlined,
        t.translate('Validée'),
        type == 'promesh' ? _dateFmt(d['validatedAt']) : ((d['statut'] ?? widget.preview.statut) == 'validee' ? _dateFmt(d['updatedAt']) : '—'),
      ),
    ];
    return _SectionCard(
      icon: Icons.timeline_rounded,
      title: t.translate('Chronologie'),
      color: color,
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 10),
              child: Row(children: [
                Icon(steps[i].$1, size: 16, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(steps[i].$2, style: tInter(fontSize: 12.5, color: kCrmTextSub))),
                Text(steps[i].$3, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(AppLocalizations t, bool twoCol) {
    final d = _d ?? {};
    final type = (d['type'] ?? widget.preview.type).toString();
    final statut = (d['statut'] ?? widget.preview.statut).toString();
    final rows = <(String, String)>[
      (t.translate('Statut'), t.translate(statut == 'validee' ? 'Validée' : 'Brouillon')),
      (t.translate('Verrouillée'), (d['isLocked'] ?? widget.preview.isLocked) == true ? t.translate('Oui') : t.translate('Non')),
    ];
    if (type == 'promesh') {
      rows.add((t.translate('Conformité'), _s(d['conformite'])));
      final dnc = _sOrNull(d['descriptionNonConformite']);
      if (dnc != null) rows.add((t.translate('Description non-conformité'), dnc));
      final ac = _sOrNull(d['actionsCorrectives']);
      if (ac != null) rows.add((t.translate('Actions correctives'), ac));
      final obs = _sOrNull(d['observationsGenerales']);
      if (obs != null) rows.add((t.translate('Observations'), obs));
    } else {
      final sq = _sOrNull(d['statutQualite']);
      if (sq != null) rows.add((t.translate('Statut qualité'), sq));
      final obs = _sOrNull(d['observations']);
      if (obs != null) rows.add((t.translate('Observations'), obs));
    }
    return _SectionCard(
        icon: Icons.fact_check_outlined, title: t.translate('Statut et validation'), color: kCrmPrimary, child: _grid(rows, twoCol));
  }

  Widget _buildAttachmentsSection(AppLocalizations t) {
    final attachments = (_d?['attachments'] as List?) ?? [];
    if (attachments.isEmpty) return const SizedBox.shrink();
    return _SectionCard(
      icon: Icons.attach_file_rounded,
      title: t.translate('Documents / Pièces jointes'),
      color: kCrmSecondary,
      child: Column(
        children: [
          for (final raw in attachments)
            if (raw is Map)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 18, color: kCrmTextSub),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_s(raw['fileName']), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText)),
                      Text(_dateFmt(raw['createdAt']), style: tInter(fontSize: 11, color: kCrmTextSub)),
                    ]),
                  ),
                ]),
              ),
        ],
      ),
    );
  }

  String _posteLabel(AppLocalizations t, dynamic poste) {
    if (poste == 'matin') return t.translate('Matin');
    if (poste == 'nuit') return t.translate('Nuit');
    return '—';
  }

  Widget _grid(List<(String, String)> rows, bool twoCol) {
    if (!twoCol) {
      return Column(children: [for (final r in rows) _gridField(r.$1, r.$2)]);
    }
    final left = <(String, String)>[];
    final right = <(String, String)>[];
    for (var i = 0; i < rows.length; i++) {
      (i.isEven ? left : right).add(rows[i]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(children: [for (final r in left) _gridField(r.$1, r.$2)])),
      const SizedBox(width: 16),
      Expanded(child: Column(children: [for (final r in right) _gridField(r.$1, r.$2)])),
    ]);
  }

  Widget _gridField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: tInter(fontSize: 10.5, fontWeight: FontWeight.w600, color: kCrmTextSub)),
        const SizedBox(height: 2),
        Text(value, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText)),
      ]),
    );
  }
}

class _TechGroupTitle extends StatelessWidget {
  final String title;
  const _TechGroupTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: kCrmTextSub)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  const _SectionCard({required this.icon, required this.title, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCrmBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCrmBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Text(title, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}
