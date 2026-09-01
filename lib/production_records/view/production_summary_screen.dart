// lib/production_records/view/production_summary_screen.dart
//
// "Production Summary / Total Production" — récapitulatif PROBAR/PROMESH
// groupé automatiquement par Diamètre (+ Taille de maille pour PROMESH),
// avec sous-totaux par diamètre et un total (par section) très visible.
// Mirrors GET /production-records/summary (backend :
// modules/production-records/services/productionRecords.service.js#getProductionSummary).
//
// Aucune nouvelle donnée : agrégation en lecture seule des fiches PorPromesh
// et IndustrialRecord (module='probar') existantes, calculée côté SQL.
//
// RÈGLE ABSOLUE : les mètres PROBAR et les m² PROMESH ne sont JAMAIS
// additionnés entre eux, ni affichés dans un même KPI/total — PROMESH et
// PROBAR ont chacun leurs propres cartes KPI, leur propre section et leur
// propre tableau (voir _buildKpiRow / _ProductionSection).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/por_promesh/view/widgets/shimmer_box.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';

import '../model/production_record_model.dart';
import '../model/production_summary_model.dart';
import '../service/production_records_service.dart';
import '../service/production_summary_export_service.dart';

// Grille responsive équi-hauteur/équi-largeur, sans GridView ni ratio fixe —
// voir le commentaire sur _buildKpiRow pour la raison (évite tout risque de
// débordement/chevauchement quand le contenu d'une carte est plus grand que
// prévu). `IntrinsicHeight` + `CrossAxisAlignment.stretch` mesure la ligne
// à la hauteur de sa carte la plus grande et applique cette hauteur à
// toutes les cartes de la ligne ; `Expanded` garantit des largeurs égales.
Widget _responsiveCardGrid(List<Widget> cards, int columns, {double gap = 14}) {
  final rows = <Widget>[];
  for (int i = 0; i < cards.length; i += columns) {
    final rowItems = cards.skip(i).take(columns).toList();
    final rowChildren = <Widget>[];
    for (int j = 0; j < columns; j++) {
      if (j > 0) rowChildren.add(SizedBox(width: gap));
      rowChildren.add(Expanded(child: j < rowItems.length ? rowItems[j] : const SizedBox.shrink()));
    }
    rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: rowChildren)));
    if (i + columns < cards.length) rows.add(const SizedBox(height: 14));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
}

const _kPeriods = <(String?, String)>[
  (null, 'Toutes les périodes'),
  ('week', 'Cette semaine'),
  ('month', 'Ce mois'),
  ('custom', 'Personnalisée'),
];

// Le filtre Statut par défaut est "Validées" — mêmes fiches que les autres
// KPI industriels de la page "Fiches de production" (voir
// getProductionTotals) ; "Toutes" est une valeur explicite distincte, jamais
// le comportement implicite en l'absence de filtre (voir
// resolveSummaryStatus côté backend).
const _kStatuses = <(String, String)>[
  ('validee', 'Validée'),
  ('brouillon', 'Brouillon'),
  ('all', 'Toutes'),
];

class ProductionSummaryScreen extends StatefulWidget {
  const ProductionSummaryScreen({super.key});

  @override
  State<ProductionSummaryScreen> createState() => _ProductionSummaryScreenState();
}

class _ProductionSummaryScreenState extends State<ProductionSummaryScreen> {
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  String? _type; // null = 'Toutes' | 'probar' | 'promesh'
  String? _period;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _machineFilter;
  String? _diameterFilter;
  String _status = 'validee';

  ProductionSummary _summary = const ProductionSummary();
  ProductionRecordFilters _filters = const ProductionRecordFilters();

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _load();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await ProductionRecordsService.instance.fetchSummary(
        type: _type,
        period: _period,
        startDate: _period == 'custom' && _customStart != null ? DateFormat('yyyy-MM-dd').format(_customStart!) : null,
        endDate: _period == 'custom' && _customEnd != null ? DateFormat('yyyy-MM-dd').format(_customEnd!) : null,
        machineId: _machineFilter,
        diameter: _diameterFilter,
        status: _status,
      );
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAll() => Future.wait([_loadFilters(), _load()]);

