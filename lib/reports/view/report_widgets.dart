// lib/reports/view/report_widgets.dart
//
// Widgets génériques du "Rapport de pilotage" : sections, cartes KPI,
// tableaux, barres horizontales et courbes (fl_chart).

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

typedef Tr = String Function(String key);

const Color kRpBlue = Color(0xFF1E3A8A);
const Color kRpAccent = Color(0xFF3B82F6);
const Color kRpGreen = Color(0xFF10B981);
const Color kRpRed = Color(0xFFEF4444);
const Color kRpAmber = Color(0xFFF59E0B);
const Color kRpGrey = Color(0xFF64748B);

String fmtNum(dynamic v, {int decimals = 2}) {
  if (v == null) return '';
  final n = v is num ? v : num.tryParse(v.toString());
  if (n == null) return v.toString();
  final isInt = n == n.roundToDouble();
  return NumberFormat(isInt ? '#,##0' : '#,##0.${'#' * decimals}').format(n);
}

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

String fmtDate(dynamic v) {
  final d = parseDate(v);
  return d == null ? '' : DateFormat('dd/MM/yyyy').format(d);
}

String fmtDateTime(dynamic v) {
  final d = parseDate(v);
  return d == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(d);
}

class RpCol {
  final String header;
  final String Function(Map<String, dynamic> row) value;
  final bool numeric;
  const RpCol(this.header, this.value, {this.numeric = false});
}

class ReportSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;

  const ReportSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kRpBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: kRpAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle != null)
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final double? variationPct;
  final String? previousLabel;

  const KpiCard({super.key, required this.label, required this.value, this.variationPct, this.previousLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = variationPct;
    final color = v == null ? kRpGrey : (v > 0 ? kRpGreen : (v < 0 ? kRpRed : kRpGrey));
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (v != null)
            Row(children: [
              Icon(v > 0 ? Icons.arrow_upward_rounded : (v < 0 ? Icons.arrow_downward_rounded : Icons.remove_rounded),
                  size: 14, color: color),
              const SizedBox(width: 2),
              Text('${v > 0 ? '+' : ''}${fmtNum(v, decimals: 1)} %',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
              if (previousLabel != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(previousLabel!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                ),
            ])
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class RpBadge extends StatelessWidget {
  final String text;
  final Color color;
  const RpBadge(this.text, {super.key, this.color = kRpAccent});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class RpNote extends StatelessWidget {
  final String text;
  final IconData icon;
  const RpNote(this.text, {super.key, this.icon = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
      ]),
    );
  }
}

class RpEmpty extends StatelessWidget {
  final String text;
  const RpEmpty(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class RpTable extends StatefulWidget {
  final List<RpCol> columns;
  final List<Map<String, dynamic>> rows;
  final String emptyText;
  final String showMoreText;
  final int initialRows;
  final void Function(Map<String, dynamic> row)? onRowTap;

  const RpTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.emptyText,
    required this.showMoreText,
    this.initialRows = 15,
    this.onRowTap,
  });

  @override
  State<RpTable> createState() => _RpTableState();
}

class _RpTableState extends State<RpTable> {
  bool _all = false;
  final _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return RpEmpty(widget.emptyText);
    final shown = _all ? widget.rows : widget.rows.take(widget.initialRows).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Scrollbar(
          controller: _hScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 22,
              headingRowHeight: 40,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 48,
              showCheckboxColumn: false,
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              dataTextStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
              columns: [
                for (final c in widget.columns) DataColumn(label: Text(c.header), numeric: c.numeric),
              ],
              rows: [
                for (final r in shown)
                  DataRow(
                    onSelectChanged: widget.onRowTap == null ? null : (_) => widget.onRowTap!(r),
                    cells: [
                      for (final c in widget.columns)
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(c.value(r), overflow: TextOverflow.ellipsis),
                        )),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (!_all && widget.rows.length > widget.initialRows)
          TextButton.icon(
            onPressed: () => setState(() => _all = true),
            icon: const Icon(Icons.expand_more_rounded),
            label: Text('${widget.showMoreText} (${widget.rows.length})'),
          ),
      ],
    );
  }
}

class ChartItem {
  final String label;
  final double value;
  const ChartItem(this.label, this.value);
}

class HBarChart extends StatelessWidget {
  final String title;
  final List<ChartItem> items;
  final Color color;
  final String emptyText;
  final int maxItems;

  const HBarChart({
    super.key,
    required this.title,
    required this.items,
    required this.emptyText,
    this.color = kRpAccent,
    this.maxItems = 12,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = items.where((e) => e.value > 0).take(maxItems).toList();
    final maxV = data.isEmpty ? 1.0 : data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Container(
      width: 420,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (data.isEmpty)
            RpEmpty(emptyText)
          else
            for (final e in data)
              Tooltip(
                message: '${e.label}: ${fmtNum(e.value)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    SizedBox(
                      width: 130,
                      child: Text(e.label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child: LayoutBuilder(builder: (context, c) {
                        final w = c.maxWidth * (e.value / maxV);
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 12,
                            width: w < 3 ? 3 : w,
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                          ),
                        );
                      }),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(fmtNum(e.value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ),
        ],
      ),
    );
  }
}

class SeriesLine {
  final String name;
  final Color color;
  /// point index -> value ; null = pas de donnée (point non tracé)
  final List<double?> values;
  const SeriesLine(this.name, this.color, this.values);
}

class LineSeriesChart extends StatelessWidget {
  final String title;
  final List<String> labels;
  final List<SeriesLine> series;
  final String emptyText;

  const LineSeriesChart({
    super.key,
    required this.title,
    required this.labels,
    required this.series,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasData = labels.isNotEmpty && series.any((s) => s.values.any((v) => v != null));
    double maxY = 1;
    for (final s in series) {
      for (final v in s.values) {
        if (v != null && v > maxY) maxY = v;
      }
    }
    final step = (labels.length / 6).ceil().clamp(1, 1000);
    return Container(
      width: 640,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            for (final s in series) ...[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(s.name, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 10),
            ],
          ]),
          const SizedBox(height: 12),
          if (!hasData)
            RpEmpty(emptyText)
          else
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY * 1.1,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withOpacity(0.4), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        getTitlesWidget: (v, meta) => Text(fmtNum(v, decimals: 0), style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= labels.length || i % step != 0) return const SizedBox.shrink();
                          final d = DateTime.tryParse(labels[i]);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(d == null ? labels[i] : DateFormat('dd/MM').format(d), style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final i = s.x.toInt();
                        final d = i >= 0 && i < labels.length ? labels[i] : '';
                        return LineTooltipItem(
                          '$d\n${series[s.barIndex].name}: ${fmtNum(s.y)}',
                          TextStyle(color: series[s.barIndex].color, fontWeight: FontWeight.w600, fontSize: 11),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    for (final s in series)
                      LineChartBarData(
                        color: s.color,
                        barWidth: 2.5,
                        isCurved: false,
                        dotData: FlDotData(show: labels.length <= 40),
                        spots: [
                          for (var i = 0; i < s.values.length; i++)
                            if (s.values[i] != null) FlSpot(i.toDouble(), s.values[i]!),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
