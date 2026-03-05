class TaskModel {
  final String id;
  final String title;
  final String description;
  final DateTime startAt;
  final String status;
  final String? creatorEmail;

  // ✅ NEW
  final String? projectId;
  final String? projectName;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startAt,
    required this.status,
    this.creatorEmail,
    this.projectId,
    this.projectName,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: (json["id"] ?? "").toString(),
      title: (json["title"] ?? "").toString(),
      description: (json["description"] ?? "").toString(),
      startAt: DateTime.tryParse((json["startAt"] ?? "").toString()) ?? DateTime.now(),
      status: (json["status"] ?? "planned").toString(),
      creatorEmail: json["creatorEmail"]?.toString(),

      // ✅ NEW
      projectId: json["projectId"]?.toString(),
      projectName: json["projectName"]?.toString(),
    );
  }
}