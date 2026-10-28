// lib/forms/industrial/view/probar/probar_poste_dashboard_screen.dart
//
// Dashboard poste PROBAR — même système de design que le poste PROMESH
// (forms/industrial/view/poste_dashboard_layout.dart) : en-tête machine,
// barre d'actions, fiches manquantes, alertes, KPI compacts, graphiques,
// fiches récentes. Données : IndustrialRecordService (service existant de
// PROBAR) — les KPI et graphiques sont calculés sur les fiches réellement
// chargées (machine + poste), sur la période choisie. Quantités en mètres
// linéaires (ml, unité enregistrée), sans conversion.

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/view/poste_dashboard_alerts.dart';
import 'package:dash_master_toolkit/forms/industrial/view/poste_dashboard_layout.dart';
import 'package:dash_master_toolkit/forms/production_fiche_approval/fiche_approval_record.dart' show FicheApprovalPaths;
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_paths.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/production_dashboard/model/production_dashboard_model.dart' show prodFormatNumber;
import 'package:dash_master_toolkit/providers/auth_service.dart';
import 'package:dash_master_toolkit/production_compliance/service/production_compliance_service.dart';
import 'package:dash_master_toolkit/production_compliance/view/production_compliance_banner.dart';
import 'package:dash_master_toolkit/production_compliance/view/production_compliance_dialogs.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_dialog.dart';

import '../../controller/probar_controller.dart';
import '../../model/industrial_record_model.dart';
import '../../service/industrial_record_service.dart';

const _kDateRanges = [
  ('today', "Aujourd'hui"),
  ('week', 'Cette semaine'),
  ('month', 'Ce mois'),
  ('all', 'Tout'),
];

const _kSorts = [
  ('date_desc', 'Date décroissante'),
  ('date_asc', 'Date croissante'),
];

const _kPageSizes = [10, 20, 50];

/// Numéro d'une fiche PROBAR : même format que le backend
/// (productionDashboard.service — ficheNumero) : `PROBAR-année-6 hex`.
String probarFicheNumero(IndustrialRecordModel r) {
  final id = (r.id ?? '').replaceAll('-', '');
  if (id.length < 6) return '—';
  final year = DateTime.tryParse(r.createdAt ?? '')?.year ?? DateTime.tryParse(r.dateFiche ?? '')?.year;
  return 'PROBAR-${year ?? '—'}-${id.substring(0, 6).toUpperCase()}';
}

class ProbarPosteDashboardScreen extends StatefulWidget {
  final String machine;
  final String poste;

  const ProbarPosteDashboardScreen({super.key, required this.machine, required this.poste});

  @override
  State<ProbarPosteDashboardScreen> createState() => _ProbarPosteDashboardScreenState();
}

class _ProbarPosteDashboardScreenState extends State<ProbarPosteDashboardScreen> {
  bool _loading = true;
  String? _error;
  List<IndustrialRecordModel> _allItems = [];
  List<IndustrialRecordModel> _periodItems = []; // période choisie (KPI, graphiques)
  List<IndustrialRecordModel> _filtered = []; // période + recherche + tri (liste)
  List<IndustrialRecordModel> _items = []; // page courante
  bool _creatingDraft = false;

  String _dateRange = 'today';
  String _sort = 'date_desc';
  String _search = '';
  Timer? _debounce;
  int _page = 1;
  int _pageSize = 10;

