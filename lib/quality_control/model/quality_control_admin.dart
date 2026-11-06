// lib/quality_control/model/quality_control_admin.dart
//
// Tableau de bord Contrôle Qualité — Super Admin : indicateurs servis par
// GET /quality-control/admin/overview (comptés en base, jamais recalculés ici).
// « En attente » = fiche non validée (brouillon) ; « non conformes » = fiches
// validées au résultat NON_CONFORME (le module n'a pas d'état « refusée »).

class QcAdminCounts {
  final int total;
  final int validated;
  final int pending;
  final int conformes;
  final int nonConformes;

  const QcAdminCounts({this.total = 0, this.validated = 0, this.pending = 0, this.conformes = 0, this.nonConformes = 0});

  factory QcAdminCounts.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return QcAdminCounts(
      total: n('total'),
      validated: n('validated'),
      pending: n('pending'),
      conformes: n('conformes'),
      nonConformes: n('nonConformes'),
    );
  }
}

class QcAdminLineCounts extends QcAdminCounts {
  final String type; // PROMESH | PROBAR
  final String label;

  const QcAdminLineCounts({
    required this.type,
    required this.label,
    super.total,
    super.validated,
    super.pending,
    super.conformes,
    super.nonConformes,
  });

  factory QcAdminLineCounts.fromJson(Map<String, dynamic> j) {
    final c = QcAdminCounts.fromJson(j);
    final type = j['type']?.toString() ?? '';
    return QcAdminLineCounts(
      type: type,
      label: j['label']?.toString() ?? type,
      total: c.total,
      validated: c.validated,
      pending: c.pending,
      conformes: c.conformes,
      nonConformes: c.nonConformes,
    );
  }
}

class QcAdminOverview {
  final QcAdminCounts totals;
  final List<QcAdminLineCounts> byProduct;

  const QcAdminOverview({this.totals = const QcAdminCounts(), this.byProduct = const []});

  factory QcAdminOverview.fromJson(Map<String, dynamic> j) => QcAdminOverview(
        totals: QcAdminCounts.fromJson(j['totals'] is Map ? Map<String, dynamic>.from(j['totals'] as Map) : const {}),
        byProduct: (j['byProduct'] as List? ?? [])
            .whereType<Map>()
            .map((m) => QcAdminLineCounts.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

/// Colonnes triables du tableau (clé envoyée à l'API `sort=`).
abstract final class QcAdminSort {
  static const reference = 'reference';
  static const product = 'productionType';
  static const date = 'date';
  static const controller = 'controller';
  static const result = 'result';
  static const state = 'state';
  static const updatedAt = 'updatedAt';
}

/// Filtre « statut » de l'écran → paramètres de l'API (state / status).
/// (valeur, libellé, state, status)
const kQcAdminStatusFilters = <(String, String, String?, String?)>[
  ('', 'Tous', null, null),
  ('validated', 'Validées', 'validated', null),
  ('draft', 'En attente', 'draft', null),
  ('conformes', 'Conformes', 'validated', 'CONFORME'),
  ('nonConformes', 'Non conformes', 'validated', 'NON_CONFORME'),
];
