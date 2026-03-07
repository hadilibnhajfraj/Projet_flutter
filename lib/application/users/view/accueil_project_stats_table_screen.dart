import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dash_master_toolkit/application/users/model/project_stats_model.dart';
import 'package:dash_master_toolkit/application/users/model/project_stats_row_model.dart';
import 'package:dash_master_toolkit/services/project_stats_service.dart';

class AccueilProjectStatsTableScreen extends StatefulWidget {
  final String token;
  final String userRole;

  const AccueilProjectStatsTableScreen({
    super.key,
    required this.token,
    required this.userRole,
  });

  @override
  State<AccueilProjectStatsTableScreen> createState() =>
      _AccueilProjectStatsTableScreenState();
}

class _AccueilProjectStatsTableScreenState
    extends State<AccueilProjectStatsTableScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<UserProjectSummary>> _future;
  late TabController _tabController;

  final service = ProjectStatsService(
    baseUrl: 'http://localhost:4000',
  );

  static const Color kPrimary = Color(0xFF1F6FEB);
  static const Color kBg = Color(0xFFF4F7FC);
  static const Color kCard = Colors.white;
  static const Color kBorder = Color(0xFFE5EAF2);
  static const Color kTextDark = Color(0xFF111827);
  static const Color kTextMuted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final role = widget.userRole.trim().toLowerCase();
    if (role == 'accueil') {
      _future = service.fetchProjectsPerUserSummary(token: widget.token);
    } else {
      _future = Future.value(<UserProjectSummary>[]);
    }
  }

  List<ProjectStatsRow> _buildDailyRows(List<UserProjectSummary> items) {
    final List<ProjectStatsRow> rows = [];
    for (final user in items) {
      for (final d in user.daily) {
        rows.add(
          ProjectStatsRow(
            userId: user.userId,
            displayName: user.displayName,
            email: user.email,
            periodType: 'Journalier',
            periodLabel: d.day,
            projectsCount: d.projectsCount,
            totalProjects: user.totalProjects,
          ),
        );
      }
    }
    return rows;
  }

  List<ProjectStatsRow> _buildWeeklyRows(List<UserProjectSummary> items) {
    final List<ProjectStatsRow> rows = [];
    for (final user in items) {
      for (final w in user.weekly) {
        rows.add(
          ProjectStatsRow(
            userId: user.userId,
            displayName: user.displayName,
            email: user.email,
            periodType: 'Hebdomadaire',
            periodLabel: w.weekStart,
            projectsCount: w.projectsCount,
            totalProjects: user.totalProjects,
          ),
        );
      }
    }
    return rows;
  }

  List<ProjectStatsRow> _buildMonthlyRows(List<UserProjectSummary> items) {
    final List<ProjectStatsRow> rows = [];
    for (final user in items) {
      for (final m in user.monthly) {
        rows.add(
          ProjectStatsRow(
            userId: user.userId,
            displayName: user.displayName,
            email: user.email,
            periodType: 'Mensuel',
            periodLabel: m.month,
            projectsCount: m.projectsCount,
            totalProjects: user.totalProjects,
          ),
        );
      }
    }
    return rows;
  }

  int _sumProjects(List<ProjectStatsRow> rows) {
    return rows.fold(0, (sum, row) => sum + row.projectsCount);
  }

  int _countUsers(List<UserProjectSummary> items) => items.length;

  @override
  Widget build(BuildContext context) {
    final role = widget.userRole.trim().toLowerCase();

    if (role != 'accueil') {
      return Scaffold(
        backgroundColor: kBg,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              'Accès réservé au rôle accueil. Rôle reçu: "$role"',
              style: const TextStyle(
                fontSize: 16,
                color: kTextDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBg,
      body: FutureBuilder<List<UserProjectSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  'Erreur: ${snapshot.error}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Aucune donnée trouvée.',
                style: TextStyle(fontSize: 16, color: kTextMuted),
              ),
            );
          }

          final dailyRows = _buildDailyRows(items);
          final weeklyRows = _buildWeeklyRows(items);
          final monthlyRows = _buildMonthlyRows(items);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistiques des projets',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: kTextDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Analyse détaillée des projets par utilisateur avec filtres, recherche, tri et export CSV.',
                  style: TextStyle(
                    fontSize: 15,
                    color: kTextMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _KpiCard(
                      title: 'Utilisateurs suivis',
                      value: _countUsers(items).toString(),
                      icon: Icons.people_alt_rounded,
                      color: kPrimary,
                    ),
                    _KpiCard(
                      title: 'Total journalier',
                      value: _sumProjects(dailyRows).toString(),
                      icon: Icons.today_rounded,
                      color: const Color(0xFF0EA5E9),
                    ),
                    _KpiCard(
                      title: 'Total hebdomadaire',
                      value: _sumProjects(weeklyRows).toString(),
                      icon: Icons.calendar_view_week_rounded,
                      color: const Color(0xFF10B981),
                    ),
                    _KpiCard(
                      title: 'Total mensuel',
                      value: _sumProjects(monthlyRows).toString(),
                      icon: Icons.bar_chart_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: kBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 22,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Row(
                          children: [
                            Icon(Icons.insights_rounded, color: kPrimary, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Tableau analytique',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: kTextDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: kPrimary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x332563EB),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          dividerColor: Colors.transparent,
                          labelColor: Colors.white,
                          unselectedLabelColor: kTextDark,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          tabs: const [
                            Tab(text: 'Journalier'),
                            Tab(text: 'Hebdomadaire'),
                            Tab(text: 'Mensuel'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 700,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            StatsDataTable(
                              rows: dailyRows,
                              title: 'Suivi journalier',
                              periodLabelTitle: 'Date',
                              csvFileName: 'stats_journalieres',
                              badgeColor: const Color(0xFFDBEAFE),
                              badgeTextColor: const Color(0xFF1D4ED8),
                            ),
                            StatsDataTable(
                              rows: weeklyRows,
                              title: 'Suivi hebdomadaire',
                              periodLabelTitle: 'Semaine',
                              csvFileName: 'stats_hebdomadaires',
                              badgeColor: const Color(0xFFD1FAE5),
                              badgeTextColor: const Color(0xFF047857),
                            ),
                            StatsDataTable(
                              rows: monthlyRows,
                              title: 'Suivi mensuel',
                              periodLabelTitle: 'Mois',
                              csvFileName: 'stats_mensuelles',
                              badgeColor: const Color(0xFFFEF3C7),
                              badgeTextColor: const Color(0xFFB45309),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatsDataTable extends StatefulWidget {
  final List<ProjectStatsRow> rows;
  final String title;
  final String periodLabelTitle;
  final String csvFileName;
  final Color badgeColor;
  final Color badgeTextColor;

  const StatsDataTable({
    super.key,
    required this.rows,
    required this.title,
    required this.periodLabelTitle,
    required this.csvFileName,
    required this.badgeColor,
    required this.badgeTextColor,
  });

  @override
  State<StatsDataTable> createState() => _StatsDataTableState();
}

class _StatsDataTableState extends State<StatsDataTable> {
  static const Color kPrimary = Color(0xFF1F6FEB);
  static const Color kBorder = Color(0xFFE5EAF2);
  static const Color kTextDark = Color(0xFF111827);
  static const Color kTextMuted = Color(0xFF6B7280);

  final TextEditingController _searchCtrl = TextEditingController();

  String _search = '';
  String _selectedUser = 'Tous';
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  int _rowsPerPage = 5;

  List<ProjectStatsRow> get _filteredRows {
    List<ProjectStatsRow> data = List<ProjectStatsRow>.from(widget.rows);

    if (_selectedUser != 'Tous') {
      data = data.where((e) => e.displayName == _selectedUser).toList();
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase().trim();
      data = data.where((e) {
        return e.displayName.toLowerCase().contains(q) ||
            e.email.toLowerCase().contains(q) ||
            e.periodLabel.toLowerCase().contains(q) ||
            e.projectsCount.toString().contains(q) ||
            e.totalProjects.toString().contains(q);
      }).toList();
    }

    data.sort((a, b) {
      dynamic av;
      dynamic bv;

      switch (_sortColumnIndex) {
        case 0:
          av = a.displayName.toLowerCase();
          bv = b.displayName.toLowerCase();
          break;
        case 1:
          av = a.email.toLowerCase();
          bv = b.email.toLowerCase();
          break;
        case 2:
          av = a.periodLabel;
          bv = b.periodLabel;
          break;
        case 3:
          av = a.projectsCount;
          bv = b.projectsCount;
          break;
        case 4:
          av = a.totalProjects;
          bv = b.totalProjects;
          break;
        default:
          av = a.displayName.toLowerCase();
          bv = b.displayName.toLowerCase();
      }

      final result = Comparable.compare(av, bv);
      return _sortAscending ? result : -result;
    });

    return data;
  }

  List<String> get _userOptions {
    final users = widget.rows.map((e) => e.displayName).toSet().toList()..sort();
    return ['Tous', ...users];
  }

  int get _activeProjectsCount {
    return _filteredRows.fold(0, (sum, e) => sum + e.projectsCount);
  }

  void _sort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  void _exportCsv() {
    final rows = _filteredRows;

    final buffer = StringBuffer();
    buffer.writeln('Utilisateur,Email,${widget.periodLabelTitle},Nb projets,Total projets,Statut');

    for (final r in rows) {
      final statut = r.projectsCount > 0 ? 'Actif' : 'Vide';
      buffer.writeln(
        '"${_escapeCsv(r.displayName)}","${_escapeCsv(r.email)}","${_escapeCsv(r.periodLabel)}","${r.projectsCount}","${r.totalProjects}","$statut"',
      );
    }

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '${widget.csvFileName}.csv')
      ..click();

    html.Url.revokeObjectUrl(url);
    anchor.remove();
  }

  String _escapeCsv(String value) {
    return value.replaceAll('"', '""');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredRows;
    final source = _StatsTableSource(rows);

    final availableOptions = <int>[5, 10, 20, 50]
        .where((e) => e <= rows.length)
        .toList();

    final effectiveOptions = availableOptions.isEmpty ? <int>[5] : availableOptions;

    final effectiveRowsPerPage = effectiveOptions.contains(_rowsPerPage)
        ? _rowsPerPage
        : effectiveOptions.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${rows.length} lignes',
                  style: TextStyle(
                    color: widget.badgeTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Total filtré: $_activeProjectsCount',
                  style: const TextStyle(
                    color: Color(0xFF4338CA),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: rows.isEmpty ? null : _exportCsv,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Exporter CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kBorder),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (value) => setState(() => _search = value),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par utilisateur, email, période...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kPrimary, width: 1.4),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUser,
                    items: _userOptions
                        .map(
                          (user) => DropdownMenuItem<String>(
                            value: user,
                            child: Text(user),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedUser = value ?? 'Tous';
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Filtrer par utilisateur',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kPrimary, width: 1.4),
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _search = '';
                      _selectedUser = 'Tous';
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réinitialiser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTextDark,
                    side: const BorderSide(color: kBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  cardColor: Colors.white,
                  dividerColor: kBorder,
                ),
                child: PaginatedDataTable(
                  header: Row(
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: kTextDark,
                        ),
                      ),
                    ],
                  ),
                  showCheckboxColumn: false,
                  rowsPerPage: effectiveRowsPerPage,
                  availableRowsPerPage: effectiveOptions,
                  onRowsPerPageChanged: (value) {
                    if (value != null) {
                      setState(() => _rowsPerPage = value);
                    }
                  },
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  columnSpacing: 28,
                  horizontalMargin: 20,
                  headingRowHeight: 58,
                  dataRowMinHeight: 64,
                  dataRowMaxHeight: 70,
                  columns: [
                    DataColumn(
                      label: const Text(
                        'Utilisateur',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onSort: (columnIndex, ascending) =>
                          _sort(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: const Text(
                        'Email',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onSort: (columnIndex, ascending) =>
                          _sort(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: Text(
                        widget.periodLabelTitle,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onSort: (columnIndex, ascending) =>
                          _sort(columnIndex, ascending),
                    ),
                    DataColumn(
                      numeric: true,
                      label: const Text(
                        'Nb projets',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onSort: (columnIndex, ascending) =>
                          _sort(columnIndex, ascending),
                    ),
                    DataColumn(
                      numeric: true,
                      label: const Text(
                        'Total projets',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onSort: (columnIndex, ascending) =>
                          _sort(columnIndex, ascending),
                    ),
                    const DataColumn(
                      label: Text(
                        'Statut',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  source: source,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsTableSource extends DataTableSource {
  final List<ProjectStatsRow> rows;

  _StatsTableSource(this.rows);

  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;

    final r = rows[index];
    final isEven = index.isEven;

    return DataRow.byIndex(
      index: index,
      color: WidgetStateProperty.resolveWith<Color?>(
        (states) => isEven ? Colors.white : const Color(0xFFFBFDFF),
      ),
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFDBEAFE),
                child: Text(
                  r.displayName.isNotEmpty ? r.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: Text(
                  r.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
        ),
        DataCell(
          SizedBox(
            width: 220,
            child: Text(
              r.email,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            r.periodLabel,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              r.projectsCount.toString(),
              style: const TextStyle(
                color: Color(0xFF4338CA),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            r.totalProjects.toString(),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: r.projectsCount > 0
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              r.projectsCount > 0 ? 'Actif' : 'Vide',
              style: TextStyle(
                color: r.projectsCount > 0
                    ? const Color(0xFF166534)
                    : const Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => rows.length;

  @override
  int get selectedRowCount => 0;
}