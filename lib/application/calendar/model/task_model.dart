class TaskModel {
  final String id;
  final String title;
  final String description;
  final DateTime startAt;
  final String status;
  final String? creatorEmail;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startAt,
    required this.status,
    this.creatorEmail,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: (json["id"] ?? "").toString(),
      title: (json["title"] ?? "").toString(),
      description: (json["description"] ?? "").toString(),
      startAt: DateTime.tryParse((json["startAt"] ?? "").toString()) ?? DateTime.now(),
      status: (json["status"] ?? "planned").toString(),
      creatorEmail: json["creatorEmail"]?.toString(),
    );
  }
}