// lib/forms/por_promesh/view/poste_dashboard_screen.dart
//
// Dashboard du poste PROMESH — étape intermédiaire Machine → Poste →
// Dashboard (avant la saisie). Ordre de lecture : en-tête machine, barre
// d'actions, fiches manquantes (conformité), alertes, KPI compacts,
// graphiques, fiches récentes (filtrables / triables / paginées).
// Tous les calculs (KPI, graphiques) sont faits côté backend
// (GET /por-promesh/dashboard et GET /por-promesh/stats) — cet écran ne fait
// jamais de somme/comptage lui-même. "+ Nouvelle fiche" est l'unique point
// d'entrée vers le parcours de saisie existant (Informations générales →
// Rendement → ... → Validation, inchangé). Présentation commune avec PROBAR :
// forms/industrial/view/poste_dashboard_layout.dart.

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
import 'package:dash_master_toolkit/production_dashboard/model/production_dashboard_model.dart' show prodFormatNumber;
import 'package:dash_master_toolkit/providers/auth_service.dart';
import 'package:dash_master_toolkit/production_compliance/service/production_compliance_service.dart';
import 'package:dash_master_toolkit/production_compliance/view/production_compliance_banner.dart';
import 'package:dash_master_toolkit/production_compliance/view/production_compliance_dialogs.dart';
import 'package:dash_master_toolkit/forms/raw_material_request/raw_material_request_dialog.dart';

import '../controller/por_promesh_controller.dart';
import '../model/por_promesh_model.dart';
import '../model/poste_dashboard_stats.dart';
import '../model/poste_charts_data.dart';
import '../service/por_promesh_service.dart';
import '../service/por_promesh_pdf_service.dart';
import '../service/por_promesh_excel_service.dart';

const _kDateRanges = [
  ('today', "Aujourd'hui"),
  ('yesterday', 'Hier'),
  ('week', 'Cette semaine'),
  ('month', 'Ce mois'),
];

const _kStatusFilters = [
  (null, 'Tous'),
  ('brouillon', 'Brouillon'),
  ('valide', 'Validé'),
  ('conforme', 'Conforme'),
  ('non_conforme', 'Non Conforme'),
];

const _kSorts = [
  ('date_desc', 'Date décroissante'),
  ('date_asc', 'Date croissante'),
  ('production_desc', 'Production'),
];

const _kPageSizes = [10, 20, 50, 100];

// La liste de ce Dashboard est chargée en mode "light" (sans les 6 tables
// enfants — voir fetchPage) pour rester rapide. Les actions PDF/Imprimer/
// Excel ont besoin de la fiche complète : on la re-récupère par id juste
// avant de générer le document, plutôt que d'alourdir la liste pour tout
// le monde.
Future<void> _viewFichePdf(BuildContext context, PorPromeshModel item, {required bool print}) async {
  try {
    final full = item.id == null ? item : await PorPromeshService.instance.fetchById(item.id!);
    if (print) {
      await PorPromeshPdfService.instance.printPdf(full);
    } else {
      await PorPromeshPdfService.instance.exportPdf(full);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red.shade700));
  }
}

Future<void> _viewFicheExcel(BuildContext context, PorPromeshModel item) async {
  try {
    final full = item.id == null ? item : await PorPromeshService.instance.fetchById(item.id!);
    PorPromeshExcelService.instance.export(full);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red.shade700));
  }
}

class PosteDashboardScreen extends StatefulWidget {
  final String machine;
  final String poste;

  const PosteDashboardScreen({super.key, required this.machine, required this.poste});

  @override
  State<PosteDashboardScreen> createState() => _PosteDashboardScreenState();
}

class _PosteDashboardScreenState extends State<PosteDashboardScreen> {
  bool _loading = true;
  String? _error;

  late String _machineFilter = widget.machine;
  String _dateRange = 'today';
  String? _statusFilter;
  String _sort = 'date_desc';
  String _search = '';
  Timer? _searchDebounce;

  int _page = 1;
  int _pageSize = 10;
  bool _creatingDraft = false;

