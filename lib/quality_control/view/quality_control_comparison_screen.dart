// lib/quality_control/view/quality_control_comparison_screen.dart
//
// Contrôle Qualité — « Comparaison qualité » (/quality-control/comparison) :
// période A vs période B, pilotée par les DONNÉES. Tout ce qui est affiché
// (12 KPI, variations, classement des machines, évolution des paramètres,
// points d'attention, améliorations, Matin / Soir, phrases d'analyse) vient de
// GET /quality-control/comparison, calculé par PostgreSQL ; Flutter ne
// recalcule rien et n'affiche aucune valeur par défaut. La page s'adapte :
// - période vide → message, aucune variation ;
// - une seule ligne → ses paramètres uniquement ; toutes les lignes → KPI
//   communs + blocs PROMESH / PROBAR séparés ;
// - une machine → son évolution ; plusieurs → classement.
// Elle se recalcule à chaque écriture du module (création, modification,
// validation) : aucun chiffre gardé en cache.
//
// Couleurs : période A = violet, période B = cyan (paire validée : contraste,
// daltonisme) — distinctes des lignes (PROMESH bleu / PROBAR orange) et des
// statuts (vert / rouge / ambre).

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as fm show Text;
import 'package:go_router/go_router.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';
import '../model/quality_control_comparison.dart';
import '../model/quality_control_model.dart';
import '../quality_control_routes.dart';
import '../service/quality_control_service.dart';
import 'quality_control_export.dart';
import 'quality_control_widgets.dart';
import '../quality_control_i18n.dart';

const Color kQcPeriodA = Color(0xFF7C3AED);
const Color kQcPeriodB = Color(0xFF0891B2);

String _iso(DateTime d) => qcIsoFromDate(d);
String _display(DateTime d) => qcIsoDateToDisplay(_iso(d));
String _pct(double? v) => qcFormatKpi(QcKpiKind.rate, v);

class QualityControlComparisonScreen extends StatefulWidget {
  const QualityControlComparisonScreen({super.key});

  @override
  State<QualityControlComparisonScreen> createState() => _QualityControlComparisonScreenState();
}

class _QualityControlComparisonScreenState extends State<QualityControlComparisonScreen> {
  final _svc = QualityControlService.instance;

  // Par défaut : A = mois précédent, B = mois en cours.
  String _presetA = 'prevMonth';
  String _presetB = 'month';
  late DateTime _aStart;
  late DateTime _aEnd;
  late DateTime _bStart;
  late DateTime _bEnd;
  String _type = ''; // '' = toutes les lignes
  String? _machine;
  String? _poste;
  String? _controller;
  String? _resultFilter;
  QualityConfig _config = const QualityConfig();

