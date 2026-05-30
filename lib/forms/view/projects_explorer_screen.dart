// lib/forms/view/projects_explorer_screen.dart
import 'dart:html' as html;

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ──────────────────────────────────────────────────────────────────────────────
const _kDivider  = Color(0xFFF1F5F9);    // très légère — invisible à l'oeil
const _kRowHover = Color(0xFFF8FAFC);
const _kHeader   = Color(0xFFF8FAFC);

// ──────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ──────────────────────────────────────────────────────────────────────────────
class _Row {
  final String id;
  final String name;
  final String type;          // 'project' | 'applicateur' | 'revendeur'
  final String ownerName;
  final String ownerEmail;
  final String createdAt;
  final String status;
  final String validation;
  final bool   isArchived;
  // Extra fields for export
  final String adresse;
  final String entreprise;
  final String architecte;
  final String ingenieur;
  final double? lat;
  final double? lng;

  _Row({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerName,
    required this.ownerEmail,
    required this.createdAt,
    required this.status,
    required this.validation,
    required this.isArchived,
    this.adresse    = '',
    this.entreprise = '',
    this.architecte = '',
    this.ingenieur  = '',
    this.lat,
    this.lng,
  });

  factory _Row.fromJson(Map<String, dynamic> j) {
    final modele = _s(j['projectModele'] ?? '').toLowerCase();
    String type = 'project';
    if (modele.contains('applicateur')) type = 'applicateur';
    if (modele.contains('revendeur'))   type = 'revendeur';

    final userMap = j['user'] is Map
        ? Map<String, dynamic>.from(j['user'] as Map) : <String, dynamic>{};
    final reqMap = j['requester'] is Map
        ? Map<String, dynamic>.from(j['requester'] as Map) : <String, dynamic>{};

    final ownerName = _s(
      j['user_nom'] ?? j['user_nom_custom'] ??
      userMap['name'] ?? userMap['nom'] ??
      reqMap['name']  ?? reqMap['nom']  ??
      j['ownerName']  ?? j['ingenieurResponsable'],
    );
    final ownerEmail = _s(
      userMap['email'] ?? reqMap['email'] ??
      j['ownerEmail']  ?? j['userEmail'] ?? j['email'],
    );

    return _Row(
      id:          _s(j['_id'] ?? j['id']),
      name:        _s(j['nomProjet'] ?? j['name']),
      type:        type,
      ownerName:   ownerName,
      ownerEmail:  ownerEmail,
      createdAt:   _s(j['dateDemarrage'] ?? j['createdAt'] ?? j['date']),
      status:      _s(j['statut'] ?? j['status']),
      validation:  _s(j['validationStatut'] ?? j['validation']),
      isArchived:  j['isArchived'] == true,
      adresse:     _s(j['adresse']),
      entreprise:  _s(j['entreprise']),
      architecte:  _s(j['architecte']),
      ingenieur:   _s(j['ingenieurResponsable']),
      lat:         _dbl(j['latitude']  ?? j['lat']),
      lng:         _dbl(j['longitude'] ?? j['lng']),
    );
  }

  static String  _s(dynamic v) =>
      (v == null || v.toString().trim().isEmpty) ? '' : v.toString().trim();
  static double? _dbl(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());
}

// ──────────────────────────────────────────────────────────────────────────────
// AVATAR HELPERS
// ──────────────────────────────────────────────────────────────────────────────
const _kPalette = [
  Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF10B981),
  Color(0xFF06B6D4), Color(0xFFF59E0B), Color(0xFFEC4899),
  Color(0xFFF97316), Color(0xFF3B82F6), Color(0xFF14B8A6),
];

Color _avatarColor(String name) {
  if (name.isEmpty) return _kPalette[0];
  return _kPalette[name.codeUnitAt(0) % _kPalette.length];
}

String _initials(String name) {
  if (name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'[\s._@()\-]'))
      .where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return name.trim()[0].toUpperCase();
}

