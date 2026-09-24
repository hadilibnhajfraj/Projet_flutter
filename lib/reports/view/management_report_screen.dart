// lib/reports/view/management_report_screen.dart
//
// "Rapport de pilotage" / "Management Report" — vue de synthèse pour la
// direction. Toutes les données viennent de GET /reports/* (agrégations SQL
// côté backend, réservé aux rôles admin). Aucun chiffre n'est calculé ni
// inventé côté Flutter : une valeur absente est affichée "Non disponible".

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';

import '../service/reports_service.dart';
import 'report_widgets.dart';

const _kEventKeys = <String, String>{
  'project_created': 'Project created',
  'project_modified': 'Project modified',
  'project_stage': 'Stage change',
  'project_archived': 'Project archived',
  'project_unarchived': 'Project unarchived',
  'contact_created': 'Contact created',
  'action_created': 'Action created',
  'relance_created': 'Follow-up created',
  'fiche_created': 'Sheet created',
};

const _kModuleKeys = <String, String>{
  'project': 'Project',
  'contact': 'Contact',
  'action': 'Action',
  'relance': 'Follow-up',
  'fiche': 'Sheet',
};

const _kKpiKeys = <String, String>{
  'totalProjects': 'Total projects',
  'projectsCreated': 'Created Projects',
  'projectsModified': 'Modified projects',
  'projectsArchived': 'Archived Projects',
  'projectsArchivedPeriod': 'Archived in period',
  'totalContacts': 'Total contacts',
  'newContacts': 'New contacts',
  'totalUsers': 'Total users',
  'activeUsers': 'Users with activity',
  'totalFiches': 'Sheets created',
  'promeshProduction': 'PROMESH production (m²)',
  'probarProduction': 'PROBAR production',
};

const _kPresets = <String>['all', '7d', '30d', 'month', 'year', 'custom'];

class ManagementReportScreen extends StatefulWidget {
  const ManagementReportScreen({super.key});

  @override
  State<ManagementReportScreen> createState() => _ManagementReportScreenState();
}

class _ManagementReportScreenState extends State<ManagementReportScreen> {
  final _svc = ReportsService.instance;
  ReportFilters _f = ReportFilters();
  String _preset = '30d';
  String? _lang;

  bool _loading = true;
  bool _exporting = false;
  String? _error;
  final Map<String, String> _errors = {};
  Map<String, dynamic> _opts = {};

  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _commercials = [];
  Map<String, dynamic> _projects = {};
  Map<String, dynamic> _archived = {};
  Map<String, dynamic> _contacts = {};
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic> _activity = {};
  Map<String, dynamic> _industrial = {};
  Map<String, dynamic> _machines = {};
  Map<String, dynamic> _production = {};
  Map<String, dynamic> _quality = {};
  Map<String, dynamic> _insights = {};

  String _t(String k) => AppLocalizations.of(context).translate(k);

  @override
  void initState() {
    super.initState();
    _applyPreset('30d', reload: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode == 'fr' ? 'fr' : 'en';
    if (_lang != lang) {
      final first = _lang == null;
      _lang = lang;
      if (first) _svc.filters().then((o) => mounted ? setState(() => _opts = o) : null).catchError((_) {});
      _load();
    }
  }

  // ── Chargement ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (!AuthService().isAdmin) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final q = _f.toQuery(_lang ?? 'fr');
    final errs = <String, String>{};
    Future<T> guard<T>(String key, Future<T> Function() call, T fallback) async {
      try {
        return await call();
      } catch (e) {
        errs[key] = e is DioException
            ? (e.response?.statusCode != null ? 'HTTP ${e.response!.statusCode}' : (e.message ?? 'network'))
            : e.toString();
        return fallback;
      }
    }

    final r = await Future.wait<dynamic>([
      guard('overview', () => _svc.overview(q), <String, dynamic>{}),
      guard('commercials', () => _svc.commercials(q), <Map<String, dynamic>>[]),
      guard('projects', () => _svc.projects(q), <String, dynamic>{}),
      guard('archived', () => _svc.archived(q), <String, dynamic>{}),
      guard('contacts', () => _svc.contacts(q), <String, dynamic>{}),
      guard('users', () => _svc.users(q), <Map<String, dynamic>>[]),
      guard('activity', () => _svc.activity(q), <String, dynamic>{}),
      guard('industrial', () => _svc.industrial(q), <String, dynamic>{}),
      guard('machines', () => _svc.machines(q), <String, dynamic>{}),
      guard('production', () => _svc.production(q), <String, dynamic>{}),
      guard('quality', () => _svc.dataQuality(q), <String, dynamic>{}),
      guard('insights', () => _svc.recommendations(q), <String, dynamic>{}),
    ]);
    if (!mounted) return;
    setState(() {
      _overview = r[0];
      _commercials = r[1];
      _projects = r[2];
      _archived = r[3];
      _contacts = r[4];
      _users = r[5];
      _activity = r[6];
      _industrial = r[7];
      _machines = r[8];
      _quality = r[10];
      _insights = r[11];
      _production = r[9];
      _errors
        ..clear()
        ..addAll(errs);
      // Erreur globale uniquement si TOUTES les sections ont échoué.
      _error = errs.length == 12 ? errs.values.first : null;
      _loading = false;
    });
  }

  void _applyPreset(String p, {bool reload = true}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _preset = p;
    switch (p) {
      case 'all':
        _f.from = null;
        _f.to = null;
        break;
      case '7d':
        _f.from = today.subtract(const Duration(days: 6));
        _f.to = today;
        break;
      case '30d':
        _f.from = today.subtract(const Duration(days: 29));
        _f.to = today;
        break;
      case 'month':
        _f.from = DateTime(now.year, now.month, 1);
        _f.to = today;
        break;
      case 'year':
        _f.from = DateTime(now.year, 1, 1);
        _f.to = today;
        break;
      default:
        break;
    }
    if (reload) {
      setState(() {});
      _load();
    }
  }

