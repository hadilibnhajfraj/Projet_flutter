// lib/production_compliance/view/production_request_statistics_screen.dart
//
// "Production — Statistiques des demandes" — combien de demandes chaque
// utilisateur de production a faites (autorisation de backfill,
// désarchivage) et leur issue, + archivages automatiques, courbe par
// période et historique complet. Tous les chiffres viennent du backend
// (GET /production-requests/statistics|history), calculés depuis la base à
// chaque chargement — rien n'est calculé ni figé ici.

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/reports/view/report_widgets.dart';
import '../service/production_requests_service.dart';
import 'production_compliance_dialogs.dart' show requestStatusColor;
import 'production_request_history_dialog.dart';

const _kTypeLabels = {
  'AUTHORIZATION': 'Autorisation',
  'UNARCHIVE': 'Désarchivage',
  'ARCHIVE': 'Archivage auto',
};

class ProductionRequestStatisticsScreen extends StatefulWidget {
  const ProductionRequestStatisticsScreen({super.key});

  @override
  State<ProductionRequestStatisticsScreen> createState() => _ProductionRequestStatisticsScreenState();
}

class _ProductionRequestStatisticsScreenState extends State<ProductionRequestStatisticsScreen> {
  final _svc = ProductionRequestsService.instance;
  final _df = DateFormat('yyyy-MM-dd');
  final _usersHScroll = ScrollController();
  final _historyHScroll = ScrollController();

  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  String? _production;
  String? _userId;
  String? _type;
  String? _status;
  String _granularity = 'day';

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _usersHScroll.dispose();
    _historyHScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _svc.fetchStatistics(
          from: _df.format(_from),
          to: _df.format(_to),
          production: _production,
          userId: _userId,
          type: _type,
          status: _status,
          granularity: _granularity,
        ),
        _svc.fetchHistory(
          from: _df.format(_from),
          to: _df.format(_to),
          production: _production,
          userId: _userId,
          type: _type,
          status: _status,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _history = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
      _to = DateTime.now();
      _production = null;
      _userId = null;
      _type = null;
      _status = null;
      _granularity = 'day';
    });
    _load();
  }

  List<Map<String, dynamic>> _opts(String key) => ((_stats['options'] as Map?)?[key] as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  int _kpi(String k) => ((_stats['kpis'] as Map?)?[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Production — Statistiques des demandes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Demandes d\'autorisation et de désarchivage par utilisateur de production — heure de Tunis',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          _filters(),
          const SizedBox(height: 16),
          if (_loading && _stats.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kRpRed.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: kRpRed),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!)),
                TextButton(onPressed: _load, child: const Text('Réessayer')),
              ]),
            )
          else ...[
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            _kpis(),
            const SizedBox(height: 20),
            _usersSection(),
            _chartsSection(),
            _historySection(),
          ],
        ]),
      ),
    );
  }

  // ── Filtres ───────────────────────────────────────────────────────────

  Widget _dateBox(String label, DateTime d, ValueChanged<DateTime> onPick) => SizedBox(
        width: 150,
        child: InkWell(
          onTap: () async {
            final p = await showDatePicker(context: context, initialDate: d, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (p != null) {
              onPick(p);
              _load();
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
            child: Text(DateFormat('dd/MM/yyyy').format(d)),
          ),
        ),
      );

  Widget _dropdown(String label, String? value, List<(String?, String)> items, ValueChanged<String?> onChanged, {double width = 170}) =>
      SizedBox(
        width: width,
        child: DropdownButtonFormField<String?>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
          items: [for (final (v, l) in items) DropdownMenuItem<String?>(value: v, child: Text(l, overflow: TextOverflow.ellipsis))],
          onChanged: (v) {
            onChanged(v);
            _load();
          },
        ),
      );

  Widget _filters() {
    return Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
      _dateBox('Du', _from, (d) => setState(() => _from = d)),
      _dateBox('Au', _to, (d) => setState(() => _to = d)),
      _dropdown('Production', _production, [
        (null, 'Toutes'),
        for (final p in _opts('productions')) (p['key'].toString(), p['label'].toString()),
      ], (v) => setState(() => _production = v)),
      _dropdown('Utilisateur', _userId, [
        (null, 'Tous'),
        for (final u in _opts('users')) (u['id'].toString(), u['label'].toString()),
      ], (v) => setState(() => _userId = v)),
      _dropdown('Type', _type, [
        (null, 'Tous'),
        for (final t in _opts('types')) (t['key'].toString(), t['label'].toString()),
      ], (v) => setState(() => _type = v), width: 200),
      _dropdown('Statut', _status, [
        (null, 'Tous'),
        for (final s in ((_stats['options'] as Map?)?['statuses'] as List? ?? [])) (s.toString(), s.toString()),
      ], (v) => setState(() => _status = v), width: 150),
      TextButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded), label: const Text('Réinitialiser')),
    ]);
  }

  // ── KPI ───────────────────────────────────────────────────────────────

  Widget _kpis() {
    return Wrap(spacing: 14, runSpacing: 14, children: [
      KpiCard(label: 'Demandes totales', value: '${_kpi('total')}'),
      KpiCard(label: 'En attente', value: '${_kpi('pending')}'),
      KpiCard(label: 'Approuvées', value: '${_kpi('approved')}'),
      KpiCard(label: 'Refusées', value: '${_kpi('rejected')}'),
      KpiCard(label: 'Demandes de désarchivage', value: '${_kpi('unarchiveRequests')}'),
      KpiCard(label: 'Demandes d\'autorisation', value: '${_kpi('authorizationRequests')}'),
      KpiCard(label: 'Archivages automatiques', value: '${_kpi('archiveEvents')}'),
      if (_kpi('expired') > 0) KpiCard(label: 'Expirées', value: '${_kpi('expired')}'),
    ]);
  }

  // ── Tableau par utilisateur ───────────────────────────────────────────

  Widget _hTable({required ScrollController controller, required double minWidth, required DataTable table}) {
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      notificationPredicate: (n) => n.depth == 0,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
            ...ScrollConfiguration.of(context).dragDevices,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.touch,
          }),
          child: ConstrainedBox(constraints: BoxConstraints(minWidth: minWidth), child: table),
        ),
      ),
    );
  }

  Widget _usersSection() {
    final users = (_stats['users'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    DataCell n(Map<String, dynamic> u, String k, {Color? color}) => DataCell(Text('${u[k] ?? 0}',
        style: TextStyle(fontWeight: FontWeight.w700, color: (u[k] ?? 0) == 0 ? null : color)));
    return ReportSection(
      title: 'Demandes par utilisateur',
      icon: Icons.people_alt_rounded,
      subtitle: 'Archivages automatiques affichés à titre indicatif — ce ne sont pas des demandes (non comptés dans le total)',
      children: [
        if (users.isEmpty)
          const RpEmpty('Aucune donnée')
        else
          _hTable(
            controller: _usersHScroll,
            minWidth: 1100,
            table: DataTable(
              columnSpacing: 18,
              headingRowHeight: 40,
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              dataTextStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
              columns: const [
                DataColumn(label: Text('Utilisateur')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Production')),
                DataColumn(label: Text('Archivages auto'), numeric: true),
                DataColumn(label: Text('Désarchivage'), numeric: true),
                DataColumn(label: Text('Autorisation'), numeric: true),
                DataColumn(label: Text('Total'), numeric: true),
                DataColumn(label: Text('Approuvées'), numeric: true),
                DataColumn(label: Text('Refusées'), numeric: true),
                DataColumn(label: Text('En attente'), numeric: true),
                DataColumn(label: Text('Expirées'), numeric: true),
              ],
              rows: [
                for (final u in users)
                  DataRow(cells: [
                    DataCell(Text(u['userLabel']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(u['userEmail']?.toString() ?? '')),
                    DataCell(Text(u['productionLabel']?.toString() ?? '—')),
                    n(u, 'archiveEvents'),
                    n(u, 'unarchiveRequests'),
                    n(u, 'authorizationRequests'),
                    n(u, 'total'),
                    n(u, 'approved', color: kRpGreen),
                    n(u, 'rejected', color: kRpRed),
                    n(u, 'pending', color: kRpAmber),
                    n(u, 'expired', color: kRpGrey),
                  ]),
              ],
            ),
          ),
      ],
    );
  }

  // ── Graphiques ────────────────────────────────────────────────────────

  Widget _chartsSection() {
    final users = (_stats['users'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final timeline = (_stats['timeline'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    double v(Map<String, dynamic> m, String k) => ((m[k] as num?) ?? 0).toDouble();
    return ReportSection(
      title: 'Graphiques',
      icon: Icons.bar_chart_rounded,
      children: [
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final bar = HBarChart(
            title: 'Demandes par utilisateur',
            items: [for (final u in users) ChartItem(u['userLabel']?.toString() ?? '—', v(u, 'total'))],
            emptyText: 'Aucune demande',
          );
          final line = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, children: [
              for (final g in const [('day', 'Jour'), ('week', 'Semaine'), ('month', 'Mois')])
                ChoiceChip(
                  label: Text(g.$2),
                  selected: _granularity == g.$1,
                  onSelected: (_) {
                    setState(() => _granularity = g.$1);
                    _load();
                  },
                ),
            ]),
            const SizedBox(height: 8),
            LineSeriesChart(
              title: 'Demandes par période',
              labels: [for (final t in timeline) t['label'].toString()],
              series: [
                SeriesLine('Autorisation', kRpAccent, [for (final t in timeline) v(t, 'authorization')]),
                SeriesLine('Désarchivage', kRpAmber, [for (final t in timeline) v(t, 'unarchive')]),
              ],
              emptyText: 'Aucune demande sur la période',
            ),
          ]);
          if (!wide) return Column(children: [bar, const SizedBox(height: 20), line]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: bar),
            const SizedBox(width: 20),
            Expanded(child: line),
          ]);
        }),
      ],
    );
  }

  // ── Historique ────────────────────────────────────────────────────────

  Widget _historySection() {
    return ReportSection(
      title: 'Historique des demandes',
      icon: Icons.history_rounded,
      subtitle: '${_history.length} ligne(s)',
      children: [
        if (_history.isEmpty)
          const RpEmpty('Aucune demande sur la période')
        else
          _hTable(
            controller: _historyHScroll,
            minWidth: 1300,
            table: DataTable(
              columnSpacing: 16,
              headingRowHeight: 40,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 56,
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              dataTextStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Heure')),
                DataColumn(label: Text('Utilisateur')),
                DataColumn(label: Text('Production')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Date(s) concernée(s)')),
                DataColumn(label: Text('Motif')),
                DataColumn(label: Text('Statut')),
                DataColumn(label: Text('Responsable')),
                DataColumn(label: Text('Date de traitement')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (final r in _history)
                  DataRow(cells: [
                    DataCell(Text(r['date']?.toString() ?? '')),
                    DataCell(Text(r['time']?.toString() ?? '')),
                    DataCell(Text(r['userLabel']?.toString() ?? '—')),
                    DataCell(Text(r['productionLabel']?.toString() ?? '—')),
                    DataCell(Text(_kTypeLabels[r['type']] ?? r['type'].toString())),
                    DataCell(Text((r['concernedDates'] as List? ?? []).map((d) => fmtDate(d)).join(', '))),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text((r['reason'] ?? '—').toString(), overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(RpBadge(r['status']?.toString() ?? '', color: requestStatusColor(r['status']?.toString() ?? ''))),
                    DataCell(Text(r['reviewerEmail']?.toString() ?? '—')),
                    DataCell(Text(r['reviewedDate']?.toString() ?? '—')),
                    DataCell(r['type'] == 'ARCHIVE'
                        ? const SizedBox.shrink()
                        : TextButton(
                            onPressed: () => showProductionRequestHistory(
                              context,
                              type: r['type'] == 'AUTHORIZATION' ? 'authorization' : 'unarchive',
                              id: r['id'].toString(),
                            ),
                            child: const Text('Voir'),
                          )),
                  ]),
              ],
            ),
          ),
      ],
    );
  }
}