// ──────────────────────────────────────────────────────────────────────────────
// STATUS COLOR
// ──────────────────────────────────────────────────────────────────────────────
Color _statusColor(String s) {
  final l = s.toLowerCase();
  if (l.contains('prospect'))                         return const Color(0xFF3B82F6);
  if (l.contains('identif'))                          return const Color(0xFF6B7280);
  if (l.contains('plan') || l.contains('technique'))  return const Color(0xFFF59E0B);
  if (l.contains('nego'))                             return const Color(0xFF8B5CF6);
  if (l.contains('offre') || l.contains('devis'))    return const Color(0xFF06B6D4);
  if (l.contains('gagn') || l.contains('won'))       return const Color(0xFF10B981);
  if (l.contains('perd') || l.contains('lost'))      return const Color(0xFFEF4444);
  if (l.contains('visite'))                          return const Color(0xFF6366F1);
  if (l.contains('echant'))                          return const Color(0xFFEC4899);
  if (l.contains('commande'))                        return const Color(0xFFF97316);
  return kCrmTextSub;
}

Color _validationColor(String s) {
  final l = s.toLowerCase();
  if (l.contains('valid') || l.contains('approv'))          return kCrmSuccess;
  if (l.contains('refus') || l.contains('rejet'))           return kCrmDanger;
  if (l.contains('attente') || l.contains('pending'))       return kCrmWarning;
  return kCrmTextSub;
}