  void _onFilterChanged() => _load();

  void _resetFilters() {
    setState(() {
      _type = null;
      _period = null;
      _customStart = null;
      _customEnd = null;
      _machineFilter = null;
      _diameterFilter = null;
      _status = 'validee';
    });
    _load();
  }

  // ── Contexte affiché / exporté (jamais recalculé différemment entre écran
  // et export — le PDF/Excel doit refléter EXACTEMENT ce que l'utilisateur
  // voit) ──────────────────────────────────────────────────────────────────
  String _periodLabel(AppLocalizations t) {
    if (_period == 'custom') {
      final s = _customStart == null ? '…' : DateFormat('dd/MM/yyyy').format(_customStart!);
      final e = _customEnd == null ? '…' : DateFormat('dd/MM/yyyy').format(_customEnd!);
      return '$s → $e';
    }
    final match = _kPeriods.firstWhere((p) => p.$1 == _period, orElse: () => (_period, 'Toutes les périodes'));
    return t.translate(match.$2);
  }

  String? get _machineLabel => _machineFilter == null ? null : 'Machine $_machineFilter';

  ProductionSummaryExportContext get _exportContext => ProductionSummaryExportContext(
        periodLabel: _periodLabel(AppLocalizations.of(context)),
        machineLabel: _machineLabel,
        diameterLabel: _diameterFilter,
        statusLabel: AppLocalizations.of(context).translate(
          _kStatuses.firstWhere((s) => s.$1 == _status, orElse: () => ('validee', 'Validée')).$2,
        ),
        // Valeurs brutes des filtres — utilisées uniquement par
        // exportExcel() pour calculer dynamiquement la plage de dates
        // réelle des fiches exportées (voir _resolveExcelPeriodRange).
        rawPeriod: _period,
        rawStartDate: _period == 'custom' && _customStart != null ? DateFormat('yyyy-MM-dd').format(_customStart!) : null,
        rawEndDate: _period == 'custom' && _customEnd != null ? DateFormat('yyyy-MM-dd').format(_customEnd!) : null,
        rawMachineId: _machineFilter,
      );

