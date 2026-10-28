// lib/forms/raw_material_request/raw_material_request_record.dart
//
// Modèles du suivi des demandes de matières premières (menu « Matières
// premières ») — reflet exact des réponses de /raw-material-requests.

import 'package:flutter/material.dart';

import 'package:dash_master_toolkit/forms/view/pipeline_theme.dart';

/// Statuts (codes backend, config/rawMaterialRequest.js) → libellé français
/// (clé de traduction) et couleur.
const kRawMaterialPendingColor = Color(0xFFEA580C);

const kRawMaterialStatuses = <String, (String, Color)>{
  'PENDING_VALIDATION': ('En attente de validation', kRawMaterialPendingColor),
  'DRAFT': ('Brouillon', kCrmTextSub),
  'SUBMITTED': ('Soumise', kCrmInfo),
  'VALIDATED': ('Validée', kCrmSuccess),
  'REJECTED': ('Rejetée', kCrmDanger),
  'IN_PROGRESS': ('En cours de traitement', kCrmWarning),
  'PROCESSED': ('Traitée', kCrmPrimary),
  'EVENING_ACCEPTED': ('Acceptée par le shift soir', Color(0xFF0D9488)),
  'EVENING_REFUSED': ('Refusée par le shift soir', Color(0xFFB91C1C)),
};

String rawMaterialStatusLabel(String? status) => kRawMaterialStatuses[status]?.$1 ?? (status ?? '—');
Color rawMaterialStatusColor(String? status) => kRawMaterialStatuses[status]?.$2 ?? kCrmTextSub;

