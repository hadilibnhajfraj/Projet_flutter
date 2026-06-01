// lib/dashboard/academic/view/dashboard_screen.dart
// Business Intelligence Dashboard — complete rewrite

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dash_master_toolkit/core/config/api_config.dart';
import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
import 'package:dash_master_toolkit/core/theme/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFFF8FAFC);
const _kCard   = Colors.white;
const _kBorder = Color(0xFFE2E8F0);
const _kText   = Color(0xFF1E293B);
const _kMuted  = Color(0xFF64748B);

// ─────────────────────────────────────────────────────────────────────────────
// KPI CARD CONFIG
// ─────────────────────────────────────────────────────────────────────────────
class _KpiCfg {
  final String   label;
  final IconData icon;
  final Color    g1, g2;
  const _KpiCfg({required this.label, required this.icon, required this.g1, required this.g2});
}

const _kKpis = [
  _KpiCfg(label: 'Total Projets',     icon: Icons.folder_copy_rounded,    g1: Color(0xFF4F46E5), g2: Color(0xFF6366F1)),
  _KpiCfg(label: 'Validés',           icon: Icons.check_circle_rounded,   g1: Color(0xFF059669), g2: Color(0xFF10B981)),
  _KpiCfg(label: 'Non validés',       icon: Icons.cancel_rounded,         g1: Color(0xFFDC2626), g2: Color(0xFFEF4444)),
  _KpiCfg(label: 'En attente',        icon: Icons.hourglass_top_rounded,  g1: Color(0xFFD97706), g2: Color(0xFFF59E0B)),
  _KpiCfg(label: 'Taux validation',   icon: Icons.percent_rounded,        g1: Color(0xFF0284C7), g2: Color(0xFF38BDF8)),
  _KpiCfg(label: 'Surface m²',        icon: Icons.square_foot_rounded,    g1: Color(0xFF7C3AED), g2: Color(0xFFA78BFA)),
];

// French month abbreviations
const _months = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
String _sf(dynamic v)   => (v == null || v.toString().trim().isEmpty) ? '' : v.toString().trim();
double _num(dynamic v)  => v is num ? v.toDouble() : double.tryParse(_sf(v)) ?? 0;

BoxDecoration _cardDeco([double r = 20]) => BoxDecoration(
  color: _kCard,
  borderRadius: BorderRadius.circular(r),
  border: Border.all(color: _kBorder, width: 0.8),
  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
);