  Future<void> _runExport(Future<void> Function() action) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context).translate('Erreur')} : $e'), backgroundColor: kCrmDanger));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final t = AppLocalizations.of(context);
    final promesh = _summary.promesh;
    final probar = _summary.probar;

    return Scaffold(
      backgroundColor: kCrmBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 1. Titre
              _buildHeader(context, isMobile),
              const SizedBox(height: 20),
              // 2. Filtres (Type + Période + Diamètre + Machine + Statut + Reset)
              _buildFiltersCard(context),
              const SizedBox(height: 22),
              // 3. KPI + tableaux — state machine loading/success/empty/error
              // (§7 : une erreur réseau/API ne doit JAMAIS afficher "Number
              // of records = 0" comme si la base était vide — le KPI row
              // n'est donc rendu QUE hors erreur, jamais en même temps que
              // le message d'erreur).
              if (_error != null)
                _buildError(context)
              else ...[
                _buildKpiRow(context, isMobile),
                const SizedBox(height: 26),
                if (_loading && promesh == null && probar == null)
                  _buildTablesSkeleton()
                else ...[
                  // 4. Section PROMESH
                  if (promesh != null) ...[
                    _ProductionSection(
                      titleKey: 'Production PROMESH',
                      totalLabelKey: 'Total PROMESH',
                      color: kPromeshColor,
                      icon: Icons.factory_outlined,
                      table: promesh,
                      isPromesh: true,
                    ),
                    const SizedBox(height: 24),
                  ],
                  // 5. Section PROBAR
                  if (probar != null) ...[
                    _ProductionSection(
                      titleKey: 'Production PROBAR',
                      totalLabelKey: 'Total PROBAR',
                      color: kProbarColor,
                      icon: Icons.factory_outlined,
                      table: probar,
                      isPromesh: false,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (promesh == null && probar == null) _buildEmpty(context, t),
                ],
              ],
              // 6. Export (toujours en tout dernier, après les deux tableaux)
              _buildExportBar(context),
            ]),
          ),
        ),
      ),
    );
  }

  // ── HEADER + EXPORTS ──────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isMobile) {
    final t = AppLocalizations.of(context);
    return Row(children: [
      Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: kCrmPrimary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.summarize_outlined, size: 22, color: kCrmPrimary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.translate('Production Summary'), style: tInter(fontSize: 21, fontWeight: FontWeight.w800, color: kCrmText)),
          const SizedBox(height: 2),
          Text(
            t.translate('Production overview for PROBAR and PROMESH'),
            style: tInter(fontSize: 12.5, color: kCrmTextSub),
          ),
        ]),
      ),
      if (!isMobile) ...[
        IconButton(
          tooltip: t.translate('Actualiser'),
          icon: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded, size: 18, color: kCrmTextSub),
          onPressed: _loading ? null : _refreshAll,
        ),
      ],
    ]);
  }

  // Placé en tout dernier dans le flux de la page (voir build()) — après
  // les deux tableaux, jamais superposé au reste du contenu.
  Widget _buildExportBar(BuildContext context) {
    final t = AppLocalizations.of(context);
    // §11 : jamais d'export possible tant que le dernier chargement a échoué
    // — même si un précédent filtre avait chargé des données avec succès
    // (`_summary` garde alors sa dernière valeur connue, volontairement pas
    // effacée pour l'affichage), exporter ces données périmées pendant qu'une
    // erreur est affichée serait trompeur.
    final hasData = _error == null && (_summary.promesh != null || _summary.probar != null);
    Widget btn(IconData icon, String label, VoidCallback? onTap) => OutlinedButton.icon(
          onPressed: (_exporting || !hasData) ? null : onTap,
          icon: Icon(icon, size: 16),
          label: Text(t.translate(label), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: kCrmPrimary,
            side: const BorderSide(color: kCrmBorder),
            backgroundColor: kCrmBg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        btn(Icons.table_view_rounded, 'Export Excel',
            () => _runExport(() => ProductionSummaryExportService.instance.exportExcel(_summary, _exportContext))),
        btn(Icons.picture_as_pdf_outlined, 'Export PDF',
            () => _runExport(() => ProductionSummaryExportService.instance.exportPdf(_summary, _exportContext))),
        btn(Icons.print_outlined, 'Imprimer',
            () => _runExport(() => ProductionSummaryExportService.instance.printSummary(_summary, _exportContext))),
        if (_exporting) ...[
          const SizedBox(width: 4),
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ]),
    );
  }

  // ── FILTRES (Type + Période + Diamètre + Machine + Statut + Reset) ─────

  Widget _buildFiltersCard(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildTypeFilter(context),
        const SizedBox(height: 14),
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
            icon: Icons.circle_outlined,
            value: _diameterFilter,
            items: [
              (null, t.translate('Tous les diamètres')),
              for (final d in _filters.diameters) (d, '$d mm'),
            ],
            onChanged: (v) => setState(() {
              _diameterFilter = v;
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
          _dropdown<String>(
            icon: Icons.fact_check_outlined,
            value: _status,
            items: [for (final s in _kStatuses) (s.$1, t.translate(s.$2))],
            onChanged: (v) => setState(() {
              _status = v!;
              _onFilterChanged();
            }),
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
            color: active ? color.withOpacity(0.12) : kCrmBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? color : kCrmBorder, width: active ? 1.4 : 1),
          ),
          child: Text(t.translate(label), style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? color : kCrmTextSub)),
        ),
      );
    }

    return Wrap(spacing: 10, runSpacing: 10, children: [
      seg(null, 'Toutes les productions', kCrmPrimary),
      seg('promesh', 'PROMESH', kPromeshColor),
      seg('probar', 'PROBAR', kProbarColor),
    ]);
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
          Text(value == null ? label : DateFormat('dd/MM/yyyy').format(value),
              style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText)),
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

  // ── KPI — jamais additionner m (PROBAR) et m² (PROMESH) : chaque unité a
  // sa propre carte, jamais combinées sur une même carte/valeur.
  //
  // Volontairement PAS de GridView.count/childAspectRatio ici : une hauteur
  // de cellule dérivée d'un ratio fixe peut devenir plus petite que le
  // contenu réel de la carte (libellés traduits plus longs, etc.), et le
  // Column déborde alors visuellement PAR-DESSUS ce qui suit (symptôme
  // "les KPI chevauchent les éléments en dessous"). `_responsiveCardGrid`
  // ci-dessous mesure la hauteur réelle du contenu (IntrinsicHeight) et
  // l'applique à toute la ligne (stretch) — largeur et hauteur toujours
  // identiques, jamais de débordement possible.
  // KPI calculés à partir des MÊMES lignes que le tableau ci-dessous
  // (promesh.grandTotal/probar.grandTotal/totalRecords — voir
  // ProductionSummaryTable) : jamais une valeur recalculée séparément,
  // jamais hardcodée.
  Widget _buildKpiRow(BuildContext context, bool isMobile) {
    final t = AppLocalizations.of(context);
    final promesh = _summary.promesh;
    final probar = _summary.probar;
    final width = MediaQuery.of(context).size.width;
    final columns = width < 700 ? 1 : (width < 1100 ? 2 : 3);

    if (_loading && promesh == null && probar == null) {
      return _responsiveCardGrid(List.generate(3, (_) => _kpiSkeletonCard()), columns);
    }

    final totalRecords = (promesh?.totalRecords ?? 0) + (probar?.totalRecords ?? 0);

    final cards = <Widget>[
      if (promesh != null)
        KpiStatCard(
          icon: Icons.factory_outlined,
          value: '${formatProductionNumber(promesh.grandTotal)} ${promesh.unit}',
          label: t.translate('Total PROMESH'),
          color: kPromeshColor,
        ),
      if (probar != null)
        KpiStatCard(
          icon: Icons.factory_outlined,
          value: '${formatProductionNumber(probar.grandTotal)} ${probar.unit}',
          label: t.translate('Total PROBAR'),
          color: kProbarColor,
        ),
      KpiStatCard(
        icon: Icons.description_outlined,
        value: '$totalRecords',
        label: t.translate('Nombre de fiches'),
        color: kCrmSuccess,
      ),
    ];

    return _responsiveCardGrid(cards, columns);
  }

  Widget _kpiSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kCrmBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: const [
        ShimmerBox(width: 44, height: 44, borderRadius: BorderRadius.all(Radius.circular(12))),
        SizedBox(height: 24),
        ShimmerBox(width: 70, height: 22),
        SizedBox(height: 6),
        ShimmerBox(width: 100, height: 12),
      ]),
    );
  }

  // §7 : un échec réseau/API affiche un message clair + Retry — jamais un
  // KPI "0" ou une liste vide qui laisserait croire que la base ne contient
  // aucune fiche (voir le if (_error != null) dans build()).
  Widget _buildError(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, color: kCrmDanger, size: 36),
          const SizedBox(height: 10),
          Text(t.translate('Impossible de charger les données de production.'),
              textAlign: TextAlign.center, style: tInter(fontSize: 14, fontWeight: FontWeight.w700, color: kCrmText)),
          const SizedBox(height: 4),
          Text(_error ?? '', textAlign: TextAlign.center, style: tInter(fontSize: 11.5, color: kCrmTextSub)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(t.translate('Réessayer')),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(child: Text(t.translate('Aucune donnée pour ces filtres'), style: tInter(fontSize: 13, color: kCrmTextSub))),
    );
  }

  Widget _buildTablesSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      child: Column(children: [
        for (int i = 0; i < 5; i++) ...[
          const ShimmerBox(width: double.infinity, height: 18),
          if (i < 4) const SizedBox(height: 12),
        ],
      ]),
    );
  }
}

