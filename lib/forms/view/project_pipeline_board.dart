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

  /// 🔥 BACKEND VALUES (NE PAS CHANGER)
  final stages = const [
    "Visite",
    "Plan technique",
    "Echantillonnage",
    "Devis envoyé",
    "Negociation",
    "Commande gagnée",
    "Commande perdue",
  ];

  /// ✅ ENGLISH LABELS (UI ONLY)
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

      child: SizedBox(
        height: MediaQuery.of(context).size.height,

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,

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

                  /// 🔥 HEADER (ENGLISH)
                  Text(
                    "${stageLabels[stage] ?? stage} (${projects.length})",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: getColor(stage),
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// LIST
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
                                elevation: 6,
                                child: SizedBox(
                                  width: 260,
                                  child: _card(context, p),
                                ),
                              ),

                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: _card(context, p),
                              ),

                              /// 🔥 CLICK + DRAG OK
                              child: InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => ProjectStatsDialog(
                                      projectId: p["id"],
                                    ),
                                  );
                                },
                                mouseCursor: SystemMouseCursors.click,
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
      ),
    );
  }

  /// 🔥 CARD UI
  Widget _card(BuildContext context, Map<String, dynamic> p) {

    final nom = p['nomProjet'] ?? "No name";
    final entreprise = p['entreprise'] ?? "";
    final stage = p['computedStage'] ?? "Visite";

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),

      child: Padding(
        padding: const EdgeInsets.all(12),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// TITLE
            Text(
              nom,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 5),

            /// COMPANY
            Text(
              entreprise,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 8),

            /// 🔥 STATUS BADGE (ENGLISH)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: getColor(stage).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                stageLabels[stage] ?? stage,
                style: TextStyle(
                  fontSize: 11,
                  color: getColor(stage),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}