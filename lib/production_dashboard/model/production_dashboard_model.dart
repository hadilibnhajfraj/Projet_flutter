// lib/production_dashboard/model/production_dashboard_model.dart
//
// Dashboard Production — miroir de GET /production-records/dashboard. Tous
// les chiffres sont calculés par le backend (agrégations PostgreSQL sur les
// fiches PROMESH / PROBAR et les déchets) ; Flutter ne recalcule rien et
// n'affiche aucune valeur par défaut.

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
double _dbl(dynamic v) => (v as num?)?.toDouble() ?? 0;
double? _dblOrNull(dynamic v) => (v as num?)?.toDouble();
Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

/// Production d'une machine sur la période.
class ProductionMachineStats {
  final String machine;
  final int fiches;
  final int validees;
  final int brouillons;
  final int archivees;
  final double quantite;
  final double dechets;
  final double? tauxDechets; // kg pour 100 unités — null sans production validée
  final String? lastDate; // AAAA-MM-JJ
  final String? lastStatut; // validee | brouillon | archivee
  final bool active;

  const ProductionMachineStats({
    required this.machine,
    this.fiches = 0,
    this.validees = 0,
    this.brouillons = 0,
    this.archivees = 0,
    this.quantite = 0,
    this.dechets = 0,
    this.tauxDechets,
    this.lastDate,
    this.lastStatut,
    this.active = false,
  });

  factory ProductionMachineStats.fromJson(Map<String, dynamic> j) => ProductionMachineStats(
        machine: (j['machine'] ?? '').toString(),
        fiches: _int(j['fiches']),
        validees: _int(j['validees']),
        brouillons: _int(j['brouillons']),
        archivees: _int(j['archivees']),
        quantite: _dbl(j['quantite']),
        dechets: _dbl(j['dechets']),
        tauxDechets: _dblOrNull(j['tauxDechets']),
        lastDate: j['lastDate']?.toString(),
        lastStatut: j['lastStatut']?.toString(),
        active: j['active'] == true,
      );
}

/// Une ligne de production (PROMESH ou PROBAR) sur la période.
class ProductionLineStats {
  final String type; // promesh | probar
  final String label;
  final String unit; // m² | m
  final String wasteUnit; // kg
  final int fiches;
  final int validees;
  final int brouillons;
  final int archivees;
  final double quantite; // fiches validées
  final double dechets;
  final double? tauxDechets;
  final String tauxDechetsUnit; // « kg / 100 m² »
  final List<ProductionMachineStats> machines;

  const ProductionLineStats({
    required this.type,
    required this.label,
    this.unit = '',
    this.wasteUnit = 'kg',
    this.fiches = 0,
    this.validees = 0,
    this.brouillons = 0,
    this.archivees = 0,
    this.quantite = 0,
    this.dechets = 0,
    this.tauxDechets,
    this.tauxDechetsUnit = '',
    this.machines = const [],
  });

  factory ProductionLineStats.fromJson(Map<String, dynamic> j, String fallbackType) => ProductionLineStats(
        type: (j['type'] ?? fallbackType).toString(),
        label: (j['label'] ?? fallbackType.toUpperCase()).toString(),
        unit: (j['unit'] ?? '').toString(),
        wasteUnit: (j['wasteUnit'] ?? 'kg').toString(),
        fiches: _int(j['fiches']),
        validees: _int(j['validees']),
        brouillons: _int(j['brouillons']),
        archivees: _int(j['archivees']),
        quantite: _dbl(j['quantite']),
        dechets: _dbl(j['dechets']),
        tauxDechets: _dblOrNull(j['tauxDechets']),
        tauxDechetsUnit: (j['tauxDechetsUnit'] ?? '').toString(),
        machines: _maps(j['machines']).map(ProductionMachineStats.fromJson).toList(),
      );
}

/// Un jour de la période (graphiques).
class ProductionDay {
  final String date; // AAAA-MM-JJ
  final double promesh;
  final double probar;
  final int fichesPromesh;
  final int fichesProbar;
  final double dechetsPromesh;
  final double dechetsProbar;

  const ProductionDay({required this.date, this.promesh = 0, this.probar = 0, this.fichesPromesh = 0, this.fichesProbar = 0, this.dechetsPromesh = 0, this.dechetsProbar = 0});

  factory ProductionDay.fromJson(Map<String, dynamic> j) => ProductionDay(
        date: j['date'].toString(),
        promesh: _dbl(j['promesh']),
        probar: _dbl(j['probar']),
        fichesPromesh: _int(j['fichesPromesh']),
        fichesProbar: _int(j['fichesProbar']),
        dechetsPromesh: _dbl(j['dechetsPromesh']),
        dechetsProbar: _dbl(j['dechetsProbar']),
      );
}

/// Une fiche du tableau « Dernières productions ».
class ProductionRecentRow {
  final String id; // « promesh:<uuid> » | « probar:<uuid> »
  final String type;
  final String ligne;
  final String? numero;
  final String? date;
  final String? machine;
  final String? poste;
  final String? userEmail;
  final double? quantite;
  final String quantiteUnite;
  final double? dechets;
  final String dechetsUnite;
  final String statut;