Color _typeColor(String type) {
  switch (type) {
    case 'applicateur': return kCrmSecondary;
    case 'revendeur':   return kCrmInfo;
    default:            return kCrmPrimary;
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'applicateur': return 'Applicateur';
    case 'revendeur':   return 'Revendeur';
    default:            return 'Projet';
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SCREEN
// ──────────────────────────────────────────────────────────────────────────────
class ProjectsExplorerScreen extends StatefulWidget {
  const ProjectsExplorerScreen({super.key});
  @override
  State<ProjectsExplorerScreen> createState() => _State();
}

class _State extends State<ProjectsExplorerScreen>
    with SingleTickerProviderStateMixin {

  // ── Auth ───────────────────────────────────────────────────────────────────
  final _auth   = AuthService();
  bool get _isAdmin => _auth.isAdmin;

  // ── Tabs ───────────────────────────────────────────────────────────────────
  static const _tabs   = ['Tous', 'Projets', 'Applicateurs', 'Revendeurs'];
  static const _modeles = <String?>[null, 'project', 'applicateur', 'revendeur'];
  late final TabController _tab;

  // ── State ──────────────────────────────────────────────────────────────────
  List<_Row> _rows      = [];
  bool       _loading   = false;
  int        _page      = 1;
  int        _totalPages = 1;
  int        _total     = 0;
  static const _limit   = 50;

  // ── Filters ────────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String?   _statusF;
  String?   _validationF;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool      _filtersOpen = false;

  // ── KPI ────────────────────────────────────────────────────────────────────
  int get _kActifs   => _rows.where((r) => !r.isArchived).length;
  int get _kArchived => _rows.where((r) =>  r.isArchived).length;
  int get _kPending  => _rows.where((r) {
    final v = r.validation.toLowerCase();
    return v.contains('attente') || v.isEmpty;
  }).length;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() { if (!_tab.indexIsChanging) { _page = 1; _load(); } });
    _load();
  }

  @override
  void dispose() { _tab.dispose(); _searchCtrl.dispose(); super.dispose(); }

  // ── API ────────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final modele = _modeles[_tab.index];
      final params = <String, dynamic>{
        'page': _page, 'limit': _limit,
        if (_searchCtrl.text.trim().isNotEmpty) 'q': _searchCtrl.text.trim(),
        if (modele != null)                     'projectModele': modele,
        if (_statusF?.isNotEmpty == true)        'statut': _statusF,
        if (_validationF?.isNotEmpty == true)    'validationStatut': _validationF,
        if (_dateFrom != null)
          'dateStart': DateFormat('yyyy-MM-dd').format(_dateFrom!),
        if (_dateTo != null)
          'dateEnd':   DateFormat('yyyy-MM-dd').format(_dateTo!),
      };

      // Admin gets all projects; user gets their own
      final endpoint = _isAdmin ? '/projects' : '/projects/my-projects';

      final res  = await ApiClient.instance.dio.get(endpoint, queryParameters: params);
      final data = res.data;
      List raw   = [];
      int total = 0, totalPages = 1;

      if (data is Map) {
        raw        = (data['items'] ?? data['data'] ?? data['results'] ?? data['docs'] ?? []) as List;
        total      = (data['total'] ?? data['count'] ?? raw.length) as int;
        totalPages = (data['totalPages'] ?? data['pages'] ?? 1) as int;
      } else if (data is List) {
        raw = data; total = raw.length;
      }

      setState(() {
        _rows      = raw.whereType<Map>()
            .map((e) => _Row.fromJson(Map<String, dynamic>.from(e))).toList();
        _total      = total;
        _totalPages = totalPages;
      });
    } catch (e) {
      debugPrint('[ProjectList] $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _apply() { _page = 1; _load(); }
  void _reset() {
    _searchCtrl.clear();
    setState(() { _statusF = null; _validationF = null; _dateFrom = null; _dateTo = null; });
    _tab.animateTo(0);
    _page = 1;
    _load();
  }

  // ── Export ─────────────────────────────────────────────────────────────────
  static const _kHexProjet      = '#EFF6FF';
  static const _kHexApplicateur = '#F0FDF4';
  static const _kHexRevendeur   = '#FFF7ED';

  void _export() {
    final role     = (_auth.userRole ?? 'user').toLowerCase();
    final name     = (_auth.userEmail ?? 'user').split('@').first;
    final year     = DateTime.now().year;
    final fileName = _isAdmin
        ? 'ProjectList_Admin_$year'
        : 'Mes_Projets_${name}_$year';

    final excelFile = xl.Excel.createExcel();
    final s = excelFile['Projets'];

    final headers = [
      'Nom', 'Type', 'Utilisateur', 'Email',
      'Date création', 'Statut', 'Validation',
      'Latitude', 'Longitude', 'Adresse', 'Entreprise', 'Architecte', 'Ingénieur',
      if (_isAdmin) 'Rôle',
    ];

    s.appendRow(headers);
    for (int i = 0; i < headers.length; i++) {
      s.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .cellStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: '#1E293B',
        fontColorHex: '#FFFFFF',
      );
    }

    for (final r in _rows) {
      final bgHex = r.type == 'applicateur'
          ? _kHexApplicateur
          : r.type == 'revendeur'
              ? _kHexRevendeur
              : _kHexProjet;
      final row = [
        r.name, _typeLabel(r.type), r.ownerName, r.ownerEmail,
        _fmtDate(r.createdAt), r.status, r.validation,
        r.lat?.toString() ?? '', r.lng?.toString() ?? '',
        r.adresse, r.entreprise, r.architecte, r.ingenieur,
        if (_isAdmin) role,
      ];
      s.appendRow(row);
      final rowIdx = _rows.indexOf(r) + 1;
      for (int i = 0; i < row.length; i++) {
        s.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIdx))
            .cellStyle = xl.CellStyle(backgroundColorHex: bgHex);
      }
    }
    for (int i = 0; i < headers.length; i++) s.setColWidth(i, 20);

    final bytes = excelFile.encode();
    if (bytes == null) return;
    final blob = html.Blob(
      [bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', '$fileName.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCrmBg,
      appBar: _appBar(),
      body: Column(children: [
        // Tab bar
        _tabBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kCrmPrimary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _filtersCard(),
                      const SizedBox(height: 16),
                      _kpiRow(),
                      const SizedBox(height: 16),
                      _rows.isEmpty ? _emptyState() : _tableCard(),
                      if (_totalPages > 1) ...[
                        const SizedBox(height: 16),
                        _pagination(),
                      ],
                    ],
                  ),
                ),
        ),
      ]),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    titleSpacing: 20,
    title: Row(children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: kCrmPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.list_alt_rounded, size: 20, color: kCrmPrimary),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Project List',
            style: tInter(fontSize: 16, fontWeight: FontWeight.w700, color: kCrmText)),
        Text(_isAdmin ? 'Vue administrateur · tous les utilisateurs' : 'Mes projets · applicateurs · revendeurs',
            style: tInter(fontSize: 11, color: kCrmTextSub)),
      ]),
    ]),
    actions: [
      if (!_loading && _rows.isNotEmpty)
        _Pill(icon: Icons.download_rounded, label: 'Export', color: kCrmSuccess, onTap: _export),
      _loading
          ? const Padding(padding: EdgeInsets.all(16),
              child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kCrmPrimary)))
          : IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _load,
              tooltip: 'Actualiser',
            ),
      const SizedBox(width: 8),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _kDivider),
    ),
  );

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget _tabBar() => Container(
    color: Colors.white,
    child: TabBar(
      controller: _tab,
      labelColor: kCrmPrimary,
      unselectedLabelColor: kCrmTextSub,
      indicatorColor: kCrmPrimary,
      indicatorWeight: 2,
      dividerColor: _kDivider,
      labelStyle: tInter(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: tInter(fontSize: 13, fontWeight: FontWeight.w500),
      tabs: _tabs.map((l) => Tab(text: l)).toList(),
    ),
  );

  // ── Filters card ───────────────────────────────────────────────────────────
  static const _statuts = [
    'Visite', 'Plan technique', 'Echantillonnage', 'Devis envoyé',
    'Negociation', 'Commande gagnée', 'Commande perdue',
  ];
  static const _validations = ['En attente', 'Validé', 'Refusé'];

  int get _activeCount => [
    _searchCtrl.text.isNotEmpty,
    _statusF != null,
    _validationF != null,
    _dateFrom != null,
    _dateTo != null,
  ].where((v) => v).length;

  Widget _filtersCard() => _SurCard(
    child: Column(children: [
      // Toggle
      InkWell(
        onTap: () => setState(() => _filtersOpen = !_filtersOpen),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Icon(Icons.tune_rounded, size: 16, color: kCrmPrimary),
            const SizedBox(width: 10),
            Text('Filtres', style: tInter(fontSize: 13, fontWeight: FontWeight.w700, color: kCrmText)),
            if (_activeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: kCrmPrimary, borderRadius: BorderRadius.circular(10)),
                child: Text('$_activeCount', style: tInter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
            const Spacer(),
            Icon(
              _filtersOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              size: 18, color: kCrmTextSub,
            ),
          ]),
        ),
      ),
      // Panel
      if (_filtersOpen) ...[
        Container(height: 1, color: _kDivider),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Search
            _SearchField(ctrl: _searchCtrl),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Drop<String?>(
                label: 'Statut',
                value: _statusF,
                none: 'Tous statuts',
                items: _statuts,
                onChanged: (v) => setState(() => _statusF = v),
              )),
              const SizedBox(width: 10),
              Expanded(child: _Drop<String?>(
                label: 'Validation',
                value: _validationF,
                none: 'Toutes',
                items: _validations,
                onChanged: (v) => setState(() => _validationF = v),
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _DateBtn(
                label: 'Date début',
                value: _dateFrom,
                onPick: (d) => setState(() => _dateFrom = d),
                onClear: () => setState(() => _dateFrom = null),
              )),
              const SizedBox(width: 10),
              Expanded(child: _DateBtn(
                label: 'Date fin',
                value: _dateTo,
                onPick: (d) => setState(() => _dateTo = d),
                onClear: () => setState(() => _dateTo = null),
              )),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text('Appliquer',
                    style: tInter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCrmPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Réinitialiser',
                    style: tInter(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCrmTextSub,
                  side: const BorderSide(color: _kDivider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              )),
            ]),
          ]),
        ),
      ],
    ]),
  );

  // ── KPI row ────────────────────────────────────────────────────────────────
  Widget _kpiRow() => Row(children: [
    _Kpi(label: 'Total',      value: _total,    icon: Icons.folder_rounded,           color: kCrmPrimary),
    const SizedBox(width: 10),
    _Kpi(label: 'Actifs',     value: _kActifs,  icon: Icons.check_circle_rounded,     color: kCrmSuccess),
    const SizedBox(width: 10),
    _Kpi(label: 'Archivés',   value: _kArchived,icon: Icons.archive_rounded,           color: kCrmTextSub),
    const SizedBox(width: 10),
    _Kpi(label: 'En attente', value: _kPending, icon: Icons.hourglass_bottom_rounded, color: kCrmWarning),
  ]);

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _emptyState() => _SurCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: kCrmPrimary.withValues(alpha: 0.06), shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_open_rounded, size: 44, color: kCrmPrimary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          Text('Aucun résultat',
              style: tInter(fontSize: 16, fontWeight: FontWeight.w700, color: kCrmText)),
          const SizedBox(height: 6),
          Text('Aucun élément trouvé avec les filtres actuels.',
              style: tInter(fontSize: 13, color: kCrmTextSub)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text('Réinitialiser les filtres',
                style: tInter(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: kCrmPrimary,
              side: BorderSide(color: kCrmPrimary.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ]),
      ),
    ),
  );

  // ── Table card ─────────────────────────────────────────────────────────────
  Widget _tableCard() => _SurCard(
    padding: EdgeInsets.zero,
    child: Column(children: [
      // Table header info
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          Icon(Icons.table_rows_rounded, size: 15, color: kCrmPrimary),
          const SizedBox(width: 8),
          Text('${_rows.length} éléments affichés sur $_total',
              style: tInter(fontSize: 12, fontWeight: FontWeight.w600, color: kCrmTextSub)),
        ]),
      ),
      Container(height: 1, color: _kDivider),
      // Actual table
      LayoutBuilder(builder: (_, c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth),
          child: _buildDataTable(),
        ),
      )),
    ]),
  );

  Widget _buildDataTable() {
    final showUserCols = _isAdmin;
    return Theme(
      // ⬇ Override divider color — removes thick black borders
      data: Theme.of(context).copyWith(
        dividerColor: _kDivider,
        dividerTheme: const DividerThemeData(color: _kDivider, thickness: 0.5),
      ),
      child: DataTable(
        dividerThickness: 0.5,
        columnSpacing: 24,
        horizontalMargin: 20,
        dataRowMinHeight: 56,
        dataRowMaxHeight: 64,
        headingRowColor: WidgetStateProperty.all(_kHeader),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return _kRowHover;
          return Colors.white;
        }),
        headingTextStyle: tInter(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: kCrmTextSub, letterSpacing: 0.6,
        ),
        columns: [
          const DataColumn(label: Text('NOM')),
          const DataColumn(label: Text('TYPE')),
          if (showUserCols) const DataColumn(label: Text('UTILISATEUR')),
          if (showUserCols) const DataColumn(label: Text('EMAIL')),
          const DataColumn(label: Text('DATE')),
          const DataColumn(label: Text('STATUT')),
          const DataColumn(label: Text('VALIDATION')),
          const DataColumn(label: Text('ACTIONS')),
        ],
        rows: _rows.map((r) => _buildRow(r, showUserCols)).toList(),
      ),
    );
  }

  DataRow _buildRow(_Row r, bool showUserCols) {
    return DataRow(cells: [
      // Nom + avatar
      DataCell(_AvatarNameCell(name: r.name, archived: r.isArchived)),
      // Type badge
      DataCell(_TypeBadge(type: r.type)),
      // Utilisateur (admin only)
      if (showUserCols)
        DataCell(SizedBox(
          width: 120,
          child: Text(r.ownerName.isEmpty ? '—' : r.ownerName,
              style: tInter(fontSize: 12, fontWeight: FontWeight.w600, color: kCrmText),
              overflow: TextOverflow.ellipsis),
        )),
      // Email (admin only)
      if (showUserCols)
        DataCell(SizedBox(
          width: 180,
          child: Text(r.ownerEmail.isEmpty ? '—' : r.ownerEmail,
              style: tInter(fontSize: 11, color: kCrmTextSub),
              overflow: TextOverflow.ellipsis),
        )),
      // Date
      DataCell(Text(_fmtDate(r.createdAt),
          style: tInter(fontSize: 11, color: kCrmTextSub))),
      // Statut
      DataCell(_StatusBadge(status: r.status)),
      // Validation
      DataCell(_ValidationBadge(status: r.validation)),
      // Actions
      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
        _Btn(
          icon: Icons.timeline_rounded, color: kCrmPrimary, tooltip: 'Timeline',
          onTap: r.isArchived ? null : () => context.go('/forms/project-timeline?projectId=${r.id}'),
        ),
        const SizedBox(width: 4),
        _Btn(
          icon: Icons.edit_rounded, color: kCrmSecondary, tooltip: 'Modifier',
          onTap: r.isArchived ? null : () => context.go(_editUrl(r.id)),
        ),
      ])),
    ]);
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  Widget _pagination() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _PageBtn(
        label: 'Précédent',
        icon: Icons.chevron_left_rounded,
        leading: true,
        onTap: _page > 1 ? () { setState(() => _page--); _load(); } : null,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text('$_page / $_totalPages',
            style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmTextSub)),
      ),
      _PageBtn(
        label: 'Suivant',
        icon: Icons.chevron_right_rounded,
        leading: false,
        onTap: _page < _totalPages ? () { setState(() => _page++); _load(); } : null,
      ),
    ],
  );

  String _editUrl(String id) => Uri(
    path: MyRoute.projectFormScreen, queryParameters: {'id': id},
  ).toString();
}