  PosteDashboardStats _stats = const PosteDashboardStats();
  PosteChartsData _charts = const PosteChartsData();
  List<PorPromeshModel> _items = [];
  int _total = 0;

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
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Alertes (validation des fiches, matières premières) : indépendantes
    // des filtres de la liste, jamais bloquantes pour la page.
    unawaited(loadPosteAlertData(type: 'promesh', machine: widget.machine, poste: widget.poste).then((a) {
      if (mounted) setState(() => _alerts = a);
    }));
    try {
      final results = await Future.wait([
        PorPromeshService.instance.fetchDashboard(
          machine: _machineFilter,
          poste: widget.poste,
          dateRange: _dateRange,
          status: _statusFilter,
        ),
        PorPromeshService.instance.fetchStats(
          machine: _machineFilter,
          poste: widget.poste,
          dateRange: _dateRange,
          status: _statusFilter,
        ),
        PorPromeshService.instance.fetchPage(
          machine: _machineFilter,
          poste: widget.poste,
          dateRange: _dateRange,
          status: _statusFilter,
          search: _search,
          sort: _sort,
          page: _page,
          pageSize: _pageSize,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as PosteDashboardStats;
        _charts = results[1] as PosteChartsData;
        final page = results[2] as ({List<PorPromeshModel> items, int total});
        _items = page.items;
        _total = page.total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onFilterChanged() {
    _page = 1;
    _load();
  }

  void _onSearchChanged(String value) {
    _search = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _onFilterChanged);
  }

  String get _backRoute => '${MyRoute.productionPromeshRoot}/machine/${widget.machine}';

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.05);
  }

  // Un seul clic doit toujours amener directement sur la page Modules
  // (jamais un module spécifique — l'utilisateur choisit) :
  // - Cas 1 (aucun brouillon ouvert dans cette session) : POST /por-promesh/new
  //   crée une fiche neuve côté backend, qui renvoie son id immédiatement.
  // - Cas 2 (l'utilisateur est déjà revenu sur ce Dashboard sans avoir validé
  //   le brouillon en cours pour CE machine+poste — le contrôleur permanent
  //   le détient encore en mémoire) : on le rouvre directement, sans appel
  //   réseau ni recréation. Ne concerne que la session en cours, jamais une
  //   recherche en base — ça évite de retomber sur d'anciennes valeurs.
  // - Cas 3 (le brouillon en mémoire est déjà VALIDE/verrouillé, ou
  //   n'existe pas) : POST /por-promesh/new crée systématiquement une
  //   fiche neuve (le backend ne réutilise jamais une fiche verrouillée).
  // Dans tous les cas : id obtenu → navigation immédiate, jamais besoin
  // d'un second clic. Le Dashboard reste affiché pendant l'appel (jamais
  // d'écran vide) ; en cas d'erreur on reste ici avec un message.
  Future<void> _createOrOpenDraft({String? date}) async {
    debugPrint('[PosteDashboard] CLICK Nouvelle fiche (machine=${widget.machine}, poste=${widget.poste})');
    if (_creatingDraft) return;
    setState(() => _creatingDraft = true);
    try {
      final existing = Get.isRegistered<PorPromeshController>() ? Get.find<PorPromeshController>() : null;
      final reusableId = date == null &&
              existing != null &&
              existing.recordId != null &&
              !existing.isLocked.value &&
              existing.machine.value == widget.machine &&
              existing.poste.value == widget.poste
          ? existing.recordId
          : null;

      late final String id;
      if (reusableId != null) {
        debugPrint('[PosteDashboard] Brouillon de session déjà ouvert, réutilisation id=$reusableId (pas de POST)');
        id = reusableId;
      } else {
        // Nouvelle fiche uniquement (jamais pour le brouillon de session
        // rouvert ci-dessus) : demande de matières premières si exigée.
        if (!await ensureRawMaterialRequest(context, module: 'promesh', machine: widget.machine, poste: widget.poste)) {
          return;
        }
        final record =
            await PorPromeshService.instance.createOrOpenDraft(machine: widget.machine, poste: widget.poste, dateProduction: date);
        debugPrint('[PosteDashboard] POST terminé, ID reçu : ${record.id}');
        id = record.id;
      }

      // Navigation immédiate, jamais de refresh du Dashboard (KPI/liste)
      // entre le POST et la navigation : le brouillon créé ne doit jamais
      // apparaître ici — seul le retour sur ce Dashboard (nouvelle instance
      // de l'écran, voir initState/_load) le rechargera.
      //
      // Ouvre la page Modules (jamais un module spécifique) — l'utilisateur
      // choisit librement le premier module à remplir. Le ficheId est
      // conservé dans l'URL (query param) et retransmis à chaque écran
      // module ensuite, aucune re-création implicite n'est plus possible.
      if (!mounted) return;
      final path = '${MyRoute.productionPromeshRoot}/machine/${widget.machine}/poste/${widget.poste}/modules?ficheId=$id';
      debugPrint('[PosteDashboard] Navigation vers la fiche : $path');
      context.go(path);
    } catch (e) {
      debugPrint('[PosteDashboard] ERREUR pendant la création/ouverture : $e');
      if (!mounted) return;
      await showProductionError(context, e, prefix: ProductionComplianceService.isComplianceBlock(e) ? null : 'Erreur :');
    } finally {
      if (mounted) setState(() => _creatingDraft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: IndustrialPageBody(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                PosteHeader(
                  lineLabel: 'PROMESH',
                  color: kPromeshColor,
                  machine: widget.machine,
                  poste: widget.poste,
                  now: DateTime.now(),
                  operatorName: AuthService().displayName,
                  onBack: () => context.go(_backRoute),
                ),
                PosteActionBar(
                  color: kPromeshColor,
                  primary: PosteAction('new',
                      label: _creatingDraft ? 'Préparation…' : 'Nouvelle fiche',
                      icon: Icons.add_rounded,
                      busy: _creatingDraft,
                      onTap: _creatingDraft ? null : _createOrOpenDraft),
                  secondary: [
                    PosteAction('list', label: 'Fiches du poste', icon: Icons.list_alt_rounded, onTap: () => _scrollTo(_listKey)),
                    PosteAction('history', label: 'Historique', icon: Icons.history_rounded, onTap: () => context.go(MyRoute.porPromeshHistoriqueScreen)),
                    PosteAction('refresh', label: 'Actualiser', icon: Icons.refresh_rounded, busy: _loading, onTap: _loading ? null : _load),
                  ],
                ),
                // Fiches manquantes / rattrapages autorisés (comptes suivis) :
                // panneau compact, dates dépliables et défilantes.
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
                  _buildKpiGrid(),
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

  // ── ALERTES ───────────────────────────────────────────────────────────

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
      if (!_loading && _error == null && _stats.nonConformites > 0)
        PosteAlert('nonconformities',
            severity: PosteSeverity.critical,
            icon: Icons.warning_amber_rounded,
            title: 'Non-conformités enregistrées',
            count: _stats.nonConformites,
            description: 'Fiches non conformes sur la période affichée.',
            actionLabel: 'Afficher',
            onTap: () {
              setState(() => _statusFilter = 'non_conforme');
              _onFilterChanged();
              _scrollTo(_listKey);
            }),
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

  // ── KPI ───────────────────────────────────────────────────────────────

  Widget _buildKpiGrid() {
    return PosteKpiGrid(
      loading: _loading,
      items: [
        PosteKpi('created', icon: Icons.description_outlined, label: 'Fiches créées', value: '${_stats.fichesCount}', color: kPromeshColor),
        PosteKpi('validated', icon: Icons.check_circle_outline_rounded, label: 'Fiches validées', value: '${_stats.fichesValidees}', color: kPosteAccepted),
        PosteKpi('drafts', icon: Icons.edit_note_rounded, label: 'En brouillon', value: '${_stats.fichesBrouillon}', color: kPosteNeutral),
        // Unité métier PROMESH : m² (productionM2), sans conversion.
        PosteKpi('production', icon: Icons.straighten_rounded, label: 'Production totale', value: '${prodFormatNumber(_stats.productionTotale)} m²', color: kPromeshColor),
        PosteKpi('nonconformities', icon: Icons.warning_amber_rounded, label: 'Non-conformités', value: '${_stats.nonConformites}', color: kPosteRejected),
        PosteKpi('operators', icon: Icons.engineering_outlined, label: 'Opérateurs présents', value: '${_stats.operateursPresents}', color: kPersonnelColor),
      ],
    );
  }

  // ── GRAPHIQUES ────────────────────────────────────────────────────────

  Widget _buildCharts() {
    final period = pdT(context, _kDateRanges.firstWhere((r) => r.$1 == _dateRange).$2);
    return PosteChartsRow(panels: [
      PosteChartPanel(
        panelKey: 'hourly',
        title: 'Production par heure',
        subtitle: 'm² · $period',
        icon: Icons.bar_chart_outlined,
        color: kPromeshColor,
        loading: _loading,
        chart: _charts.parHeure.any((h) => h.production > 0) ? _buildHourlyBarChart() : null,
        emptyMessage: 'Aucune production sur cette période',
      ),
      PosteChartPanel(
        panelKey: 'conformity',
        title: 'Conformité',
        subtitle: '${pdT(context, 'Fiches')} · $period',
        icon: Icons.pie_chart_outline_rounded,
        color: kPosteAccepted,
        loading: _loading,
        chart: _charts.conforme + _charts.nonConforme > 0 ? _buildConformitePieChart() : null,
        emptyMessage: 'Aucun contrôle de conformité sur cette période',
      ),
      PosteChartPanel(
        panelKey: 'trend',
        title: 'Production des 7 derniers jours',
        subtitle: 'm² / jour',
        icon: Icons.show_chart_rounded,
        color: kPromeshColor,
        loading: _loading,
        chart: _charts.parJour.any((d) => d.production > 0) ? _buildTrendLineChart() : null,
        emptyMessage: 'Aucune production sur les 7 derniers jours',
      ),
    ]);
  }

  FlTitlesData _titles(Widget Function(double value, TitleMeta meta) bottom, {double? interval}) => FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox.shrink() : Text(prodFormatNumber(v, maxDecimals: 0), style: tInter(fontSize: 9.5, color: kCrmTextSub)),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: interval, reservedSize: 24, getTitlesWidget: bottom)),
      );

  Widget _buildHourlyBarChart() {
    final maxY = _charts.parHeure.fold<double>(0, (m, h) => h.production > m ? h.production : m) * 1.2;
    return BarChart(BarChartData(
      maxY: maxY <= 0 ? 1 : maxY,
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: kCrmBorder, strokeWidth: 0.6)),
      borderData: FlBorderData(show: false),
      titlesData: _titles(
        (value, meta) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${value.toInt()}h', style: tInter(fontSize: 9.5, color: kCrmTextSub)),
        ),
        interval: 3,
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => kCrmText,
          getTooltipItem: (group, gi, rod, ri) => BarTooltipItem('${group.x}h · ${prodFormatNumber(rod.toY)} m²', tInter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
      barGroups: [
        for (final h in _charts.parHeure)
          BarChartGroupData(x: h.hour, barRods: [
            BarChartRodData(toY: h.production, color: kPromeshColor, width: 7, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
          ]),
      ],
    ));
  }

  Widget _buildConformitePieChart() {
    final total = _charts.conforme + _charts.nonConforme;
    return Row(children: [
      Expanded(
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 30,
          sections: [
            if (_charts.conforme > 0)
              PieChartSectionData(
                value: _charts.conforme.toDouble(),
                color: kPosteAccepted,
                title: '${(_charts.conforme / total * 100).round()}%',
                titleStyle: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                radius: 42,
              ),
            if (_charts.nonConforme > 0)
              PieChartSectionData(
                value: _charts.nonConforme.toDouble(),
                color: kPosteRejected,
                title: '${(_charts.nonConforme / total * 100).round()}%',
                titleStyle: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                radius: 42,
              ),
          ],
        )),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        posteLegendDot(context, kPosteAccepted, '${pdT(context, 'Conforme')} (${_charts.conforme})'),
        const SizedBox(height: 8),
        posteLegendDot(context, kPosteRejected, '${pdT(context, 'Non Conforme')} (${_charts.nonConforme})'),
      ]),
    ]);
  }

  Widget _buildTrendLineChart() {
    final spots = [
      for (int i = 0; i < _charts.parJour.length; i++) FlSpot(i.toDouble(), _charts.parJour[i].production),
    ];
    final maxY = _charts.parJour.fold<double>(0, (m, d) => d.production > m ? d.production : m) * 1.2;
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxY <= 0 ? 1 : maxY,
      gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: kCrmBorder, strokeWidth: 0.6)),
      borderData: FlBorderData(show: false),
      titlesData: _titles((value, meta) {
        final i = value.toInt();
        if (i < 0 || i >= _charts.parJour.length || value != i.toDouble()) return const SizedBox.shrink();
        final d = DateTime.tryParse(_charts.parJour[i].date);
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(d == null ? '' : DateFormat('dd/MM').format(d), style: tInter(fontSize: 9.5, color: kCrmTextSub)),
        );
      }, interval: 1),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => kCrmText,
          getTooltipItems: (spots) => [
            for (final s in spots) LineTooltipItem('${pdDate(_charts.parJour[s.spotIndex].date)} · ${prodFormatNumber(s.y)} m²', tInter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: kPromeshColor,
          barWidth: 2.5,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: kPromeshColor.withValues(alpha: 0.10)),
        ),
      ],
    ));
  }

  // ── FICHES RÉCENTES ───────────────────────────────────────────────────

  PosteFicheRow _row(PorPromeshModel item) => PosteFicheRow(
        id: item.id ?? '',
        numero: item.numero,
        date: item.dateProduction,
        poste: item.poste,
        machine: item.machine,
        producer: item.creator?['email'],
        operateur: item.operateur,
        quantity: item.productionM2,
        unit: 'm²',
        isDraft: item.status == 'draft',
        approvalStatus: item.approval?.status,
        rejectionComment: item.approval?.rejectionComment,
        rejectedAt: item.approval?.rejectedAt ?? item.approval?.decidedAt,
        nonConforme: item.conformite == 'non_conforme',
      );

  Widget _buildFiches() {
    final byId = {for (final i in _items) i.id ?? '': i};
    final totalPages = (_total / _pageSize).ceil().clamp(1, 999999);
    return PosteFichesSection(
      color: kPromeshColor,
      total: _total,
      rows: [for (final i in _items) _row(i)],
      loading: _loading,
      error: _error,
      onRetry: _load,
      onViewAll: () => context.go(MyRoute.porPromeshHistoriqueScreen),
      actions: (r) {
        final item = byId[r.id]!;
        return [
          PosteRowAction(actionKey: 'poste-fiche-view-${r.id}', tooltip: 'Voir', icon: Icons.visibility_outlined, color: kCrmTextSub, onTap: () => context.go('${MyRoute.porPromeshDetailScreen}?id=${item.id}')),
          PosteRowAction(actionKey: 'poste-fiche-pdf-${r.id}', tooltip: 'Télécharger PDF', icon: Icons.picture_as_pdf_outlined, color: kCrmSecondary, onTap: () => _viewFichePdf(context, item, print: false)),
          PosteRowAction(actionKey: 'poste-fiche-print-${r.id}', tooltip: 'Imprimer', icon: Icons.print_outlined, color: kCrmTextSub, onTap: () => _viewFichePdf(context, item, print: true)),
          PosteRowAction(actionKey: 'poste-fiche-excel-${r.id}', tooltip: 'Export Excel', icon: Icons.grid_on_rounded, color: kCrmSuccess, onTap: () => _viewFicheExcel(context, item)),
        ];
      },
      filters: PosteFiltersBar(
        hint: 'Rechercher par opérateur, responsable, numéro de fiche, date...',
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
            label: 'Machine',
            value: _machineFilter,
            items: [for (final m in ['1', '2', '3', '4']) (m, 'Machine $m')],
            onChanged: (v) => setState(() {
              _machineFilter = v!;
              _onFilterChanged();
            }),
          ),
          PosteFilterDropdown<String?>(
            label: 'Statut',
            value: _statusFilter,
            items: _kStatusFilters,
            onChanged: (v) => setState(() {
              _statusFilter = v;
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
        onPrevious: _page > 1 ? () => setState(() { _page--; _load(); }) : null,
        onNext: _page < totalPages ? () => setState(() { _page++; _load(); }) : null,
      ),
    );
  }
}
