class NotificationData {
  final String id;
  final String title;
  final String message;
  bool         isRead;
  final String type;
  final String createdAt;
  final String projectId;
  final String projectName;
  // Fiche de production à valider / validée / refusée ('promesh' | 'probar').
  final String productionFicheType;
  final String productionFicheId;
  // Demande de matières premières concernée.
  final String rawMaterialRequestId;

  NotificationData({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.type,
    this.createdAt   = '',
    this.projectId   = '',
    this.projectName = '',
    this.productionFicheType = '',
    this.productionFicheId = '',
    this.rawMaterialRequestId = '',
  });

  /// Lien vers la demande dans « Production → Matières premières ».
  String? get rawMaterialRequestLink =>
      rawMaterialRequestId.isEmpty ? null : '/production/matieres-premieres?id=$rawMaterialRequestId';

  /// Élément à ouvrir depuis la notification (fiche ou demande) et libellé.
  (String, String)? get target => productionFicheLink != null
      ? (productionFicheLink!, 'Voir la fiche')
      : rawMaterialRequestLink != null
          ? (rawMaterialRequestLink!, 'Voir la demande')
          : null;

  /// Lien vers la fiche dans « Validation des fiches de production ».
  String? get productionFicheLink => productionFicheType.isEmpty || productionFicheId.isEmpty
      ? null
      : '/production/validation-fiches?fiche=$productionFicheType:$productionFicheId';

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    print("JSON ITEM = $json");
    return NotificationData(
      id:          (json['id']  ?? json['_id'] ?? '').toString(),
      title:       (json['title']   ?? '').toString(),
      message:     (json['message'] ?? '').toString(),
      isRead:      json['isRead'] == true || json['read'] == true,
      type:        (json['type']   ?? '').toString(),
      createdAt:   (json['createdAt'] ?? json['date'] ?? json['timestamp'] ?? '').toString(),
      projectId:   (json['projectId'] ?? json['project'] ?? '').toString(),
      projectName: (json['projectName'] ?? json['nomProjet'] ?? '').toString(),
      productionFicheType: (json['productionFicheType'] ?? '').toString(),
      productionFicheId: (json['productionFicheId'] ?? '').toString(),
      rawMaterialRequestId: (json['rawMaterialRequestId'] ?? '').toString(),
    );
  }
}

class NotificationResponse {
  final int unreadCount;
  final List<NotificationData> items;

  NotificationResponse({required this.unreadCount, required this.items});

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    print("NOTIF JSON KEYS = ${json.keys.toList()}");

    // Couvre toutes les clés possibles retournées par le backend
    final raw = (json['items']         as List?) ??
                (json['notifications'] as List?) ??
                (json['data']          as List?) ??
                (json['results']       as List?) ??
                (json['docs']          as List?) ??
                [];

    print("NOTIFICATION COUNT API (fromJson) = ${raw.length}");

    final items = raw
        .whereType<Map>()
        .map((e) => NotificationData.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return NotificationResponse(
      unreadCount: (json['unreadCount'] ?? json['unread'] ?? json['totalUnread'] ?? 0) as int,
      items: items,
    );
  }
}