// ══════════════════════════════════════════════════════════════════════════════
// CELL WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
class _AvatarNameCell extends StatelessWidget {
  final String name;
  final bool   archived;
  const _AvatarNameCell({required this.name, required this.archived});

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(name);
    final ini   = _initials(name);
    return Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.7), color],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(ini, style: tInter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 160,
          child: Text(name.isEmpty ? '—' : name,
              style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: kCrmText),
              overflow: TextOverflow.ellipsis),
        ),
        if (archived)
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: kCrmTextSub.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('Archivé',
                style: tInter(fontSize: 9, fontWeight: FontWeight.w700, color: kCrmTextSub)),
          ),
      ]),
    ]);
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});
  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    final label = _typeLabel(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: tInter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        status.isEmpty ? '—' : status,
        style: tInter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _ValidationBadge extends StatelessWidget {
  final String status;
  const _ValidationBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = _validationColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        status.isEmpty ? '—' : status,
        style: tInter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  const _Btn({required this.icon, required this.color, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return Tooltip(
      message: active ? tooltip : 'Archivé',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.08) : kCrmBg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: active ? color : kCrmBorder),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
class _SurCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _SurCard({required this.child, this.padding = EdgeInsets.zero});
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFEEF2F7), width: 1),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
      ],
    ),
    child: child,
  );
}

