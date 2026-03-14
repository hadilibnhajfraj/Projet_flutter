class ProjectAction {

  final String id;
  final String typeAction;
  final String commentaire;
   final String dateAction;
  final String createdBy;

  ProjectAction({
    required this.id,
    required this.typeAction,
    required this.commentaire,
    required this.dateAction,
    required this.createdBy,
  });

  factory ProjectAction.fromJson(Map<String,dynamic> json){

    return ProjectAction(
      id: json["id"].toString(),
      typeAction: json["typeAction"] ?? "",
      commentaire: json["commentaire"] ?? "",
      dateAction: json["dateAction"] ?? json["createdAt"],
      createdBy: json["createdBy"] ?? "",
    );

  }

}