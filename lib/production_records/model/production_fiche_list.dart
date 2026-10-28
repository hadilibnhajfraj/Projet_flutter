// lib/production_records/model/production_fiche_list.dart
//
// Liste des fiches d'UNE ligne (PROMESH ou PROBAR) — miroir de
// GET /production-records/fiches. Les chiffres (compteurs, totaux) viennent
// du backend, calculés sur les filtres envoyés ; Flutter ne recompte rien.
// Statut de validation (`approval`) et verrouillage (`isLocked`) sont deux
// informations indépendantes.

int _int(dynamic v) => (v as num?)?.toInt() ?? int.tryParse(v?.toString() ?? '') ?? 0;
double? _dbl(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class FicheListApproval {
  final String status; // APPROVED | PENDING | REJECTED
  final String? rejectionComment;
  final String? decidedByEmail;
  final DateTime? decidedAt;
  const FicheListApproval({required this.status, this.rejectionComment, this.decidedByEmail, this.decidedAt});

  static FicheListApproval? fromJson(dynamic j) => j is Map && j['status'] != null
      ? FicheListApproval(
          status: j['status'].toString(),
          rejectionComment: j['rejectionComment']?.toString(),
          decidedByEmail: j['decidedByEmail']?.toString(),
          decidedAt: _date(j['decidedAt']),
        )
      : null;
}

class FicheListRow {
  final String id; // « promesh:<uuid> »
  final String type;
  final String? numero;
  final String? machine;
  final String? poste;
  final String? date; // AAAA-MM-JJ
  final DateTime? createdAt;
  final String? operateur;
  final double? quantite; // null : non saisie (≠ 0)
  final String unite;
  final String statut; // saisie : validee | brouillon | inconnu (valeur inattendue)
  final bool isLocked;
  final FicheListApproval? approval;
  final String? creatorEmail;
  final String? createdBy; // id du compte créateur (droits d'écriture)

  const FicheListRow({
    required this.id,
    required this.type,
    this.numero,
    this.machine,
    this.poste,
    this.date,
    this.createdAt,
    this.operateur,
    this.quantite,
    this.unite = '',
    this.statut = 'brouillon',
    this.isLocked = false,
    this.approval,
    this.creatorEmail,
    this.createdBy,
  });

  factory FicheListRow.fromJson(Map<String, dynamic> j) => FicheListRow(
        id: j['id'].toString(),
        type: (j['type'] ?? '').toString(),
        numero: j['numero']?.toString(),
        machine: j['machine']?.toString(),
        poste: j['poste']?.toString(),
        date: j['date']?.toString(),
        createdAt: _date(j['createdAt']),
        operateur: j['operateur']?.toString(),
        quantite: _dbl(j['quantite']),
        unite: (j['quantiteUnite'] ?? '').toString(),
        // Absent ou inattendu : « inconnu », jamais supposé validé.
        statut: switch (j['statut']) { 'validee' => 'validee', 'brouillon' => 'brouillon', _ => 'inconnu' },
        isLocked: j['isLocked'] == true,
        approval: FicheListApproval.fromJson(j['approval']),
        creatorEmail: j['creator'] is Map ? (j['creator'] as Map)['email']?.toString() : null,
        createdBy: j['createdBy']?.toString(),
      );

  /// Identifiant de la fiche dans sa table (sans le préfixe de ligne).
  String get recordId => id.contains(':') ? id.substring(id.indexOf(':') + 1) : id;
  bool get isDraft => statut == 'brouillon';
}

/// Répartition des fiches filtrées par statut de validation.
class FicheListSummary {
  final int total;
  final int approved;
  final int pending;
  final int rejected;
  final int none; // hors circuit de validation
  const FicheListSummary({this.total = 0, this.approved = 0, this.pending = 0, this.rejected = 0, this.none = 0});

  factory FicheListSummary.fromJson(dynamic j) => j is Map
      ? FicheListSummary(total: _int(j['total']), approved: _int(j['approved']), pending: _int(j['pending']), rejected: _int(j['rejected']), none: _int(j['none']))
      : const FicheListSummary();

  /// Fiches soumises à validation (décidées ou en attente).
  int get submitted => approved + pending + rejected;

  /// Taux de validation : acceptées / fiches soumises — null sans fiche soumise.
  double? get validationRate => submitted == 0 ? null : approved * 100 / submitted;
}

class FicheListPage {
  final List<FicheListRow> rows;
  final int page;
  final int limit;
  final int total; // résultats (statut compris)
  final int totalPages;
  final FicheListSummary summary;
  const FicheListPage({this.rows = const [], this.page = 1, this.limit = 20, this.total = 0, this.totalPages = 1, this.summary = const FicheListSummary()});

  factory FicheListPage.fromJson(Map<String, dynamic> body) {
    final p = body['pagination'] is Map ? body['pagination'] as Map : const {};
    return FicheListPage(
      rows: [for (final r in (body['data'] as List? ?? const [])) if (r is Map) FicheListRow.fromJson(Map<String, dynamic>.from(r))],
      page: _int(p['page']).clamp(1, 1 << 30),
      limit: _int(p['limit']),
      total: _int(p['total']),
      totalPages: _int(p['totalPages']).clamp(1, 1 << 30),
      summary: FicheListSummary.fromJson(body['summary']),
    );
  }
}

/// Filtres combinables envoyés tels quels au backend.
class FicheListFilters {
  final String period; // all | today | week | month | quarter | year | custom
  final DateTime? start;
  final DateTime? end;
  final String? machine;
  final String? poste; // matin | nuit
  final String? approval; // PENDING | APPROVED | REJECTED | NONE
  final String search;
  final String sort; // date_desc | date_asc | quantite_desc
  final int page;
  final int limit;

  const FicheListFilters({
    this.period = 'all',
    this.start,
    this.end,
    this.machine,
    this.poste,
    this.approval,
    this.search = '',
    this.sort = 'date_desc',
    this.page = 1,
    this.limit = 20,
  });

  static String _d(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toQuery(String type) => {
        'type': type,
        if (period != 'all') 'period': period,
        if (period == 'custom' && start != null) 'startDate': _d(start!),
        if (period == 'custom' && end != null) 'endDate': _d(end!),
        if (machine != null) 'machine': machine,
        if (poste != null) 'poste': poste,
        if (approval != null) 'approval': approval,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'sort': sort,
        'page': page,
        'limit': limit,
      };

  /// Au moins un filtre (hors tri / pagination) appliqué.
  bool get isFiltered => period != 'all' || machine != null || poste != null || approval != null || search.trim().isNotEmpty;

  FicheListFilters copyWith({
    String? period,
    DateTime? start,
    DateTime? end,
    String? machine,
    String? poste,
    String? approval,
    String? search,
    String? sort,
    int? page,
    int? limit,
    Set<String> clear = const {},
  }) =>
      FicheListFilters(
        period: period ?? this.period,
        start: clear.contains('start') ? null : (start ?? this.start),
        end: clear.contains('end') ? null : (end ?? this.end),
        machine: clear.contains('machine') ? null : (machine ?? this.machine),
        poste: clear.contains('poste') ? null : (poste ?? this.poste),
        approval: clear.contains('approval') ? null : (approval ?? this.approval),
        search: search ?? this.search,
        sort: sort ?? this.sort,
        page: page ?? this.page,
        limit: limit ?? this.limit,
      );
}
