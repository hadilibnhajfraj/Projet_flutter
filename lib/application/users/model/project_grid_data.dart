class ProjectGridData {
  final String id;
  final String nomProjet;
  final String statut;
  final String entreprise;
  final String adresse;
  final String dateDemarrage;
  final String permission;

  ProjectGridData({
    required this.id,
    required this.nomProjet,
    required this.statut,
    required this.entreprise,
    required this.adresse,
    required this.dateDemarrage,
    required this.permission,
  });

  bool get canEdit => permission == "editor" || permission == "owner";
bool get canDelete => permission == "owner";


  factory ProjectGridData.fromJson(Map<String, dynamic> j) {
    return ProjectGridData(
      id: j["id"],
      nomProjet: j["nomProjet"] ?? "",
      statut: j["statut"] ?? "",
      entreprise: j["entreprise"] ?? "",
      adresse: j["adresse"] ?? "",
      dateDemarrage: j["dateDemarrage"] ?? "",
      permission: j["permission"] ?? "viewer",
    );
  }
}
