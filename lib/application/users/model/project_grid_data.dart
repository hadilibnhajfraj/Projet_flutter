class ProjectGridData {
  final String id;
  final String nomProjet;
  final String entreprise;
  final String statut;
  final String adresse;
  final String dateDemarrage;
  final String permission;

  final String ingenieurResponsable;
  final String architecte;

  final int commentCount;
  final int taskCount; // ✅

  final String validationStatut;
  final String ownerName;
  final bool isArchived;
  final bool hasDevis;
  final bool hasBonCommande;

  ProjectGridData({
    required this.id,
    required this.nomProjet,
    required this.entreprise,
    required this.statut,
    required this.adresse,
    required this.dateDemarrage,
    required this.permission,
    required this.commentCount,
    required this.taskCount,
    required this.ingenieurResponsable,
    required this.isArchived,
    required this.architecte,
    required this.validationStatut,
    required this.ownerName,
    required this.hasDevis,
    required this.hasBonCommande,
  });

  bool get canEdit => permission == "owner" || permission == "editor";
  bool get canDelete => permission == "owner";

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  factory ProjectGridData.fromJson(Map<String, dynamic> json) {
    final devisCount = _toInt(json["devisCount"]);
    final bcCount = _toInt(json["bonCommandeCount"]);

    return ProjectGridData(
      id: (json["id"] ?? "").toString(),
      nomProjet: (json["nomProjet"] ?? "").toString(),
      entreprise: (json["entreprise"] ?? "").toString(),
      isArchived: json["isArchived"] ?? false,
      statut: (json["statut"] ?? "").toString(),
      adresse: (json["adresse"] ?? "").toString(),
      dateDemarrage: (json["dateDemarrage"] ?? "").toString(),
      permission: (json["permission"] ?? "viewer").toString(),
      commentCount: _toInt(json["commentCount"]),
      taskCount: _toInt(json["taskCount"]), // ✅ IMPORTANT

      ingenieurResponsable: (json["ingenieurResponsable"] ?? "").toString(),
      architecte: (json["architecte"] ?? "").toString(),
      validationStatut: (json["validationStatut"] ?? "").toString(),
      ownerName: (json["ownerName"] ?? "").toString(),

      hasDevis: devisCount > 0,
      hasBonCommande: bcCount > 0,
    );
  }
}