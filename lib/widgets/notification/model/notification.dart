class NotificationData {
  final String title;
  final String message;
  final String timeAgo;
  final String icon;
  final bool isUnread;
  final String category; // Example: "announcement", "booking", "payment"

  NotificationData({
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.icon,
    required this.isUnread,
    required this.category,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      title: json["title"],
      message: json["message"],
      timeAgo: json["time_ago"],
      icon: json["icon"],
      isUnread: json["is_unread"] ?? false,
      category: json["category"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "message": message,
      "time_ago": timeAgo,
      "icon": icon,
      "is_unread": isUnread,
      "category": category,
    };
  }
}