  PosteAlertData? _alerts;
  int _missingSheets = 0;
  final _listKey = GlobalKey();
  final _complianceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    unawaited(loadPosteAlertData(type: 'probar', machine: widget.machine, poste: widget.poste).then((a) {
      if (mounted) setState(() => _alerts = a);
    }));
    try {
      final items = await IndustrialRecordService.instance.fetchAll(
        module: 'probar',
        machine: widget.machine,
        poste: widget.poste,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() => _allItems = items);
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _inPeriod(IndustrialRecordModel r, DateTime now) {
    if (_dateRange == 'all') return true;
    if (_dateRange == 'today') return r.dateFiche == DateFormat('yyyy-MM-dd').format(now);
    final d = DateTime.tryParse(r.dateFiche ?? '');
    final from = now.subtract(Duration(days: _dateRange == 'week' ? 7 : 30));
    return d != null && !d.isBefore(from);
  }

  void _applyFilters() {
    final now = DateTime.now();
    final period = _allItems.where((r) => _inPeriod(r, now)).toList();
    var filtered = List<IndustrialRecordModel>.from(period);

    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      filtered = filtered
          .where((r) =>
              (r.operateur ?? '').toLowerCase().contains(q) ||
              (r.dateFiche ?? '').contains(q) ||
              (r.machine ?? '').contains(q))
          .toList();
    }

    filtered.sort((a, b) {
      final da = a.dateFiche ?? '';
      final db = b.dateFiche ?? '';
      return _sort == 'date_asc' ? da.compareTo(db) : db.compareTo(da);
    });

    final start = (_page - 1) * _pageSize;
    setState(() {
      _periodItems = period;
      _filtered = filtered;
      _items = filtered.skip(start).take(_pageSize).toList();
    });
  }

  void _onFilterChanged() {
    _page = 1;
    _applyFilters();
  }

