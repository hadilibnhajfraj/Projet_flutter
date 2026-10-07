// lib/quality_control/model/quality_control_comparison.dart
//
// Comparaison qualité période A / période B — miroir de
// GET /quality-control/comparison. TOUT est calculé côté backend sur
// PostgreSQL (KPI, variations, classement des machines, paramètres, points
// d'attention, phrases d'analyse) ; Flutter ne recalcule rien et n'invente
// aucune valeur. Formatage : taux en POINTS, « N/A » quand une variation
// n'est pas calculable, jamais de NaN / Infinity.

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
double? _dbl(dynamic v) => (v as num?)?.toDouble();
Map<String, dynamic>? _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

/// KPI d'une période (ou d'une machine / ligne / poste sur une période).
class QcKpis {
  final String? start;
  final String? end;
  final int total;
  final int releves; // prélèvements des fiches — comptés à part des contrôles
  final int conformes;
  final int nonConformes;
  final int aVerifier;
  final int valides;
  final int parametresControles;
  final int parametresNonConformes;
  final int machinesControlees;
  final double? tauxConformite; // % sur les contrôles qualité validés, null si aucun
  final double? tauxNonConformite;
  final double? moyenneParametresControles;
  final double? moyenneParametresNonConformes;

  /// 'none' (aucun contrôle), 'limited' (un seul) ou 'ok'.
  final String dataLevel;

  const QcKpis({
    this.start,
    this.end,
    this.total = 0,
    this.releves = 0,
    this.conformes = 0,
    this.nonConformes = 0,
    this.aVerifier = 0,
    this.valides = 0,
    this.parametresControles = 0,
    this.parametresNonConformes = 0,
    this.machinesControlees = 0,
    this.tauxConformite,
    this.tauxNonConformite,
    this.moyenneParametresControles,
    this.moyenneParametresNonConformes,
    this.dataLevel = 'ok',
  });

  factory QcKpis.fromJson(Map<String, dynamic>? j) {
    final m = j ?? const <String, dynamic>{};
    final total = _int(m['total']);
    return QcKpis(
      start: m['start']?.toString(),
      end: m['end']?.toString(),
      total: total,
      releves: _int(m['releves']),
      conformes: _int(m['conformes']),
      nonConformes: _int(m['nonConformes']),
      aVerifier: _int(m['aVerifier']),
      valides: _int(m['valides']),
      parametresControles: _int(m['parametresControles']),
      parametresNonConformes: _int(m['parametresNonConformes']),
      machinesControlees: _int(m['machinesControlees']),
      tauxConformite: _dbl(m['tauxConformite']),
      tauxNonConformite: _dbl(m['tauxNonConformite']),
      moyenneParametresControles: _dbl(m['moyenneParametresControles']),
      moyenneParametresNonConformes: _dbl(m['moyenneParametresNonConformes']),
      dataLevel: (m['dataLevel'] ?? (total == 0 ? 'none' : 'ok')).toString(),
    );
  }

  num? value(String key) => switch (key) {
        'total' => total,
        'releves' => releves,
        'conformes' => conformes,
        'nonConformes' => nonConformes,
        'aVerifier' => aVerifier,
        'parametresControles' => parametresControles,
        'parametresNonConformes' => parametresNonConformes,
        'machinesControlees' => machinesControlees,
        'tauxConformite' => tauxConformite,
        'tauxNonConformite' => tauxNonConformite,
        'moyenneParametresControles' => moyenneParametresControles,
        'moyenneParametresNonConformes' => moyenneParametresNonConformes,
        _ => null,
      };
}

/// Évolution d'un KPI : absolue (B − A), relative (%, null si A = 0) ou en
/// points pour les taux. Tout est null quand une période est vide.
class QcEvolution {
  final num? absolue;
  final double? relative;
  final double? points;

  const QcEvolution({this.absolue, this.relative, this.points});

  factory QcEvolution.fromJson(Map<String, dynamic>? j) =>
      QcEvolution(absolue: j?['absolue'] as num?, relative: _dbl(j?['relative']), points: _dbl(j?['points']));
}

Map<String, QcEvolution> _evolutions(dynamic v) => {
      for (final e in (v is Map ? v : const {}).entries) e.key.toString(): QcEvolution.fromJson(_map(e.value)),
    };