Color _statutColor(String? s) {
  final l = (s ?? '').toLowerCase();
  if (l.contains('identif'))    return const Color(0xFF6B7280);
  if (l.contains('prospect'))   return const Color(0xFF3B82F6);
  if (l.contains('contact'))    return const Color(0xFF0EA5E9);
  if (l.contains('visite'))     return const Color(0xFF6366F1);
  if (l.contains('plan'))       return const Color(0xFF8B5CF6);
  if (l.contains('echant'))     return const Color(0xFF14B8A6);
  if (l.contains('devis'))      return const Color(0xFFF59E0B);
  if (l.contains('nego'))       return const Color(0xFFF97316);
  if (l.contains('gagn') || l.contains('valid') && !l.contains('non')) return const Color(0xFF22C55E);
  if (l.contains('perd') || l.contains('refus') || l.contains('non val')) return const Color(0xFFEF4444);
  if (l.contains('commande'))   return const Color(0xFF8B5CF6);
  if (l.contains('attente'))    return const Color(0xFFF59E0B);
  return const Color(0xFF94A3B8);
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  final String token;
  const DashboardScreen({super.key, required this.token});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Role ─────────────────────────────────────────────────────────────────
  bool _isAdmin = false;
  String _currentUserId = '';

  // ── Raw API data ─────────────────────────────────────────────────────────
  Map<String, dynamic> _kpiRaw   = {};
  List<dynamic>        _projects = [];
  bool                 _loading  = true;
  DateTime?            _lastUpdate;

  @override
  void initState() {
    super.initState();
    final auth = AuthService();
    final role = (auth.userRole ?? '').toLowerCase().trim();
    _isAdmin       = role == 'admin' || role == 'superadmin';
    _currentUserId = auth.userId ?? '';
    _loadAll();
  }

  // ── Load — branché par rôle ───────────────────────────────────────────────
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      // 1. KPI summary — admin gets all, user gets only their own
      final kpiUri = Uri.parse('${ApiConfig.baseUrl}/projects/dashboard/kpi').replace(
        queryParameters: (!_isAdmin && _currentUserId.isNotEmpty) ? {'userId': _currentUserId} : null,
      );
      final kpiRes = await http.get(kpiUri,
          headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'});
      if (kpiRes.statusCode == 200) {
        _kpiRaw = Map<String, dynamic>.from(jsonDecode(kpiRes.body));
      }

      // 2. Projects list:
      //    Admin → /projects (tous) | User → /projects/my-projects (les siens)
      final endpoint  = _isAdmin ? '/projects' : '/projects/my-projects';
      final queryParams = {'page': 1, 'limit': 1000};
      final projRes = await ApiClient.instance.dio.get(endpoint, queryParameters: queryParams);
      final projData = projRes.data;
      List raw = [];
      if (projData is Map) raw = (projData['items'] ?? projData['data'] ?? projData['results'] ?? []) as List;
      else if (projData is List) raw = projData;

      setState(() {
        _projects   = raw;
        _lastUpdate = DateTime.now();
      });
    } catch (e) {
      debugPrint('[Dashboard] $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Computed getters ──────────────────────────────────────────────────────
  List   get _userStats   => (_kpiRaw['userStats']   as List?) ?? [];
  List   get _statutStats => (_kpiRaw['statutStats'] as List?) ?? [];
  int    get _total       => _projects.length;
  int    get _validated   => _projects.where((p) {
    final v = _sf(p['validationStatut']).toLowerCase();
    return v.contains('valid') && !v.contains('non');
  }).length;
  int    get _nonValidated => _projects.where((p) {
    final v = _sf(p['validationStatut']).toLowerCase();
    return v.contains('non') || v.contains('refus');
  }).length;
  int    get _pending     => _total - _validated - _nonValidated;
  double get _validRate   => _total == 0 ? 0 : _validated / _total * 100;
  double get _surface     => _projects.fold(0, (s, p) => s + _num(p['surfaceProspectee']));

  int get _thisMonth {
    final now = DateTime.now();
    return _projects.where((p) {
      final d = DateTime.tryParse(_sf(p['createdAt']));
      return d != null && d.year == now.year && d.month == now.month;
    }).length;
  }
  int get _lastMonth {
    final now = DateTime.now();
    final lm  = now.month == 1 ? DateTime(now.year - 1, 12) : DateTime(now.year, now.month - 1);
    return _projects.where((p) {
      final d = DateTime.tryParse(_sf(p['createdAt']));
      return d != null && d.year == lm.year && d.month == lm.month;
    }).length;
  }

  String _variation(int current, int prev) {
    if (prev == 0) return current > 0 ? '+100%' : '—';
    final pct = ((current - prev) / prev * 100).round();
    return pct >= 0 ? '+$pct%' : '$pct%';
  }

  bool   _isUp(int current, int prev) => current >= prev;

  // Missing field counts
  int _missing(String Function(dynamic) field) =>
      _projects.where((p) => field(p).isEmpty).length;

  int get _missingBureau  => _missing((p) => _sf(p['bureauControle']));
  int get _missingArch    => _missing((p) => _sf(p['architecte']));
  int get _missingIng     => _missing((p) => _sf(p['ingenieurResponsable']));
  int get _missingTel     => _missing((p) => _sf(p['telephoneIngenieur'] ?? p['telephone']));
  int get _missingAddr    => _missing((p) => _sf(p['adresse']));

  List get _revendeurs   => _projects.where((p) => _sf(p['projectModele']).toLowerCase() == 'revendeur').toList();
  List get _applicateurs => _projects.where((p) => _sf(p['projectModele']).toLowerCase() == 'applicateur').toList();
  List get _relances     => _projects.where((p) => _sf(p['prochaineRelance']).isNotEmpty).toList()
    ..sort((a, b) => _sf(a['prochaineRelance']).compareTo(_sf(b['prochaineRelance'])));

  // Monthly data: last 6 months
  List<(String label, int created, int validated)> get _monthly {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final m    = DateTime(now.year, now.month - 5 + i);
      final lbl  = '${_months[m.month - 1]} ${m.year.toString().substring(2)}';
      final proj = _projects.where((p) {
        final d = DateTime.tryParse(_sf(p['createdAt']));
        return d != null && d.year == m.year && d.month == m.month;
      });
      final val = proj.where((p) {
        final v = _sf(p['validationStatut']).toLowerCase();
        return v.contains('valid') && !v.contains('non');
      }).length;
      return (lbl, proj.length, val);
    });
  }

  String get _lastUpdateStr => _lastUpdate == null
      ? '—'
      : DateFormat('dd/MM/yyyy HH:mm').format(_lastUpdate!);

  // Statut distribution computed directly from _projects (works for both roles)
  List<Map<String, dynamic>> get _computedStatutStats {
    final counts = <String, int>{};
    for (final p in _projects) {
      final s = _sf(p['statut'] ?? p['validationStatut']);
      if (s.isNotEmpty) counts[s] = (counts[s] ?? 0) + 1;
    }
    final list = counts.entries.map((e) => {'statut': e.key, 'count': e.value}).toList();
    list.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return list;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2),
            const SizedBox(height: 16),
            Text('Chargement du dashboard...', style: AppTextStyles.bodyMuted),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        color: const Color(0xFF4F46E5),
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              if (_isAdmin) ...[
                // ── ADMIN VIEW ──────────────────────────────────────────
                _buildAdminKpiRow(context),
                const SizedBox(height: 28),
                _buildStatusSection(context),
                const SizedBox(height: 28),
                _buildUserTable(context),
                const SizedBox(height: 28),
                _buildRevendeurApplicateurRow(context),
                const SizedBox(height: 28),
                _buildMonthlyChart(context),
                const SizedBox(height: 28),
                _buildAlerts(context),
                const SizedBox(height: 28),
                _buildRelances(context),
              ] else ...[
                // ── USER VIEW ───────────────────────────────────────────
                _buildUserKpiRow(context),
                const SizedBox(height: 28),
                _buildUserStatusSection(context),
                const SizedBox(height: 28),
                _buildMonthlyChart(context),
                const SizedBox(height: 28),
                _buildRelances(context),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. HEADER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    final subtitle = _isAdmin
        ? 'Vue globale des performances — $_total projets · ${_userStats.length} utilisateurs'
        : 'Mes performances personnelles — $_total projets';
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _isAdmin ? 'Business Intelligence Dashboard' : 'Mon Dashboard',
            style: AppTextStyles.pageTitle,
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTextStyles.bodyMuted),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
            const SizedBox(width: 5),
            Text('Dernière mise à jour : $_lastUpdateStr',
                style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
          ]),
        ]),
      ),
      const SizedBox(width: 16),
      // Role badge
      Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isAdmin ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
              size: 14, color: _isAdmin ? const Color(0xFF4F46E5) : const Color(0xFF22C55E)),
          const SizedBox(width: 5),
          Text(_isAdmin ? 'Admin' : 'Utilisateur',
              style: TextStyle(
                fontFamily: 'InterTight', fontSize: 11, fontWeight: FontWeight.w700,
                color: _isAdmin ? const Color(0xFF4F46E5) : const Color(0xFF22C55E),
              )),
        ]),
      ),
      TextButton.icon(
        onPressed: _loadAll,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Actualiser'),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF4F46E5),
          backgroundColor: const Color(0xFFEEF2FF),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontFamily: 'InterTight', fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2A. ADMIN KPI ROW  (7 cards)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAdminKpiRow(BuildContext context) {
    final w    = MediaQuery.of(context).size.width;
    final cols = w > 1300 ? 7 : w > 900 ? 4 : w > 600 ? 3 : 2;

    const cfgs = [
      _KpiCfg(label: 'Total Projets',     icon: Icons.folder_copy_rounded,     g1: Color(0xFF4F46E5), g2: Color(0xFF6366F1)),
      _KpiCfg(label: 'Utilisateurs',      icon: Icons.people_alt_rounded,      g1: Color(0xFF0284C7), g2: Color(0xFF38BDF8)),
      _KpiCfg(label: 'Applicateurs',      icon: Icons.brush_rounded,           g1: Color(0xFF7C3AED), g2: Color(0xFFA78BFA)),
      _KpiCfg(label: 'Revendeurs',        icon: Icons.storefront_rounded,      g1: Color(0xFFD97706), g2: Color(0xFFF59E0B)),
      _KpiCfg(label: 'Validés',           icon: Icons.check_circle_rounded,    g1: Color(0xFF059669), g2: Color(0xFF10B981)),
      _KpiCfg(label: 'Non validés',       icon: Icons.cancel_rounded,          g1: Color(0xFFDC2626), g2: Color(0xFFEF4444)),
      _KpiCfg(label: 'Surface m²',        icon: Icons.square_foot_rounded,     g1: Color(0xFF0E7490), g2: Color(0xFF06B6D4)),
    ];

    final surfStr = _surface >= 1000
        ? '${(_surface / 1000).toStringAsFixed(1)}k'
        : _surface.toStringAsFixed(0);

    final values = [
      '$_total',
      '${_userStats.length}',
      '${_applicateurs.length}',
      '${_revendeurs.length}',
      '$_validated',
      '$_nonValidated',
      surfStr,
    ];

    final variations = [
      _variation(_thisMonth, _lastMonth),
      '—', '—', '—',
      '—', '—', '—',
    ];

    return _ResponsiveGrid(
      cols: cols, gap: 14,
      children: List.generate(7, (i) => _KpiCard(
        cfg: cfgs[i], value: values[i], variation: variations[i],
        isUp: true,
      )),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2B. USER KPI ROW  (5 cards — only the user's own data)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildUserKpiRow(BuildContext context) {
    final w    = MediaQuery.of(context).size.width;
    final cols = w > 1000 ? 5 : w > 700 ? 3 : w > 500 ? 2 : 1;

    const cfgs = [
      _KpiCfg(label: 'Mes Projets',        icon: Icons.folder_copy_rounded,    g1: Color(0xFF4F46E5), g2: Color(0xFF6366F1)),
      _KpiCfg(label: 'Mes Validations',    icon: Icons.check_circle_rounded,   g1: Color(0xFF059669), g2: Color(0xFF10B981)),
      _KpiCfg(label: 'Mon Taux Réussite',  icon: Icons.percent_rounded,        g1: Color(0xFF0284C7), g2: Color(0xFF38BDF8)),
      _KpiCfg(label: 'Mes Relances',       icon: Icons.alarm_rounded,          g1: Color(0xFFD97706), g2: Color(0xFFF59E0B)),
      _KpiCfg(label: 'Ma Surface m²',      icon: Icons.square_foot_rounded,    g1: Color(0xFF7C3AED), g2: Color(0xFFA78BFA)),
    ];

    final surfStr = _surface >= 1000
        ? '${(_surface / 1000).toStringAsFixed(1)}k'
        : _surface.toStringAsFixed(0);

    final values = [
      '$_total',
      '$_validated',
      '${_validRate.toStringAsFixed(1)}%',
      '${_relances.length}',
      surfStr,
    ];

    final variations = [
      _variation(_thisMonth, _lastMonth),
      '—', '—', '—', '—',
    ];

    return _ResponsiveGrid(
      cols: cols, gap: 14,
      children: List.generate(5, (i) => _KpiCard(
        cfg: cfgs[i], value: values[i], variation: variations[i],
        isUp: true,
      )),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3B. USER STATUS SECTION  (only user's own projects)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildUserStatusSection(BuildContext context) {
    final stats = _computedStatutStats;
    final w = MediaQuery.of(context).size.width;

    Widget donut = Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('Mes projets par statut'),
        const SizedBox(height: 16),
        stats.isEmpty ? _emptyState('Aucun projet') : _buildDonutFromList(stats),
      ]),
    );

    Widget bars = Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('Volume par statut'),
        const SizedBox(height: 16),
        stats.isEmpty ? _emptyState('Aucun projet') : _buildHBarsFromList(stats),
      ]),
    );

    return w > 800
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: donut), const SizedBox(width: 16), Expanded(child: bars),
          ])
        : Column(children: [donut, const SizedBox(height: 16), bars]);
  }

  // ── Donut + HBars from a computed list ────────────────────────────────────
  Widget _buildDonutFromList(List<Map<String, dynamic>> stats) {
    final total = stats.fold<double>(0, (s, e) => s + _num(e['count']));
    if (total == 0) return _emptyState('Aucune donnée');
    return Column(children: [
      SizedBox(
        height: 220,
        child: PieChart(PieChartData(
          centerSpaceRadius: 55,
          sectionsSpace: 2,
          sections: stats.asMap().entries.map((en) {
            final count = _num(en.value['count']);
            final pct   = count / total * 100;
            final color = _statutColor(_sf(en.value['statut']));
            return PieChartSectionData(
              value: count, color: color, radius: 50,
              title: '${pct.toStringAsFixed(0)}%',
              titleStyle: const TextStyle(fontFamily: 'InterTight', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
            );
          }).toList(),
        )),
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 12, runSpacing: 6, children: stats.map((s) {
        final color = _statutColor(_sf(s['statut']));
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text('${_sf(s['statut'])} (${_num(s['count']).toInt()})', style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
        ]);
      }).toList()),
    ]);
  }

  Widget _buildHBarsFromList(List<Map<String, dynamic>> stats) {
    final max = stats.fold<double>(0, (m, e) => _num(e['count']) > m ? _num(e['count']) : m);
    if (max == 0) return _emptyState('Aucune donnée');
    return Column(children: stats.map((s) {
      final count = _num(s['count']);
      final color = _statutColor(_sf(s['statut']));
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 110, child: Text(_sf(s['statut']), style: AppTextStyles.bodyMuted.copyWith(fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: max == 0 ? 0 : count / max, minHeight: 18,
                  backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation(color)))),
          const SizedBox(width: 8),
          SizedBox(width: 28, child: Text('${count.toInt()}', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.right)),
        ]),
      );
    }).toList());
  }

  // ── keep old _buildKpiRow name as alias so nothing else breaks ────────────
  Widget _buildKpiRow(BuildContext context) => _buildAdminKpiRow(context);

  // (existing _buildStatusSection reads _statutStats from API — kept for admin)
  // dummy placeholder for the old reference:
  Widget _buildOldKpiRow(BuildContext context) {
    final w    = MediaQuery.of(context).size.width;
    final cols = w > 1200 ? 6 : w > 800 ? 3 : w > 550 ? 2 : 1;

    final values = [
      '$_total',
      '$_validated',
      '$_nonValidated',
      '$_pending',
      '${_validRate.toStringAsFixed(1)}%',
      _surface >= 1000
          ? '${(_surface / 1000).toStringAsFixed(1)}k'
          : _surface.toStringAsFixed(0),
    ];

    final variations = [
      _variation(_thisMonth, _lastMonth),
      _variation(
        _projects.where((p) {
          final v = _sf(p['validationStatut']).toLowerCase();
          final d = DateTime.tryParse(_sf(p['createdAt']));
          final now = DateTime.now();
          return d != null && d.year == now.year && d.month == now.month &&
              v.contains('valid') && !v.contains('non');
        }).length,
        0,
      ),
      '—', '—', '—', '—',
    ];

    return _ResponsiveGrid(
      cols: cols,
      gap: 14,
      children: List.generate(6, (i) => _KpiCard(
        cfg:       _kKpis[i],
        value:     values[i],
        variation: variations[i],
        isUp:      !variations[i].startsWith('-'),
      )),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. STATUS SECTION  (donut + horizontal bars)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStatusSection(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Répartition par statut'),
        const SizedBox(height: 16),
        _statutStats.isEmpty
            ? _emptyState('Aucun statut disponible')
            : _buildDonut(),
      ],
    );

    final bars = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Volume par statut'),
        const SizedBox(height: 16),
        _statutStats.isEmpty
            ? _emptyState('Aucun statut disponible')
            : _buildHBars(),
      ],
    );

    final cardL = Container(padding: const EdgeInsets.all(24), decoration: _cardDeco(), child: side);
    final cardR = Container(padding: const EdgeInsets.all(24), decoration: _cardDeco(), child: bars);

    return w > 800
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: cardL),
            const SizedBox(width: 16),
            Expanded(child: cardR),
          ])
        : Column(children: [cardL, const SizedBox(height: 16), cardR]);
  }

  Widget _buildDonut() {
    final total = _statutStats.fold<double>(0, (s, e) => s + _num(e['count']));
    if (total == 0) return _emptyState('Aucune donnée');

    return Column(children: [
      SizedBox(
        height: 220,
        child: PieChart(PieChartData(
          centerSpaceRadius: 55,
          sectionsSpace: 2,
          sections: _statutStats.asMap().entries.map((en) {
            final s     = en.value;
            final count = _num(s['count']);
            final pct   = count / total * 100;
            final color = _statutColor(_sf(s['statut']));
            return PieChartSectionData(
              value: count,
              color: color,
              radius: 50,
              title: '${pct.toStringAsFixed(0)}%',
              titleStyle: const TextStyle(fontFamily: 'InterTight', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
            );
          }).toList(),
        )),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12, runSpacing: 8,
        children: _statutStats.map((s) {
          final color = _statutColor(_sf(s['statut']));
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text('${_sf(s['statut'])} (${_num(s['count']).toInt()})',
                style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
          ]);
        }).toList(),
      ),
    ]);
  }

  Widget _buildHBars() {
    final max = _statutStats.fold<double>(0, (m, e) => _num(e['count']) > m ? _num(e['count']) : m);
    if (max == 0) return _emptyState('Aucune donnée');
    return Column(
      children: _statutStats.map((s) {
        final count = _num(s['count']);
        final frac  = max == 0 ? 0.0 : count / max;
        final color = _statutColor(_sf(s['statut']));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(
              width: 120,
              child: Text(_sf(s['statut']), style: AppTextStyles.bodyMuted.copyWith(fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: frac.toDouble(),
                  minHeight: 18,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              child: Text('${count.toInt()}',
                  style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                  textAlign: TextAlign.right),
            ),
          ]),
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 4. USER PERFORMANCE TABLE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildUserTable(BuildContext context) {
    // Enrich userStats with validated count from _projects
    final valByUser = <String, int>{};
    for (final p in _projects) {
      final userMap = p['user'] is Map ? p['user'] as Map : {};
      final uid = _sf(userMap['_id'] ?? userMap['id'] ?? p['userId']);
      final v   = _sf(p['validationStatut']).toLowerCase();
      if (uid.isNotEmpty && v.contains('valid') && !v.contains('non')) {
        valByUser[uid] = (valByUser[uid] ?? 0) + 1;
      }
    }

    final users = List<Map>.from(_userStats)
      ..sort((a, b) => (_num(b['count']) - _num(a['count'])).toInt());
    final top10 = users.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('Top 10 — Performance Utilisateurs', badge: '${top10.length}'),
        const SizedBox(height: 20),
        if (top10.isEmpty)
          _emptyState('Aucun utilisateur')
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 60,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingTextStyle: AppTextStyles.tableHeader,
              dividerThickness: 0.5,
              columns: const [
                DataColumn(label: Text('UTILISATEUR')),
                DataColumn(label: Text('EMAIL')),
                DataColumn(label: Text('NB PROJETS'), numeric: true),
                DataColumn(label: Text('VALIDÉS'), numeric: true),
                DataColumn(label: Text('NON VALIDÉS'), numeric: true),
                DataColumn(label: Text('TAUX RÉUSSITE')),
              ],
              rows: top10.asMap().entries.map((en) {
                final u       = en.value;
                final total   = _num(u['count']).toInt();
                final uid     = _sf(u['userId'] ?? u['_id']);
                final valid   = valByUser[uid] ?? 0;
                final nonVal  = total - valid;
                final rate    = total == 0 ? 0.0 : valid / total * 100;

                return DataRow(cells: [
                  DataCell(Row(children: [
                    _avatar(_sf(u['userName'] ?? u['name'] ?? u['nom']), en.key),
                    const SizedBox(width: 10),
                    Text(_sf(u['userName'] ?? u['name'] ?? u['nom']),
                        style: const TextStyle(fontFamily: 'InterTight', fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
                  ])),
                  DataCell(Text(_sf(u['userEmail'] ?? u['email']),
                      style: AppTextStyles.bodyMuted.copyWith(fontSize: 12))),
                  DataCell(_statBadge('$total', const Color(0xFF4F46E5))),
                  DataCell(_statBadge('$valid', const Color(0xFF22C55E))),
                  DataCell(_statBadge('$nonVal', nonVal > 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8))),
                  DataCell(_rateBar(rate)),
                ]);
              }).toList(),
            ),
          ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 5. REVENDEUR + APPLICATEUR (side by side)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildRevendeurApplicateurRow(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final rv = _buildModelTable('Top Revendeurs', _revendeurs, ['Nom','Email','Projets','Surface','Validation']);
    final ap = _buildModelTable('Top Applicateurs', _applicateurs, ['Nom','Email','Projets','Surface','Validation']);
    return w > 900
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: rv), const SizedBox(width: 16), Expanded(child: ap),
          ])
        : Column(children: [rv, const SizedBox(height: 16), ap]);
  }

  Widget _buildModelTable(String title, List items, List<String> cols) {
    final top = items.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(title, badge: '${items.length}'),
        const SizedBox(height: 16),
        if (top.isEmpty)
          _emptyState('Aucun élément')
        else
          ...top.asMap().entries.map((en) {
            final p    = en.value;
            final name = _sf(p['nomProjet'] ?? p['name']);
            final email = _sf(p['user'] is Map ? (p['user'] as Map)['email'] : p['userEmail']);
            final surf = _num(p['surfaceProspectee']);
            final val  = _sf(p['validationStatut']);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                _avatar(name, en.key),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.isNotEmpty ? name : '—',
                      style: const TextStyle(fontFamily: 'InterTight', fontSize: 12, fontWeight: FontWeight.w600, color: _kText),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(email.isNotEmpty ? email : '—',
                      style: AppTextStyles.bodyMuted.copyWith(fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 8),
                if (surf > 0)
                  Text('${surf.toStringAsFixed(0)} m²', style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
                const SizedBox(width: 8),
                if (val.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statutColor(val).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(val, style: TextStyle(fontFamily: 'InterTight', fontSize: 10, fontWeight: FontWeight.w700, color: _statutColor(val))),
                  ),
              ]),
            );
          }),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 6. MONTHLY EVOLUTION  (line chart)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMonthlyChart(BuildContext context) {
    final data = _monthly;
    final maxY = data.fold<int>(0, (m, d) => d.$2 > m ? d.$2 : m) + 2;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _sectionHeader('Évolution mensuelle des projets')),
          _legend(const Color(0xFF4F46E5), 'Créations'),
          const SizedBox(width: 12),
          _legend(const Color(0xFF22C55E), 'Validations'),
        ]),
        const SizedBox(height: 24),
        SizedBox(
          height: 220,
          child: data.every((d) => d.$2 == 0 && d.$3 == 0)
              ? _emptyState('Aucune donnée mensuelle')
              : LineChart(LineChartData(
                  minY: 0,
                  maxY: maxY.toDouble(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY / 4).ceilToDouble(),
                    getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      interval: (maxY / 4).ceilToDouble(),
                      reservedSize: 30,
                      getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: AppTextStyles.chartAxis),
                    )),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox();
                        return Padding(padding: const EdgeInsets.only(top: 6),
                            child: Text(data[i].$1, style: AppTextStyles.chartAxis));
                      },
                    )),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.$2.toDouble())).toList(),
                      isCurved: true, curveSmoothness: 0.35,
                      color: const Color(0xFF4F46E5),
                      barWidth: 2.5,
                      dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: const Color(0xFF4F46E5))),
                      belowBarData: BarAreaData(show: true, color: const Color(0xFF4F46E5).withOpacity(0.08)),
                    ),
                    LineChartBarData(
                      spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.$3.toDouble())).toList(),
                      isCurved: true, curveSmoothness: 0.35,
                      color: const Color(0xFF22C55E),
                      barWidth: 2.5,
                      dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: const Color(0xFF22C55E))),
                      belowBarData: BarAreaData(show: true, color: const Color(0xFF22C55E).withOpacity(0.06)),
                    ),
                  ],
                )),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 7. ALERTS  (missing fields)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAlerts(BuildContext context) {
    final alerts = [
      (label: 'Bureau de contrôle manquant', icon: Icons.domain_disabled_rounded,  count: _missingBureau, color: const Color(0xFFEF4444)),
      (label: 'Architecte manquant',         icon: Icons.architecture_rounded,      count: _missingArch,   color: const Color(0xFFF97316)),
      (label: 'Ingénieur manquant',          icon: Icons.engineering_rounded,       count: _missingIng,    color: const Color(0xFFF59E0B)),
      (label: 'Téléphone manquant',          icon: Icons.phone_disabled_rounded,    count: _missingTel,    color: const Color(0xFF8B5CF6)),
      (label: 'Adresse manquante',           icon: Icons.location_off_rounded,      count: _missingAddr,   color: const Color(0xFF3B82F6)),
    ];

    final w    = MediaQuery.of(context).size.width;
    final cols = w > 1100 ? 5 : w > 700 ? 3 : 2;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Alertes — Champs manquants'),
      const SizedBox(height: 16),
      _ResponsiveGrid(
        cols: cols, gap: 12,
        children: alerts.map((a) => _AlertCard(label: a.label, icon: a.icon, count: a.count, color: a.color, total: _total)).toList(),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 8. RELANCES TABLE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildRelances(BuildContext context) {
    final top = _relances.take(10).toList();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('Relances à venir', badge: '${_relances.length}'),
        const SizedBox(height: 20),
        if (top.isEmpty)
          _emptyState('Aucune relance planifiée')
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 60,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingTextStyle: AppTextStyles.tableHeader,
              dividerThickness: 0.5,
              columns: const [
                DataColumn(label: Text('PROJET')),
                DataColumn(label: Text('UTILISATEUR')),
                DataColumn(label: Text('STATUT')),
                DataColumn(label: Text('DERNIÈRE RELANCE')),
                DataColumn(label: Text('PROCHAINE RELANCE')),
              ],
              rows: top.map((p) {
                final statut   = _sf(p['statut'] ?? p['validationStatut']);
                final userMap  = p['user'] is Map ? p['user'] as Map : {};
                final user     = _sf(userMap['nom'] ?? userMap['name'] ?? p['user_nom']);
                final last     = _fmtDate(_sf(p['derniereRelance'] ?? p['lastRelanceAt']));
                final next     = _sf(p['prochaineRelance'] ?? p['nextRelanceAt']);
                final nextDt   = DateTime.tryParse(next);
                final isUrgent = nextDt != null && nextDt.isBefore(DateTime.now().add(const Duration(days: 3)));

                return DataRow(cells: [
                  DataCell(Text(_sf(p['nomProjet'] ?? p['name']),
                      style: const TextStyle(fontFamily: 'InterTight', fontSize: 12, fontWeight: FontWeight.w600, color: _kText))),
                  DataCell(Text(user.isNotEmpty ? user : '—', style: AppTextStyles.bodyMuted.copyWith(fontSize: 12))),
                  DataCell(statut.isEmpty ? const Text('—') : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _statutColor(statut).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(statut, style: TextStyle(fontFamily: 'InterTight', fontSize: 10, fontWeight: FontWeight.w700, color: _statutColor(statut))),
                  )),
                  DataCell(Text(last.isNotEmpty ? last : '—', style: AppTextStyles.bodyMuted.copyWith(fontSize: 12))),
                  DataCell(Row(children: [
                    if (isUrgent) const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEF4444)),
                    ),
                    Text(_fmtDate(next).isNotEmpty ? _fmtDate(next) : '—',
                        style: TextStyle(fontFamily: 'InterTight', fontSize: 12, fontWeight: FontWeight.w600,
                            color: isUrgent ? const Color(0xFFEF4444) : _kMuted)),
                  ])),
                ]);
              }).toList(),
            ),
          ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _sectionHeader(String title, {String? badge}) => Row(children: [
    Text(title, style: AppTextStyles.cardTitle),
    if (badge != null) ...[
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(20)),
        child: Text(badge, style: const TextStyle(fontFamily: 'InterTight', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
      ),
    ],
  ]);

  Widget _emptyState(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_rounded, size: 40, color: Colors.grey[300]),
        const SizedBox(height: 10),
        Text(msg, style: AppTextStyles.bodyMuted),
      ]),
    ),
  );

  Widget _avatar(String name, int idx) {
    const colors = [Color(0xFF4F46E5), Color(0xFF22C55E), Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6)];
    final color  = colors[idx % colors.length];
    final init   = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: Text(init, style: TextStyle(fontFamily: 'InterTight', fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _statBadge(String v, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(v, style: TextStyle(fontFamily: 'InterTight', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
  );

  Widget _rateBar(double rate) => SizedBox(
    width: 100,
    child: Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate / 100,
            minHeight: 6,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation(rate >= 70 ? const Color(0xFF22C55E) : rate >= 40 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text('${rate.toStringAsFixed(0)}%', style: AppTextStyles.bodyMuted.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 5),
    Text(label, style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
  ]);

  String _fmtDate(String v) {
    if (v.isEmpty) return '';
    try { return DateFormat('dd/MM/yyyy').format(DateTime.parse(v)); } catch (_) { return v; }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI CARD WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.cfg, required this.value, required this.variation, required this.isUp});
  final _KpiCfg  cfg;
  final String   value;
  final String   variation;
  final bool     isUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cfg.g1, cfg.g2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: cfg.g1.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(cfg.icon, size: 20, color: Colors.white),
          ),
          const Spacer(),
          if (variation != '—')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 12, color: Colors.white),
                const SizedBox(width: 3),
                Text(variation, style: const TextStyle(fontFamily: 'InterTight', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
        ]),
        const SizedBox(height: 16),
        Text(value, style: const TextStyle(fontFamily: 'InterTight', fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1, height: 1)),
        const SizedBox(height: 6),
        Text(cfg.label, style: const TextStyle(fontFamily: 'InterTight', fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT CARD WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.label, required this.icon, required this.count, required this.color, required this.total});
  final String   label;
  final IconData icon;
  final int      count;
  final Color    color;
  final int      total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: count > 0 ? color.withOpacity(0.3) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const Spacer(),
          Text('$count', style: TextStyle(fontFamily: 'InterTight', fontSize: 22, fontWeight: FontWeight.w800, color: count > 0 ? color : const Color(0xFF94A3B8))),
        ]),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontFamily: 'InterTight', fontSize: 11, fontWeight: FontWeight.w600, color: _kText), maxLines: 2),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 4,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation(count > 0 ? color : const Color(0xFF94A3B8)),
          ),
        ),
        const SizedBox(height: 4),
        Text(total > 0 ? '${(pct * 100).toStringAsFixed(0)}% des projets' : '—',
            style: AppTextStyles.bodyMuted.copyWith(fontSize: 10)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE GRID
// ─────────────────────────────────────────────────────────────────────────────
class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.cols, required this.gap, required this.children});
  final int         cols;
  final double      gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += cols) {
      final rowChildren = children.sublist(i, (i + cols).clamp(0, children.length));
      while (rowChildren.length < cols) rowChildren.add(const SizedBox());
      // IntrinsicHeight résout la hauteur sans contrainte infinie
      // (CrossAxisAlignment.stretch interdit dans SingleChildScrollView)
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rowChildren.asMap().entries.map((e) {
            return Expanded(child: Padding(
              padding: EdgeInsets.only(left: e.key == 0 ? 0 : gap),
              child: e.value,
            ));
          }).toList(),
        ),
      ));
      if (i + cols < children.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }
}