  bool _loading = false;
  bool _exporting = false;
  String? _error;
  QualityComparison? _result;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final a = qcPeriodRange(_presetA, now)!;
    _aStart = a.$1;
    _aEnd = a.$2;
    final b = qcPeriodRange(_presetB, now)!;
    _bStart = b.$1;
    _bEnd = b.$2;
    _svc.fetchConfig().then((c) {
      if (mounted) setState(() => _config = c);
    }).catchError((_) {});
    // Contrôle créé / modifié / validé ailleurs dans le module : recalcul.
    _svc.revision.addListener(_onRevision);
    _compare();
  }

  @override
  void dispose() {
    _svc.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted && !_loading) _compare();
  }

  Map<String, String> get _query => {
        'periodAStart': _iso(_aStart),
        'periodAEnd': _iso(_aEnd),
        'periodBStart': _iso(_bStart),
        'periodBEnd': _iso(_bEnd),
        if (_type.isNotEmpty) 'productionType': _type,
        if (_machine != null) 'machine': _machine!,
        if (_poste != null) 'poste': _poste!,
        if (_controller != null) 'controller': _controller!,
        if (_resultFilter != null) 'result': _resultFilter!,
      };

  String? get _rangeError {
    if (_aStart.isAfter(_aEnd)) return 'Période A : la date de début doit précéder la date de fin.';
    if (_bStart.isAfter(_bEnd)) return 'Période B : la date de début doit précéder la date de fin.';
    return null;
  }

  Future<void> _compare() async {
    final rangeError = _rangeError;
    if (rangeError != null) {
      setState(() => _error = rangeError);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _svc.fetchComparison(_query);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    final q = _query;
    await runQcExport(
      context,
      format: format,
      fetch: () => _svc.exportComparison(format, q),
      fileName: qcComparisonExportFileName(q['periodAStart']!, q['periodBEnd']!, format),
    );
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _pick(DateTime current, ValueChanged<DateTime> onPicked, String help) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      helpText: qcT(help),
      cancelText: qcT('Annuler'),
      confirmText: qcT('Valider'),
    );
    if (picked != null && mounted) setState(() => onPicked(picked));
  }

  /// Machines proposées : celles de la ligne choisie (configuration).
  List<String> get _machines {
    final lines = _type.isEmpty ? _config.productionLines : [if (_config.line(_type) != null) _config.line(_type)!];
    final set = {for (final l in lines) ...l.machines}.toList()..sort();
    return set.isEmpty ? const ['1', '2', '3', '4'] : set;
  }

  @override
  Widget build(BuildContext context) {
    QcI18n.watch(context); // reconstruit au changement de langue
    final r = _result;
    return QcPage(
      onRefresh: _compare,
      children: [
        QcPageHeader(
          crumbs: const [('Contrôle Qualité', QcPaths.root), ('Comparaison qualité', null)],
          title: 'Comparaison qualité',
          subtitle: 'Analysez l\'évolution de la qualité entre deux périodes.',
          icon: Icons.compare_arrows_rounded,
          onBack: () => context.go(QcPaths.history),
          actions: [
            QcExportButton(
              label: 'Exporter la comparaison',
              formats: const ['xlsx', 'pdf'],
              busy: _exporting,
              enabled: r != null && _rangeError == null,
              onSelected: _export,
            ),
          ],
        ),
        _filters(),
        if (_error != null) QcErrorBanner(_error!, onRetry: _compare),
        if (_loading && r == null) const QcSkeletonRows(rows: 6, height: 48),
        if (r != null) ..._results(r),
      ],
    );
  }

  /// Sections affichées selon les données réellement disponibles.
  List<Widget> _results(QualityComparison r) {
    final messages = [for (final m in r.messages) _message(m)];
    // Aucune donnée : rien à comparer, rien n'est affiché à la place.
    if (r.isEmpty) return [...messages, _analysisSection(r)];
    // Une seule période alimentée : ses chiffres, aucune comparaison.
    if (!r.comparable) return [...messages, _kpiSection(r), _analysisSection(r)];
    return [
      ...messages,
      _kpiSection(r),
      _pair(_resultsChart(r), _conformitySection(r), flexA: 3, flexB: 2),
      _dailySection(r),
      if (r.byType.length > 1) _lineSection(r),
      _machineSection(r),
      _parametersSection(r),
      _pair(_movesSection(r.improvements, improving: true), _movesSection(r.attentionPoints, improving: false)),
      if (r.byShift.isNotEmpty && r.posteFilter == null) _shiftSection(r),
      _analysisSection(r),
    ];
  }

  Widget _pair(Widget a, Widget b, {int flexA = 1, int flexB = 1}) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 980) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, b]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: flexA, child: a),
          const SizedBox(width: 16),
          Expanded(flex: flexB, child: b),
        ]);
      });

  Widget _message(String text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kQcAVerifierText.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(kQcRadius),
          border: Border.all(color: kQcAVerifierText.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 20, color: kQcAVerifierText),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w700, color: kQcAVerifierText))),
        ]),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, style: tInter(fontSize: 11.5, color: kCrmTextSub)),
      );

  // ── Périodes + filtres ─────────────────────────────────────────────────

  Widget _dropdown<T>({
    required String id,
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T?> onChanged,
    IconData? icon,
    double? width = 190,
  }) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: kCrmBorder));
    final field = DropdownButtonFormField<T>(
      key: ValueKey('qc-cmp-$id-$value-${items.length}'),
      initialValue: value,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: kCrmSurface,
        prefixIcon: icon == null ? null : Icon(icon, size: 18),
        border: border,
        enabledBorder: border,
      ),
      items: [for (final (v, label) in items) DropdownMenuItem<T>(value: v, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis))],
      onChanged: onChanged,
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }

  Widget _periodCard(String label, Color color, String id, String preset, DateTime start, DateTime end, void Function(String preset, DateTime start, DateTime end) apply) {
    Widget field(String title, DateTime value, ValueChanged<DateTime> onPicked) => Expanded(
          child: InkWell(
            onTap: () => _pick(value, onPicked, '$label — $title'),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: kCrmSurface, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10.5, fontWeight: FontWeight.w600, color: kCrmTextSub)),
                    Text(_display(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmText)),
                  ]),
                ),
              ]),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(kQcRadius),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: tInter(fontSize: 12, fontWeight: FontWeight.w800, color: kCrmText, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 10),
        // Raccourcis : la période est calculée à partir de la date du jour.
        _dropdown<String>(
          id: 'preset-$id',
          value: preset,
          width: null,
          icon: Icons.event_repeat_rounded,
          items: kQcPeriodPresets,
          onChanged: (v) {
            if (v == null) return;
            final range = qcPeriodRange(v, DateTime.now());
            setState(() => apply(v, range?.$1 ?? start, range?.$2 ?? end));
          },
        ),
        const SizedBox(height: 8),
        // Une date choisie à la main : période « Personnalisé ».
        Row(children: [
          field('Date début', start, (d) => apply('custom', d, end)),
          const SizedBox(width: 8),
          field('Date fin', end, (d) => apply('custom', start, d)),
        ]),
      ]),
    );
  }

  Widget _filters() {
    final controllers = _result?.controllers ?? const <QcControllerOption>[];
    final controller = controllers.any((c) => c.id == _controller) ? _controller : null;
    final machines = _machines;
    return QcSection(
      icon: Icons.tune_rounded,
      title: 'Périodes et filtres',
      subtitle: 'Les filtres s\'appliquent aux deux périodes',
      children: [
        LayoutBuilder(builder: (context, c) {
          final a = _periodCard('Période A', kQcPeriodA, 'a', _presetA, _aStart, _aEnd, (p, s, e) {
            _presetA = p;
            _aStart = s;
            _aEnd = e;
          });
          final b = _periodCard('Période B', kQcPeriodB, 'b', _presetB, _bStart, _bEnd, (p, s, e) {
            _presetB = p;
            _bStart = s;
            _bEnd = e;
          });
          if (c.maxWidth < 760) return Column(children: [a, const SizedBox(height: 10), b]);
          return Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]);
        }),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _segmented(
            value: _type,
            options: [('', 'Toutes'), for (final l in _config.productionLines) (l.type, l.label)],
            colorOf: (v) => v.isEmpty ? kCrmText : productionTypeColor(v),
            // La machine dépend de la ligne : remise à « Toutes » si elle
            // n'existe pas sur la ligne choisie.
            onChanged: (v) => setState(() {
              _type = v;
              if (_machine != null && !_machines.contains(_machine)) _machine = null;
            }),
          ),
          _dropdown<String?>(
            id: 'machine-$_type',
            value: machines.contains(_machine) ? _machine : null,
            icon: kMachineIcon,
            items: [(null, 'Toutes machines'), for (final m in machines) (m, 'Machine $m')],
            onChanged: (v) => setState(() => _machine = v),
          ),
          _dropdown<String?>(
            id: 'poste',
            value: _poste,
            icon: Icons.schedule_rounded,
            items: const [(null, 'Tous les postes'), ('matin', 'Matin'), ('soir', 'Soir')],
            onChanged: (v) => setState(() => _poste = v),
          ),
          // Contrôleurs ayant réellement des contrôles (liste de l'API).
          _dropdown<String?>(
            id: 'controller',
            value: controller,
            width: 220,
            icon: Icons.person_outline_rounded,
            items: [(null, 'Tous les contrôleurs'), for (final c in controllers) (c.id, c.label)],
            onChanged: (v) => setState(() => _controller = v),
          ),
          // « À vérifier » et « Brouillon » : même état (fiche non validée).
          _dropdown<String?>(
            id: 'result',
            value: _resultFilter,
            width: 220,
            icon: Icons.fact_check_outlined,
            items: const [(null, 'Tous les résultats'), ('CONFORME', 'Conforme'), ('NON_CONFORME', 'Non conforme'), ('A_VERIFIER', 'À vérifier (brouillon)')],
            onChanged: (v) => setState(() => _resultFilter = v),
          ),
          FilledButton.icon(
            onPressed: _loading ? null : _compare,
            style: FilledButton.styleFrom(backgroundColor: kQualityControlColor),
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.compare_arrows_rounded, size: 18),
            label: const Text('Comparer'),
          ),
        ]),
      ],
    );
  }

  Widget _segmented<T>({required T value, required List<(T, String)> options, required Color Function(T v) colorOf, required ValueChanged<T> onChanged}) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(9), border: Border.all(color: kCrmBorder)),
      child: Wrap(children: [
        for (final (v, label) in options)
          InkWell(
            onTap: () => onChanged(v),
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: v == value ? kCrmSurface : Colors.transparent, borderRadius: BorderRadius.circular(7)),
              child: Text(label,
                  style: tInter(fontSize: 12, fontWeight: v == value ? FontWeight.w700 : FontWeight.w500, color: v == value ? colorOf(v) : kCrmTextSub)),
            ),
          ),
      ]),
    );
  }

  // ── KPI : période A, période B, variation ──────────────────────────────

  Color _trendColor(QcTrend trend, int? sign) {
    if (sign == null || sign == 0 || trend == QcTrend.neutral) return kCrmTextSub;
    final good = trend == QcTrend.higherIsBetter ? sign > 0 : sign < 0;
    return good ? kQcConformeText : kQcNonConformeText;
  }

  Widget _badge(String text, Color color, int? sign) {
    final icon = sign == null || sign == 0 ? Icons.remove_rounded : (sign > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
      ]),
    );
  }

  Widget _evolutionBadge(QcKpiDef def, QcEvolution? e, {bool longPoints = false}) {
    final sign = qcEvolutionSign(def.kind, e);
    return _badge(qcFormatEvolution(def.kind, e, longPoints: longPoints), _trendColor(def.trend, sign), sign);
  }

  /// Écart en points d'un taux de conformité (une hausse est favorable).
  Widget _pointsBadge(double? points, {bool long = false}) {
    final sign = points == null ? null : (points > 0 ? 1 : (points < 0 ? -1 : 0));
    return _badge(qcFormatPoints(points, long: long), _trendColor(QcTrend.higherIsBetter, sign), sign);
  }

  Widget _periodValue(Color color, String letter, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
          child: fm.Text(letter, style: tInter(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 17, fontWeight: FontWeight.w800, color: kCrmText))),
      ]);

  Widget _kpiSection(QualityComparison r) {
    String periodText(QcKpis k) => k.start == null ? '' : '${qcIsoDateToDisplay(k.start)} → ${qcIsoDateToDisplay(k.end)}';
    Widget card(QcKpiDef def) => Container(
          padding: const EdgeInsets.all(12),
          decoration: qcCardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(def.label.toUpperCase(),
                maxLines: 2, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 10.5, fontWeight: FontWeight.w700, color: kCrmTextSub, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 14, runSpacing: 6, children: [
              _periodValue(kQcPeriodA, 'A', qcFormatKpi(def.kind, r.a.value(def.key))),
              _periodValue(kQcPeriodB, 'B', qcFormatKpi(def.kind, r.b.value(def.key))),
            ]),
            const SizedBox(height: 8),
            // Variation uniquement quand les deux périodes ont des données.
            if (r.comparable)
              _evolutionBadge(def, r.evolution[def.key], longPoints: true)
            else
              Text('Variation non calculée', style: tInter(fontSize: 11.5, color: kCrmTextSub)),
          ]),
        );
    return QcSection(
      icon: Icons.insights_rounded,
      title: 'Indicateurs',
      subtitle: 'A : ${periodText(r.a)}   ·   B : ${periodText(r.b)}',
      children: [
        qcGrid(columns: qcColumnsFor(250, max: 4), [for (final def in kQcComparisonKpis) card(def)]),
        _note('Taux calculés sur les contrôles qualité validés (brouillons = « À vérifier ») ; évolution des taux en points.'),
      ],
    );
  }

  // ── Graphiques ─────────────────────────────────────────────────────────

  Widget _legend() => Wrap(spacing: 14, children: [
        for (final (label, color) in [('Période A', kQcPeriodA), ('Période B', kQcPeriodB)])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(label, style: tInter(fontSize: 12, color: kCrmText)),
          ]),
      ]);

  /// Barres groupées A / B ; valeurs affichées au-dessus de chaque barre.
  Widget _groupedBars(List<(String, double, double)> groups) {
    final top = (groups.expand((g) => [g.$2, g.$3]).fold<double>(0, (m, v) => v > m ? v : m) * 1.25).clamp(1, double.infinity).toDouble();
    return SizedBox(
      height: 230,
      child: BarChart(
        BarChartData(
          maxY: top,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: kCrmBorder, strokeWidth: 0.6),
          ),
          borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: kCrmBorder))),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(groups[v.toInt()].$1, style: tInter(fontSize: 11.5, color: kCrmTextSub)),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: false,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 2,
              getTooltipItem: (group, gi, rod, ri) =>
                  BarTooltipItem(rod.toY.toInt().toString(), tInter(fontSize: 11, fontWeight: FontWeight.w800, color: kCrmText)),
            ),
          ),
          barGroups: [
            for (var i = 0; i < groups.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 2,
                showingTooltipIndicators: const [0, 1],
                barRods: [
                  BarChartRodData(toY: groups[i].$2, color: kQcPeriodA, width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                  BarChartRodData(toY: groups[i].$3, color: kQcPeriodB, width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultsChart(QualityComparison r) => QcSection(
        icon: Icons.bar_chart_rounded,
        title: 'Résultats : période A vs période B',
        trailing: _legend(),
        children: [
          _groupedBars([
            ('Conformes', r.a.conformes.toDouble(), r.b.conformes.toDouble()),
            ('Non conformes', r.a.nonConformes.toDouble(), r.b.nonConformes.toDouble()),
            ('À vérifier', r.a.aVerifier.toDouble(), r.b.aVerifier.toDouble()),
          ]),
        ],
      );

  /// Barre 0 → 100 % d'un taux (non tracée quand le taux n'est pas calculable).
  Widget _rateBar(String label, double? rate, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmText))),
            Text(_pct(rate), style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: ((rate ?? 0) / 100).clamp(0, 1).toDouble(), minHeight: 14, backgroundColor: kCrmBorder, color: color),
          ),
        ]),
      );

  Widget _conformitySection(QualityComparison r) {
    final a = r.a.tauxConformite;
    final b = r.b.tauxConformite;
    return QcSection(
      icon: Icons.percent_rounded,
      title: 'Taux de conformité',
      subtitle: 'Contrôles qualité validés',
      children: [
        if (a == null && b == null)
          const QcEmptyState('Aucun contrôle qualité validé sur ces périodes — taux N/A', icon: Icons.percent_rounded)
        else ...[
          _rateBar('Période A', a, kQcPeriodA),
          _rateBar('Période B', b, kQcPeriodB),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Variation', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText)),
            _pointsBadge(r.evolution['tauxConformite']?.points, long: true),
          ]),
        ],
      ],
    );
  }

  /// Taux de conformité par jour : les deux périodes superposées sur le rang
  /// du jour (J1 = premier jour de la période). Un point par jour ayant des
  /// contrôles validés — rien n'est interpolé pour les jours sans donnée.
  Widget _dailySection(QualityComparison r) {
    DateTime day(String iso) => DateTime.parse('${iso}T00:00:00Z');
    List<(FlSpot, QcDailyPoint)> points(List<QcDailyPoint> rows, String? start) => [
          if (start != null)
            for (final p in rows)
              if (p.tauxConformite != null) (FlSpot(day(p.date).difference(day(start)).inDays.toDouble(), p.tauxConformite!), p),
        ];
    final a = points(r.dailyA, r.a.start);
    final b = points(r.dailyB, r.b.start);
    final maxX = [...a, ...b].fold<double>(1, (m, p) => p.$1.x > m ? p.$1.x : m);
    final interval = (maxX / 6).ceilToDouble().clamp(1, double.infinity).toDouble();
    LineChartBarData line(List<(FlSpot, QcDailyPoint)> pts, Color color) => LineChartBarData(
          spots: [for (final p in pts) p.$1],
          color: color,
          barWidth: 2,
          isCurved: false,
          dotData: FlDotData(getDotPainter: (s, p, bar, i) => FlDotCirclePainter(radius: 4, color: color, strokeWidth: 2, strokeColor: kCrmSurface)),
        );
    final series = [a, b];
    return QcSection(
      icon: Icons.show_chart_rounded,
      title: 'Évolution du taux de conformité',
      subtitle: 'Par jour de la période (J1 = premier jour) · contrôles qualité validés',
      trailing: _legend(),
      children: [
        if (a.isEmpty && b.isEmpty)
          const QcEmptyState('Aucun contrôle qualité validé sur ces périodes — taux N/A', icon: Icons.show_chart_rounded)
        else
          SizedBox(
            height: 240,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 14),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: 0,
                  maxY: 100,
                  clipData: const FlClipData.none(),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (_) => const FlLine(color: kCrmBorder, strokeWidth: 0.6),
                  ),
                  borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: kCrmBorder))),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: 50,
                        getTitlesWidget: (v, meta) => fm.Text('${v.toInt()} %', style: tInter(fontSize: 10.5, color: kCrmTextSub)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: interval,
                        getTitlesWidget: (v, meta) => v != v.roundToDouble()
                            ? const SizedBox.shrink()
                            : Padding(padding: const EdgeInsets.only(top: 6), child: fm.Text('J${v.toInt() + 1}', style: tInter(fontSize: 10.5, color: kCrmTextSub))),
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => kCrmText,
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            '${s.barIndex == 0 ? 'A' : 'B'} · ${qcIsoDateToDisplay(series[s.barIndex][s.spotIndex].$2.date)} · ${_pct(s.y)}',
                            tInter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [line(a, kQcPeriodA), line(b, kQcPeriodB)],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Tableaux / cartes de comparaison ───────────────────────────────────

  Widget _table(List<(String, int)> columns, List<List<Widget>> rows, {double minWidth = 760}) {
    Widget cell(int flex, Widget child, {bool first = false}) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Align(alignment: first ? Alignment.centerLeft : Alignment.center, child: child),
          ),
        );
    return LayoutBuilder(builder: (context, c) {
      final table = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: kCrmBg, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            for (var i = 0; i < columns.length; i++)
              cell(
                columns[i].$2,
                Text(columns[i].$1.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tInter(fontSize: 10.5, fontWeight: FontWeight.w700, color: kCrmTextSub, letterSpacing: 0.5)),
                first: i == 0,
              ),
          ]),
        ),
        for (final row in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
            child: Row(children: [for (var i = 0; i < columns.length; i++) cell(columns[i].$2, row[i], first: i == 0)]),
          ),
      ]);
      if (c.maxWidth >= minWidth) return table;
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: minWidth, child: table));
    });
  }

  Text _num(String text, {Color color = kCrmText}) => Text(text, style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: color));

  /// Carte « indicateur · A · B · variation » d'une ligne ou d'un poste.
  Widget _compareCard(QcComparisonRow row, {required Color color, required IconData icon, required List<QcKpiDef> defs}) => Container(
        decoration: qcCardDecoration(border: color.withValues(alpha: 0.35)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 3, color: color),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Colonnes proportionnelles (aucune largeur fixe) : indicateur,
              // A, B, variation — lisible de la tablette au desktop.
              Row(children: [
                Expanded(
                  flex: 4,
                  child: Row(children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Flexible(child: Text(row.label, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 15, fontWeight: FontWeight.w800, color: color))),
                  ]),
                ),
                Expanded(flex: 2, child: fm.Text('A', textAlign: TextAlign.center, style: tInter(fontSize: 11, fontWeight: FontWeight.w800, color: kQcPeriodA))),
                Expanded(flex: 2, child: fm.Text('B', textAlign: TextAlign.center, style: tInter(fontSize: 11, fontWeight: FontWeight.w800, color: kQcPeriodB))),
                const Expanded(flex: 4, child: SizedBox()),
              ]),
              const SizedBox(height: 6),
              for (final d in defs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(flex: 4, child: Text(d.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, color: kCrmTextSub))),
                    Expanded(flex: 2, child: Center(child: _num(qcFormatKpi(d.kind, row.a.value(d.key))))),
                    Expanded(flex: 2, child: Center(child: _num(qcFormatKpi(d.kind, row.b.value(d.key))))),
                    Expanded(flex: 4, child: Align(alignment: Alignment.centerRight, child: _evolutionBadge(d, row.evolution[d.key]))),
                  ]),
                ),
            ]),
          ),
        ]),
      );

  /// Toutes les lignes : un bloc par ligne, limité aux indicateurs COMMUNS.
  Widget _lineSection(QualityComparison r) {
    final defs = [for (final d in kQcComparisonKpis) if (kQcCommonKpiKeys.contains(d.key)) d];
    return QcSection(
      icon: Icons.view_agenda_outlined,
      title: 'PROMESH / PROBAR',
      subtitle: 'Indicateurs communs aux deux lignes',
      children: [
        qcGrid(columns: qcColumnsFor(380, max: 2), [
          for (final l in r.byType) _compareCard(l, color: productionTypeColor(l.type), icon: productionTypeIcon(l.type), defs: defs),
        ]),
        _note('Les paramètres propres à une ligne (treillis GFRP, barre…) ne sont jamais comparés entre PROMESH et PROBAR.'),
      ],
    );
  }

  // ── Machines : classement (plusieurs) ou évolution (une seule) ──────────

  Widget _rankRow(int rank, QcRankedMachine m, {required bool best, required bool worst}) {
    final color = best ? kQcConformeText : (worst ? kQcNonConformeText : kCrmTextSub);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(width: 24, child: fm.Text('$rank', style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: kCrmTextSub))),
          Flexible(child: QcLineChip(m.type, dense: true)),
          const SizedBox(width: 8),
          Expanded(child: Text('Machine ${m.machine}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: kCrmText))),
          Text(_pct(m.tauxConformite), style: tInter(fontSize: 14, fontWeight: FontWeight.w800, color: kCrmText)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(value: (m.tauxConformite / 100).clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: kCrmBorder, color: color),
        ),
        if (best || worst)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(children: [
              Icon(best ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(best ? 'Meilleure performance' : 'Performance à surveiller',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _machineSection(QualityComparison r) {
    const totalDef = QcKpiDef('total', 'Contrôles qualité', QcKpiKind.count, QcTrend.neutral);
    final ranking = r.ranking;
    final single = r.machineFilter != null;
    final table = _table(
      const [('Machine', 4), ('Période A', 2), ('Période B', 2), ('Évolution', 3), ('Taux A', 2), ('Taux B', 2), ('Évolution du taux', 3)],
      [
        for (final m in r.byMachine)
          [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: QcLineChip(m.type, dense: true)),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Machine ${m.machine}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: kCrmText)),
              ),
            ]),
            _num('${m.a.total}'),
            _num('${m.b.total}'),
            _evolutionBadge(totalDef, m.evolution['total']),
            _num(_pct(m.a.tauxConformite)),
            _num(_pct(m.b.tauxConformite)),
            _pointsBadge(m.evolution['tauxConformite']?.points),
          ],
      ],
      minWidth: 860,
    );
    return QcSection(
      icon: kMachineIcon,
      title: ranking != null ? 'Classement des machines' : (single ? 'Évolution de la machine' : 'Comparaison par machine'),
      subtitle: ranking != null ? 'Taux de conformité sur la période B (contrôles qualité validés)' : null,
      children: [
        if (r.byMachine.isEmpty)
          const QcEmptyState('Aucune machine pour ces filtres')
        else ...[
          if (ranking != null) ...[
            for (var i = 0; i < ranking.length; i++) _rankRow(i + 1, ranking[i], best: i == 0, worst: i == ranking.length - 1),
            const SizedBox(height: 12),
          ],
          table,
          if (ranking == null && !single) _note('Classement non établi : moins de deux machines ont des contrôles qualité validés sur la période B.'),
        ],
      ],
    );
  }

  // ── Paramètres ─────────────────────────────────────────────────────────

  Widget _limitedTag() => Container(
        margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: kQcAVerifierText.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(4)),
        child: Text('Données limitées', style: tInter(fontSize: 10, fontWeight: FontWeight.w700, color: kQcAVerifierText)),
      );

  /// Conformité de chaque paramètre réellement contrôlé — un bloc par ligne :
  /// jamais un paramètre d'une ligne dans le bloc de l'autre.
  Widget _parametersSection(QualityComparison r) {
    final types = <String>{for (final p in r.parameters) if (p.type.isNotEmpty) p.type}.toList();
    Widget block(String type) {
      final rows = r.parameters.where((p) => p.type == type).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (types.length > 1) Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Align(alignment: Alignment.centerLeft, child: QcLineChip(type))),
        _table(
          const [('Paramètre', 6), ('Période A', 2), ('Période B', 2), ('Évolution', 3)],
          [
            for (final p in rows)
              [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 12.5, fontWeight: FontWeight.w700, color: kCrmText)),
                  Text(p.group == 'treillis' ? 'Treillis GFRP · ${p.sectionLabel}' : p.sectionLabel,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 11, color: kCrmTextSub)),
                ]),
                _num(_pct(p.tauxA)),
                _num(_pct(p.tauxB)),
                Column(mainAxisSize: MainAxisSize.min, children: [_pointsBadge(p.evolutionPoints), if (p.limited) _limitedTag()]),
              ],
          ],
          minWidth: 560,
        ),
      ]);
    }

    return QcSection(
      icon: Icons.tune_rounded,
      title: 'Évolution des paramètres',
      subtitle: 'Taux de conformité des paramètres contrôlés sur ces périodes',
      children: [
        if (r.parameters.isEmpty)
          const QcEmptyState('Aucun paramètre contrôlé sur ces périodes', icon: Icons.tune_rounded)
        else
          for (final type in types) block(type),
      ],
    );
  }

  /// Améliorations (conformité en hausse) ou points d'attention (en baisse) :
  /// uniquement les paramètres dont l'écart est calculé par le backend.
  Widget _movesSection(List<QcParameterEvolution> rows, {required bool improving}) {
    final color = improving ? kQcConformeText : kQcNonConformeText;
    final multi = rows.map((p) => p.type).toSet().length > 1;
    return QcSection(
      icon: improving ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
      title: improving ? 'Améliorations' : 'Points d\'attention',
      subtitle: improving ? 'Paramètres dont la conformité augmente' : 'Paramètres dont la conformité diminue',
      color: color,
      children: [
        if (rows.isEmpty)
          QcEmptyState(improving ? 'Aucune amélioration détectée sur ces données' : 'Aucun point d\'attention détecté sur ces données',
              icon: improving ? Icons.trending_flat_rounded : Icons.check_circle_outline_rounded)
        else
          for (final p in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kCrmBorder))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(improving ? Icons.check_rounded : Icons.warning_amber_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: kCrmText)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      if (multi) QcLineChip(p.type, dense: true),
                      fm.Text('${_pct(p.tauxA)} → ${_pct(p.tauxB)}', style: tInter(fontSize: 12.5, fontWeight: FontWeight.w600, color: kCrmTextSub)),
                      _pointsBadge(p.evolutionPoints, long: true),
                      if (p.limited) _limitedTag(),
                    ]),
                  ]),
                ),
              ]),
            ),
      ],
    );
  }

  // ── Matin / Soir ───────────────────────────────────────────────────────

  Widget _shiftSection(QualityComparison r) {
    const defs = [
      QcKpiDef('total', 'Contrôles qualité', QcKpiKind.count, QcTrend.neutral),
      QcKpiDef('tauxConformite', 'Taux de conformité', QcKpiKind.rate, QcTrend.higherIsBetter),
      QcKpiDef('tauxNonConformite', 'Taux de non-conformité', QcKpiKind.rate, QcTrend.lowerIsBetter),
    ];
    return QcSection(
      icon: Icons.schedule_rounded,
      title: 'Matin / Soir',
      subtitle: 'Comparaison par poste',
      children: [
        qcGrid(columns: qcColumnsFor(380, max: 2), [
          for (final s in r.byShift)
            _compareCard(s, color: kQualityControlColor, icon: s.poste == 'soir' ? Icons.nights_stay_outlined : Icons.wb_sunny_outlined, defs: defs),
        ]),
        const SizedBox(height: 10),
        if (r.shiftInsight != null)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lightbulb_outline_rounded, size: 18, color: kQualityControlColor),
            const SizedBox(width: 8),
            Expanded(child: Text(r.shiftInsight!, style: tInter(fontSize: 13, fontWeight: FontWeight.w600, color: kCrmText))),
          ])
        else
          _note('Aucun écart calculable entre les postes sur la période B : moins de deux contrôles qualité validés par poste, ou écart inférieur à 1 point.'),
      ],
    );
  }

  // ── Analyse ────────────────────────────────────────────────────────────

  /// Phrases construites par le backend à partir des chiffres ci-dessus —
  /// aucune explication n'est ajoutée quand les données ne l'établissent pas.
  Widget _analysisSection(QualityComparison r) => QcSection(
        icon: Icons.auto_graph_rounded,
        title: 'Analyse',
        subtitle: 'Synthèse calculée à partir des données sélectionnées',
        children: [
          if (r.analysis.isEmpty)
            const QcEmptyState('Pas suffisamment de données pour cette analyse', icon: Icons.auto_graph_rounded)
          else
            for (final line in r.analysis)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: kQualityControlColor)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(line, style: tInter(fontSize: 13.5, fontWeight: FontWeight.w500, color: kCrmText).copyWith(height: 1.4))),
                ]),
              ),
        ],
      );
}
