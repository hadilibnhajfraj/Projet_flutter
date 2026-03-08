class UserProjectModel {
  final String id;
  final String nomProjet;
  final String dateDemarrage;
  final String typeAdresseChantier;
  final String ingenieurResponsable;
  final String telephoneIngenieur;
  final String? architecte;
  final String? telephoneArchitecte;
  final String? matriculeFiscale;
  final String entreprise;
  final String? promoteur;
  final String? bureauEtude;
  final String bureauControle;
  final String? adresse;
  final String latitude;
  final String longitude;
  final String? localisationCommentaire;
  final String? statut;
  final String? entrepriseFluide;
  final String? entrepriseElectricite;
  final String? pourcentageReussite;
  final String? validationStatut;
  final String? typeProjet;
  final String? surfaceProspectee;
  final String createdAt;
  final String updatedAt;

  UserProjectModel({
    required this.id,
    required this.nomProjet,
    required this.dateDemarrage,
    required this.typeAdresseChantier,
    required this.ingenieurResponsable,
    required this.telephoneIngenieur,
    required this.architecte,
    required this.telephoneArchitecte,
    required this.matriculeFiscale,
    required this.entreprise,
    required this.promoteur,
    required this.bureauEtude,
    required this.bureauControle,
    required this.adresse,
    required this.latitude,
    required this.longitude,
    required this.localisationCommentaire,
    required this.statut,
    required this.entrepriseFluide,
    required this.entrepriseElectricite,
    required this.pourcentageReussite,
    required this.validationStatut,
    required this.typeProjet,
    required this.surfaceProspectee,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProjectModel.fromJson(Map<String, dynamic> json) {
    return UserProjectModel(
      id: (json['id'] ?? '').toString(),
      nomProjet: (json['nomProjet'] ?? '').toString(),
      dateDemarrage: (json['dateDemarrage'] ?? '').toString(),
      typeAdresseChantier: (json['typeAdresseChantier'] ?? '').toString(),
      ingenieurResponsable: (json['ingenieurResponsable'] ?? '').toString(),
      telephoneIngenieur: (json['telephoneIngenieur'] ?? '').toString(),
      architecte: json['architecte']?.toString(),
      telephoneArchitecte: json['telephoneArchitecte']?.toString(),
      matriculeFiscale: json['matriculeFiscale']?.toString(),
      entreprise: (json['entreprise'] ?? '').toString(),
      promoteur: json['promoteur']?.toString(),
      bureauEtude: json['bureauEtude']?.toString(),
      bureauControle: (json['bureauControle'] ?? '').toString(),
      adresse: json['adresse']?.toString(),
      latitude: (json['latitude'] ?? '').toString(),
      longitude: (json['longitude'] ?? '').toString(),
      localisationCommentaire: json['localisationCommentaire']?.toString(),
      statut: json['statut']?.toString(),
      entrepriseFluide: json['entrepriseFluide']?.toString(),
      entrepriseElectricite: json['entrepriseElectricite']?.toString(),
      pourcentageReussite: json['pourcentageReussite']?.toString(),
      validationStatut: json['validationStatut']?.toString(),
      typeProjet: json['typeProjet']?.toString(),
      surfaceProspectee: json['surfaceProspectee']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
    );
  }
}

class UserProjectsResponse {
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final List<UserProjectModel> items;

  UserProjectsResponse({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.items,
  });

  factory UserProjectsResponse.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List?) ?? const [];

    return UserProjectsResponse(
      total: int.tryParse('${json['total'] ?? 0}') ?? 0,
      page: int.tryParse('${json['page'] ?? 1}') ?? 1,
      limit: int.tryParse('${json['limit'] ?? 10}') ?? 10,
      totalPages: int.tryParse('${json['totalPages'] ?? 1}') ?? 1,
      items: itemsJson
          .map((e) => UserProjectModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}