class _Kpi extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _Kpi({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: _SurCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: tInter(fontSize: 20, fontWeight: FontWeight.w900, color: kCrmText)),
          Text(label, style: tInter(fontSize: 11, color: kCrmTextSub), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    ),
  );
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Pill({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label, style: tInter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    ),
  );
}

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  const _SearchField({required this.ctrl});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      hintText: 'Recherche par nom, type, utilisateur...',
      hintStyle: tInter(fontSize: 13, color: kCrmTextSub),
      prefixIcon: Icon(Icons.search_rounded, size: 18, color: kCrmTextSub),
      filled: true, fillColor: kCrmBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kDivider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kDivider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCrmPrimary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
    ),
    style: tInter(fontSize: 13, color: kCrmText),
  );
}

class _Drop<T> extends StatelessWidget {
  final String label, none;
  final T value;
  final List<String> items;
  final ValueChanged<T?> onChanged;
  const _Drop({required this.label, required this.none, required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    value: value,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: tInter(fontSize: 11, color: kCrmTextSub),
      filled: true, fillColor: kCrmBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kDivider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kDivider)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    style: tInter(fontSize: 13, color: kCrmText),
    items: [
      DropdownMenuItem<T>(value: null as T, child: Text(none, style: tInter(fontSize: 13, color: kCrmTextSub))),
      ...items.map((s) => DropdownMenuItem<T>(value: s as T, child: Text(s, style: tInter(fontSize: 13, color: kCrmText)))),
    ],
    onChanged: onChanged,
  );
}