  void _onSearchChanged(String v) {
    _search = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _onFilterChanged);
  }

  String get _backRoute => '${MyRoute.productionProbarRoot}/machine/${widget.machine}';
  String get _base => '${MyRoute.productionProbarRoot}/machine/${widget.machine}/poste/${widget.poste}';
  String get _modulesRoute => '$_base/modules';

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.05);
  }

  // Nouveau workflow (ficheId explicite, conservé pendant toute la
  // navigation) :
  // 1. On retrouve un éventuel brouillon déjà existant pour aujourd'hui
  //    (même machine + poste) via bootstrapForMachinePoste — pour ne
  //    JAMAIS créer une deuxième fiche si une existe déjà.
  // 2. Si aucun brouillon n'existe, on crée IMMÉDIATEMENT la fiche en base
  //    (saveDraft) pour obtenir un ficheId stable dès l'ouverture.
  // 3. On navigue vers la page Modules avec ce ficheId en query param —
  //    c'est ce même id qui sera transmis à chaque écran module ensuite,
  //    aucune re-création implicite n'est plus possible.
  Future<void> _createOrOpenDraft({String? date}) async {
    if (_creatingDraft) return;
    setState(() => _creatingDraft = true);
    try {
      final c = Get.isRegistered<ProbarController>()
          ? Get.find<ProbarController>()
          : Get.put(ProbarController(), permanent: true);

      await c.bootstrapForMachinePoste(widget.machine, widget.poste, forceRefresh: true, productionDate: date);

      if (c.recordId == null) {
        // Nouvelle fiche uniquement (un brouillon existant est rouvert sans
        // popup) : demande de matières premières si exigée.
        if (!mounted) return;
        if (!await ensureRawMaterialRequest(context, module: 'probar', machine: widget.machine, poste: widget.poste)) {
          return;
        }
        await c.saveDraft();
      }
      final ficheId = c.recordId;
      if (ficheId == null) {
        throw Exception('Échec de la création de la fiche.');
      }

      if (!mounted) return;
      context.go('$_modulesRoute?ficheId=$ficheId');
    } catch (e, stack) {
      debugPrint('[ProbarDashboard] ERREUR : $e\n$stack');
      if (!mounted) return;
      await showProductionError(context, e,
          prefix: ProductionComplianceService.isComplianceBlock(e) ? null : '${AppLocalizations.of(context).translate('Erreur')} :');
    } finally {
      if (mounted) setState(() => _creatingDraft = false);
    }
  }

  // ── KPI (fiches de la période choisie) ─────────────────────────────────
  int get _totalFiches => _periodItems.length;
  int get _fichesValidees => _periodItems.where((r) => r.statut == 'validee').length;
  int get _fichesBrouillon => _periodItems.where((r) => r.statut != 'validee').length;
  int get _nonConformites => _periodItems.where((r) => r.statutQualite == 'nok').length;
  // Même règle que la production totale PROMESH du poste : somme des fiches
  // de la période (quantité saisie, en ml).
  double get _productionTotale => _periodItems.fold(0.0, (s, r) => s + (r.quantiteProduite ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(forceRefresh: true),
          child: IndustrialPageBody(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                PosteHeader(
                  lineLabel: 'PROBAR',
                  color: kProbarColor,
                  machine: widget.machine,
                  poste: widget.poste,
                  now: DateTime.now(),
                  operatorName: AuthService().displayName,
                  onBack: () => context.go(_backRoute),
                ),
                PosteActionBar(
                  color: kProbarColor,
                  primary: PosteAction('new',
                      label: _creatingDraft ? 'Préparation…' : 'Nouvelle fiche',
                      icon: Icons.add_rounded,
                      busy: _creatingDraft,
                      onTap: _creatingDraft ? null : _createOrOpenDraft),
                  secondary: [
                    PosteAction('list', label: 'Fiches du poste', icon: Icons.list_alt_rounded, onTap: () => _scrollTo(_listKey)),
                    PosteAction('history', label: 'Historique', icon: Icons.history_rounded, onTap: () => context.go(MyRoute.probarListScreen)),
                    PosteAction('refresh', label: 'Actualiser', icon: Icons.refresh_rounded, busy: _loading, onTap: _loading ? null : () => _load(forceRefresh: true)),
                  ],
                ),
                KeyedSubtree(
                  key: _complianceKey,
                  child: ProductionComplianceBanner(
                    onBackfill: (d) => _createOrOpenDraft(date: d),
                    onLoaded: (me) {
                      final n = (me['missingDates'] as List?)?.length ?? 0;
                      if (mounted && n != _missingSheets) setState(() => _missingSheets = n);
                    },
                  ),
                ),
                PosteAlertsPanel(alerts: _buildAlerts(), loading: _loading && _alerts == null),
                if (_error == null) ...[
                  PosteKpiGrid(
                    loading: _loading,
                    skeletonCount: 5,
                    items: [
                      PosteKpi('created', icon: Icons.description_outlined, label: 'Fiches créées', value: '$_totalFiches', color: kProbarColor),
                      PosteKpi('validated', icon: Icons.check_circle_outline_rounded, label: 'Fiches validées', value: '$_fichesValidees', color: kPosteAccepted),
                      PosteKpi('drafts', icon: Icons.edit_note_rounded, label: 'En brouillon', value: '$_fichesBrouillon', color: kPosteNeutral),
                      PosteKpi('production', icon: Icons.straighten_rounded, label: 'Production totale', value: '${prodFormatNumber(_productionTotale)} ml', color: kProbarColor),
                      PosteKpi('nonconformities', icon: Icons.warning_amber_rounded, label: 'Non-conformités', value: '$_nonConformites', color: kPosteRejected),
                      // « Opérateurs présents » : non enregistré sur les fiches PROBAR — pas affiché.
                    ],
                  ),
                  _buildCharts(),
                ],
                KeyedSubtree(key: _listKey, child: _buildFiches()),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── ALERTES ────────────────────────────────────────────────────────────

  List<PosteAlert> _buildAlerts() {
    final a = _alerts;
    final raw = a?.raw;
    return [
      if ((a?.rejected ?? 0) > 0)
        PosteAlert('rejected',
            severity: PosteSeverity.critical,
            icon: Icons.block_rounded,
            title: 'Fiches refusées',
            count: a!.rejected!,
            description: 'Refusées par le responsable : motif consultable, correction et nouvelle soumission requises.',
            actionLabel: 'Voir',
            onTap: () => context.go(FicheApprovalPaths.root)),
      if (_missingSheets > 0)
        PosteAlert('missing',
            severity: PosteSeverity.critical,
            icon: Icons.event_busy_rounded,
            title: 'Fiches précédentes manquantes',
            count: _missingSheets,
            description: 'Dates sans fiche : une autorisation peut être nécessaire pour régulariser.',
            actionLabel: 'Voir les dates',
            onTap: () => _scrollTo(_complianceKey)),
      if (!_loading && _error == null && _nonConformites > 0)
        PosteAlert('nonconformities',
            severity: PosteSeverity.critical,
            icon: Icons.warning_amber_rounded,
            title: 'Non-conformités enregistrées',
            count: _nonConformites,
            description: 'Fiches non conformes sur la période affichée.',
            actionLabel: 'Afficher',
            onTap: () => _scrollTo(_listKey)),
      if ((a?.pending ?? 0) > 0)
        PosteAlert('pending',
            severity: PosteSeverity.warning,
            icon: Icons.hourglass_top_rounded,
            title: 'Fiches en attente de validation',
            count: a!.pending!,
            description: AuthService().isFicheApprovalValidator ? 'À accepter ou refuser.' : 'En attente de la décision du responsable.',
            actionLabel: 'Voir',
            onTap: () => context.go(FicheApprovalPaths.root)),
      if (raw != null && raw.pending > 0)
        PosteAlert('raw',
            severity: PosteSeverity.warning,
            icon: Icons.inventory_2_outlined,
            title: 'Demandes de matières premières non traitées',
            count: raw.pending,
            description: raw.isValidator ? 'À accepter ou refuser.' : 'Vos demandes en attente de validation par le responsable.',
            actionLabel: 'Voir',
            onTap: () => context.go(raw.isValidator ? RawMaterialPaths.toValidate : RawMaterialPaths.tracking)),
    ];
  }

  // ── GRAPHIQUES (fiches réellement chargées) ────────────────────────────

  Widget _buildCharts() {
    final period = pdT(context, _kDateRanges.firstWhere((r) => r.$1 == _dateRange).$2);
    final ok = _periodItems.where((r) => r.statutQualite == 'ok').length;
    final nok = _nonConformites;
    // 7 derniers jours (aujourd'hui inclus) : quantité saisie par date de fiche.
    final today = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) DateFormat('yyyy-MM-dd').format(today.subtract(Duration(days: i)))];
    final perDay = {for (final d in days) d: 0.0};
    for (final r in _allItems) {
      if (perDay.containsKey(r.dateFiche)) perDay[r.dateFiche!] = perDay[r.dateFiche!]! + (r.quantiteProduite ?? 0);
    }
    return PosteChartsRow(panels: [
      // L'heure de production des quantités PROBAR n'est pas enregistrée :
      // aucun graphique horaire simulé.
      PosteChartPanel(
        panelKey: 'hourly',
        title: 'Production par heure',
        subtitle: 'ml',
        icon: Icons.bar_chart_outlined,
        color: kProbarColor,
        loading: _loading,
        chart: null,
        emptyMessage: 'Non disponible : la production PROBAR n\'est pas enregistrée par heure',
      ),
      PosteChartPanel(
        panelKey: 'conformity',
        title: 'Conformité',
        subtitle: '${pdT(context, 'Fiches')} · $period',
        icon: Icons.pie_chart_outline_rounded,
        color: kPosteAccepted,
        loading: _loading,
        chart: ok + nok > 0 ? _conformityChart(ok, nok) : null,
        emptyMessage: 'Aucun contrôle de conformité sur cette période',
      ),
      PosteChartPanel(
        panelKey: 'trend',
        title: 'Production des 7 derniers jours',
        subtitle: 'ml / jour',
        icon: Icons.show_chart_rounded,
        color: kProbarColor,
        loading: _loading,
        chart: perDay.values.any((v) => v > 0) ? _trendChart(days, perDay) : null,
        emptyMessage: 'Aucune production sur les 7 derniers jours',
      ),
    ]);
  }

  Widget _conformityChart(int ok, int nok) {
    final total = ok + nok;
    return Row(children: [
      Expanded(
        child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 30, sections: [
          if (ok > 0)
            PieChartSectionData(value: ok.toDouble(), color: kPosteAccepted, title: '${(ok / total * 100).round()}%', titleStyle: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white), radius: 42),
          if (nok > 0)
            PieChartSectionData(value: nok.toDouble(), color: kPosteRejected, title: '${(nok / total * 100).round()}%', titleStyle: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white), radius: 42),
        ])),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        posteLegendDot(context, kPosteAccepted, '${pdT(context, 'Conforme')} ($ok)'),
        const SizedBox(height: 8),
        posteLegendDot(context, kPosteRejected, '${pdT(context, 'Non Conforme')} ($nok)'),
      ]),
    ]);
  }

  Widget _trendChart(List<String> days, Map<String, double> perDay) {
    final maxY = perDay.values.fold<double>(0, (m, v) => v > m ? v : m) * 1.2;
    return BarChart(BarChartData(
      maxY: maxY <= 0 ? 1 : maxY,
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: kCrmBorder, strokeWidth: 0.6)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox.shrink() : Text(prodFormatNumber(v, maxDecimals: 0), style: tInter(fontSize: 9.5, color: kCrmTextSub)),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (v, meta) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(DateFormat('dd/MM').format(DateTime.parse(days[v.toInt().clamp(0, days.length - 1)])), style: tInter(fontSize: 9.5, color: kCrmTextSub)),
            ),
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => kCrmText,
          getTooltipItem: (group, gi, rod, ri) => BarTooltipItem('${pdDate(days[group.x])} · ${prodFormatNumber(rod.toY)} ml', tInter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
      barGroups: [
        for (var i = 0; i < days.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: perDay[days[i]]!, color: kProbarColor, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
          ]),
      ],
    ));
  }

  // ── FICHES RÉCENTES ────────────────────────────────────────────────────

  PosteFicheRow _row(IndustrialRecordModel item) => PosteFicheRow(
        id: item.id ?? '',
        numero: probarFicheNumero(item),
        date: item.dateFiche,
        poste: item.poste,
        machine: item.machine,
        producer: item.creator?['email'],
        operateur: item.operateur,
        quantity: item.quantiteProduite,
        unit: 'ml',
        isDraft: item.statut != 'validee',
        approvalStatus: item.approval?.status,
        rejectionComment: item.approval?.rejectionComment,
        rejectedAt: item.approval?.rejectedAt ?? item.approval?.decidedAt,
        nonConforme: item.statutQualite == 'nok',
      );

  Widget _buildFiches() {
    final byId = {for (final i in _items) i.id ?? '': i};
    final totalPages = (_filtered.length / _pageSize).ceil().clamp(1, 999999);
    return PosteFichesSection(
      color: kProbarColor,
      total: _filtered.length,
      rows: [for (final i in _items) _row(i)],
      loading: _loading,
      error: _error,
      onRetry: () => _load(forceRefresh: true),
      onViewAll: () => context.go(MyRoute.probarListScreen),
      actions: (r) {
        final item = byId[r.id]!;
        return [
          PosteRowAction(
            actionKey: 'poste-fiche-view-${r.id}',
            tooltip: 'Voir',
            icon: Icons.visibility_outlined,
            color: kCrmTextSub,
            onTap: () => context.go('${MyRoute.productionProbarRoot}/machine/${item.machine ?? widget.machine}/poste/${item.poste ?? widget.poste}/detail?id=${item.id}'),
          ),
        ];
      },
      filters: PosteFiltersBar(
        hint: 'Rechercher par opérateur, date, machine…',
        onSearch: _onSearchChanged,
        filters: [
          PosteFilterDropdown<String>(
            label: 'Date',
            value: _dateRange,
            items: _kDateRanges,
            onChanged: (v) => setState(() {
              _dateRange = v!;
              _onFilterChanged();
            }),
          ),
          PosteFilterDropdown<String>(
            label: 'Tri',
            value: _sort,
            items: _kSorts,
            onChanged: (v) => setState(() {
              _sort = v!;
              _onFilterChanged();
            }),
          ),
        ],
      ),
      pagination: PostePagination(
        page: _page,
        totalPages: totalPages,
        pageSize: _pageSize,
        pageSizes: _kPageSizes,
        onPageSize: (v) => setState(() {
          _pageSize = v;
          _onFilterChanged();
        }),
        onPrevious: _page > 1
            ? () => setState(() {
                  _page--;
                  _applyFilters();
                })
            : null,
        onNext: _page < totalPages
            ? () => setState(() {
                  _page++;
                  _applyFilters();
                })
            : null,
      ),
    );
  }
}