  const ProductionRecentRow({
    required this.id,
    required this.type,
    required this.ligne,
    this.numero,
    this.date,
    this.machine,
    this.poste,
    this.userEmail,
    this.quantite,
    this.quantiteUnite = '',
    this.dechets,
    this.dechetsUnite = 'kg',
    this.statut = 'brouillon',
  });

  factory ProductionRecentRow.fromJson(Map<String, dynamic> j) => ProductionRecentRow(
        id: j['id'].toString(),
        type: (j['type'] ?? '').toString(),
        ligne: (j['ligne'] ?? '').toString(),
        numero: j['numero']?.toString(),
        date: j['date']?.toString(),
        machine: j['machine']?.toString(),
        poste: j['poste']?.toString(),
        userEmail: j['userEmail']?.toString(),
        quantite: _dblOrNull(j['quantite']),
        quantiteUnite: (j['quantiteUnite'] ?? '').toString(),
        dechets: _dblOrNull(j['dechets']),
        dechetsUnite: (j['dechetsUnite'] ?? 'kg').toString(),
        statut: (j['statut'] ?? 'brouillon').toString(),
      );

  /// Identifiant de la fiche dans sa table (sans le préfixe de ligne).
  String get recordId => id.contains(':') ? id.substring(id.indexOf(':') + 1) : id;
}

class ProductionDashboard {
  final String periodKey;
  final String? periodStart;
  final String? periodEnd;
  final bool ownScope; // true : le compte ne voit que ses propres fiches
  final ProductionLineStats promesh;
  final ProductionLineStats probar;
  final int fiches;
  final int productionsToday;
  final int machinesActives;
  final int machinesTotal;
  final List<ProductionDay> daily;
  final List<ProductionRecentRow> recent;

  const ProductionDashboard({
    this.periodKey = 'month',
    this.periodStart,
    this.periodEnd,
    this.ownScope = false,
    required this.promesh,
    required this.probar,
    this.fiches = 0,
    this.productionsToday = 0,
    this.machinesActives = 0,
    this.machinesTotal = 0,
    this.daily = const [],
    this.recent = const [],
  });

  factory ProductionDashboard.fromJson(Map<String, dynamic> j) {
    final period = _map(j['period']);
    final production = _map(j['production']);
    final machines = _map(j['machines']);
    return ProductionDashboard(
      periodKey: (period['key'] ?? 'month').toString(),
      periodStart: period['start']?.toString(),
      periodEnd: period['end']?.toString(),
      ownScope: j['scope'] == 'own',
      promesh: ProductionLineStats.fromJson(_map(j['promesh']), 'promesh'),
      probar: ProductionLineStats.fromJson(_map(j['probar']), 'probar'),
      fiches: _int(production['fiches']),
      productionsToday: _int(production['today']),
      machinesActives: _int(machines['actives']),
      machinesTotal: _int(machines['total']),
      daily: _maps(_map(j['charts'])['daily']).map(ProductionDay.fromJson).toList(),
      recent: _maps(j['recent']).map(ProductionRecentRow.fromJson).toList(),
    );
  }

  List<ProductionLineStats> get lines => [promesh, probar];
}

// ── Périodes ─────────────────────────────────────────────────────────────

/// (clé envoyée à l'API, libellé).
const kProductionPeriods = <(String, String)>[
  ('today', 'Aujourd\'hui'),
  ('week', 'Cette semaine'),
  ('month', 'Ce mois'),
  ('year', 'Cette année'),
  ('custom', 'Personnalisée'),
];

// ── Formatage ────────────────────────────────────────────────────────────

/// « 1 250 », « 51 358,5 » : séparateur de milliers, décimales seulement si
/// nécessaires.
String prodFormatNumber(num? v, {int maxDecimals = 2}) {
  if (v == null || (v is double && (v.isNaN || v.isInfinite))) return '—';
  var fixed = v.toStringAsFixed(maxDecimals);
  if (fixed.contains('.')) fixed = fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  final negative = fixed.startsWith('-');
  final parts = (negative ? fixed.substring(1) : fixed).split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer${parts.length > 1 ? ',${parts[1]}' : ''}';
}

/// « 1 250 m² » — « — » quand la valeur n'existe pas.
String prodFormatQuantity(num? v, String unit) => v == null ? '—' : '${prodFormatNumber(v)} $unit';

/// « 28/09/2026 » depuis « 2026-09-28 ».
String prodFormatDate(String? iso) {
  if (iso == null || iso.length < 10) return '—';
  return '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';
}

String prodPosteLabel(String? poste) => switch (poste) {
      'matin' => 'Matin',
      'soir' => 'Soir',
      'nuit' => 'Nuit',
      null || '' => '—',
      _ => poste,
    };

String prodStatusLabel(String? statut) => switch (statut) {
      'validee' => 'Validée',
      'archivee' => 'Archivée',
      _ => 'Brouillon',
    };

/// « production_1 » depuis « production_1@cbi-tunisia.com ».
String prodUserLabel(String? email) {
  if (email == null || email.isEmpty) return '—';
  final at = email.indexOf('@');
  return at > 0 ? email.substring(0, at) : email;
}
