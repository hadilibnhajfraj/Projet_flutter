// lib/production_dashboard/view/production_dashboard_screen.dart
//
// DASHBOARD PRODUCTION (/production/dashboard) — point d'entrée du module
// Production : KPI, filtre de période, cartes PROMESH / PROBAR (production
// par machine), graphiques, dernières productions et accès rapides.
//
// Tous les chiffres viennent de GET /production-records/dashboard (UN appel,
// agrégations PostgreSQL) ; l'écran ne calcule rien et n'affiche aucune
// valeur par défaut. Il ne modifie aucune fiche : la saisie reste sur les
// écrans PROMESH / PROBAR existants, vers lesquels pointent les accès rapides.
//
// Même langage visuel que le Dashboard Industriel et le Contrôle Qualité
// (cartes à bordure fine, rayon 12, ombre légère, icônes Material). Couleurs
// réservées à l'identification : PROMESH bleu, PROBAR orange, statuts
// vert / ambre / gris. Unités différentes (m², m, kg) : jamais deux mesures
// sur un même axe.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as fm show Text;
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/industrial/theme/industrial_theme.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import 'package:dash_master_toolkit/quality_control/model/quality_control_model.dart' show qcIsoFromDate;
import 'package:dash_master_toolkit/quality_control/quality_control_i18n.dart';
import 'package:dash_master_toolkit/quality_control/view/quality_control_widgets.dart';

import '../model/production_dashboard_model.dart';
import '../production_dashboard_routes.dart';
import '../service/production_dashboard_service.dart';

const Color kProductionColor = Color(0xFF0F766E); // accent du module (ni PROMESH ni PROBAR)
const Color _kValidee = Color(0xFF047857);
const Color _kBrouillon = Color(0xFFB45309);
const Color _kArchivee = Color(0xFF64748B);

Color _lineColor(String type) => type == 'probar' ? kProbarColor : kPromeshColor;
IconData _lineIcon(String type) => type == 'probar' ? Icons.view_week_outlined : Icons.grid_on_rounded;
Color _statusColor(String? statut) => switch (statut) {
      'validee' => _kValidee,
      'archivee' => _kArchivee,
      _ => _kBrouillon,
    };
String _shortDate(String iso) => iso.length >= 10 ? '${iso.substring(8, 10)}/${iso.substring(5, 7)}' : iso;

/// Badge de statut d'une fiche : Brouillon / Validée / Archivée.
class ProductionStatusBadge extends StatelessWidget {
  final String? statut;
  const ProductionStatusBadge(this.statut, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(statut);
    final icon = switch (statut) {
      'validee' => Icons.check_circle_outline_rounded,
      'archivee' => Icons.inventory_2_outlined,
      _ => Icons.edit_note_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(prodStatusLabel(statut), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: color))),
      ]),
    );
  }
}

class ProductionDashboardScreen extends StatefulWidget {
  const ProductionDashboardScreen({super.key});

  @override
  State<ProductionDashboardScreen> createState() => _ProductionDashboardScreenState();
}

class _ProductionDashboardScreenState extends State<ProductionDashboardScreen> {
  final _svc = ProductionDashboardService.instance;

