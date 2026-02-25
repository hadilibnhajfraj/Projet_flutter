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
  final String validationStatut;

  final String ownerName;

  // ✅ NEW
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
    required this.ingenieurResponsable,
    required this.architecte,
    required this.validationStatut,
    required this.ownerName,
    required this.hasDevis,
    required this.hasBonCommande,
  });

  // ✅ RESTORE getters (important)
  bool get canEdit => permission == "owner" || permission == "editor";
  bool get canDelete => permission == "owner";

  factory ProjectGridData.fromJson(Map<String, dynamic> json) {
    final devisCount = int.tryParse("${json["devisCount"] ?? 0}") ?? 0;
    final bcCount = int.tryParse("${json["bonCommandeCount"] ?? 0}") ?? 0;

    return ProjectGridData(
      id: (json["id"] ?? "").toString(),
      nomProjet: (json["nomProjet"] ?? "").toString(),
      entreprise: (json["entreprise"] ?? "").toString(),
      statut: (json["statut"] ?? "").toString(),
      adresse: (json["adresse"] ?? "").toString(),
      dateDemarrage: (json["dateDemarrage"] ?? "").toString(),
      permission: (json["permission"] ?? "viewer").toString(),
      commentCount: (json["commentCount"] is int)
          ? (json["commentCount"] as int)
          : int.tryParse("${json["commentCount"] ?? 0}") ?? 0,
      ingenieurResponsable: (json["ingenieurResponsable"] ?? "").toString(),
      architecte: (json["architecte"] ?? "").toString(),
      validationStatut: (json["validationStatut"] ?? "").toString(),
      ownerName: (json["ownerName"] ?? "").toString(),

      // ✅ from backend counts
      hasDevis: devisCount > 0,
      hasBonCommande: bcCount > 0,
    );
  }
}