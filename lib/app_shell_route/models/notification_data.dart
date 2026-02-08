class NotificationData {
  final String id;
  final String title;
  final String message;
  final bool isRead;

  NotificationData({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      id: json["id"]?.toString() ?? "",
      title: json["title"] ?? "",
      message: json["message"] ?? "",
      isRead: json["isRead"] == true,
    );
  }
}

class NotificationResponse {
  final int unreadCount;
  final List<NotificationData> items;

  NotificationResponse({required this.unreadCount, required this.items});

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    final items = (json["items"] as List? ?? [])
        .map((e) => NotificationData.fromJson(e as Map<String, dynamic>))
        .toList();

    return NotificationResponse(
      unreadCount: json["unreadCount"] ?? 0,
      items: items,
    );
  }
}