  void _reset() {
    _f = ReportFilters();
    _applyPreset('30d');
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = (isFrom ? _f.from : _f.to) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      if (isFrom) {
        _f.from = d;
      } else {
        _f.to = d;
      }
      _preset = 'custom';
    });
    _load();
  }

  Future<void> _export(String kind) async {
    setState(() => _exporting = true);
    try {
      final Uint8List bytes = await _svc.export(kind, _f.toQuery(_lang ?? 'fr'));
      final isPdf = kind == 'pdf';
      final blob = html.Blob(
        [bytes],
        isPdf ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      final url = html.Url.createObjectUrlFromBlob(blob);
      final name = 'rapport-pilotage-${DateFormat('yyyyMMdd').format(DateTime.now())}.${isPdf ? 'pdf' : 'xlsx'}';
      html.AnchorElement(href: url)
        ..setAttribute('download', name)
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_t(kind == 'pdf' ? 'Unable to generate the PDF report.' : 'Unable to generate the Excel report.')} ($e)'),
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _rows(dynamic v) =>
      (v as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  String _s(dynamic v) => v == null ? '' : v.toString();
  String _na(dynamic v) => (v == null || v.toString().isEmpty) ? _t('Not available') : v.toString();
  String _n(dynamic v) => v == null ? _t('Not available') : fmtNum(v);

  String _shift(dynamic s) {
    switch (s?.toString()) {
      case 'matin':
        return _t('Morning');
      case 'nuit':
        return _t('Night');
      case 'soir':
        return _t('Evening');
      case null:
      case 'unknown':
        return _t('Not specified');
      default:
        return s.toString();
    }
  }

  String _machineName(dynamic m) => m?.toString() == 'unknown' ? _t('Not specified') : _s(m);

  String _event(dynamic type) => _t(_kEventKeys[type] ?? _s(type));

  RpTable _table(List<RpCol> cols, List<Map<String, dynamic>> rows,
          {int initialRows = 15, void Function(Map<String, dynamic>)? onTap}) =>
      RpTable(
        columns: cols,
        rows: rows,
        emptyText: _t('Not available'),
        showMoreText: _t('Show all'),
        initialRows: initialRows,
        onRowTap: onTap,
      );

  HBarChart _bar(String title, List<ChartItem> items, {Color color = kRpAccent}) =>
      HBarChart(title: title, items: items, emptyText: _t('Not available'), color: color);

  Widget _details(String title, Widget child, {bool open = false}) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: open,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [Align(alignment: Alignment.centerLeft, child: child)],
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!AuthService().isAdmin) {
      return Scaffold(body: Center(child: Text(_t('Access denied'))));
    }
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 16),
            _filtersBar(),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 80), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              _errorBox()
            else ...[
              _sec('overview', 'Overview', Icons.dashboard_rounded, _overviewSection),
              _sec('commercials', 'Sales activity', Icons.groups_rounded, _commercialSection),
              _sec('projects', 'Project traceability', Icons.account_tree_rounded, _projectsSection),
              _sec('contacts', 'Contact activity', Icons.contacts_rounded, _contactsSection),
              _sec('archived', 'Archived Projects', Icons.archive_rounded, _archivedSection),
              _sec('users', 'User Activity', Icons.manage_accounts_rounded, _usersSection),
              _sec('activity', 'Recent activity', Icons.history_rounded, _activitySection),
              _sec('industrial', 'Industrial Production', Icons.factory_rounded, _industrialSection),
              _sec('production', 'Production', Icons.precision_manufacturing_rounded, () => _prodLineSection(0)),
              _sec('production', 'Production', Icons.precision_manufacturing_rounded, () => _prodLineSection(1)),
              _sec('production', 'Sheet creation trend', Icons.show_chart_rounded, _prodTrendSection),
              _sec('machines', 'Machine analysis', Icons.precision_manufacturing_rounded, _machinesSection),
              _sec('insights', 'Remarks', Icons.lightbulb_outline_rounded, _remarksSection),
              _sec('quality', 'Data quality', Icons.fact_check_rounded, _qualitySection),
              _sec('insights', 'Recommendations', Icons.task_alt_rounded, _recommendationsSection),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sec(String key, String titleKey, IconData icon, Widget Function() build) {
    final e = _errors[key];
    if (e == null) return build();
    return ReportSection(
      title: _t(titleKey),
      icon: icon,
      children: [
        Row(children: [
          const Icon(Icons.error_outline_rounded, color: kRpRed),
          const SizedBox(width: 10),
          Expanded(child: Text('${_t(titleKey)} — ${_t('data unavailable')} ($e)')),
          TextButton(onPressed: _load, child: Text(_t('Retry'))),
        ]),
      ],
    );
  }

  Widget _errorBox() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kRpRed.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: kRpRed),
          const SizedBox(width: 10),
          Expanded(child: Text('${_t('Failed to load the report')} (${_error ?? ''})')),
          TextButton(onPressed: _load, child: Text(_t('Retry'))),
        ]),
      );

  Widget _header() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_t('Management Report'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(_periodText(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton.icon(
            onPressed: _exporting ? null : () => _export('excel'),
            icon: const Icon(Icons.table_view_rounded, size: 18),
            label: Text(_t('Export Excel')),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _exporting ? null : () => _export('pdf'),
            icon: _exporting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: Text(_t('Export PDF')),
          ),
        ]),
      ],
    );
  }

  String _periodText() {
    final df = DateFormat('dd/MM/yyyy');
    if (_f.from == null && _f.to == null) return _t('All time');
    return '${_f.from != null ? df.format(_f.from!) : '…'}  →  ${_f.to != null ? df.format(_f.to!) : '…'}';
  }

  // ── Filtres ───────────────────────────────────────────────────────────────

  Widget _dd(String label, String? value, List<(String, String)> options, ValueChanged<String?> onChanged, {double width = 190}) {
    final valid = options.any((o) => o.$1 == value) ? value : null;
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String?>(
        value: valid,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(_t('All'))),
          for (final o in options) DropdownMenuItem<String?>(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) {
          onChanged(v);
          _load();
        },
      ),
    );
  }

  List<(String, String)> _idName(dynamic list) =>
      _rows(list).map((e) => (_s(e['id']), _s(e['name']))).where((e) => e.$1.isNotEmpty).toList();

  Widget _dateBox(String label, DateTime? d, bool isFrom) => SizedBox(
        width: 150,
        child: InkWell(
          onTap: () => _pickDate(isFrom),
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
            child: Text(d == null ? '—' : DateFormat('dd/MM/yyyy').format(d)),
          ),
        ),
      );

  Widget _filtersBar() {
    final presetLabels = {
      'all': _t('All time'),
      '7d': _t('Last 7 days'),
      '30d': _t('Last 30 days'),
      'month': _t('This month'),
      'year': _t('This year'),
      'custom': _t('Custom'),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              value: _preset,
              isExpanded: true,
              decoration: InputDecoration(labelText: _t('Period'), isDense: true, border: const OutlineInputBorder()),
              items: [for (final p in _kPresets) DropdownMenuItem(value: p, child: Text(presetLabels[p]!))],
              onChanged: (v) {
                if (v == null) return;
                if (v == 'custom') {
                  setState(() => _preset = 'custom');
                } else {
                  _applyPreset(v);
                }
              },
            ),
          ),
          _dateBox(_t('Start date'), _f.from, true),
          _dateBox(_t('End date'), _f.to, false),
          _dd(_t('Sales rep'), _f.commercialId, _idName(_opts['commercials']), (v) => setState(() => _f.commercialId = v)),
          _dd(_t('User'), _f.userId, _idName(_opts['users']), (v) => setState(() => _f.userId = v)),
          _dd(_t('Project status'), _f.statut,
              (_opts['statuses'] as List? ?? []).map((e) => (e.toString(), e.toString())).toList(), (v) => setState(() => _f.statut = v)),
          _dd(_t('Project'), _f.projectId, _idName(_opts['projects']), (v) => setState(() => _f.projectId = v), width: 230),
          _dd(_t('Client'), _f.companyId, _idName(_opts['clients']), (v) => setState(() => _f.companyId = v), width: 210),
          _dd(_t('Machine'), _f.machine,
              (_opts['machines'] as List? ?? []).map((e) => (e.toString(), e.toString())).toList(), (v) => setState(() => _f.machine = v),
              width: 140),
          _dd(_t('Production type'), _f.module, const [('promesh', 'PROMESH'), ('probar', 'PROBAR')], (v) => setState(() => _f.module = v), width: 160),
          _dd(_t('Shift'), _f.poste,
              (_opts['postes'] as List? ?? []).map((e) => (e.toString(), _shift(e))).toList(), (v) => setState(() => _f.poste = v),
              width: 140),
          TextButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded), label: Text(_t('Reset filters'))),
        ],
      ),
    );
  }

  // ── 1. Vue générale ───────────────────────────────────────────────────────

  Widget _overviewSection() {
    final kpis = _rows(_overview['kpis']);
    final charts = _map(_overview['charts']);
    final hasPrev = _overview['previousPeriod'] != null;
    return ReportSection(
      title: _t('Overview'),
      icon: Icons.dashboard_rounded,
      subtitle: hasPrev ? _t('Change vs previous period') : null,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final k in kpis)
              KpiCard(
                label: _t(_kKpiKeys[k['key']] ?? _s(k['key'])),
                value: fmtNum(k['value']),
                variationPct: (k['variationPct'] as num?)?.toDouble(),
                previousLabel: k['previous'] != null ? '(${fmtNum(k['previous'])})' : null,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 14, runSpacing: 14, children: [
          _bar(_t('Projects by status'), [for (final r in _rows(charts['projectsByStatus'])) ChartItem(_s(r['label']), (r['value'] as num).toDouble())]),
          _bar(_t('Projects created per month'), [for (final r in _rows(charts['projectsByMonth'])) ChartItem(_s(r['label']), (r['value'] as num).toDouble())]),
          _bar(_t('Shift distribution'), [for (final r in _rows(charts['shifts'])) ChartItem(_shift(r['label']), (r['value'] as num).toDouble())],
              color: kRpAmber),
        ]),
      ],
    );
  }

  // ── 2/3. Commerciaux ──────────────────────────────────────────────────────

  Widget _commercialSection() {
    return ReportSection(
      title: _t('Sales activity'),
      icon: Icons.groups_rounded,
      subtitle: _t('Statistical count of records per user — not a performance ranking'),
      children: [
        _bar(_t('Projects created by sales rep'),
            [for (final r in _commercials) ChartItem(_s(r['name']), (r['projectsCreated'] as num).toDouble())]),
        const SizedBox(height: 12),
        RpNote(_t('Project states (active / won / lost / archived) reflect the current situation of the projects owned by each sales rep.')),
        _table([
          RpCol(_t('Sales rep'), (r) => _s(r['name'])),
          RpCol(_t('Projects created'), (r) => fmtNum(r['projectsCreated']), numeric: true),
          RpCol(_t('Active projects'), (r) => fmtNum(r['projectsActive']), numeric: true),
          RpCol(_t('Won projects'), (r) => fmtNum(r['projectsWon']), numeric: true),
          RpCol(_t('Lost projects'), (r) => fmtNum(r['projectsLost']), numeric: true),
          RpCol(_t('Archived Projects'), (r) => fmtNum(r['projectsArchived']), numeric: true),
          RpCol(_t('Contacts created'), (r) => fmtNum(r['contactsCreated']), numeric: true),
          RpCol(_t('Actions'), (r) => fmtNum(r['actions']), numeric: true),
          RpCol(_t('Follow-ups'), (r) => fmtNum(r['relances']), numeric: true),
          RpCol(_t('Last project'), (r) => _s(r['lastProject'])),
          RpCol(_t('Last project date'), (r) => fmtDate(r['lastProjectAt'])),
          RpCol(_t('Last activity'), (r) => fmtDateTime(r['lastActivityAt'])),
        ], _commercials),
      ],
    );
  }

  // ── 4. Projets ────────────────────────────────────────────────────────────

  Widget _projectsSection() {
    final rows = _rows(_projects['rows']);
    return ReportSection(
      title: _t('Project traceability'),
      icon: Icons.account_tree_rounded,
      subtitle: '${fmtNum(_projects['total'])} ${_t('projects')}',
      children: [
        RpNote(_t('Projects have no "created by" field: the owner is shown and is not guaranteed to be the creator.')),
        RpNote(_t('"Modified by" comes from the project history (edits and stage changes).')),
        _details(
          _t('Details'),
          _table(_projectCols(false), rows, initialRows: 20),
        ),
      ],
    );
  }

  List<RpCol> _projectCols(bool archived) => [
        RpCol(_t('Project'), (r) => _s(r['name'])),
        RpCol(_t('Client'), (r) => _s(r['client'])),
        RpCol(_t('Owner'), (r) => _s(r['owner'])),
        RpCol(_t('Created by'), (r) => _t('Not available')),
        RpCol(_t('Created on'), (r) => fmtDateTime(r['createdAt'])),
        RpCol(_t('Last modified'), (r) => fmtDateTime(r['updatedAt'])),
        RpCol(_t('Modified by'), (r) => _na(r['updatedBy'])),
        RpCol(_t('Status'), (r) => _s(r['status'])),
        RpCol(_t('Archived by'), (r) => (archived || r['isArchived'] == true) ? _na(r['archivedBy']) : ''),
        RpCol(_t('Archived on'), (r) => fmtDateTime(r['archivedAt'])),
        if (archived) RpCol(_t('Reason'), (r) => _s(r['archiveReason'])),
        RpCol(_t('Last action'), (r) => fmtDate(r['lastActionAt'])),
        RpCol(_t('Last follow-up'), (r) => fmtDate(r['lastRelanceAt'])),
        RpCol(_t('Last activity'), (r) => fmtDateTime(r['lastActivityAt'])),
      ];

  // ── 5. Contacts ───────────────────────────────────────────────────────────

  Widget _contactsSection() {
    final rows = _rows(_contacts['rows']);
    return ReportSection(
      title: _t('Contact activity'),
      icon: Icons.contacts_rounded,
      subtitle: '${fmtNum(_contacts['unassigned'])} ${_t('contacts without assigned sales rep')}',
      children: [
        _bar(_t('Contacts created by sales rep'),
            [for (final r in rows) ChartItem(_s(r['name']), (r['contactsCreated'] as num).toDouble())], color: kRpGreen),
        const SizedBox(height: 12),
        _table([
          RpCol(_t('Sales rep'), (r) => _s(r['name'])),
          RpCol(_t('Contacts created'), (r) => fmtNum(r['contactsCreated']), numeric: true),
          RpCol(_t('Last contact'), (r) => _s(r['lastContact'])),
          RpCol(_t('Last contact date'), (r) => fmtDateTime(r['lastContactAt'])),
          RpCol(_t('Last modified'), (r) => fmtDateTime(r['lastModifiedAt'])),
          RpCol(_t('Last activity'), (r) => fmtDateTime(r['lastActivityAt'])),
        ], rows),
        _details(
          _t('Recent contacts'),
          _table([
            RpCol(_t('Contact'), (r) => _s(r['name'])),
            RpCol(_t('Status'), (r) => _s(r['statut'])),
            RpCol(_t('Created by'), (r) => _s(r['createdBy'])),
            RpCol(_t('Created on'), (r) => fmtDateTime(r['createdAt'])),
            RpCol(_t('Last modified'), (r) => fmtDateTime(r['updatedAt'])),
          ], _rows(_contacts['recent'])),
        ),
      ],
    );
  }

  // ── 6. Archivés ───────────────────────────────────────────────────────────

  Widget _archivedSection() {
    return ReportSection(
      title: _t('Archived Projects'),
      icon: Icons.archive_rounded,
      subtitle: '${fmtNum(_archived['total'])} ${_t('projects')}',
      children: [
        RpNote(_t('"Archived by" comes from approved archive requests; a direct archive does not record any user.')),
        _table(_projectCols(true), _rows(_archived['rows']), initialRows: 20),
      ],
    );
  }

  // ── 7. Utilisateurs ───────────────────────────────────────────────────────

  int _userTotal(Map<String, dynamic> u) =>
      ((u['fiches'] as num?) ?? 0).toInt() +
      ((u['projectsCreated'] as num?) ?? 0).toInt() +
      ((u['projectsModified'] as num?) ?? 0).toInt() +
      ((u['projectsArchived'] as num?) ?? 0).toInt() +
      ((u['contactsCreated'] as num?) ?? 0).toInt() +
      ((u['actionsCreated'] as num?) ?? 0).toInt() +
      ((u['relancesCreated'] as num?) ?? 0).toInt() +
      ((u['documents'] as num?) ?? 0).toInt();

  Widget _usersSection() {
    final sorted = [..._users]..sort((a, b) => _userTotal(b).compareTo(_userTotal(a)));
    return ReportSection(
      title: _t('User Activity'),
      icon: Icons.manage_accounts_rounded,
      subtitle: _t('Click a user to see the detailed sheet'),
      children: [
        _bar(_t('Recorded operations per user'), [for (final u in sorted) ChartItem(_s(u['name']), _userTotal(u).toDouble())],
            color: kRpBlue),
        const SizedBox(height: 12),
        RpNote(_t('"Sheets" are production / waste sheets (PROMESH, PROBAR, Mixing, Maintenance, Recoverables).')),
        _table([
          RpCol(_t('Name'), (r) => _s(r['name'])),
          RpCol(_t('Email'), (r) => _s(r['email'])),
          RpCol(_t('Role'), (r) => _s(r['role'])),
          RpCol(_t('Sheets'), (r) => fmtNum(r['fiches']), numeric: true),
          RpCol(_t('Projects created'), (r) => fmtNum(r['projectsCreated']), numeric: true),
          RpCol(_t('Projects modified'), (r) => fmtNum(r['projectsModified']), numeric: true),
          RpCol(_t('Archived Projects'), (r) => fmtNum(r['projectsArchived']), numeric: true),
          RpCol(_t('Contacts created'), (r) => fmtNum(r['contactsCreated']), numeric: true),
          RpCol(_t('Actions'), (r) => fmtNum(r['actionsCreated']), numeric: true),
          RpCol(_t('Follow-ups'), (r) => fmtNum(r['relancesCreated']), numeric: true),
          RpCol(_t('Documents'), (r) => fmtNum(r['documents']), numeric: true),
          RpCol(_t('Last activity'), (r) => fmtDateTime(r['lastActivityAt'])),
        ], sorted, onTap: (r) => _showUser(_s(r['id']))),
      ],
    );
  }

  Future<void> _showUser(String id) async {
    final q = _f.toQuery(_lang ?? 'fr');
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _svc.userDetail(id, q),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError || snap.data == null || snap.data!.isEmpty) {
                return SizedBox(height: 160, child: Center(child: Text(_t('Failed to load the report'))));
              }
              return _userSheet(ctx, snap.data!);
            },
          ),
        ),
      ),
    );
  }

  Widget _userSheet(BuildContext ctx, Map<String, dynamic> d) {
    final u = _map(d['user']);
    Widget stat(String label, dynamic v) => Container(
          width: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            Text(fmtNum(v), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        );
    Widget info(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 190, child: Text(k, style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant))),
            Expanded(child: Text(v)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(_s(u['name']), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 8),
          Text(_t('User sheet'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          info(_t('Name'), _s(u['name'])),
          info(_t('Email'), _s(u['email'])),
          info(_t('Role'), _s(u['role'])),
          info(_t('Status'), u['isActive'] == true ? _t('Active') : _t('Inactive')),
          info(_t('Created on'), fmtDate(u['createdAt'])),
          info(_t('Last MFA verification'), d['lastMfaVerifiedAt'] == null ? _t('Not available') : fmtDateTime(d['lastMfaVerifiedAt'])),
          info(_t('Last activity'), u['lastActivityAt'] == null ? _t('Not available') : fmtDateTime(u['lastActivityAt'])),
          const SizedBox(height: 14),
          Text(_t('Activity'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            stat(_t('Projects created'), u['projectsCreated']),
            stat(_t('Projects modified'), u['projectsModified']),
            stat(_t('Archived Projects'), u['projectsArchived']),
            stat(_t('Contacts created'), u['contactsCreated']),
            stat(_t('Actions'), u['actionsCreated']),
            stat(_t('Follow-ups'), u['relancesCreated']),
            stat(_t('Documents'), u['documents']),
            stat(_t('Sheets'), u['fiches']),
          ]),
          const SizedBox(height: 16),
          Text(_t('Latest activities'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _table([
            RpCol(_t('Date'), (r) => fmtDateTime(r['at'])),
            RpCol(_t('Module'), (r) => _t(_kModuleKeys[r['module']] ?? _s(r['module']))),
            RpCol(_t('Object'), (r) => _s(r['label'])),
            RpCol(_t('Action'), (r) => _event(r['type'])),
          ], _rows(d['recent']), initialRows: 30),
        ]),
      ),
    );
  }

  // ── 8. Activité ───────────────────────────────────────────────────────────

  Widget _activitySection() {
    final rows = _rows(_activity['rows']);
    final userWord = _t('owner');
    String who(Map<String, dynamic> r) {
      final n = _s(r['userName']);
      if (n.isEmpty) return _t('Not available');
      return r['actorSource'] == 'owner' ? '$n ($userWord)' : n;
    }

    return ReportSection(
      title: _t('Recent activity'),
      icon: Icons.history_rounded,
      subtitle: '${fmtNum(_activity['total'])} ${_t('events')}',
      children: [
        if (rows.isEmpty) RpEmpty(_t('Not available')),
        for (final r in rows.take(10))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: kRpBlue.withOpacity(0.1),
              child: Icon(_iconFor(_s(r['type'])), size: 16, color: kRpAccent),
            ),
            title: Text('${_event(r['type']).toUpperCase()} — ${_s(r['label'])}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text('${who(r)}  ·  ${fmtDateTime(r['at'])}'),
          ),
        _details(
          _t('Activity log'),
          _table([
            RpCol(_t('Date'), (r) => fmtDate(r['at'])),
            RpCol(_t('Time'), (r) => parseDate(r['at']) == null ? '' : DateFormat('HH:mm').format(parseDate(r['at'])!)),
            RpCol(_t('User'), who),
            RpCol(_t('Role'), (r) => _s(r['userRole'])),
            RpCol(_t('Module'), (r) => _t(_kModuleKeys[r['module']] ?? _s(r['module']))),
            RpCol(_t('Object'), (r) => _s(r['label'])),
            RpCol(_t('Action'), (r) => _event(r['type'])),
            RpCol(_t('Reference'), (r) => _s(r['ref']).length > 8 ? _s(r['ref']).substring(0, 8) : _s(r['ref'])),
            RpCol(_t('Status'), (r) => _s(r['status'])),
          ], rows, initialRows: 25),
        ),
        RpNote(_t('For project creation events, the owner is shown (no "created by" field exists).')),
      ],
    );
  }

  IconData _iconFor(String type) {
    if (type.startsWith('project_archived')) return Icons.archive_rounded;
    if (type.startsWith('project')) return Icons.folder_rounded;
    if (type == 'contact_created') return Icons.person_add_alt_1_rounded;
    if (type == 'action_created') return Icons.bolt_rounded;
    if (type == 'relance_created') return Icons.notifications_active_rounded;
    return Icons.description_rounded;
  }

  // ── 9. Industrie ──────────────────────────────────────────────────────────

  Widget _totalsCard(String title, Color color, List<(String, String)> lines) => Container(
        width: 300,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 8),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text(l.$1, style: const TextStyle(fontSize: 12))),
                Text(l.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
        ]),
      );

  LineSeriesChart _perDayChart(String title, List<Map<String, dynamic>> perDay, Color color) {
    final dates = perDay.map((e) => _s(e['date'])).toList();
    return LineSeriesChart(
      title: title,
      labels: dates,
      emptyText: _t('Not available'),
      series: [
        SeriesLine(_t('Quantity'), color, [for (final e in perDay) (e['quantity'] as num?)?.toDouble()]),
        SeriesLine(_t('Waste'), kRpRed, [for (final e in perDay) (e['waste'] as num?)?.toDouble()]),
      ],
    );
  }

  Widget _industrialSection() {
    final p = _industrial['promesh'] is Map ? _map(_industrial['promesh']) : null;
    final b = _industrial['probar'] is Map ? _map(_industrial['probar']) : null;
    final rec = _map(_industrial['recuperables']);
    final pt = p == null ? <String, dynamic>{} : _map(p['totals']);
    final bt = b == null ? <String, dynamic>{} : _map(b['totals']);
    final shiftItems = <String, double>{};
    for (final src in [p, b]) {
      if (src == null) continue;
      for (final s in _rows(src['perShift'])) {
        final k = _shift(s['shift']);
        shiftItems[k] = (shiftItems[k] ?? 0) + (s['fiches'] as num).toDouble();
      }
    }
    return ReportSection(
      title: _t('Industrial Production'),
      icon: Icons.factory_rounded,
      subtitle: _t('Data recorded in the system'),
      children: [
        Wrap(spacing: 14, runSpacing: 14, children: [
          if (p != null)
            _totalsCard('PROMESH', kRpBlue, [
              (_t('Sheets'), fmtNum(pt['fiches'])),
              (_t('Production (m²)'), fmtNum(pt['quantity'])),
              (_t('Bar offcuts'), _n(pt['wasteBars'])),
              (_t('Seed waste'), _n(pt['wasteSeed'])),
              (_t('Machines used'), fmtNum(pt['machines'])),
              (_t('Last production'), pt['lastAt'] == null ? _t('Not available') : fmtDate(pt['lastAt'])),
            ]),
          if (b != null)
            _totalsCard('PROBAR', kRpGreen, [
              (_t('Sheets'), fmtNum(bt['fiches'])),
              (_t('Quantity'), fmtNum(bt['quantity'])),
              (_t('Waste (recoverable sheets)'), _n(bt['waste'])),
              (_t('Machines used'), fmtNum(bt['machines'])),
              (_t('Last production'), bt['lastAt'] == null ? _t('Not available') : fmtDate(bt['lastAt'])),
            ]),
        ]),
        const SizedBox(height: 14),
        RpNote(_t('PROMESH waste = bar offcuts + seed waste; PROBAR waste = PROBAR recoverable sheets.')),
        Wrap(spacing: 14, runSpacing: 14, children: [
          if (p != null) _perDayChart(_t('PROMESH production per day'), _rows(p['perDay']), kRpBlue),
          if (b != null) _perDayChart(_t('PROBAR production per day'), _rows(b['perDay']), kRpGreen),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 14, runSpacing: 14, children: [
          _bar(_t('Shift distribution'), [for (final e in shiftItems.entries) ChartItem(e.key, e.value)], color: kRpAmber),
          if (p != null)
            _bar(_t('PROMESH production per mesh diameter'), [
              for (final r in _rows(p['perDiameter']))
                ChartItem(_s(r['diameter']) == 'unknown' ? _t('Not specified') : _s(r['diameter']), (r['quantity'] as num).toDouble()),
            ]),
          _bar(_t('Recoverable waste per diameter'), [
            for (final r in _rows(rec['perDiameter']))
              ChartItem(_s(r['diameter']) == 'unknown' ? _t('Not specified') : _s(r['diameter']), (r['waste'] as num).toDouble()),
          ], color: kRpRed),
        ]),
      ],
    );
  }

  // ── PROD 1 / PROD 2 ──────────────────────────────────────────────────────

  Widget _prodLineSection(int idx) {
    final lines = _rows(_production['lines']);
    if (idx >= lines.length) return const SizedBox.shrink();
    final l = lines[idx];
    final byType = _map(l['byType']);
    final last = l['last'] is Map ? _map(l['last']) : null;
    final perDay = _rows(l['perDay']);
    final total = ((l['total'] as num?) ?? 0).toInt();
    return ReportSection(
      title: '${_t('Production')} — ${_s(l['name'])}',
      icon: Icons.precision_manufacturing_rounded,
      subtitle: _t('Data recorded in the system'),
      children: [
        if (idx == 0)
          RpNote(_t('PROD 1 / PROD 2 = sheets whose machine is "1" / "2" (PROMESH, PROBAR and Recoverable sheets). Date = sheet creation date; user = sheet creator.')),
        _totalsCard(_s(l['name']), idx == 0 ? kRpBlue : kRpGreen, [
          (_t('Total sheets'), fmtNum(total)),
          (_t('First sheet'), l['firstAt'] == null ? _t('Not available') : fmtDate(l['firstAt'])),
          (_t('Last sheet'), l['lastAt'] == null ? _t('Not available') : fmtDate(l['lastAt'])),
          (_t('Last sheet created'), last == null ? _t('Not available') : _s(last['label'])),
          (_t('Created by'), last == null ? _t('Not available') : _na(last['userName'])),
          (_t('Created on'), last == null ? _t('Not available') : fmtDateTime(last['at'])),
          ('PROMESH', fmtNum(byType['promesh'] ?? 0)),
          ('PROBAR', fmtNum(byType['probar'] ?? 0)),
          (_t('Recoverables'), fmtNum(byType['recuperable'] ?? 0)),
        ]),
        const SizedBox(height: 14),
        LineSeriesChart(
          title: _t('Sheets created per day'),
          labels: [for (final d in perDay) _s(d['date'])],
          emptyText: _t('Not available'),
          series: [
            SeriesLine(_t('Sheets'), idx == 0 ? kRpBlue : kRpGreen, [for (final d in perDay) (d['count'] as num?)?.toDouble()]),
          ],
        ),
        const SizedBox(height: 12),
        Text(_t('Sheets created per user'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        _table([
          RpCol(_t('User'), (r) => _na(r['name'])),
          RpCol(_t('Sheets'), (r) => fmtNum(r['fiches']), numeric: true),
          RpCol(_t('First creation'), (r) => fmtDateTime(r['firstAt'])),
          RpCol(_t('Last creation'), (r) => fmtDateTime(r['lastAt'])),
        ], _rows(l['perUser'])),
        _details(
          _t('Sheets created per day'),
          _table([
            RpCol(_t('Date'), (r) => fmtDate(r['date'])),
            RpCol(_t('Sheets'), (r) => fmtNum(r['count']), numeric: true),
          ], perDay.where((d) => ((d['count'] as num?) ?? 0) > 0).toList(), initialRows: 31),
        ),
      ],
    );
  }

  Widget _prodTrendSection() {
    return ReportSection(
      title: _t('Sheet creation trend'),
      icon: Icons.show_chart_rounded,
      subtitle: _t('Data recorded in the system'),
      children: [
        _table([
          RpCol(_t('Date'), (r) => fmtDate(r['date'])),
          RpCol('PROD 1', (r) => fmtNum(r['prod1']), numeric: true),
          RpCol('PROD 2', (r) => fmtNum(r['prod2']), numeric: true),
          RpCol(_t('Total'), (r) => fmtNum(r['total']), numeric: true),
        ], _rows(_production['daily']), initialRows: 31),
        const SizedBox(height: 16),
        Text(_t('User Activity — Production'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        _table([
          RpCol(_t('User'), (r) => _na(r['name'])),
          RpCol('PROD 1', (r) => fmtNum(r['prod1']), numeric: true),
          RpCol('PROD 2', (r) => fmtNum(r['prod2']), numeric: true),
          RpCol(_t('Total'), (r) => fmtNum(r['total']), numeric: true),
          RpCol(_t('First creation'), (r) => fmtDateTime(r['firstAt'])),
          RpCol(_t('Last creation'), (r) => fmtDateTime(r['lastAt'])),
        ], _rows(_production['users'])),
      ],
    );
  }

  // ── 10. Machines ──────────────────────────────────────────────────────────

  Widget _machinesSection() {
    final machines = _rows(_machines['machines']);
    String label(Map<String, dynamic> m) => '${m['module']} ${_machineName(m['machine'])}';
    return ReportSection(
      title: _t('Machine analysis'),
      icon: Icons.precision_manufacturing_rounded,
      subtitle: _t('Data recorded in the system'),
      children: [
        Wrap(spacing: 14, runSpacing: 14, children: [
          _bar(_t('Production per machine'), [for (final m in machines) ChartItem(label(m), ((m['quantity'] as num?) ?? 0).toDouble())]),
          _bar(_t('Waste per machine'), [for (final m in machines) ChartItem(label(m), ((m['waste'] as num?) ?? 0).toDouble())], color: kRpRed),
        ]),
        const SizedBox(height: 12),
        _table([
          RpCol(_t('Module'), (r) => _s(r['module'])),
          RpCol(_t('Machine'), (r) => _machineName(r['machine'])),
          RpCol(_t('Sheets'), (r) => fmtNum(r['fiches']), numeric: true),
          RpCol(_t('Quantity'), (r) => fmtNum(r['quantity']), numeric: true),
          RpCol(_t('Waste'), (r) => _n(r['waste']), numeric: true),
          RpCol(_t('First record'), (r) => fmtDate(r['firstAt'])),
          RpCol(_t('Last production'), (r) => fmtDate(r['lastAt'])),
          RpCol(_t('Morning sheets'), (r) => fmtNum(_map(r['shifts'])['matin'] ?? 0), numeric: true),
          RpCol(_t('Night sheets'), (r) => fmtNum(_map(r['shifts'])['nuit'] ?? 0), numeric: true),
          RpCol(_t('Recorded stoppages'), (r) => _n(r['stoppages']), numeric: true),
          RpCol(_t('Maintenance sheets'), (r) => fmtNum(r['maintenanceSheets']), numeric: true),
        ], machines),
        const SizedBox(height: 8),
        Text(_t('Machine operation'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        RpNote(_t('Only what is recorded in the sheets is shown. Stoppage duration and reason exist only as free text in the recorded observations; no technical interpretation is made.')),
        _details(
          _t('Production runs (date, shift, quantity, waste)'),
          _table([
            RpCol(_t('Date'), (r) => _s(r['date'])),
            RpCol(_t('Module'), (r) => _s(r['module'])),
            RpCol(_t('Machine'), (r) => _machineName(r['machine'])),
            RpCol(_t('Shift'), (r) => _shift(r['shift'])),
            RpCol(_t('Quantity'), (r) => _n(r['quantity']), numeric: true),
            RpCol(_t('Waste'), (r) => _n(r['waste']), numeric: true),
            RpCol(_t('Start'), (r) => _s(r['startTime'])),
            RpCol(_t('End'), (r) => _s(r['endTime'])),
            RpCol(_t('Stoppages'), (r) => _n(r['stoppages']), numeric: true),
            RpCol(_t('Status'), (r) => _s(r['status'])),
            RpCol(_t('Operator'), (r) => _s(r['operator'])),
          ], _rows(_machines['runs']), initialRows: 25),
        ),
        _details(
          _t('Recorded stoppages'),
          _table([
            RpCol(_t('Date'), (r) => _s(r['date'])),
            RpCol(_t('Machine'), (r) => _machineName(r['machine'])),
            RpCol(_t('Shift'), (r) => _shift(r['shift'])),
            RpCol(_t('Stoppage'), (r) => _s(r['stopValue'])),
            RpCol(_t('Observation'), (r) => _s(r['observation'])),
          ], _rows(_machines['stoppages'])),
        ),
        _details(
          _t('Maintenance sheets and requests'),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _table([
              RpCol(_t('Date'), (r) => _s(r['date'])),
              RpCol(_t('Machine'), (r) => _machineName(r['machine'])),
              RpCol(_t('Fault type'), (r) => _s(r['faultType'])),
              RpCol(_t('Urgency'), (r) => _s(r['urgency'])),
              RpCol(_t('Status'), (r) => _s(r['status'])),
              RpCol(_t('Description'), (r) => _s(r['description'])),
            ], _rows(_machines['maintenanceSheets'])),
            const SizedBox(height: 10),
            _table([
              RpCol(_t('Ticket'), (r) => _s(r['ticketNo'])),
              RpCol(_t('Equipment'), (r) => _s(r['equipment'])),
              RpCol(_t('Fault type'), (r) => _s(r['faultType'])),
              RpCol(_t('Urgency'), (r) => _s(r['urgency'])),
              RpCol(_t('Status'), (r) => _s(r['status'])),
              RpCol(_t('Created on'), (r) => fmtDate(r['createdAt'])),
            ], _rows(_machines['maintenanceRequests'])),
          ]),
        ),
      ],
    );
  }

  // ── 11. Remarques ─────────────────────────────────────────────────────────

  Widget _remarksSection() {
    final remarks = _rows(_insights['remarks']);
    return ReportSection(
      title: _t('Remarks'),
      icon: Icons.lightbulb_outline_rounded,
      subtitle: _t('Generated from the recorded data — factual observations, not judgments on individuals'),
      children: [
        if (remarks.isEmpty) RpEmpty(_t('No particular remark for the selected data.')),
        for (final r in remarks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RpBadge(
                r['kind'] == 'recorded' ? _t('Recorded data') : _t('Interpretation'),
                color: r['kind'] == 'recorded' ? kRpBlue : kRpAmber,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_s(r['text']))),
            ]),
          ),
      ],
    );
  }

  // ── 12. Qualité ───────────────────────────────────────────────────────────

  Widget _qualitySection() {
    final checks = _rows(_quality['checks']).where((c) => c['hidden'] != true).toList();
    final withIssues = checks.where((c) => (c['count'] as num) > 0).toList();
    return ReportSection(
      title: _t('Data quality'),
      icon: Icons.fact_check_rounded,
      subtitle: _s(_quality['disclaimer']),
      children: [
        if (withIssues.isEmpty) RpEmpty(_t('No data anomaly detected.')),
        if (withIssues.isNotEmpty)
          _table([
            RpCol(_t('Type'), (r) => _s(r['label'])),
            RpCol(_t('Count'), (r) => fmtNum(r['count']), numeric: true),
            RpCol(_t('Examples'), (r) => (r['examples'] as List? ?? []).join(' | ')),
            RpCol(_t('Potential impact'), (r) => _s(r['impact'])),
          ], withIssues, initialRows: 30),
      ],
    );
  }

  // ── 13. Recommandations ───────────────────────────────────────────────────

  Widget _recommendationsSection() {
    final recs = _rows(_insights['recommendations']);
    Widget step(String k, String v, Color c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 130, child: Text(k.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c))),
            Expanded(child: Text(v)),
          ]),
        );
    return ReportSection(
      title: _t('Recommendations'),
      icon: Icons.task_alt_rounded,
      subtitle: _t('Each recommendation is tied to a measured finding'),
      children: [
        if (recs.isEmpty) RpEmpty(_t('No recommendation: no measurable finding for the selected data.')),
        for (final r in recs)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              step(_t('Finding'), _s(r['finding']), kRpAmber),
              step(_t('Data'), _s(r['dataText']), kRpGrey),
              step(_t('Potential impact'), _s(r['impact']), kRpRed),
              step(_t('Recommendation'), _s(r['recommendation']), kRpGreen),
            ]),
          ),
      ],
    );
  }
}
