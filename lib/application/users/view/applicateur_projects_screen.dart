import 'package:flutter/material.dart';
import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:dash_master_toolkit/services/user_project_service.dart';
import 'package:dash_master_toolkit/application/users/model/user_project_model.dart';
import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
class ApplicateurProjectsScreen extends StatefulWidget {
 const ApplicateurProjectsScreen({super.key});

  @override
  State<ApplicateurProjectsScreen> createState() =>
      _ApplicateurProjectsScreenState();
}

class _ApplicateurProjectsScreenState
    extends State<ApplicateurProjectsScreen> {



  static const Color kPrimary = Color(0xFF1F6FEB);
  static const Color kBg = Color(0xFFF4F7FC);
  static const Color kCard = Colors.white;
  static const Color kBorder = Color(0xFFE5EAF2);

  final UserProjectService service =
      UserProjectService(baseUrl: 'https://api.crmprobar.com');

  List<UserProjectModel> items = [];
  bool loading = false;
   late String token;
  int page = 1;
  int totalPages = 1;
  int total = 0;
  final int limit = 10;

  final TextEditingController searchCtrl = TextEditingController();


 @override
  void initState() {
    super.initState();

    token = AuthService().accessToken ?? "";

    if (token.isEmpty) {
      print("❌ TOKEN MANQUANT");
    } else {
      print("✅ TOKEN OK");
    }

     loadProjects();
  }
  Future<void> loadProjects() async {
    setState(() => loading = true);

    try {
      final res = await service.fetchMyProjects(
        token: token,
        projectModele: "applicateur",
        q: searchCtrl.text,
        page: page,
        limit: limit,
      );

      setState(() {
        items = res.items;
        total = res.total;
        totalPages = res.totalPages;
      });

    } catch (e) {
      print("ERROR: $e");
    }

    setState(() => loading = false);
  }

  String editUrl(String id) {
    return Uri(
      path: MyRoute.projectFormScreen,
      queryParameters: {'id': id},
    ).toString();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: kBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 🔥 HEADER
            const Text(
              "Applicateur Projects",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 8),

            const Text("Manage applicateur projects professionally"),

            const SizedBox(height: 24),

            /// 📊 CARDS
            Row(
              children: [
                _card("Total", total.toString(), Icons.folder),
                _card("Page", page.toString(), Icons.layers),
                _card("Pages", totalPages.toString(), Icons.grid_view),
              ],
            ),

            const SizedBox(height: 24),

            /// 🔍 FILTER
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: "Search...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                ElevatedButton(
                  onPressed: () {
                    page = 1;
                    loadProjects();
                  },
                  child: const Text("Apply"),
                ),

                const SizedBox(width: 10),

                OutlinedButton(
                  onPressed: () {
                    searchCtrl.clear();
                    page = 1;
                    loadProjects();
                  },
                  child: const Text("Reset"),
                ),
              ],
            ),

            const SizedBox(height: 24),

            /// 📊 TABLE
            Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                children: [

                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.table_chart, color: kPrimary),
                        SizedBox(width: 10),
                        Text("Applicateur Table",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  const Divider(),

                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(),
                    )
                  else
                    LayoutBuilder(
  builder: (context, constraints) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: constraints.maxWidth, // ✅ FULL WIDTH
        ),
        child: DataTable(
          columnSpacing: 40,
          horizontalMargin: 20,
          columns: const [
            DataColumn(label: Text("Projet")),
            DataColumn(label: Text("Dallagiste")),
            DataColumn(label: Text("Téléphone")),
            DataColumn(label: Text("Adresse")),
            DataColumn(label: Text("Actions")),
          ],
          rows: items.map((p) {
            return DataRow(
              onSelectChanged: (v) {
                if (v == true) {
                  context.go(editUrl(p.id));
                }
              },
              cells: [

                /// 🔵 NOM + AVATAR
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          p.nomProjet.isNotEmpty
                              ? p.nomProjet[0].toUpperCase()
                              : "P",
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded( // ✅ évite overflow
                        child: Text(
                          p.nomProjet,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                /// 👷 DALLAGISTE
                DataCell(Text(p.dallagiste ?? "-")),

                /// 📞 TEL
                DataCell(Text(p.telephoneDallagiste ?? "-")),

                /// 📍 ADRESSE
                DataCell(
                  SizedBox(
                    width: 200, // ✅ évite casse UI URL longue
                    child: Text(
                      p.adresse ?? "-",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                /// ⚙️ ACTIONS
                DataCell(
                  Row(
                    children: [

                      /// TIMELINE
                      IconButton(
                        icon: const Icon(Icons.timeline),
                        onPressed: () {
                          context.go(
                            "/forms/project-timeline?projectId=${p.id}",
                          );
                        },
                      ),

                      /// EDIT
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          context.go(editUrl(p.id));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  },
),

                  const Divider(),

                  /// 📄 PAGINATION
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text("Page $page / $totalPages"),
                        const Spacer(),

                        OutlinedButton(
                          onPressed: page > 1
                              ? () {
                                  page--;
                                  loadProjects();
                                }
                              : null,
                          child: const Text("Previous"),
                        ),

                        const SizedBox(width: 10),

                        ElevatedButton(
                          onPressed: page < totalPages
                              ? () {
                                  page++;
                                  loadProjects();
                                }
                              : null,
                          child: const Text("Next"),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _card(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: kPrimary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
}