// ── SECTION (titre "Production PROMESH/PROBAR" + pastille total + tableau)
// ─────────────────────────────────────────────────────────────────────────
class _ProductionSection extends StatelessWidget {
  final String titleKey;
  final String totalLabelKey;
  final Color color;
  final IconData icon;
  final ProductionSummaryTable table;
  final bool isPromesh;

  const _ProductionSection({
    required this.titleKey,
    required this.totalLabelKey,
    required this.color,
    required this.icon,
    required this.table,
    required this.isPromesh,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Text(t.translate(titleKey), style: tInter(fontSize: 16, fontWeight: FontWeight.w800, color: kCrmText)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.35))),
          child: Text('${t.translate(totalLabelKey)} : ${formatProductionNumber(table.grandTotal)} ${table.unit}',
              style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
        ),
      ]),
      const SizedBox(height: 12),
      _SummaryTableCard(color: color, table: table, isPromesh: isPromesh, grandTotalLabelKey: totalLabelKey),
    ]);
  }
}

// ── TABLEAU RÉCAPITULATIF (un par type — PROMESH ou PROBAR) ────────────
//
// Style "rapport ERP" : une ligne par fiche réelle (id/date/machine/
// diamètre/cell size/quantité — voir ProductionRecordModel, même modèle que
// "Fiches de production", aucun champ inventé), total de la section très
// visible en bas. Une fiche PROMESH machine 4 (valeur réelle de la colonne
// `machine`, jamais la position de la ligne — voir isPromesh4Machine) est
// mise en évidence sur toute la ligne. Pagination locale par fiches quand il
// y en a beaucoup — l'export (Excel/PDF) utilise toujours `widget.table.rows`
// en entier, jamais seulement la page actuellement affichée.
class _SummaryTableCard extends StatefulWidget {
  final Color color;
  final ProductionSummaryTable table;
  final bool isPromesh;
  final String grandTotalLabelKey;

