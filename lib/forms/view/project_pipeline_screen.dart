import 'package:flutter/material.dart';
import 'project_pipeline_board.dart';
import '../../providers/api_client.dart';

class ProjectPipelineScreen extends StatefulWidget {
  const ProjectPipelineScreen({super.key});

  @override
  State<ProjectPipelineScreen> createState() => _ProjectPipelineScreenState();
}

/// 🔥 ACTIONS = COLONNES CRM
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

  /// ✅ LOAD PROJECTS
  Future<void> loadProjects() async {

    final res = await ApiClient.instance.dio.get("/projects/myprojects?limit=100");

    final List data = res.data["items"] ?? [];

    final Map<String, List<Map<String, dynamic>>> map = {
      for (var stage in ACTION_STAGES) stage: []
    };

    for (var p in data) {

      final project = Map<String, dynamic>.from(p);

      /// 🔥 récupérer dernière action
      final lastAction = project["lastAction"];

      String stage = "Visite";

      if (lastAction != null && lastAction["typeAction"] != null) {
        stage = lastAction["typeAction"];
      }

      project["computedStage"] = stage;

      map[stage]?.add(project);
    }

    setState(() {
      grouped = map;
    });
  }

  /// ✅ DRAG LOGIC = UPDATE ACTION
  Future<void> _onMove(Map<String, dynamic> project, String newStage) async {

  try {

    final projectId = project["id"];
    final action = project["lastAction"];

    print("🔥 MOVE PROJECT → $newStage");

    /// ✅ CAS 1 : action existe → UPDATE
    if (action != null && action["id"] != null) {

      await ApiClient.instance.dio.put(
        "/projects/$projectId",
        data: {
          "typeAction": newStage,
        },
      );

    } 
    
    /// ✅ CAS 2 : PAS D'ACTION → CREATE
    else {

      print("⚠️ No action → CREATE");

      await ApiClient.instance.dio.post(
        "/projects/$projectId/actions",
        data: {
          "typeAction": newStage,
          "commentaire": "Auto pipeline move",
        },
      );
    }

    /// 🔥 reload UI
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