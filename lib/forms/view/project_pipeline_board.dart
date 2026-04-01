import 'package:flutter/material.dart';
import 'project_stats_dialog.dart';

class PipelineBoard extends StatelessWidget {

  final Map<String, List<Map<String, dynamic>>> data;
  final Function(Map<String, dynamic>, String) onMove;

  const PipelineBoard({
    super.key,
    required this.data,
    required this.onMove,
  });

  final stages = const [
    "Visite",
    "Plan technique",
    "Echantillonnage",
    "Devis envoyé",
    "Negociation",
    "Commande gagnée",
    "Commande perdue",
  ];

  final Map<String, String> stageLabels = const {
    "Visite": "Site Visit",
    "Plan technique": "Technical Plan",
    "Echantillonnage": "Sampling",
    "Devis envoyé": "Quote Sent",
    "Negociation": "Negotiation",
    "Commande gagnée": "✅ Won",
    "Commande perdue": "❌ Lost",
  };

  Color getColor(String stage) {
    switch(stage){
      case "Visite": return Colors.blue;
      case "Plan technique": return Colors.orange;
      case "Echantillonnage": return Colors.deepOrange;
      case "Devis envoyé": return Colors.purple;
      case "Negociation": return Colors.red;
      case "Commande gagnée": return Colors.green;
      case "Commande perdue": return Colors.black;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: stages.map((stage) {

          final projects = data[stage] ?? [];

          return Container(
            width: 300,
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(10),

            decoration: BoxDecoration(
              color: getColor(stage).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),

            child: Column(
              children: [

                Text(
                  "${stageLabels[stage]} (${projects.length})",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: getColor(stage),
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: DragTarget<Map<String, dynamic>>(

                    onAccept: (project) {
                      onMove(project, stage);
                    },

                    builder: (_, __, ___) {

                      return ListView(
                        children: projects.map((p) {

                          return Draggable<Map<String, dynamic>>(

                            data: p,

                            feedback: Material(
                              child: SizedBox(
                                width: 260,
                                child: _card(context, p),
                              ),
                            ),

                            child: InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ProjectStatsDialog(
                                    projectId: p["id"],
                                  ),
                                );
                              },
                              child: _card(context, p),
                            ),
                          );

                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          );

        }).toList(),
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> p) {

    final nom = p['nomProjet'] ?? "";
    final entreprise = p['entreprise'] ?? "";
    final stage = p['computedStage'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(nom, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(entreprise, style: const TextStyle(color: Colors.grey)),

            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: getColor(stage).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(stageLabels[stage]!),
            )
          ],
        ),
      ),
    );
  }
}