  const _SummaryTableCard({
    required this.color,
    required this.table,
    required this.isPromesh,
    required this.grandTotalLabelKey,
  });

  @override
  State<_SummaryTableCard> createState() => _SummaryTableCardState();
}

class _SummaryTableCardState extends State<_SummaryTableCard> {
  static const _rowsPerPage = 15;
  int _page = 0;

  static const _flexIndex = 1;
  static const _flexDate = 3;
  static const _flexMachine = 3;
  static const _flexDiameter = 2;
  static const _flexMesh = 3;
  static const _flexQty = 3;
  // §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS RECOVERABLES.
  static const _flexWaste = 3;

  static const _promesh4Bg = Color(0xFFFEF3C7); // amber-100 — distinct du bleu PROMESH, lisible
  static const _promesh4Border = Color(0xFFF59E0B); // kCrmWarning

  @override
  void didUpdateWidget(covariant _SummaryTableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Filtres changés → les fiches affichées ne correspondent plus forcément
    // à la page courante ; on revient toujours en page 1 pour éviter une
    // page vide.
    if (oldWidget.table.rows != widget.table.rows) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final rows = widget.table.rows;
    final totalPages = rows.isEmpty ? 1 : ((rows.length + _rowsPerPage - 1) ~/ _rowsPerPage);
    final page = _page.clamp(0, totalPages - 1);
    final pageRows = rows.skip(page * _rowsPerPage).take(_rowsPerPage).toList();
    final showPagination = rows.length > _rowsPerPage;

    return Container(
      decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCrmBorder)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(child: Text(t.translate('Aucune donnée pour ces filtres'), style: tInter(fontSize: 12.5, color: kCrmTextSub))),
          )
        else
          // IMPORTANT : `ConstrainedBox(minWidth: ...)` seul NE BORNE PAS la
          // largeur maximale (maxWidth reste infini) — dans un
          // SingleChildScrollView horizontal, cela laisse les Row/Expanded
          // ci-dessous (_headerRow/_dataRow/_grandTotalRow)
          // avec une largeur non bornée, ce que Flutter refuse de layouter
          // (RenderFlex avec flex non nul sous contrainte de largeur
          // infinie) — le tableau entier disparaissait silencieusement,
          // laissant un grand espace vide entre les KPI et les boutons
          // d'export. `LayoutBuilder` + `SizedBox(width: ...)` donne une
          // largeur réellement bornée (au moins la largeur disponible, plus
          // si nécessaire sur mobile pour permettre le défilement — jamais
          // de hauteur fixe trop petite, chaque ligne garde sa hauteur
          // intrinsèque).
          LayoutBuilder(builder: (context, constraints) {
            final tableWidth = constraints.maxWidth < 620 ? 620.0 : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _headerRow(t),
                  for (int i = 0; i < pageRows.length; i++) _dataRow(t, page * _rowsPerPage + i + 1, pageRows[i]),
                  _grandTotalRow(t),
                  // §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS
                  // RECOVERABLES — deuxième ligne de total, sous TOTAL
                  // PROMESH/PROBAR (§6/§7 du ticket), jamais fusionnée avec la
                  // quantité (unités différentes, §8 : jamais mélangées).
                  _grandTotalWasteRow(t),
                ]),
              ),
            );
          }),
        if (showPagination) _buildPagination(t, page, totalPages),
      ]),
    );
  }

  Widget _headerRow(AppLocalizations t) {
    return Container(
      color: kCrmBg,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(children: [
        Expanded(flex: _flexIndex, child: Text('#', style: _headStyle)),
        Expanded(flex: _flexDate, child: Text(t.translate('Date production'), style: _headStyle)),
        // §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS
        // RECOVERABLES (§2) — "Machine" est désormais affiché pour PROBAR
        // aussi, plus seulement PROMESH.
        Expanded(flex: _flexMachine, child: Text(t.translate('Machine'), style: _headStyle)),
        Expanded(flex: _flexDiameter, child: Text(t.translate('Diameter'), style: _headStyle)),
        if (widget.isPromesh) Expanded(flex: _flexMesh, child: Text(t.translate('Cell size'), style: _headStyle)),
        Expanded(flex: _flexQty, child: Text('${t.translate('Quantity')} (${widget.table.unit})', style: _headStyle, textAlign: TextAlign.right)),
        Expanded(flex: _flexWaste, child: Text('${t.translate('Waste')} (${widget.table.wasteUnit})', style: _headStyle, textAlign: TextAlign.right)),
      ]),
    );
  }

  static final _headStyle = tInter(fontSize: 11, fontWeight: FontWeight.w800, color: kCrmTextSub, letterSpacing: 0.3);

  Widget _dataRow(AppLocalizations t, int index, ProductionRecordModel r) {
    final isPromesh4 = widget.isPromesh && isPromesh4Machine(r.machine);
    final dateLabel = _formatProductionDate(r.date);
    final machineLabel = widget.isPromesh ? formatPromeshMachineLabel(r.machine) : formatProbarMachineLabel(r.machine);
    final diameterLabel = (r.diametre == null || r.diametre!.isEmpty) ? t.translate('Non renseigné') : '${r.diametre} mm';
    final meshLabel = (r.tailleMaille == null || r.tailleMaille!.isEmpty) ? t.translate('Non renseigné') : formatCellSize(r.tailleMaille!);
    final qtyLabel = '${formatProductionNumber(r.quantite ?? 0)} ${widget.table.unit}';
    // §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS RECOVERABLES
    // — `r.waste` vient directement du backend (jointure module+date sur
    // Recuperables.waste, voir productionRecords.service.js#attachWaste),
    // jamais recalculé ici à partir de Quantity/Diameter (§15). Absent → 0
    // (§5, jamais null/undefined/NaN affiché).
    final wasteLabel = '${r.waste.toStringAsFixed(2)} ${widget.table.wasteUnit}';

    final textStyle = tInter(fontSize: 12.5, fontWeight: isPromesh4 ? FontWeight.w700 : FontWeight.w500, color: kCrmText);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: isPromesh4 ? _promesh4Bg : null,
        border: Border(
          bottom: const BorderSide(color: kCrmBorder, width: 0.6),
          left: isPromesh4 ? const BorderSide(color: _promesh4Border, width: 3) : BorderSide.none,
        ),
      ),
      child: Row(children: [
        Expanded(flex: _flexIndex, child: Text('$index', style: textStyle)),
        Expanded(flex: _flexDate, child: Text(dateLabel, style: textStyle)),
        Expanded(
          flex: _flexMachine,
          child: isPromesh4 ? _promesh4Badge(r.machine) : Text(machineLabel, style: textStyle),
        ),
        Expanded(flex: _flexDiameter, child: Text(diameterLabel, style: textStyle)),
        if (widget.isPromesh) Expanded(flex: _flexMesh, child: Text(meshLabel, style: textStyle)),
        Expanded(flex: _flexQty, child: Text(qtyLabel, textAlign: TextAlign.right, style: textStyle)),
        Expanded(flex: _flexWaste, child: Text(wasteLabel, textAlign: TextAlign.right, style: textStyle)),
      ]),
    );
  }

  // Badge coloré pour la machine PROMESH 4 (§3 : "le badge Machine peut
  // également être coloré") — même couleur que la mise en évidence de ligne
  // (_promesh4Border), texte toujours parfaitement lisible.
  Widget _promesh4Badge(String? machine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _promesh4Border,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(formatPromeshMachineLabel(machine),
          style: tInter(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }

  Widget _grandTotalRow(AppLocalizations t) {
    final leadingFlex = _flexIndex + _flexDate + _flexMachine + _flexDiameter + (widget.isPromesh ? _flexMesh : 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(color: widget.color),
      child: Row(children: [
        Expanded(
          flex: leadingFlex,
          child: Text(t.translate(widget.grandTotalLabelKey).toUpperCase(),
              style: tInter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.4)),
        ),
        Expanded(
          flex: _flexQty,
          child: Text('${formatProductionNumber(widget.table.grandTotal)} ${widget.table.unit}',
              textAlign: TextAlign.right, style: tInter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        // Colonne Waste laissée vide sur cette ligne — son propre total
        // s'affiche sur la ligne dédiée juste en dessous (_grandTotalWasteRow,
        // §6/§7 : jamais mélangé avec Quantity, unités différentes).
        Expanded(flex: _flexWaste, child: const SizedBox.shrink()),
      ]),
    );
  }

  // §MODIFICATION — PRODUCTION SUMMARY : AJOUT DU WASTE DEPUIS RECOVERABLES —
  // "TOTAL WASTE", deuxième ligne sous TOTAL PROMESH/PROBAR. Valeur = somme
  // des dates DISTINCTES du tableau (déjà calculée côté backend, voir
  // `grandTotalWaste`) — jamais une somme "par ligne" côté client, qui
  // doublonnerait une date partagée par plusieurs lignes de production.
  Widget _grandTotalWasteRow(AppLocalizations t) {
    final leadingFlex = _flexIndex + _flexDate + _flexMachine + _flexDiameter + (widget.isPromesh ? _flexMesh : 0) + _flexQty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(color: widget.color.withOpacity(0.85)),
      child: Row(children: [
        Expanded(
          flex: leadingFlex,
          child: Text(t.translate('TOTAL WASTE'),
              style: tInter(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.4)),
        ),
        Expanded(
          flex: _flexWaste,
          child: Text('${widget.table.grandTotalWaste.toStringAsFixed(2)} ${widget.table.wasteUnit}',
              textAlign: TextAlign.right, style: tInter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ]),
    );
  }

  Widget _buildPagination(AppLocalizations t, int page, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kCrmBorder))),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('${t.translate('Page')} ${page + 1} ${t.translate('sur')} $totalPages', style: tInter(fontSize: 12, color: kCrmTextSub)),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 20),
          onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 20),
          onPressed: page < totalPages - 1 ? () => setState(() => _page = page + 1) : null,
        ),
      ]),
    );
  }
}

// Date réelle de production (jamais la date du jour) — le champ `date` du
// modèle vient de PorPromesh.dateProduction / IndustrialRecord.dateFiche
// (voir productionRecords.dto.js), au format ISO "yyyy-MM-dd" côté API.
// Affichage standardisé "dd/MM/yyyy" — même format que le reste du module
// Production (voir production_records_screen.dart).
String _formatProductionDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '—';
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) return isoDate;
  return DateFormat('dd/MM/yyyy').format(parsed);
}