/// Une ligne, une machine ou un poste : période A, période B, évolution.
class QcComparisonRow {
  final String type; // ligne (vide pour un poste)
  final String? machine;
  final String? poste;
  final String label;
  final QcKpis a;
  final QcKpis b;
  final Map<String, QcEvolution> evolution;

  const QcComparisonRow({this.type = '', this.machine, this.poste, required this.label, required this.a, required this.b, this.evolution = const {}});

  factory QcComparisonRow.fromJson(Map<String, dynamic> j) => QcComparisonRow(
        type: (j['type'] ?? '').toString(),
        machine: j['machine']?.toString(),
        poste: j['poste']?.toString(),
        label: (j['label'] ?? j['type'] ?? j['poste'] ?? '').toString(),
        a: QcKpis.fromJson(_map(j['periodA'])),
        b: QcKpis.fromJson(_map(j['periodB'])),
        evolution: _evolutions(j['evolution']),
      );
}

class QcParameterNc {
  final String key;
  final String label;
  final int a;
  final int b;
  final int total;

  const QcParameterNc({required this.key, required this.label, this.a = 0, this.b = 0, this.total = 0});

  factory QcParameterNc.fromJson(Map<String, dynamic> j) =>
      QcParameterNc(key: j['key'].toString(), label: j['label'].toString(), a: _int(j['periodA']), b: _int(j['periodB']), total: _int(j['total']));
}

/// Conformité d'un paramètre RÉELLEMENT contrôlé (par ligne de production).
class QcParameterEvolution {
  final String type;
  final String key;
  final String label;
  final String sectionLabel;
  final String group; // 'releve' ou 'treillis'
  final int controlesA;
  final int nonConformesA;
  final double? tauxA; // % de conformité, null si non contrôlé sur A
  final int controlesB;
  final int nonConformesB;
  final double? tauxB;
  final double? evolutionPoints; // null si non contrôlé sur les deux périodes
  final bool limited; // moins de 2 mesures sur une période

  const QcParameterEvolution({
    required this.type,
    required this.key,
    required this.label,
    this.sectionLabel = '',
    this.group = 'releve',
    this.controlesA = 0,
    this.nonConformesA = 0,
    this.tauxA,
    this.controlesB = 0,
    this.nonConformesB = 0,
    this.tauxB,
    this.evolutionPoints,
    this.limited = false,
  });

  factory QcParameterEvolution.fromJson(Map<String, dynamic> j) {
    final a = _map(j['periodA']) ?? const <String, dynamic>{};
    final b = _map(j['periodB']) ?? const <String, dynamic>{};
    return QcParameterEvolution(
      type: (j['type'] ?? '').toString(),
      key: j['key'].toString(),
      label: j['label'].toString(),
      sectionLabel: (j['sectionLabel'] ?? '').toString(),
      group: (j['group'] ?? 'releve').toString(),
      controlesA: _int(a['controles']),
      nonConformesA: _int(a['nonConformes']),
      tauxA: _dbl(a['tauxConformite']),
      controlesB: _int(b['controles']),
      nonConformesB: _int(b['nonConformes']),
      tauxB: _dbl(b['tauxConformite']),
      evolutionPoints: _dbl(j['evolutionPoints']),
      limited: j['limited'] == true,
    );
  }
}

class QcRankedMachine {
  final String type;
  final String machine;
  final String label;
  final double tauxConformite;
  final int valides;

  const QcRankedMachine({required this.type, required this.machine, required this.label, required this.tauxConformite, this.valides = 0});

  factory QcRankedMachine.fromJson(Map<String, dynamic> j) => QcRankedMachine(
        type: j['type'].toString(),
        machine: j['machine'].toString(),
        label: j['label'].toString(),
        tauxConformite: _dbl(j['tauxConformite']) ?? 0,
        valides: _int(j['valides']),
      );
}

/// Un jour d'une période (graphique linéaire). `tauxConformite` est null
/// quand le jour n'a aucun contrôle validé.
class QcDailyPoint {
  final String date;
  final int total;
  final int valides;
  final double? tauxConformite;

  const QcDailyPoint({required this.date, this.total = 0, this.valides = 0, this.tauxConformite});

