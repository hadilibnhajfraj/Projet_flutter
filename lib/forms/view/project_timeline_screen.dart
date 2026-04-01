import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controller/project_timeline_controller.dart';
import '../../providers/api_client.dart';
import 'add_project_action_screen.dart';
import 'package:url_launcher/url_launcher.dart';
class ProjectTimelineScreen extends StatefulWidget {

  final String projectId;

  const ProjectTimelineScreen({super.key, required this.projectId});

  @override
  State<ProjectTimelineScreen> createState() => _ProjectTimelineScreenState();
}

class _ProjectTimelineScreenState extends State<ProjectTimelineScreen> {

  final controller = Get.put(ProjectTimelineController());
Future _deleteAction(String actionId) async {

  final confirm = await showDialog<bool>(

    context: context,

    builder: (context) {

      return AlertDialog(

        title: const Text("Delete action"),

        content: const Text(
          "Are you sure you want to delete this action?"
        ),

        actions: [

          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),

        ],

      );
    },
  );

  if (confirm != true) return;

  try {

    await ApiClient.instance.dio.delete(
      "/projects/actions/$actionId",
    );

    Get.snackbar(
      "Success",
      "Action deleted",
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );

    controller.loadActions(widget.projectId);

  } catch (e) {

    Get.snackbar(
      "Error",
      "Cannot delete action",
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );

  }

}
  @override
  void initState() {
    super.initState();
    controller.loadActions(widget.projectId);
  }

  /// RELANCE COLOR
  Color getRelanceColor(DateTime dateRelance) {

    final now = DateTime.now();

    if (dateRelance.isBefore(now)) {
      return Colors.red;
    }

    final diff = dateRelance.difference(now).inHours;

    if (diff <= 48) {
      return Colors.orange;
    }

    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("CRM Timeline"),
      ),

      body: Obx(() {

        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.actions.isEmpty) {
          return const Center(child: Text("No CRM actions yet"));
        }

        return ListView.builder(

          itemCount: controller.actions.length,

          itemBuilder: (context, index) {

            final action = controller.actions[index];

            return Card(

              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),

              child: Padding(

                padding: const EdgeInsets.all(16),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    /// HEADER
                   Row(

  children: [

    const Icon(Icons.timeline, color: Colors.blue),

    const SizedBox(width: 10),

    Expanded(
      child: Text(
        action.typeAction,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ),

    Text(
      DateFormat("yyyy-MM-dd HH:mm")
          .format(DateTime.parse(action.dateAction)),
      style: const TextStyle(fontSize: 12),
    ),

    const SizedBox(width: 10),

    /// DELETE ACTION
    IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () => _deleteAction(action.id),
    ),

  ],

),
if (action.fileUrl != null)

  Padding(
    padding: const EdgeInsets.only(top: 10),
    child: InkWell(
      onTap: () async {

  if (action.fileUrl == null) return;

  final url = "http://localhost:4000${action.fileUrl}";

  try {

    final uri = Uri.parse(url);

    if (!await launchUrl(uri)) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot open file")),
      );

    }

  } catch (e) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invalid file URL")),
    );

  }
},
      child: Row(
        children: [

          Icon(
            action.fileUrl!.endsWith(".pdf")
                ? Icons.picture_as_pdf
                : Icons.image,
            color: Colors.blue,
          ),

          const SizedBox(width: 8),

          const Text(
            "Voir fichier",
            style: TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),

        ],
      ),
    ),
  ),

                    /// COMMENT
                    if (action.commentaire != null &&
                        action.commentaire!.isNotEmpty)

                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(action.commentaire!),
                      ),

                    /// REMINDERS
                    if (action.reminders.isNotEmpty)

                      Column(

                        children: action.reminders.map<Widget>((reminder) {

                          final relanceDate =
    DateTime.parse(reminder.dateRelance).toLocal();

                          final color = getRelanceColor(relanceDate);

                          return Container(

                            margin: const EdgeInsets.only(top: 10),

                            padding: const EdgeInsets.all(10),

                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color),
                            ),

                            child: Column(

                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [

                                Row(

                                  children: [

                                    Icon(Icons.notifications, color: color),

                                    const SizedBox(width: 8),

                                    Text(
                                      "Relance : ${DateFormat("yyyy-MM-dd").format(relanceDate)}",
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                  ],
                                ),

                                if (reminder.message != null &&
                                    reminder.message!.isNotEmpty)

                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(reminder.message!),
                                  ),

                              ],
                            ),
                          );

                        }).toList(),
                      ),

                    const SizedBox(height: 10),

                    /// ACTION BUTTONS
                    Row(

                      children: [

                        ElevatedButton.icon(

                          icon: const Icon(Icons.schedule),

                          label: const Text("Relance"),

                          onPressed: () =>
                              _openReminder(context, widget.projectId, action.id),

                        ),

                        const SizedBox(width: 10),

                        OutlinedButton.icon(

                          icon: const Icon(Icons.comment),

                          label: const Text("Comment"),

                          onPressed: () =>
                              _openComment(context, widget.projectId),

                        ),

                      ],
                    )

                  ],
                ),
              ),
            );
          },
        );
      }),

      floatingActionButton: FloatingActionButton.extended(

        icon: const Icon(Icons.add),

        label: const Text("Add Action"),

        onPressed: () => _openAddAction(context, widget.projectId),

      ),
    );
  }

  /// ADD ACTION
  Future _openAddAction(BuildContext context, String projectId) async {

  /// 1. Choisir type action
  final action = await showDialog<String>(

    context: context,

    builder: (context) {

      return SimpleDialog(

        title: const Text("Select Action"),

        children: [

          SimpleDialogOption(
            child: const Text("Visite chantier"),
            onPressed: () => Navigator.pop(context, "Visite"),
          ),

          SimpleDialogOption(
            child: const Text("Plan technique"),
            onPressed: () => Navigator.pop(context, "Plan technique"),
          ),

          SimpleDialogOption(
            child: const Text("Echantillonnage"),
            onPressed: () => Navigator.pop(context, "Echantillonnage"),
          ),

          SimpleDialogOption(
            child: const Text("Devis envoyé"),
            onPressed: () => Navigator.pop(context, "Devis envoyé"),
          ),

          SimpleDialogOption(
            child: const Text("Négociation"),
            onPressed: () => Navigator.pop(context, "Negociation"),
          ),

        ],
      );
    },
  );

  if (action == null) return;

  /// 2. Ouvrir écran complet (UPLOAD + COMMENT + RELANCE)
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddProjectActionScreen(
        projectId: projectId,
        initialType: action, // ✅ on passe le type
      ),
    ),
  );

  /// 3. Refresh timeline
  if (result == true) {
    controller.loadActions(projectId);
  }
}

  /// COMMENT
  Future _openComment(BuildContext context, String projectId) async {

    final text = TextEditingController();

    await showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          title: const Text("Add Comment"),

          content: TextField(
            controller: text,
            decoration: const InputDecoration(
              labelText: "Comment",
            ),
          ),

          actions: [

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              child: const Text("Save"),
              onPressed: () async {

                if (text.text.trim().isEmpty) {

                  Get.snackbar(
                    "Error",
                    "Comment cannot be empty",
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );

                  return;
                }

                await ApiClient.instance.dio.post(
                  "/projects/$projectId/comments",
                  data: {"body": text.text.trim()},
                );

                Navigator.pop(context);

                controller.loadActions(projectId);

              },
            ),

          ],
        );
      },
    );
  }

  /// REMINDER
  Future _openReminder(
      BuildContext context,
      String projectId,
      String actionId) async {

    final date = await showDatePicker(

      context: context,

      initialDate: DateTime.now().add(const Duration(days: 2)),

      firstDate: DateTime.now(),

      lastDate: DateTime(2100),

    );

    if (date == null) return;

    final message = TextEditingController();

    await showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          title: const Text("Relance"),

          content: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              Text(DateFormat("yyyy-MM-dd").format(date)),

              const SizedBox(height: 10),

              TextField(
                controller: message,
                decoration: const InputDecoration(
                  labelText: "Reminder message",
                ),
              ),

            ],
          ),

          actions: [

            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),

            ElevatedButton(

              child: const Text("Save"),

              onPressed: () async {

                await ApiClient.instance.dio.post(
                  "/projects/actions/$actionId/reminders",
                  data: {
                    "dateRelance": date.toIso8601String(),
                    "message": message.text.trim()
                  },
                );

                Navigator.pop(context);

                controller.loadActions(projectId);

              },

            ),

          ],
        );
      },
    );
  }
}