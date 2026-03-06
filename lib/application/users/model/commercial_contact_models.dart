class CommercialProductInput {
  String produit;
  double qte;

  CommercialProductInput({this.produit = "", this.qte = 1});

  Map<String, dynamic> toJson() => {
        "produit": produit.trim(),
        "qte": qte,
      };
}

class CommercialContactCreateDto {
  String typeClient; // "particulier" | "societe" | "entrepreneur" | "autre"
  String nomSociete;
  String nom;
  String prenom;
  String localisation;
  String telephone;
  String message;
  List<CommercialProductInput> produits;

  CommercialContactCreateDto({
    this.typeClient = "autre",
    this.nomSociete = "",
    this.nom = "",
    this.prenom = "",
    this.localisation = "",
    this.telephone = "",
    this.message = "",
    List<CommercialProductInput>? produits,
  }) : produits = produits ?? [];

  Map<String, dynamic> toJson() => {
        "typeClient": typeClient,
        "nomSociete": nomSociete.trim().isEmpty ? null : nomSociete.trim(),
        "nom": nom.trim(),
        "prenom": prenom.trim(),
        "localisation": localisation.trim().isEmpty ? null : localisation.trim(),
        "telephone": telephone.trim(),
        "message": message.trim().isEmpty ? null : message.trim(),
        "produits": produits
            .where((p) => p.produit.trim().isNotEmpty)
            .map((p) => p.toJson())
            .toList(),
      };
}