class CommercialContactProduct {
  final String id;
  final String produit;
  final double qte;

  CommercialContactProduct({
    required this.id,
    required this.produit,
    required this.qte,
  });

  factory CommercialContactProduct.fromJson(Map<String, dynamic> json) {
    return CommercialContactProduct(
      id: json['id']?.toString() ?? '',
      produit: (json['produit']?.toString().trim().isNotEmpty ?? false)
          ? json['produit'].toString()
          : 'PROBAR',
      qte: double.tryParse(json['qte']?.toString() ?? '1') ?? 1,
    );
  }
}

class CommercialContactRelance {
  final String id;
  final String? dateRelance;
  final String? heureRelance;
  final String? commentaire;
  final String? statutRelance;

  CommercialContactRelance({
    required this.id,
    this.dateRelance,
    this.heureRelance,
    this.commentaire,
    this.statutRelance,
  });

  factory CommercialContactRelance.fromJson(Map<String, dynamic> json) {
    return CommercialContactRelance(
      id: json['id']?.toString() ?? '',
      dateRelance: json['dateRelance']?.toString(),
      heureRelance: json['heureRelance']?.toString(),
      commentaire: json['commentaire']?.toString(),
      statutRelance: json['statutRelance']?.toString(),
    );
  }
}
class CommercialProject {
  final String id;
  final String? nomProjet;
  final String? localisation;
  final String? typeProjet;
  final String? description;

  CommercialProject({
    required this.id,
    this.nomProjet,
    this.localisation,
    this.typeProjet,
    this.description,
  });

  factory CommercialProject.fromJson(Map<String, dynamic> json) {
    return CommercialProject(
      id: json['id']?.toString() ?? '',
      nomProjet: json['nomProjet']?.toString(),
      localisation: json['localisation']?.toString(),
      typeProjet: json['typeProjet']?.toString(),
      description: json['description']?.toString(),
    );
  }
}
class CommercialContact {
  final String id;
  final String typeClient;
  final String statut;
  final String? nomSociete;
  final String nom;
  final String prenom;
  final String? localisation;
  final String telephone;
  final String? message;
  final String? createdBy;
  final int nbAppels;
  final String? sujetDiscussion;

  // ✅ NEW FIELDS (IMPORTANT)
  final String pipelineStage;
  final DateTime? dateAppel;

  final List<CommercialContactProduct> produits;
  final List<CommercialProject> projects;
  final List<CommercialContactRelance> relances;
  final DateTime? createdAt;

  CommercialContact({
    required this.id,
    required this.typeClient,
    required this.statut,
    this.nomSociete,
    required this.nom,
    required this.prenom,
    this.localisation,
    required this.telephone,
    this.message,
    this.createdBy,
    required this.nbAppels,
    this.sujetDiscussion,

    // ✅ NEW
    required this.pipelineStage,
    this.dateAppel,
    required this.projects,
    required this.produits,
    required this.relances,
    this.createdAt,
  });

  factory CommercialContact.fromJson(Map<String, dynamic> json) {
    return CommercialContact(
      id: json['id']?.toString() ?? '',

      typeClient: json['typeClient']?.toString() ?? 'autre',
      statut: json['statut']?.toString() ?? 'user_injoignable',

      nomSociete: json['nomSociete']?.toString(),

      nom: (json['nom']?.toString() ?? '').trim(),
      prenom: (json['prenom']?.toString() ?? '').trim(),

      localisation: json['localisation']?.toString(),
      telephone: json['telephone']?.toString() ?? '',

      message: json['message']?.toString(),
      createdBy: json['createdBy']?.toString(),

      nbAppels: int.tryParse(json['nbAppels']?.toString() ?? '0') ?? 0,
      sujetDiscussion: json['sujetDiscussion']?.toString(),

      // ✅ NEW PARSING
      pipelineStage: json['pipelineStage']?.toString() ?? 'Prospect',

      dateAppel: json['dateAppel'] != null
          ? DateTime.tryParse(json['dateAppel'].toString())
          : null,

      produits: (json['produits'] as List<dynamic>? ?? [])
          .map((e) => CommercialContactProduct.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
      projects: (json['projects'] as List<dynamic>? ?? [])
    .map((e) => CommercialProject.fromJson(e as Map<String, dynamic>))
    .toList(),

      relances: (json['relances'] as List<dynamic>? ?? [])
          .map((e) => CommercialContactRelance.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),

      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  String get fullName => '$nom $prenom';

  // ✅ BONUS UI (pro)
  String get displayPipeline {
    switch (pipelineStage) {
      case "Prospect":
        return "🔵 Prospect";
      case "Devis envoyé":
        return "🟣 Devis";
      case "Negociation":
        return "🟡 Négociation";
      case "Gagné":
        return "🟢 Gagné";
      case "Perdu":
        return "🔴 Perdu";
      default:
        return pipelineStage;
    }
  }
}