class _DateBtn extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onClear;
  const _DateBtn({required this.label, required this.value, required this.onPick, required this.onClear});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime.now(),
        firstDate: DateTime(2020), lastDate: DateTime(2031),
      );
      if (d != null) onPick(d);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: kCrmBg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kDivider),
      ),
      child: Row(children: [
        Icon(Icons.calendar_today_rounded, size: 14, color: kCrmTextSub),
        const SizedBox(width: 8),
        Expanded(child: Text(
          value != null ? DateFormat('dd/MM/yyyy').format(value!) : label,
          style: tInter(fontSize: 13, color: value != null ? kCrmText : kCrmTextSub),
          overflow: TextOverflow.ellipsis,
        )),
        if (value != null) GestureDetector(
          onTap: onClear,
          child: Icon(Icons.close_rounded, size: 14, color: kCrmTextSub),
        ),
      ]),
    ),
  );
}

class _PageBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool leading;
  final VoidCallback? onTap;
  const _PageBtn({required this.label, required this.icon, required this.leading, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    final c      = active ? kCrmPrimary : kCrmBorder;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? Colors.white : kCrmBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kDivider),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (leading) Icon(icon, size: 16, color: c),
          if (leading) const SizedBox(width: 4),
          Text(label, style: tInter(fontSize: 12, fontWeight: FontWeight.w600, color: active ? kCrmText : kCrmTextSub)),
          if (!leading) const SizedBox(width: 4),
          if (!leading) Icon(icon, size: 16, color: c),
        ]),
      ),
    );
  }
}

// ── Global helpers ────────────────────────────────────────────────────────────
String _fmtDate(String v) {
  if (v.isEmpty) return '—';
  try { return DateFormat('dd/MM/yyyy').format(DateTime.parse(v)); }
  catch (_) { return v; }
}