  factory QcDailyPoint.fromJson(Map<String, dynamic> j) =>
      QcDailyPoint(date: j['date'].toString(), total: _int(j['total']), valides: _int(j['valides']), tauxConformite: _dbl(j['tauxConformite']));
}

class QcControllerOption {
  final String id;
  final String email;
  final String label;
  const QcControllerOption({required this.id, required this.email, required this.label});
}

class QualityComparison {
  final QcKpis a;
  final QcKpis b;
  final Map<String, QcEvolution> evolution;

  /// 'empty' (aucune donnée), 'insufficient' (une seule période alimentée),
  /// 'limited' (un seul contrôle sur une période) ou 'ok'.
  final String dataStatus;
  final List<String> messages;
  final List<QcComparisonRow> byMachine;
  final List<QcComparisonRow> byType;
  final List<QcComparisonRow> byShift;
  final String? shiftInsight;

  /// Classement des machines sur la période B — null quand une seule machine
  /// est sélectionnée ou classable.
  final List<QcRankedMachine>? ranking;
  final List<QcDailyPoint> dailyA;
  final List<QcDailyPoint> dailyB;
  final List<QcParameterEvolution> parameters;
  final List<QcParameterEvolution> improvements;
  final List<QcParameterEvolution> attentionPoints;
  final List<String> analysis;
  final List<QcParameterNc> byParameter; // classé : plus de NC d'abord
  final List<QcControllerOption> controllers;
  final String? controleur;
  final String? machineFilter;
  final String? posteFilter;

  const QualityComparison({
    required this.a,
    required this.b,
    this.evolution = const {},
    this.dataStatus = 'ok',
    this.messages = const [],
    this.byMachine = const [],
    this.byType = const [],
    this.byShift = const [],
    this.shiftInsight,
    this.ranking,
    this.dailyA = const [],
    this.dailyB = const [],
    this.parameters = const [],
    this.improvements = const [],
    this.attentionPoints = const [],
    this.analysis = const [],
    this.byParameter = const [],
    this.controllers = const [],
    this.controleur,
    this.machineFilter,
    this.posteFilter,
  });

  factory QualityComparison.fromJson(Map<String, dynamic> j) {
    final a = QcKpis.fromJson(_map(j['periodA']));
    final b = QcKpis.fromJson(_map(j['periodB']));
    final daily = _map(j['daily']) ?? const <String, dynamic>{};
    final ranking = _map(j['ranking']);
    List<QcParameterEvolution> params(String key) => _maps(j[key]).map(QcParameterEvolution.fromJson).toList();
    return QualityComparison(
      a: a,
      b: b,
      evolution: _evolutions(j['evolution']),
      dataStatus: (j['dataStatus'] ?? (a.total == 0 && b.total == 0 ? 'empty' : (a.total == 0 || b.total == 0 ? 'insufficient' : 'ok'))).toString(),
      messages: _maps(j['messages']).map((m) => (m['text'] ?? '').toString()).where((t) => t.isNotEmpty).toList(),
      byMachine: _maps(j['byMachine']).map(QcComparisonRow.fromJson).toList(),
      byType: _maps(j['byType']).map(QcComparisonRow.fromJson).toList(),
      byShift: _maps(j['byShift']).map(QcComparisonRow.fromJson).toList(),
      shiftInsight: j['shiftInsight']?.toString(),
      ranking: ranking == null ? null : _maps(ranking['machines']).map(QcRankedMachine.fromJson).toList(),
      dailyA: _maps(daily['periodA']).map(QcDailyPoint.fromJson).toList(),
      dailyB: _maps(daily['periodB']).map(QcDailyPoint.fromJson).toList(),
      parameters: params('parameters'),
      improvements: params('improvements'),
      attentionPoints: params('attentionPoints'),
      analysis: (j['analysis'] as List? ?? []).map((e) => e.toString()).toList(),
      byParameter: _maps(j['byParameter']).map(QcParameterNc.fromJson).toList(),
      controllers: _maps(_map(j['options'])?['controllers'])
          .map((c) => QcControllerOption(id: c['id'].toString(), email: (c['email'] ?? '').toString(), label: (c['label'] ?? c['email'] ?? '').toString()))
          .toList(),
      controleur: j['controleur']?.toString(),
      machineFilter: _map(j['filters'])?['machine']?.toString(),
      posteFilter: _map(j['filters'])?['poste']?.toString(),
    );
  }

