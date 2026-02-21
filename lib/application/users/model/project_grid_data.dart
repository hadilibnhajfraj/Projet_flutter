class ProjectGridData {
  final String id;
  final String nomProjet;
  final String entreprise;
  final String statut;
  final String adresse;
  final String dateDemarrage;
  final String permission;

  // ✅ NEW FIELDS
  final String ingenieurResponsable;  // Add this field
  final String architecte;  // Add this field
  final int commentCount;
  final String validationStatut; 

  ProjectGridData({
    required this.id,
    required this.nomProjet,
    required this.entreprise,
    required this.statut,
    required this.adresse,
    required this.dateDemarrage,
    required this.permission,
    required this.commentCount,  // ✅ لازم
    required this.ingenieurResponsable,  // Required
    required this.architecte,  // Required
    required this.validationStatut,
  });

  bool get canEdit => permission == "owner" || permission == "editor";
  bool get canDelete => permission == "owner";

  factory ProjectGridData.fromJson(Map<String, dynamic> json) {
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
      ingenieurResponsable: (json["ingenieurResponsable"] ?? "").toString(), // Add this
      architecte: (json["architecte"] ?? "").toString(), // Add this
      validationStatut: (json["validationStatut"] ?? "").toString(),
    );
  }
}