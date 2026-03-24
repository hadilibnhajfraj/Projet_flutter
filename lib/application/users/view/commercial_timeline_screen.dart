import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/commercial_action_model.dart';
import 'package:dash_master_toolkit/services/commercial_action_service.dart';
class CommercialTimelineScreen extends StatefulWidget {
  final String contactId;
  final String token;

  const CommercialTimelineScreen({
    super.key,
    required this.contactId,
    required this.token,
  });

  @override
  State<CommercialTimelineScreen> createState() =>
      _CommercialTimelineScreenState();
}

class _CommercialTimelineScreenState
    extends State<CommercialTimelineScreen> {

  final service = CommercialActionService();

  List<CommercialAction> actions = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await service.getActions(
        token: widget.token,
        contactId: widget.contactId,
      );

      setState(() {
        actions = data;
        loading = false;
      });

    } catch (e) {
      setState(() => loading = false);
    }
  }

  IconData getIcon(String type) {
    switch (type) {
      case "Visite":
        return Icons.location_on;
      case "Devis envoyé":
        return Icons.description;
      case "Negociation":
        return Icons.handshake;
      case "Relance":
        return Icons.alarm;
      case "Commande gagnée":
        return Icons.check_circle;
      case "Commande perdue":
        return Icons.cancel;
      default:
        return Icons.timeline;
    }
  }

  Color getColor(String type) {
    switch (type) {
      case "Visite":
        return Colors.orange;
      case "Devis envoyé":
        return Colors.blue;
      case "Negociation":
        return Colors.amber;
      case "Relance":
        return Colors.purple;
      case "Commande gagnée":
        return Colors.green;
      case "Commande perdue":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("CRM Timeline"),
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: actions.length,

        itemBuilder: (_, i) {

          final a = actions[i];

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// TIMELINE
              Column(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: getColor(a.typeAction),
                    child: Icon(
                      getIcon(a.typeAction),
                      size: 16,
                      color: Colors.white,
                    ),
                  ),

                  if (i != actions.length - 1)
                    Container(
                      width: 2,
                      height: 60,
                      color: Colors.grey.shade300,
                    ),
                ],
              ),

              const SizedBox(width: 14),

              /// CARD
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        a.typeAction,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      if (a.commentaire != null)
                        Text(a.commentaire!),

                      const SizedBox(height: 6),

                      Text(
                        a.dateAction?.toString() ?? "",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),

                      if (a.fileUrl != null)
                        TextButton(
                          onPressed: () async {
                            final url = Uri.parse(
                              "http://localhost:4000${a.fileUrl}",
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                          child: const Text("📎 Voir fichier"),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}