  bool get isEmpty => dataStatus == 'empty';

  /// Les deux périodes ont des contrôles : une variation a un sens.
  bool get comparable => a.total > 0 && b.total > 0;

  /// Paramètres ayant au moins une non-conformité sur l'une des périodes.
  List<QcParameterNc> get nonConformParameters => byParameter.where((p) => p.total > 0).toList();
}

// ── Indicateurs affichés ─────────────────────────────────────────────────

/// Nature d'un KPI pour le formatage : nombre, taux (%), moyenne.
enum QcKpiKind { count, rate, average }

/// Sens favorable d'une hausse (couleur de l'évolution).
enum QcTrend { higherIsBetter, lowerIsBetter, neutral }

class QcKpiDef {
  final String key;
  final String label;
  final QcKpiKind kind;
  final QcTrend trend;
  const QcKpiDef(this.key, this.label, this.kind, this.trend);
}

/// Les 12 indicateurs de la comparaison (valeurs lues dans la réponse API).
const kQcComparisonKpis = <QcKpiDef>[
  QcKpiDef('total', 'Contrôles qualité', QcKpiKind.count, QcTrend.neutral),
  QcKpiDef('conformes', 'Conformes', QcKpiKind.count, QcTrend.higherIsBetter),
  QcKpiDef('nonConformes', 'Non conformes', QcKpiKind.count, QcTrend.lowerIsBetter),
  QcKpiDef('aVerifier', 'À vérifier', QcKpiKind.count, QcTrend.lowerIsBetter),
  QcKpiDef('tauxConformite', 'Taux de conformité', QcKpiKind.rate, QcTrend.higherIsBetter),
  QcKpiDef('tauxNonConformite', 'Taux de non-conformité', QcKpiKind.rate, QcTrend.lowerIsBetter),
  QcKpiDef('parametresControles', 'Paramètres contrôlés', QcKpiKind.count, QcTrend.neutral),
  QcKpiDef('parametresNonConformes', 'Paramètres non conformes', QcKpiKind.count, QcTrend.lowerIsBetter),
  QcKpiDef('machinesControlees', 'Machines contrôlées', QcKpiKind.count, QcTrend.neutral),
  QcKpiDef('releves', 'Prélèvements', QcKpiKind.count, QcTrend.neutral),
  QcKpiDef('moyenneParametresControles', 'Moy. paramètres contrôlés / contrôle', QcKpiKind.average, QcTrend.neutral),
  QcKpiDef('moyenneParametresNonConformes', 'Moy. non-conformités / contrôle', QcKpiKind.average, QcTrend.lowerIsBetter),
];

/// Indicateurs COMMUNS aux deux lignes : les seuls comparés entre PROMESH et
/// PROBAR (jamais un paramètre propre à une ligne).
const kQcCommonKpiKeys = ['total', 'conformes', 'nonConformes', 'tauxConformite', 'tauxNonConformite', 'machinesControlees', 'releves', 'parametresControles'];

String _fr(double v, int digits) => v.toStringAsFixed(digits).replaceAll('.', ',');
String _signed(num v, String text) => v > 0 ? '+$text' : text;

/// Valeur d'un KPI : "25", "80,0 %", "0,36" ou "N/A".
String qcFormatKpi(QcKpiKind kind, num? v) {
  if (v == null || (v is double && (v.isNaN || v.isInfinite))) return 'N/A';
  return switch (kind) {
    QcKpiKind.rate => '${_fr(v.toDouble(), 1)} %',
    QcKpiKind.average => _fr(v.toDouble(), 2),
    QcKpiKind.count => v.toInt().toString(),
  };
}

/// Écart d'un taux en POINTS : "+3,7 pt" (tableaux) ou "+3,7 points".
String qcFormatPoints(double? p, {bool long = false}) {
  if (p == null || p.isNaN || p.isInfinite) return 'N/A';
  final text = _signed(p, _fr(p, 1));
  if (!long) return '$text pt';
  return '$text ${p.abs() >= 2 ? 'points' : 'point'}';
}