/// 'matin' → Matin, 'nuit' → Soir (libellé utilisé partout dans Production).
String rawMaterialPosteLabel(String? poste) => switch (poste) {
      'matin' => 'Matin',
      'nuit' => 'Soir',
      _ => poste ?? '—',
    };

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
double? _num(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

class RawMaterialItem {
  final String material;
  final String label;
  final String? reference;
  final String? lot;
  final double? quantiteDisponible;
  final double? besoinProduction;
  final double? quantiteDemandee;
  final String unite;

  const RawMaterialItem({
    required this.material,
    required this.label,
    this.reference,
    this.lot,
    this.quantiteDisponible,
    this.besoinProduction,
    this.quantiteDemandee,
    this.unite = 'KG',
  });

  factory RawMaterialItem.fromJson(Map<String, dynamic> j) => RawMaterialItem(
        material: j['material']?.toString() ?? '',
        label: j['label']?.toString() ?? j['material']?.toString() ?? '',
        reference: j['reference']?.toString(),
        lot: j['lot']?.toString(),
        quantiteDisponible: _num(j['quantiteDisponible']),
        besoinProduction: _num(j['besoinProduction']),
        quantiteDemandee: _num(j['quantiteDemandee']),
        unite: j['unite']?.toString() ?? 'KG',
      );

  Map<String, dynamic> toJson() => {
        'material': material,
        'label': label,
        'reference': reference,
        'lot': lot,
        'quantiteDisponible': quantiteDisponible,
        'besoinProduction': besoinProduction,
        'quantiteDemandee': quantiteDemandee,
        'unite': unite,
      };
}

class RawMaterialStatusChange {
  final String? fromStatus; // null : création
  final String toStatus;
  final String? changedByEmail;
  final String? comment;
  final DateTime? createdAt;

  const RawMaterialStatusChange({this.fromStatus, required this.toStatus, this.changedByEmail, this.comment, this.createdAt});

  factory RawMaterialStatusChange.fromJson(Map<String, dynamic> j) => RawMaterialStatusChange(
        fromStatus: j['fromStatus']?.toString(),
        toStatus: j['toStatus']?.toString() ?? '',
        changedByEmail: j['changedByEmail']?.toString(),
        comment: j['comment']?.toString(),
        createdAt: _date(j['createdAt']),
      );
}

class RawMaterialRequestRecord {
  final String id;
  final String requestNumber;
  final String? userId;
  final String userEmail;
  final String? module;
  final String? machine;
  final String poste;
  final String? productionDate; // AAAA-MM-JJ
  final List<RawMaterialItem> items;
  final String status;
  final DateTime? validatedAt;
  final String? validatedByEmail;
  final DateTime? createdAt;
  final List<RawMaterialStatusChange> history; // vide dans la liste, rempli au détail
  // Échéance de validation (vendredi 14 h) et indicateurs calculés par le serveur.
  final DateTime? deadlineAt;
  final bool overdue;
  final bool dueSoon;
  final DateTime? rejectedAt;
  final String? rejectedByEmail;
  final String? rejectionComment;
  // Détail uniquement : le demandeur peut corriger sa demande rejetée.
  final bool canResubmit;
  // Shift soir : quantités réelles par matière (code → KG), prise en charge.
  final Map<String, double?>? actualQuantities;
  final DateTime? eveningHandledAt;
  final String? eveningHandledByEmail;
  final String? eveningRefusalComment;
  // Détail uniquement : le shift soir peut accepter / refuser cette demande.
  final bool canEveningHandle;

  const RawMaterialRequestRecord({
    required this.id,
    required this.requestNumber,
    this.userId,
    required this.userEmail,
    this.module,
    this.machine,
    required this.poste,
    this.productionDate,
    required this.items,
    required this.status,
    this.validatedAt,
    this.validatedByEmail,
    this.createdAt,
    this.history = const [],
    this.deadlineAt,
    this.overdue = false,
    this.dueSoon = false,
    this.rejectedAt,
    this.rejectedByEmail,
    this.rejectionComment,
    this.canResubmit = false,
    this.actualQuantities,
    this.eveningHandledAt,
    this.eveningHandledByEmail,
    this.eveningRefusalComment,
    this.canEveningHandle = false,
  });

  factory RawMaterialRequestRecord.fromJson(Map<String, dynamic> j) => RawMaterialRequestRecord(
        id: j['id']?.toString() ?? '',
        requestNumber: j['requestNumber']?.toString() ?? '',
        userId: j['userId']?.toString(),
        userEmail: j['userEmail']?.toString() ?? '',
        module: j['module']?.toString(),
        machine: j['machine']?.toString(),
        poste: j['poste']?.toString() ?? '',
        productionDate: j['productionDate']?.toString(),
        items: [
          for (final i in (j['items'] as List? ?? const []))
            if (i is Map) RawMaterialItem.fromJson(Map<String, dynamic>.from(i)),
        ],
        status: j['status']?.toString() ?? '',
        validatedAt: _date(j['validatedAt']),
        validatedByEmail: j['validatedByEmail']?.toString(),
        createdAt: _date(j['createdAt']),
        history: [
          for (final h in (j['history'] as List? ?? const []))
            if (h is Map) RawMaterialStatusChange.fromJson(Map<String, dynamic>.from(h)),
        ],
        deadlineAt: _date(j['deadlineAt']),
        overdue: j['overdue'] == true,
        dueSoon: j['dueSoon'] == true,
        rejectedAt: _date(j['rejectedAt']),
        rejectedByEmail: j['rejectedByEmail']?.toString(),
        rejectionComment: j['rejectionComment']?.toString(),
        canResubmit: j['canResubmit'] == true,
        actualQuantities: j['actualItems'] is List
            ? {
                for (final a in j['actualItems'] as List)
                  if (a is Map) a['material'].toString(): _num(a['quantiteReelle']),
              }
            : null,
        eveningHandledAt: _date(j['eveningHandledAt']),
        eveningHandledByEmail: j['eveningHandledByEmail']?.toString(),
        eveningRefusalComment: j['eveningRefusalComment']?.toString(),
        canEveningHandle: j['canEveningHandle'] == true,
      );
}

/// Droits renvoyés par GET /raw-material-requests/permissions.
class RawMaterialPermissions {
  final bool canView;
  final bool fullVisibility;
  final bool canManageStatus;
  // Responsable logistique achats : valide / rejette les demandes en attente.
  final bool canValidate;
  // Shift soir : accepte / refuse les demandes validées.
  final bool canEveningHandle;
  final Map<String, List<String>> transitions;

  const RawMaterialPermissions({
    this.canView = false,
    this.fullVisibility = false,
    this.canManageStatus = false,
    this.canValidate = false,
    this.canEveningHandle = false,
    this.transitions = const {},
  });

  factory RawMaterialPermissions.fromJson(Map<String, dynamic> j) => RawMaterialPermissions(
        canView: j['canView'] == true,
        fullVisibility: j['fullVisibility'] == true,
        canManageStatus: j['canManageStatus'] == true,
        canValidate: j['canValidate'] == true,
        canEveningHandle: j['canEveningHandle'] == true,
        transitions: {
          for (final e in (j['transitions'] as Map? ?? const {}).entries)
            e.key.toString(): [for (final s in (e.value as List? ?? const [])) s.toString()],
        },
      );

  // Transitions déjà filtrées par le backend selon le compte connecté.
  List<String> nextStatuses(String status) => transitions[status] ?? const [];
}

/// Filtres de la page de suivi — mêmes noms que les paramètres du backend.
class RawMaterialFilters {
  final DateTime? from;
  final DateTime? to;
  final String? userId;
  final String? poste;
  final String? material;
  final String? status;
  final String search;
  final int page;
  final int pageSize;
  // Demandes à valider : sans décision (en attente de validation ou soumises).
  final bool toProcess;

  const RawMaterialFilters({
    this.from,
    this.to,
    this.userId,
    this.poste,
    this.material,
    this.status,
    this.search = '',
    this.page = 1,
    this.pageSize = 20,
    this.toProcess = false,
  });

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toQuery({bool paged = true}) => {
        if (from != null) 'from': _iso(from!),
        if (to != null) 'to': _iso(to!),
        if (userId != null) 'userId': userId,
        if (poste != null) 'poste': poste,
        if (material != null) 'material': material,
        if (status != null) 'status': status,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (toProcess) 'toProcess': 'true',
        if (paged) 'page': page,
        if (paged) 'pageSize': pageSize,
      };

  bool get isEmpty =>
      from == null && to == null && userId == null && poste == null && material == null && status == null && search.trim().isEmpty;

  /// Copie ; `clear` remet à null les champs nommés (sentinelles simples).
  RawMaterialFilters copyWith({
    DateTime? from,
    DateTime? to,
    String? userId,
    String? poste,
    String? material,
    String? status,
    String? search,
    int? page,
    Set<String> clear = const {},
  }) =>
      RawMaterialFilters(
        from: clear.contains('from') ? null : (from ?? this.from),
        to: clear.contains('to') ? null : (to ?? this.to),
        userId: clear.contains('userId') ? null : (userId ?? this.userId),
        poste: clear.contains('poste') ? null : (poste ?? this.poste),
        material: clear.contains('material') ? null : (material ?? this.material),
        status: clear.contains('status') ? null : (status ?? this.status),
        search: search ?? this.search,
        page: page ?? this.page,
        pageSize: pageSize,
        toProcess: toProcess,
      );
}
