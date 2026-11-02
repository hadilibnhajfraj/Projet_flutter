// Module « Notes de calcul » — modèles (réponses de /calculation-notes).

import 'package:flutter/material.dart';

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
String? _str(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Erreur de désérialisation d'une réponse de /calculation-notes : nomme le
/// champ en cause au lieu d'une TypeError anonyme.
class CalculationNoteFormatException implements Exception {
  final String field;
  final Object? value;
  const CalculationNoteFormatException(this.field, this.value);
  @override
  String toString() => 'Réponse inattendue du serveur (champ « $field » : ${value.runtimeType}).';
}

/// Entier facultatif : nombre JSON (ou texte numérique) ; jamais une liste
/// ou un objet convertis arbitrairement — null dans ce cas.
int? _int(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// Entier obligatoire (identifiants) : erreur explicite s'il manque.
int _reqInt(Map j, String field) => _int(j[field]) ?? (throw CalculationNoteFormatException(field, j[field]));

/// Liste d'objets JSON (éléments non-objets ignorés).
List<Map> _maps(dynamic v) => v is List ? v.whereType<Map>().toList() : const [];

class NoteUser {
  final String id;
  final String email;
  final String name;
  final String? role;
  const NoteUser({required this.id, required this.email, required this.name, this.role});

  static NoteUser? fromJson(dynamic j) {
    if (j is! Map) return null;
    final email = j['email']?.toString() ?? '';
    final name = _str(j['name']) ?? email;
    return NoteUser(id: j['id'].toString(), email: email, name: name, role: _str(j['role']));
  }

  /// « email · rôle » (présentation d'un collaborateur).
  String get details => [email, if (role != null) kNoteRoleLabels[role] ?? role!].join(' · ');
}

/// Libellés des rôles CRM (clés de traduction).
const kNoteRoleLabels = <String, String>{
  'user': 'Utilisateur CRM',
  'commercial': 'Commercial',
  'admin': 'Administrateur',
  'superadmin': 'Super administrateur',
  'superadmin2': 'Super administrateur',
};

/// Envoi d'un email lié à une note (file d'envoi du backend).
class NoteEmailStatus {
  final String id;
  final String to;
  final String subject;
  final String status; // PENDING | RETRYING | SENT | FAILED | CANCELLED
  final int attempts;
  final String? lastErrorMessage;
  final DateTime? sentAt;
  final DateTime? nextAttemptAt;
  const NoteEmailStatus({required this.id, required this.to, required this.subject, required this.status, this.attempts = 0, this.lastErrorMessage, this.sentAt, this.nextAttemptAt});

  factory NoteEmailStatus.fromJson(Map j) => NoteEmailStatus(
        id: j['id'].toString(),
        to: j['to']?.toString() ?? '',
        subject: j['subject']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        attempts: _int(j['attempts']) ?? 0,
        lastErrorMessage: _str(j['lastErrorMessage']),
        sentAt: _date(j['sentAt']),
        nextAttemptAt: _date(j['nextAttemptAt']),
      );
}

/// Entrée de l'historique des affectations.
class NoteAssignmentEntry {
  final String action; // NOTE_ASSIGNED | ASSIGNMENT_CHANGED | ASSIGNMENT_REMOVED
  final NoteUser? from;
  final NoteUser? to;
  final NoteUser? by;
  final DateTime? createdAt;
  const NoteAssignmentEntry({required this.action, this.from, this.to, this.by, this.createdAt});

  factory NoteAssignmentEntry.fromJson(Map j) => NoteAssignmentEntry(
        action: j['action']?.toString() ?? '',
        from: NoteUser.fromJson(j['from']),
        to: NoteUser.fromJson(j['to']),
        by: NoteUser.fromJson(j['by']),
        createdAt: _date(j['createdAt']),
      );
}

class NoteProject {
  final String id;
  final String nomProjet;
  final String? statut;
  final String? projectModele;
  final String? entreprise;
  final String? adresse;
  final bool isArchived;
  const NoteProject({required this.id, required this.nomProjet, this.statut, this.projectModele, this.entreprise, this.adresse, this.isArchived = false});

  static NoteProject? fromJson(dynamic j) {
    if (j is! Map) return null;
    return NoteProject(
      id: j['id'].toString(),
      nomProjet: j['nomProjet']?.toString() ?? '',
      statut: _str(j['statut']),
      projectModele: _str(j['projectModele']),
      entreprise: _str(j['entreprise']),
      adresse: _str(j['adresse']),
      isArchived: j['isArchived'] == true,
    );
  }
}

class NoteDocument {
  final String id;
  final int noteId;
  final String originalName;
  final String extension;
  final String mimeType;
  final int sizeBytes;
  final String? commentaire;
  final String? title;
  final String? documentType;
  /// INITIAL (création) | ADDED (ajouté par un éditeur) | COMPLEMENTARY
  /// (déposé par l'utilisateur affecté).
  final String origin;
  final NoteUser? uploadedBy;
  final DateTime? createdAt;
  const NoteDocument({
    required this.id,
    required this.noteId,
    required this.originalName,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
    this.commentaire,
    this.title,
    this.documentType,
    this.origin = kNoteDocOriginInitial,
    this.uploadedBy,
    this.createdAt,
  });

  bool get isPdf => extension == 'pdf';

  bool get isComplementary => origin == kNoteDocOriginComplementary;

  factory NoteDocument.fromJson(Map j) => NoteDocument(
        id: j['id'].toString(),
        noteId: _reqInt(j, 'noteId'),
        originalName: j['originalName']?.toString() ?? '',
        extension: (j['extension']?.toString() ?? '').toLowerCase(),
        mimeType: j['mimeType']?.toString() ?? '',
        sizeBytes: _int(j['sizeBytes']) ?? 0,
        commentaire: _str(j['commentaire']),
        title: _str(j['title']),
        documentType: _str(j['documentType']),
        origin: _str(j['origin']) ?? kNoteDocOriginInitial,
        uploadedBy: NoteUser.fromJson(j['uploadedBy']),
        createdAt: _date(j['createdAt']),
      );
}

class NoteHistoryEntry {
  final String action;
  final NoteUser? user;
  final Map<String, dynamic> details;
  final DateTime? createdAt;
  const NoteHistoryEntry({required this.action, this.user, this.details = const {}, this.createdAt});

  factory NoteHistoryEntry.fromJson(Map j) => NoteHistoryEntry(
        action: j['action']?.toString() ?? '',
        user: NoteUser.fromJson(j['user']),
        details: j['details'] is Map ? Map<String, dynamic>.from(j['details'] as Map) : const {},
        createdAt: _date(j['createdAt']),
      );
}

/// Statut de validation et décision (communs à la liste et au détail).
/// can* = actions que le backend autorisera à l'utilisateur connecté.
class NoteWorkflow {
  final String status;
  final String statusLabel;
  final int submissionVersion;
  final DateTime? submittedAt;
  final NoteUser? validator;
  final NoteUser? decidedBy;
  final DateTime? decidedAt;
  final String? decisionComment;
  final NoteUser? cancelledBy;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final bool canDecide;
  final bool canCancel;
  final NoteUser? assignedTo;
  final DateTime? assignedAt;
  final NoteUser? assignedBy;
  const NoteWorkflow({
    this.status = kNoteStatusPending,
    this.statusLabel = 'En attente de validation',
    this.submissionVersion = 1,
    this.submittedAt,
    this.validator,
    this.decidedBy,
    this.decidedAt,
    this.decisionComment,
    this.cancelledBy,
    this.cancelledAt,
    this.cancellationReason,
    this.canDecide = false,
    this.canCancel = false,
    this.assignedTo,
    this.assignedAt,
    this.assignedBy,
  });

  factory NoteWorkflow.fromJson(Map j) => NoteWorkflow(
        status: _str(j['status']) ?? kNoteStatusPending,
        statusLabel: _str(j['statusLabel']) ?? kNoteStatusLabels[_str(j['status'])] ?? '',
        submissionVersion: _int(j['submissionVersion']) ?? 1,
        submittedAt: _date(j['submittedAt']),
        validator: NoteUser.fromJson(j['validator']),
        decidedBy: NoteUser.fromJson(j['decidedBy']),
        decidedAt: _date(j['decidedAt']),
        decisionComment: _str(j['decisionComment']),
        cancelledBy: NoteUser.fromJson(j['cancelledBy']),
        cancelledAt: _date(j['cancelledAt']),
        cancellationReason: _str(j['cancellationReason']),
        canDecide: j['canDecide'] == true,
        canCancel: j['canCancel'] == true,
        assignedTo: NoteUser.fromJson(j['assignedTo']),
        assignedAt: _date(j['assignedAt']),
        assignedBy: NoteUser.fromJson(j['assignedBy']),
      );
}

/// Ligne de la liste.
class CalculationNoteSummary {
  final int id;
  final String reference;
  final NoteProject? project;
  final NoteUser? requester;
  final NoteUser? creator;
  final DateTime? createdAt;
  final int documentsCount;
  final String? commentaire;
  final String? observations;
  final bool canEdit;
  final NoteWorkflow workflow;
  const CalculationNoteSummary({
    required this.id,
    required this.reference,
    this.project,
    this.requester,
    this.creator,
    this.createdAt,
    this.documentsCount = 0,
    this.commentaire,
    this.observations,
    this.canEdit = false,
    this.workflow = const NoteWorkflow(),
  });

  factory CalculationNoteSummary.fromJson(Map j) => CalculationNoteSummary(
        id: _reqInt(j, 'id'),
        reference: j['reference']?.toString() ?? '',
        project: NoteProject.fromJson(j['project']),
        requester: NoteUser.fromJson(j['requester']),
        creator: NoteUser.fromJson(j['creator']),
        createdAt: _date(j['createdAt']),
        documentsCount: _int(j['documentsCount']) ?? 0,
        commentaire: _str(j['commentaire']),
        observations: _str(j['observations']),
        canEdit: j['canEdit'] == true,
        workflow: NoteWorkflow.fromJson(j),
      );
}

class CalculationNoteDetail {
  final int id;
  final String reference;
  final NoteProject? project;
  final NoteUser? requester;
  final NoteUser? creator;
  final String? commentaire;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<NoteDocument> documents;
  final List<NoteHistoryEntry> history;
  final bool canEdit;
  final bool canResubmit;
  final bool canAssign;
  final bool canManageNotifications;
  final bool canAddComplementary;
  final NoteWorkflow workflow;
  const CalculationNoteDetail({
    required this.id,
    required this.reference,
    this.project,
    this.requester,
    this.creator,
    this.commentaire,
    this.createdAt,
    this.updatedAt,
    this.documents = const [],
    this.history = const [],
    this.canEdit = false,
    this.canResubmit = false,
    this.canAssign = false,
    this.canManageNotifications = false,
    this.canAddComplementary = false,
    this.workflow = const NoteWorkflow(),
  });

  factory CalculationNoteDetail.fromJson(Map j) => CalculationNoteDetail(
        id: _reqInt(j, 'id'),
        reference: j['reference']?.toString() ?? '',
        project: NoteProject.fromJson(j['project']),
        requester: NoteUser.fromJson(j['requester']),
        creator: NoteUser.fromJson(j['creator']),
        commentaire: _str(j['commentaire']),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        documents: _maps(j['documents']).map(NoteDocument.fromJson).toList(),
        history: _maps(j['history']).map(NoteHistoryEntry.fromJson).toList(),
        canEdit: j['canEdit'] == true,
        canResubmit: j['canResubmit'] == true,
        canAssign: j['canAssign'] == true,
        canManageNotifications: j['canManageNotifications'] == true,
        canAddComplementary: j['canAddComplementary'] == true,
        workflow: NoteWorkflow.fromJson(j),
      );
}

class CalculationNotePage {
  final List<CalculationNoteSummary> data;
  final int page;
  final int totalPages;
  final int total;
  final Map<String, int> summary;
  /// Nombre de notes par créateur (même périmètre que la liste).
  final List<({NoteUser user, int count})> byCreator;
  const CalculationNotePage({required this.data, required this.page, required this.totalPages, required this.total, required this.summary, this.byCreator = const []});

  factory CalculationNotePage.fromJson(Map j) {
    final p = j['pagination'] is Map ? j['pagination'] as Map : const {};
    final s = j['summary'] is Map ? j['summary'] as Map : const {};
    return CalculationNotePage(
      data: _maps(j['data']).map(CalculationNoteSummary.fromJson).toList(),
      page: _int(p['page']) ?? 1,
      totalPages: _int(p['totalPages']) ?? 1,
      total: _int(p['total']) ?? 0,
      // summary = compteurs (nombres : total, thisMonth, documents, mine et un
      // par statut) + byCreator (LISTE [{ user, count }]). Seuls les nombres
      // vont dans `summary` : une liste n'est jamais convertie en nombre.
      summary: {for (final e in s.entries) if (e.value is num) e.key.toString(): (e.value as num).toInt()},
      byCreator: [
        for (final r in _maps(s['byCreator']))
          if (NoteUser.fromJson(r['user']) != null) (user: NoteUser.fromJson(r['user'])!, count: _int(r['count']) ?? 0),
      ],
    );
  }
}

class CalculationNoteOptions {
  final List<NoteProject> projects;
  final List<NoteUser> requesters;
  /// « Affecter à » : utilisateurs CRM actifs autorisés (lus en base).
  final List<NoteUser> assignees;
  final bool assigneeRequired;
  final String? currentUserId;
  const CalculationNoteOptions({this.projects = const [], this.requesters = const [], this.assignees = const [], this.assigneeRequired = false, this.currentUserId});

  factory CalculationNoteOptions.fromJson(Map j) => CalculationNoteOptions(
        projects: _maps(j['projects']).map((p) => NoteProject.fromJson(p)!).toList(),
        requesters: _maps(j['requesters']).map((u) => NoteUser.fromJson(u)!).toList(),
        assignees: _maps(j['assignees']).map((u) => NoteUser.fromJson(u)!).toList(),
        assigneeRequired: j['assigneeRequired'] == true,
        currentUserId: _str(j['currentUserId']),
      );
}

/// Document choisi localement, pas encore envoyé : nom réel du fichier
/// (jamais saisi), type et commentaire propres à chaque document.
class PendingNoteDocument {
  final String name;
  final List<int> bytes;
  final TextEditingController comment;
  String? documentType;
  PendingNoteDocument({required this.name, required this.bytes, String commentaire = '', this.documentType})
      : comment = TextEditingController(text: commentaire);

  String get extension {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }
}

// Origine d'un document.
const kNoteDocOriginInitial = 'INITIAL';
const kNoteDocOriginAdded = 'ADDED';
const kNoteDocOriginComplementary = 'COMPLEMENTARY';

// ── Validation ───────────────────────────────────────────────────────────
const kNoteStatusPending = 'EN_ATTENTE_VALIDATION';
const kNoteStatusValidated = 'VALIDEE';
const kNoteStatusRejected = 'REFUSEE';
const kNoteStatusCancelled = 'ANNULEE';
const kNoteStatusLabels = <String, String>{
  kNoteStatusPending: 'En attente de validation',
  kNoteStatusValidated: 'Validée',
  kNoteStatusRejected: 'Refusée',
  kNoteStatusCancelled: 'Annulée',
};

/// Validateur officiel (affichage du menu uniquement : le backend vérifie
/// l'ID du validateur enregistré sur chaque note).
const kCalculationNoteValidatorEmail = 'medwethekgc@gmail.com';
bool isCalculationNoteValidator(String? email) => (email ?? '').trim().toLowerCase() == kCalculationNoteValidatorEmail;

// ── Présentation ─────────────────────────────────────────────────────────
const kNoteAllowedExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx'];

/// Types de document (mêmes valeurs que DOCUMENT_TYPES côté backend) →
/// libellé français (clé de traduction).
const kNoteDocumentTypes = <String, String>{
  'note_de_calcul': 'Note de calcul',
  'plan': 'Plan',
  'hypotheses': 'Hypothèses',
  'metre': 'Métré',
  'rapport': 'Rapport',
  'annexe': 'Annexe',
  'autre': 'Autre',
};

String formatNoteFileSize(int bytes) {
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1).replaceAll('.', ',')} Ko';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}

String formatNoteDate(DateTime? d, {bool withTime = false}) {
  if (d == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${two(d.day)}/${two(d.month)}/${d.year}';
  return withTime ? '$date ${two(d.hour)}:${two(d.minute)}' : date;
}

({IconData icon, Color color}) noteFileVisual(String extension) {
  switch (extension) {
    case 'pdf':
      return (icon: Icons.picture_as_pdf_rounded, color: const Color(0xFFDC2626));
    case 'doc':
    case 'docx':
      return (icon: Icons.description_rounded, color: const Color(0xFF2563EB));
    case 'xls':
    case 'xlsx':
      return (icon: Icons.table_chart_rounded, color: const Color(0xFF16A34A));
    default:
      return (icon: Icons.insert_drive_file_rounded, color: const Color(0xFF64748B));
  }
}