/// Évolution : "+6 (+24,0 %)", "+3 (N/A)" (base nulle), "+0,7 pt", "N/A"
/// (période vide : aucune variation calculée).
String qcFormatEvolution(QcKpiKind kind, QcEvolution? e, {bool longPoints = false}) {
  if (e == null) return 'N/A';
  switch (kind) {
    case QcKpiKind.rate:
      return qcFormatPoints(e.points, long: longPoints);
    case QcKpiKind.average:
      final a = e.absolue;
      return a == null ? 'N/A' : _signed(a, _fr(a.toDouble(), 2));
    case QcKpiKind.count:
      final a = e.absolue;
      if (a == null) return 'N/A';
      final r = e.relative;
      return '${_signed(a, a.toInt().toString())} (${r == null ? 'N/A' : '${_signed(r, _fr(r, 1))} %'})';
  }
}

/// Signe de l'évolution (−1, 0, 1) pour la couleur — null si inconnue.
int? qcEvolutionSign(QcKpiKind kind, QcEvolution? e) {
  final v = kind == QcKpiKind.rate ? e?.points : e?.absolue;
  if (v == null) return null;
  return v > 0 ? 1 : (v < 0 ? -1 : 0);
}

// ── Raccourcis de période ────────────────────────────────────────────────

/// (identifiant, libellé) — « Personnalisé » : dates saisies à la main.
const kQcPeriodPresets = <(String, String)>[
  ('today', 'Aujourd\'hui'),
  ('week', 'Cette semaine'),
  ('prevWeek', 'Semaine précédente'),
  ('month', 'Ce mois'),
  ('prevMonth', 'Mois précédent'),
  ('quarter', 'Ce trimestre'),
  ('prevQuarter', 'Trimestre précédent'),
  ('year', 'Cette année'),
  ('prevYear', 'Année précédente'),
  ('custom', 'Personnalisé'),
];

/// Bornes (incluses) d'un raccourci — semaine du lundi au dimanche. Null pour
/// « Personnalisé ».
(DateTime, DateTime)? qcPeriodRange(String preset, DateTime now) {
  final y = now.year;
  final m = now.month;
  final d = now.day;
  final monday = d - (now.weekday - 1);
  final q = (m - 1) ~/ 3; // trimestre 0..3
  return switch (preset) {
    'today' => (DateTime(y, m, d), DateTime(y, m, d)),
    'week' => (DateTime(y, m, monday), DateTime(y, m, monday + 6)),
    'prevWeek' => (DateTime(y, m, monday - 7), DateTime(y, m, monday - 1)),
    'month' => (DateTime(y, m, 1), DateTime(y, m + 1, 0)),
    'prevMonth' => (DateTime(y, m - 1, 1), DateTime(y, m, 0)),
    'quarter' => (DateTime(y, q * 3 + 1, 1), DateTime(y, q * 3 + 4, 0)),
    'prevQuarter' => (DateTime(y, q * 3 - 2, 1), DateTime(y, q * 3 + 1, 0)),
    'year' => (DateTime(y, 1, 1), DateTime(y, 12, 31)),
    'prevYear' => (DateTime(y - 1, 1, 1), DateTime(y - 1, 12, 31)),
    _ => null,
  };
}

// ── Noms des fichiers exportés (même règle que le backend) ──────────────

String qcHistoryExportFileName({String? productionType, String? machine, String? from, String? to, required String ext, DateTime? now}) {
  final parts = ['Rapport_Controle_Qualite'];
  if (productionType != null && productionType.isNotEmpty) parts.add(productionType.toUpperCase());
  if (machine != null && machine.isNotEmpty) parts.add('Machine$machine');
  if ((from ?? '').isNotEmpty || (to ?? '').isNotEmpty) {
    parts.add('${(from ?? '').isEmpty ? 'debut' : from}_${(to ?? '').isEmpty ? 'fin' : to}');
  } else {
    final d = now ?? DateTime.now();
    parts.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
  }
  return '${parts.join('_')}.$ext';
}

String qcComparisonExportFileName(String aStart, String bEnd, String ext) => 'Comparaison_Qualite_${aStart}_$bEnd.$ext';

const kQcExportMime = {
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'pdf': 'application/pdf',
  'csv': 'text/csv',
};
