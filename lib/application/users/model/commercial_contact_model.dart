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
      produit: json['produit']?.toString() ?? '',
      qte: double.tryParse(json['qte']?.toString() ?? '0') ?? 0,
    );
  }
}

class CommercialContact {
  final String id;
  final String typeClient;
  final String? nomSociete;
  final String nom;
  final String prenom;
  final String? localisation;
  final String telephone;
  final String? message;
  final String? createdBy;
  final List<CommercialContactProduct> produits;
  final DateTime? createdAt;

  CommercialContact({
    required this.id,
    required this.typeClient,
    this.nomSociete,
    required this.nom,
    required this.prenom,
    this.localisation,
    required this.telephone,
    this.message,
    this.createdBy,
    required this.produits,
    this.createdAt,
  });

  factory CommercialContact.fromJson(Map<String, dynamic> json) {
    return CommercialContact(
      id: json['id']?.toString() ?? '',
      typeClient: json['typeClient']?.toString() ?? '',
      nomSociete: json['nomSociete']?.toString(),
      nom: json['nom']?.toString() ?? '',
      prenom: json['prenom']?.toString() ?? '',
      localisation: json['localisation']?.toString(),
      telephone: json['telephone']?.toString() ?? '',
      message: json['message']?.toString(),
      createdBy: json['createdBy']?.toString(),
      produits: (json['produits'] as List<dynamic>? ?? [])
          .map((e) => CommercialContactProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  String get fullName => '$nom $prenom';
}