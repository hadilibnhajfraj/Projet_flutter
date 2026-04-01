import 'package:flutter/material.dart';
import 'project_pipeline_board.dart';
import '../../providers/api_client.dart';

class ProjectPipelineScreen extends StatefulWidget {
  const ProjectPipelineScreen({super.key});

  @override
  State<ProjectPipelineScreen> createState() => _ProjectPipelineScreenState();
}

const ACTION_STAGES = [
  "Visite",
  "Plan technique",
  "Echantillonnage",
  "Devis envoyé",
  "Negociation",
  "Commande gagnée",
  "Commande perdue",
];

class _ProjectPipelineScreenState extends State<ProjectPipelineScreen> {

  Map<String, List<Map<String, dynamic>>> grouped = {};

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  /// 🔥 NORMALIZE
 String normalizeStage(String? stage) {
  if (stage == null) return "Visite";

  final s = stage
      .toLowerCase()
      .trim()
      .replaceAll("é", "e")
      .replaceAll("è", "e");

  if (s.contains("visite")) return "Visite";
  if (s.contains("plan")) return "Plan technique";
  if (s.contains("echant")) return "Echantillonnage";
  if (s.contains("devis")) return "Devis envoyé";
  if (s.contains("nego")) return "Negociation";
  if (s.contains("gagn")) return "Commande gagnée";
  if (s.contains("perd")) return "Commande perdue";

  return "Visite";
}

  /// 🔥 FIX ICI (dateAction au lieu de createdAt)
  Map<String, dynamic>? getLastAction(List actions) {
    if (actions.isEmpty) return null;

    actions.sort((a, b) {
      final da = DateTime.tryParse(a["dateAction"] ?? "") ?? DateTime(2000);
      final db = DateTime.tryParse(b["dateAction"] ?? "") ?? DateTime(2000);
      return db.compareTo(da); // DESC (latest first)
    });

    return actions.first;
  }

  /// ✅ LOAD
Future<void> loadProjects() async {
  try {
    final res = await ApiClient.instance.dio.get(
      "/projects/myprojects?limit=1000",
    );

    final List data = res.data["items"] ?? [];

    final Map<String, List<Map<String, dynamic>>> map = {
      for (var stage in ACTION_STAGES) stage: []
    };

    for (var p in data) {

      final project = Map<String, dynamic>.from(p);
      final projectId = project["id"];

      /// 🔥 RÉCUPÉRER TOUTES LES ACTIONS
      final actionsRes = await ApiClient.instance.dio.get(
        "/projects/$projectId/actions",
      );

      final List actions = actionsRes.data ?? [];

      /// 🔥 FILTRER (IGNORER RELANCE)
      final validActions = actions.where((a) {
        final type = (a["typeAction"] ?? "").toString().toLowerCase();
        return !type.contains("relance");
      }).toList();

      /// 🔥 TRIER PAR DATE
      validActions.sort((a, b) {
        final da = DateTime.tryParse(a["dateAction"] ?? "") ?? DateTime(2000);
        final db = DateTime.tryParse(b["dateAction"] ?? "") ?? DateTime(2000);
        return db.compareTo(da);
      });

      /// 🔥 PRENDRE LA DERNIÈRE VRAIE ACTION
      final lastAction = validActions.isNotEmpty
          ? validActions.first
          : project["lastAction"]; // fallback

      print("--------------");
      print("PROJECT: ${project["nomProjet"]}");
      print("REAL LAST ACTION: ${lastAction?["typeAction"]}");

      final stage = normalizeStage(
        lastAction?["typeAction"],
      );

      project["computedStage"] = stage;
      project["lastAction"] = lastAction;

      map[stage]!.add(project);
    }

    setState(() {
      grouped = map;
    });

  } catch (e) {
    print("❌ LOAD ERROR: $e");
  }
}

  /// ✅ MOVE
  Future<void> _onMove(Map<String, dynamic> project, String newStage) async {
    try {
      final projectId = project["id"];

      await ApiClient.instance.dio.post(
        "/projects/$projectId/actions",
        data: {
          "typeAction": newStage,
          "commentaire": "Moved via pipeline",
        },
      );

      await loadProjects();

    } catch (e) {
      print("❌ MOVE ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("CRM Pipeline PRO")),

      body: grouped.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : PipelineBoard(
              data: grouped,
              onMove: _onMove,
            ),
    );
  }
}