class ProjectGridData {
  final String id;
  final String nomProjet;
  final String statut;
  final String entreprise;
  final String adresse;
  final String dateDemarrage;

  ProjectGridData({
    required this.id,
    required this.nomProjet,
    required this.statut,
    required this.entreprise,
    required this.adresse,
    required this.dateDemarrage,
  });

  factory ProjectGridData.fromJson(Map<String, dynamic> j) {
    return ProjectGridData(
      id: (j['id'] ?? '').toString(),
      nomProjet: (j['nomProjet'] ?? '').toString(),
      statut: (j['statut'] ?? '').toString(),
      entreprise: (j['entreprise'] ?? '').toString(),
      adresse: (j['adresse'] ?? '').toString(),
      dateDemarrage: (j['dateDemarrage'] ?? '').toString(),
    );
  }
}
