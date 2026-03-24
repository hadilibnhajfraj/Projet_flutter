class CommercialProductInput {
  String produit;
  double qte;

  CommercialProductInput({
    this.produit = "PROBAR",
    this.qte = 1,
  });

  Map<String, dynamic> toJson() => {
        "produit": produit.trim().isEmpty ? "PROBAR" : produit.trim(),
        "qte": qte <= 0 ? 1 : qte,
      };
}

class CommercialRelanceInput {
  String? dateRelance;
  String? heureRelance;
  String commentaire;
  int nbAppels;
  String sujetDiscussion;

  CommercialRelanceInput({
    this.dateRelance,
    this.heureRelance,
    this.commentaire = "",
    this.nbAppels = 0,
    this.sujetDiscussion = "",
  });

  Map<String, dynamic> toJson() => {
        "dateRelance": dateRelance,
        "heureRelance": heureRelance,
        "commentaire": commentaire.trim().isEmpty ? null : commentaire.trim(),
        "nbAppels": nbAppels,
        "sujetDiscussion":
            sujetDiscussion.trim().isEmpty ? null : sujetDiscussion.trim(),
      };
}

class CommercialContactCreateDto {
  String typeClient;
  String statut;
  String nomSociete;
  String nom;
  String prenom;
  String localisation;
  String telephone;
  String message;
  int nbAppels;
  String sujetDiscussion;
  List<CommercialProductInput> produits;
  CommercialRelanceInput? relance;

  // ✅ NEW
  String pipelineStage;
  String? dateAppel;

  CommercialContactCreateDto({
    this.typeClient = "autre",
    this.statut = "user_injoignable",
    this.nomSociete = "",
    this.nom = "",
    this.prenom = "",
    this.localisation = "",
    this.telephone = "",
    this.message = "",
    this.nbAppels = 0,
    this.sujetDiscussion = "",
    List<CommercialProductInput>? produits,
    this.relance,

    // ✅ NEW
    this.pipelineStage = "Prospect",
    this.dateAppel,
  }) : produits = produits ?? [CommercialProductInput()];

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      "typeClient": typeClient,
      "statut": statut,
      "nomSociete": nomSociete.trim().isEmpty ? null : nomSociete.trim(),
      "nom": nom.trim(),
      "prenom": prenom.trim(),
      "localisation": localisation.trim().isEmpty ? null : localisation.trim(),
      "telephone": telephone.trim(),
      "message": message.trim().isEmpty ? null : message.trim(),
      "nbAppels": nbAppels,
      "sujetDiscussion":
          sujetDiscussion.trim().isEmpty ? null : sujetDiscussion.trim(),

      // ✅ PRODUITS
      "produits": produits.isEmpty
          ? [CommercialProductInput().toJson()]
          : produits.map((p) => p.toJson()).toList(),

      // ✅ NEW FIELDS
      "pipelineStage": pipelineStage,
      "dateAppel": dateAppel,
    };

    // ✅ RELANCE (important: flatten comme ton backend attend)
    if (relance != null) {
      data.addAll(relance!.toJson());
    }

    return data;
  }
}