  String _period = 'year';
  DateTime? _start;
  DateTime? _end;
  bool _loading = false;
  String? _error;
  ProductionDashboard? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Période personnalisée : rien n'est demandé tant que les deux dates
    // ne sont pas choisies et cohérentes.
    if (_period == 'custom') {
      if (_start == null || _end == null) return;
      if (_start!.isAfter(_end!)) {
        setState(() => _error = 'La date de début doit précéder la date de fin.');
        return;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _svc.fetch(
        period: _period,
        startDate: _start == null ? null : qcIsoFromDate(_start!),
        endDate: _end == null ? null : qcIsoFromDate(_end!),
      );
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setPeriod(String period) {
    if (period == _period) return;
    setState(() => _period = period);
    _load();
  }

  Future<void> _pick({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: qcT(start ? 'Date début' : 'Date fin'),
      cancelText: qcT('Annuler'),
      confirmText: qcT('Valider'),
    );
    if (picked == null || !mounted) return;
    setState(() => start ? _start = picked : _end = picked);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context);
    final d = _data;
    return QcPage(
      onRefresh: _load,
      children: [
        QcPageHeader(
          title: 'Dashboard Production',
          subtitle: 'Suivez les productions PROMESH et PROBAR, les quantités, les déchets, les fiches et les performances.',
          icon: Icons.factory_outlined,
          color: kProductionColor,
          actions: [
            OutlinedButton.icon(
              key: const ValueKey('prod-refresh'),
              onPressed: _loading ? null : _load,
              style: OutlinedButton.styleFrom(foregroundColor: kCrmText, side: const BorderSide(color: kCrmBorder), minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Actualiser'),
            ),
          ],
        ),
        _periodBar(d),
        if (_error != null) QcErrorBanner(_error!, onRetry: _load),
        if (_loading && d == null) const QcSkeletonRows(rows: 6, height: 52),
        if (d != null) ...[
          _kpiSection(d),
          LayoutBuilder(builder: (context, c) {
            final cards = [_lineCard(d.promesh), _lineCard(d.probar)];
            if (c.maxWidth < 1000) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cards[0]), const SizedBox(width: 16), Expanded(child: cards[1])]);
          }),
          _dailySection(d),
          _pair(_statusChart(d), _wasteChart(d)),
          _recentSection(d),
          _quickLinks(),
        ],
      ],
    );
  }

  Widget _pair(Widget a, Widget b) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 1000) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, b]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)]);
      });

  // ── Période ────────────────────────────────────────────────────────────

  Widget _periodBar(ProductionDashboard? d) {
    Widget dateField(String label, DateTime? value, bool start) => InkWell(
          key: ValueKey('prod-date-${start ? 'start' : 'end'}'),
          onTap: () => _pick(start: start),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_today_outlined, size: 15, color: kProductionColor),
              const SizedBox(width: 8),
              Text(label, style: tInter(fontSize: 11.5, fontWeight: FontWeight.w600, color: kCrmTextSub)),
              const SizedBox(width: 6),
              fm.Text(value == null ? '—' : prodFormatDate(qcIsoFromDate(value)), style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
            ]),
          ),
        );
    final range = d == null || d.periodStart == null ? null : '${prodFormatDate(d.periodStart)} → ${prodFormatDate(d.periodEnd)}';
    return QcSection(
      icon: Icons.date_range_rounded,
      title: 'Période',
      subtitle: 'Les indicateurs, les graphiques et les listes se recalculent sur la période choisie',
      color: kProductionColor,
      trailing: range == null ? null : fm.Text(range, style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmTextSub)),
      children: [
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
            child: Wrap(children: [
              for (final (key, label) in kProductionPeriods)
                InkWell(
                  key: ValueKey('prod-period-$key'),
                  onTap: () => _setPeriod(key),
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: key == _period ? kCrmSurface : Colors.transparent, borderRadius: BorderRadius.circular(7)),
                    child: Text(label, style: tInter(fontSize: 12.5, fontWeight: key == _period ? FontWeight.w800 : FontWeight.w500, color: key == _period ? kProductionColor : kCrmTextSub)),
                  ),
                ),
            ]),
          ),
          if (_period == 'custom') ...[
            dateField('Date début', _start, true),
            dateField('Date fin', _end, false),
          ],
        ]),
        if (_period == 'custom' && (_start == null || _end == null))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Choisissez une date de début et une date de fin.', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
          ),
        if (d != null && d.ownScope)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Périmètre : vos propres fiches de production.', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
          ),
      ],
    );
  }

  // ── KPI ────────────────────────────────────────────────────────────────

  String _rate(ProductionLineStats l) => l.tauxDechets == null ? 'N/A' : prodFormatNumber(l.tauxDechets);

  List<Widget> _lineKpis(ProductionLineStats l) {
    final color = _lineColor(l.type);
    return [
      QcKpiTile(icon: Icons.description_outlined, label: 'Fiches ${l.label}', value: '${l.fiches}', caption: '${l.brouillons} brouillon(s) · ${l.archivees} archivée(s)', color: color),
      QcKpiTile(icon: Icons.task_alt_rounded, label: 'Productions validées', value: '${l.validees}', caption: l.label, color: color),
      QcKpiTile(icon: Icons.straighten_rounded, label: 'Quantité produite', value: prodFormatNumber(l.quantite), caption: '${l.unit} · fiches validées', color: color),
      QcKpiTile(icon: Icons.delete_outline_rounded, label: 'Déchets', value: prodFormatNumber(l.dechets), caption: '${l.wasteUnit} · ${l.label}', color: color),
      QcKpiTile(icon: Icons.percent_rounded, label: 'Taux de déchets', value: _rate(l), caption: l.tauxDechetsUnit, color: color),
    ];
  }

  Widget _kpiSection(ProductionDashboard d) => QcSection(
        icon: Icons.insights_rounded,
        title: 'Indicateurs',
        subtitle: 'Calculés sur les fiches enregistrées · quantités : fiches validées',
        color: kProductionColor,
        children: [
          // Desktop : 4 colonnes ; tablette : 2 ; mobile : 1.
          qcGrid(columns: (w) => w >= 1000 ? 4 : (w >= 560 ? 2 : 1), [
            ..._lineKpis(d.promesh),
            ..._lineKpis(d.probar),
            QcKpiTile(icon: kMachineIcon, label: 'Machines actives', value: '${d.machinesActives} / ${d.machinesTotal}', caption: 'Au moins une fiche sur la période', color: kProductionColor),
            QcKpiTile(icon: Icons.today_rounded, label: 'Productions aujourd\'hui', value: '${d.productionsToday}', caption: 'Fiches du jour, toutes lignes', color: kProductionColor),
          ]),
        ],
      );

  // ── Cartes PROMESH / PROBAR ────────────────────────────────────────────

  Widget _stat(String label, String value, {String? unit}) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10, fontWeight: FontWeight.w700, color: kCrmTextSub, letterSpacing: 0.5)),
        const SizedBox(height: 3),
        fm.Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 17, fontWeight: FontWeight.w800, color: kCrmText)),
        if (unit != null) fm.Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10.5, color: kCrmTextSub)),
      ]);

  Widget _machineRow(ProductionLineStats l, ProductionMachineStats m, double maxQty) {
    final color = _lineColor(l.type);
    Widget meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: kCrmTextSub),
          const SizedBox(width: 4),
          Flexible(child: fm.Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, color: kCrmTextSub))),
        ]);
    return Container(
      key: ValueKey('prod-machine-${l.type}-${m.machine}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kCrmBorder))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(kMachineIcon, size: 17, color: m.active ? color : kCrmTextSub),
          const SizedBox(width: 8),
          Expanded(child: Text('Machine ${m.machine}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText))),
          fm.Text(prodFormatQuantity(m.quantite, l.unit), style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText)),
        ]),
        const SizedBox(height: 6),
        // Production par machine : part de la machine la plus productive.
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: maxQty > 0 ? (m.quantite / maxQty).clamp(0, 1).toDouble() : 0, minHeight: 6, backgroundColor: kCrmBorder, color: color),
        ),
        const SizedBox(height: 7),
        Wrap(spacing: 12, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
          meta(Icons.description_outlined, qcT('${m.fiches} fiche(s)')),
          meta(Icons.delete_outline_rounded, '${prodFormatNumber(m.dechets)} ${l.wasteUnit}'),
          meta(Icons.event_outlined, m.lastDate == null ? qcT('Aucune production') : prodFormatDate(m.lastDate)),
          if (m.lastStatut != null) ProductionStatusBadge(m.lastStatut) else Text('Aucune fiche sur la période', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
        ]),
      ]),
    );
  }

  Widget _lineCard(ProductionLineStats l) {
    final color = _lineColor(l.type);
    final maxQty = l.machines.fold<double>(0, (m, x) => x.quantite > m ? x.quantite : m);
    return QcSection(
      key: ValueKey('prod-line-${l.type}'),
      icon: _lineIcon(l.type),
      title: l.label,
      subtitle: 'Production par machine',
      color: color,
      trailing: TextButton.icon(
        onPressed: () => context.go(l.type == 'probar' ? ProdPaths.probarSummary : ProdPaths.promeshSummary),
        style: TextButton.styleFrom(foregroundColor: color),
        icon: const Icon(Icons.summarize_outlined, size: 16),
        label: const Text('Résumé'),
      ),
      children: [
        qcGrid(columns: (w) => w >= 520 ? 4 : 2, gap: 14, [
          _stat('Fiches', '${l.fiches}'),
          _stat('Quantité', prodFormatNumber(l.quantite), unit: l.unit),
          _stat('Déchets', prodFormatNumber(l.dechets), unit: l.wasteUnit),
          _stat('Taux de déchets', _rate(l), unit: l.tauxDechetsUnit),
        ]),
        const SizedBox(height: 12),
        for (final m in l.machines) _machineRow(l, m, maxQty),
      ],
    );
  }

  // ── Graphiques ─────────────────────────────────────────────────────────

  Widget _legend(List<(String, Color)> items) => Wrap(spacing: 14, runSpacing: 4, children: [
        for (final (label, color) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(label, style: tInter(fontSize: 12, color: kCrmText)),
          ]),
      ]);

  FlTitlesData _titles({required Widget Function(double) bottom, double interval = 1, bool left = true}) => FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: left,
            reservedSize: 46,
            getTitlesWidget: (v, meta) => v == meta.max || v == meta.min && v != 0
                ? const SizedBox.shrink()
                : fm.Text(prodFormatNumber(v, maxDecimals: 0), style: tInter(fontSize: 10, color: kCrmTextSub)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: interval,
            getTitlesWidget: (v, meta) => v != v.roundToDouble() ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top: 6), child: bottom(v)),
          ),
        ),
      );

  FlGridData get _grid => FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: kCrmBorder, strokeWidth: 0.6));
  FlBorderData get _border => FlBorderData(show: true, border: const Border(bottom: BorderSide(color: kCrmBorder)));

  /// Barres d'une ligne : quantité validée par jour (un axe, une unité).
  Widget _dailyBars(ProductionLineStats l, List<(String, double)> days) {
    final color = _lineColor(l.type);
    final maxY = days.fold<double>(0, (m, d) => d.$2 > m ? d.$2 : m);
    final interval = (days.length / 8).ceilToDouble().clamp(1, double.infinity).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Expanded(child: fm.Text('${l.label} (${l.unit})', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText))),
      ]),
      const SizedBox(height: 8),
      if (days.isEmpty)
        const QcEmptyState('Aucune production validée sur cette période', icon: Icons.bar_chart_rounded)
      else
        SizedBox(
          height: 210,
          child: BarChart(
            key: ValueKey('prod-chart-daily-${l.type}'),
            BarChartData(
              maxY: maxY <= 0 ? 1 : maxY * 1.15,
              minY: 0,
              gridData: _grid,
              borderData: _border,
              titlesData: _titles(interval: interval, bottom: (v) => fm.Text(_shortDate(days[v.toInt().clamp(0, days.length - 1)].$1), style: tInter(fontSize: 10, color: kCrmTextSub))),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => kCrmText,
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    '${prodFormatDate(days[group.x].$1)}\n${prodFormatQuantity(rod.toY, l.unit)}',
                    tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(toY: days[i].$2, color: color, width: days.length > 20 ? 6 : 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                  ]),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _dailySection(ProductionDashboard d) => QcSection(
        icon: Icons.bar_chart_rounded,
        title: 'Production par jour',
        subtitle: 'Quantité des fiches validées, par date de production · une échelle par ligne (m² et m ne sont pas comparables)',
        color: kProductionColor,
        children: [
          _pair(
            _dailyBars(d.promesh, [for (final x in d.daily) if (x.promesh > 0) (x.date, x.promesh)]),
            _dailyBars(d.probar, [for (final x in d.daily) if (x.probar > 0) (x.date, x.probar)]),
          ),
        ],
      );

  /// PROMESH vs PROBAR : nombre de fiches par statut (même unité : la fiche).
  Widget _statusChart(ProductionDashboard d) {
    final groups = [
      ('Validées', d.promesh.validees, d.probar.validees),
      ('Brouillons', d.promesh.brouillons, d.probar.brouillons),
      ('Archivées', d.promesh.archivees, d.probar.archivees),
    ];
    final maxY = groups.fold<int>(0, (m, g) => [m, g.$2, g.$3].reduce((a, b) => a > b ? a : b));
    return QcSection(
      icon: Icons.compare_arrows_rounded,
      title: 'Production PROMESH vs PROBAR',
      subtitle: 'Nombre de fiches par statut',
      color: kProductionColor,
      trailing: _legend(const [('PROMESH', kPromeshColor), ('PROBAR', kProbarColor)]),
      children: [
        if (d.fiches == 0)
          const QcEmptyState('Aucune fiche sur cette période', icon: Icons.compare_arrows_rounded)
        else
          SizedBox(
            height: 230,
            child: BarChart(
              key: const ValueKey('prod-chart-status'),
              BarChartData(
                maxY: maxY <= 0 ? 1 : maxY * 1.2,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                gridData: _grid,
                borderData: _border,
                titlesData: _titles(bottom: (v) => Text(groups[v.toInt().clamp(0, 2)].$1, style: tInter(fontSize: 11.5, color: kCrmTextSub))),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => kCrmText,
                    getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                      '${ri == 0 ? 'PROMESH' : 'PROBAR'} · ${qcT(groups[group.x].$1)}\n${rod.toY.toInt()}',
                      tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < groups.length; i++)
                    BarChartGroupData(x: i, barsSpace: 2, barRods: [
                      BarChartRodData(toY: groups[i].$2.toDouble(), color: kPromeshColor, width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                      BarChartRodData(toY: groups[i].$3.toDouble(), color: kProbarColor, width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                    ]),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Évolution des déchets (kg) : une courbe par ligne, même unité.
  Widget _wasteChart(ProductionDashboard d) {
    final days = [for (final x in d.daily) if (x.dechetsPromesh > 0 || x.dechetsProbar > 0) x];
    final maxY = days.fold<double>(0, (m, x) => [m, x.dechetsPromesh, x.dechetsProbar].reduce((a, b) => a > b ? a : b));
    LineChartBarData line(Color color, double Function(ProductionDay) value) => LineChartBarData(
          spots: [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), value(days[i]))],
          color: color,
          barWidth: 2,
          dotData: FlDotData(getDotPainter: (s, p, bar, i) => FlDotCirclePainter(radius: 4, color: color, strokeWidth: 2, strokeColor: kCrmSurface)),
        );
    return QcSection(
      icon: Icons.show_chart_rounded,
      title: 'Évolution des déchets',
      subtitle: 'Déchets déclarés par jour (kg)',
      color: kProductionColor,
      trailing: _legend(const [('PROMESH', kPromeshColor), ('PROBAR', kProbarColor)]),
      children: [
        if (days.isEmpty)
          const QcEmptyState('Aucun déchet déclaré sur cette période', icon: Icons.show_chart_rounded)
        else
          SizedBox(
            height: 230,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, right: 12),
              child: LineChart(
                key: const ValueKey('prod-chart-waste'),
                LineChartData(
                  minX: 0,
                  maxX: days.length <= 1 ? 1 : (days.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY <= 0 ? 1 : maxY * 1.15,
                  gridData: _grid,
                  borderData: _border,
                  titlesData: _titles(
                    interval: (days.length / 6).ceilToDouble().clamp(1, double.infinity).toDouble(),
                    bottom: (v) => v.toInt() >= days.length ? const SizedBox.shrink() : fm.Text(_shortDate(days[v.toInt()].date), style: tInter(fontSize: 10, color: kCrmTextSub)),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => kCrmText,
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            '${s.barIndex == 0 ? 'PROMESH' : 'PROBAR'} · ${prodFormatDate(days[s.spotIndex].date)} · ${prodFormatQuantity(s.y, 'kg')}',
                            tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [line(kPromeshColor, (x) => x.dechetsPromesh), line(kProbarColor, (x) => x.dechetsProbar)],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Dernières productions ──────────────────────────────────────────────

  /// Ouvre la fiche sur son écran existant (aucun nouvel écran de saisie).
  void _open(ProductionRecentRow r) {
    final m = r.machine;
    final p = r.poste;
    if (m == null || m.isEmpty || p == null || p.isEmpty) {
      context.go(ProdPaths.records);
    } else if (r.type == 'probar') {
      context.go(ProdPaths.probarFiche(m, p, r.recordId));
    } else {
      context.go(ProdPaths.promeshFiche(m, p, r.recordId));
    }
  }

  Widget _recentSection(ProductionDashboard d) {
    const columns = <(String, int)>[('Date', 3), ('Référence', 5), ('Ligne', 3), ('Machine', 3), ('Poste', 2), ('Utilisateur', 4), ('Quantité', 3), ('Déchets', 2), ('Statut', 3), ('Action', 2)];
    Widget cell(int flex, Widget child) => Expanded(flex: flex, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Align(alignment: Alignment.centerLeft, child: child)));
    fm.Text value(String text, {bool strong = false}) =>
        fm.Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w500, color: kCrmText));
    final table = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          for (final (label, flex) in columns)
            cell(flex, Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10.5, fontWeight: FontWeight.w700, color: kCrmTextSub, letterSpacing: 0.5))),
        ]),
      ),
      for (final r in d.recent)
        Container(
          key: ValueKey('prod-recent-${r.id}'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
          child: Row(children: [
            cell(3, value(prodFormatDate(r.date))),
            cell(5, value(r.numero ?? '—', strong: true)),
            cell(3, QcLineChip(r.ligne, dense: true)),
            cell(3, r.machine == null ? value('—') : Text('Machine ${r.machine}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText))),
            cell(2, Text(prodPosteLabel(r.poste), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, color: kCrmText))),
            cell(4, Tooltip(message: r.userEmail ?? '', child: value(prodUserLabel(r.userEmail)))),
            cell(3, value(prodFormatQuantity(r.quantite, r.quantiteUnite), strong: true)),
            cell(2, value(prodFormatQuantity(r.dechets, r.dechetsUnite))),
            cell(3, ProductionStatusBadge(r.statut)),
            cell(
              2,
              TextButton(
                onPressed: () => _open(r),
                style: TextButton.styleFrom(foregroundColor: kProductionColor, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
                child: const Text('Voir'),
              ),
            ),
          ]),
        ),
    ]);
    return QcSection(
      icon: Icons.history_rounded,
      title: 'Dernières productions',
      subtitle: 'Les fiches les plus récentes de la période, toutes lignes',
      color: kProductionColor,
      trailing: TextButton.icon(
        onPressed: () => context.go(ProdPaths.records),
        style: TextButton.styleFrom(foregroundColor: kProductionColor),
        icon: const Icon(Icons.list_alt_rounded, size: 16),
        label: const Text('Toutes les fiches'),
      ),
      children: [
        if (d.recent.isEmpty)
          const QcEmptyState('Aucune production sur cette période', icon: Icons.history_rounded)
        else
          // Petit écran : tableau défilable horizontalement.
          LayoutBuilder(builder: (context, c) {
            const minWidth = 1040.0;
            if (c.maxWidth >= minWidth) return table;
            return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: minWidth, child: table));
          }),
      ],
    );
  }

  // ── Accès rapides ──────────────────────────────────────────────────────

  Widget _quickLinks() {
    Widget link(String id, IconData icon, String title, String caption, Color color, String route) => Material(
          color: kCrmSurface,
          borderRadius: BorderRadius.circular(kQcRadius),
          child: InkWell(
            key: ValueKey('prod-link-$id'),
            onTap: () => context.go(route),
            borderRadius: BorderRadius.circular(kQcRadius),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(kQcRadius), border: Border.all(color: kCrmBorder)),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w800, color: kCrmText)),
                    Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11.5, color: kCrmTextSub)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: kCrmTextSub, size: 20),
              ]),
            ),
          ),
        );
    return QcSection(
      icon: Icons.bolt_rounded,
      title: 'Accès rapides',
      color: kProductionColor,
      children: [
        qcGrid(columns: (w) => w >= 1000 ? 3 : (w >= 560 ? 2 : 1), [
          link('new-promesh', Icons.add_circle_outline_rounded, 'Nouvelle fiche PROMESH', 'Choisir la machine et le poste', kPromeshColor, ProdPaths.promesh),
          link('new-probar', Icons.add_circle_outline_rounded, 'Nouvelle fiche PROBAR', 'Choisir la machine et le poste', kProbarColor, ProdPaths.probar),
          link('summary-promesh', Icons.summarize_outlined, 'Résumé PROMESH', 'Production Summary et export', kPromeshColor, ProdPaths.promeshSummary),
          link('summary-probar', Icons.summarize_outlined, 'Résumé PROBAR', 'Production Summary et export', kProbarColor, ProdPaths.probarSummary),
          link('records', Icons.list_alt_rounded, 'Fiches de production', 'Historique PROMESH et PROBAR, filtres', kProductionColor, ProdPaths.records),
          link('summary', Icons.analytics_outlined, 'Résumé Production', 'Toutes lignes, par diamètre', kProductionColor, ProdPaths.summary),
        ]),
      ],
    );
  }
}
