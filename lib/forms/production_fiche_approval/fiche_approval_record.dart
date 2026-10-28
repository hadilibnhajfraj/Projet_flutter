// lib/forms/production_fiche_approval/fiche_approval_record.dart
//
// Validation des fiches de production (PROMESH / PROBAR) par le responsable
// logistique : modèles lus depuis /production-fiche-approvals et depuis le
// bloc `approval` des fiches existantes. Statut distinct du cycle de saisie
// (Brouillon / Saisie terminée), qui n'est jamais une validation.

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

/// Libellés de décision du module « Validation des fiches » (mapping
/// explicite des statuts backend ; tout autre statut : « Statut inconnu »).
const Map<String, String> kFicheDecisionLabels = {
  'PENDING': 'En attente',
  'APPROVED': 'Acceptée',
  'REJECTED': 'Refusée',
};

/// Code → (libellé français = clé de traduction, couleur).
const Map<String, (String, Color)> kFicheApprovalStatuses = {
  'PENDING': ('En attente de validation', Color(0xFFD97706)),
  'APPROVED': ('Validée', kCrmSuccess),
  'REJECTED': ('Refusée', kCrmDanger),
};

/// Chemins, sans dépendance vers my_route.dart (testable hors navigateur).
abstract final class FicheApprovalPaths {
  static const root = '/production/validation-fiches';
}

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
double? _num(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
String? _str(dynamic v) => v == null || v.toString().isEmpty ? null : v.toString();

/// Bloc `approval` d'une fiche (null : fiche hors circuit de validation).
class FicheApproval {
  final String status;
  final int version;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final String? decidedByEmail;
  final DateTime? rejectedAt;
  final String? rejectionComment;

  const FicheApproval({
    required this.status,
    this.version = 1,
    this.submittedAt,
    this.decidedAt,
    this.decidedByEmail,
    this.rejectedAt,
    this.rejectionComment,
  });

  static FicheApproval? fromJson(dynamic j) {
    if (j is! Map || j['status'] == null) return null;
    return FicheApproval(
      status: j['status'].toString(),
      version: (j['version'] as num?)?.toInt() ?? 1,
      submittedAt: _date(j['submittedAt']),
      decidedAt: _date(j['decidedAt']),
      decidedByEmail: _str(j['decidedByEmail']),
      rejectedAt: _date(j['rejectedAt']),
      rejectionComment: _str(j['rejectionComment']),
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
}

class FicheDetailSection {
  final String title;
  final List<(String, String)> rows;
  const FicheDetailSection(this.title, this.rows);
}

class FicheDetailTable {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  const FicheDetailTable(this.title, this.columns, this.rows);
}

class FicheApprovalStep {
  final int version;
  final String? fromStatus;
  final String toStatus;
  final String? changedByEmail;
  final String? comment;
  final DateTime? createdAt;
  const FicheApprovalStep({required this.version, this.fromStatus, required this.toStatus, this.changedByEmail, this.comment, this.createdAt});
}

/// Fiche dans la liste « Validation des fiches de production » (le détail
/// complet, l'historique et les droits ne sont renseignés que par detail()).
class FicheApprovalItem {
  final String ficheType; // promesh | probar
  final String ficheTypeLabel;
  final String id;
  final String? numero;
  final String status;
  final int version;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final String? decidedByEmail;
  final DateTime? rejectedAt;
  final String? rejectionComment;
  final DateTime? createdAt;
  /// Valeur brute renvoyée telle quelle avec une décision (version affichée).
  final String? updatedAtRaw;
  final String? creatorEmail;
  final String? machine;
  final String? poste;
  final String? posteLabel;
  final String? dateProduction;
  final String? operateur;
  final String? saisieLabel;
  final String productionLabel;
  final double? productionValue;
  final String? productionUnit;
  final List<(String, double?)> dechets;
  final List<FicheDetailSection> sections;
  final List<FicheDetailTable> tables;
  final List<FicheApprovalStep> history;
  final bool canDecide;
  final bool canResubmit;

  const FicheApprovalItem({
    required this.ficheType,
    required this.ficheTypeLabel,
    required this.id,
    this.numero,
    required this.status,
    this.version = 1,
    this.submittedAt,
    this.decidedAt,
    this.decidedByEmail,
    this.rejectedAt,
    this.rejectionComment,
    this.createdAt,
    this.updatedAtRaw,
    this.creatorEmail,
    this.machine,
    this.poste,
    this.posteLabel,
    this.dateProduction,
    this.operateur,
    this.saisieLabel,
    this.productionLabel = 'Production',
    this.productionValue,
    this.productionUnit,
    this.dechets = const [],
    this.sections = const [],
    this.tables = const [],
    this.history = const [],
    this.canDecide = false,
    this.canResubmit = false,
  });

  factory FicheApprovalItem.fromJson(Map<String, dynamic> j) {
    final prod = j['production'] is Map ? j['production'] as Map : const {};
    final details = j['details'] is Map ? j['details'] as Map : const {};
    return FicheApprovalItem(
      ficheType: (j['ficheType'] ?? '').toString(),
      ficheTypeLabel: (j['ficheTypeLabel'] ?? j['ficheType'] ?? '').toString(),
      id: (j['id'] ?? '').toString(),
      numero: _str(j['numero']),
      status: (j['status'] ?? '').toString(),
      version: (j['version'] as num?)?.toInt() ?? 1,
      submittedAt: _date(j['submittedAt']),
      decidedAt: _date(j['decidedAt']),
      decidedByEmail: _str(j['decidedByEmail']),
      rejectedAt: _date(j['rejectedAt']),
      rejectionComment: _str(j['rejectionComment']),
      createdAt: _date(j['createdAt']),
      updatedAtRaw: _str(j['updatedAt']),
      creatorEmail: _str(j['creatorEmail']),
      machine: _str(j['machine']),
      poste: _str(j['poste']),
      posteLabel: _str(j['posteLabel']),
      dateProduction: _str(j['dateProduction']),
      operateur: _str(j['operateur']),
      saisieLabel: _str(j['saisieLabel']),
      productionLabel: (prod['label'] ?? 'Production').toString(),
      productionValue: _num(prod['value']),
      productionUnit: _str(prod['unit']),
      dechets: [
        for (final d in (j['dechets'] as List? ?? const []))
          if (d is Map) ((d['label'] ?? '').toString(), _num(d['value'])),
      ],
      sections: [
        for (final s in (details['sections'] as List? ?? const []))
          if (s is Map)
            FicheDetailSection((s['title'] ?? '').toString(), [
              for (final r in (s['rows'] as List? ?? const []))
                if (r is Map) ((r['label'] ?? '').toString(), (r['value'] ?? '').toString()),
            ]),
      ],
      tables: [
        for (final t in (details['tables'] as List? ?? const []))
          if (t is Map)
            FicheDetailTable(
              (t['title'] ?? '').toString(),
              [for (final c in (t['columns'] as List? ?? const [])) c.toString()],
              [
                for (final r in (t['rows'] as List? ?? const []))
                  if (r is List) [for (final c in r) c.toString()],
              ],
            ),
      ],
      history: [
        for (final h in (j['history'] as List? ?? const []))
          if (h is Map)
            FicheApprovalStep(
              version: (h['version'] as num?)?.toInt() ?? 1,
              fromStatus: _str(h['fromStatus']),
              toStatus: (h['toStatus'] ?? '').toString(),
              changedByEmail: _str(h['changedByEmail']),
              comment: _str(h['comment']),
              createdAt: _date(h['createdAt']),
            ),
      ],
      canDecide: j['canDecide'] == true,
      canResubmit: j['canResubmit'] == true,
    );
  }

  String get reference => numero ?? '$ficheTypeLabel ${id.substring(0, id.length < 8 ? id.length : 8)}';
  bool get isPending => status == 'PENDING';
  bool get isRejected => status == 'REJECTED';
}

class FicheApprovalPermissions {
  final bool canView;
  final bool canViewAll;
  final bool canDecide;
  final bool isCreator;
  /// Producteurs proposés dans le filtre de l'historique.
  final List<String> creators;
  const FicheApprovalPermissions({
    this.canView = false,
    this.canViewAll = false,
    this.canDecide = false,
    this.isCreator = false,
    this.creators = const [],
  });

  factory FicheApprovalPermissions.fromJson(Map<String, dynamic> j) => FicheApprovalPermissions(
        canView: j['canView'] == true,
        canViewAll: j['canViewAll'] == true,
        canDecide: j['canDecide'] == true,
        isCreator: j['isCreator'] == true,
        creators: [for (final c in (j['creators'] as List? ?? const [])) c.toString()],
      );
}

/// Filtres de l'historique des validations (null : pas de filtre).
class FicheApprovalFilters {
  final String status; // PENDING | APPROVED | REJECTED | all
  final DateTime? from; // période : date de production
  final DateTime? to;
  final String? creator;
  final String? type; // promesh | probar
  final String? machine;
  final String? poste; // matin | nuit
  final String? search;

  const FicheApprovalFilters({this.status = 'all', this.from, this.to, this.creator, this.type, this.machine, this.poste, this.search});

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toQuery() => {
        'status': status,
        if (from != null) 'from': _d(from!),
        if (to != null) 'to': _d(to!),
        if (creator != null) 'creator': creator,
        if (type != null) 'type': type,
        if (machine != null) 'machine': machine,
        if (poste != null) 'poste': poste,
        if (search != null && search!.trim().isNotEmpty) 'search': search!.trim(),
      };

  /// Compteurs : mêmes filtres que la liste, sauf le statut.
  Map<String, dynamic> toSummaryQuery() => toQuery()..remove('status');

  /// Au moins un filtre (autre que le statut) appliqué.
  bool get hasScopeFilters => toSummaryQuery().isNotEmpty;
}

/// Compteurs des cartes KPI (données backend).
typedef FicheApprovalCounts = ({int pending, int approved, int rejected, int processed});
