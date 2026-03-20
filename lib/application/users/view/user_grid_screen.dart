import 'package:dash_master_toolkit/application/users/controller/user_grid_controller.dart';
import 'package:dash_master_toolkit/application/users/model/project_grid_data.dart';
import 'package:dash_master_toolkit/constant/app_color.dart';
import 'package:dash_master_toolkit/constant/app_images.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/theme/theme_controller.dart';
import 'package:dash_master_toolkit/widgets/common_app_widget.dart';
import 'package:dash_master_toolkit/widgets/common_search_field.dart';
import 'package:dash_master_toolkit/forms/view/ProjectCommentScreen.dart';
import 'package:dash_master_toolkit/app_shell_route/components/topbar/NotificationController.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_grid/responsive_grid.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;

class UserGridScreen extends StatefulWidget {
  const UserGridScreen({super.key});

  @override
  State<UserGridScreen> createState() => _UserGridScreenState();
}

class _UserGridScreenState extends State<UserGridScreen> {

  final controller = Get.put(UserGridController());

  int currentPage = 1;
  int rowsPerPage = 5;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),

      body: Column(
        children: [

          /// HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: const Text(
              "Projects Table",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),

          /// SEARCH
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              controller: controller.searchController,
              onChanged: controller.searchProject,
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          /// TABLE
          Expanded(
            child: Obx(() {

              final list = controller.filtered;

              /// PAGINATION
              final start = (currentPage - 1) * rowsPerPage;
              final end = start + rowsPerPage;

              final paginated = list.sublist(
                start,
                end > list.length ? list.length : end,
              );

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 15),
                padding: const EdgeInsets.all(15),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),

                child: Column(
                  children: [

                    /// HEADER TABLE
                    _tableHeader(),

                    const Divider(),

                    /// ROWS
                    Expanded(
                      child: ListView.builder(
                        itemCount: paginated.length,
                        itemBuilder: (_, i) {
                          return _row(paginated[i]);
                        },
                      ),
                    ),

                    /// PAGINATION FOOTER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        DropdownButton<int>(
                          value: rowsPerPage,
                          items: [5, 10, 20]
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text("$e"),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              rowsPerPage = v!;
                              currentPage = 1;
                            });
                          },
                        ),

                        Text("Page $currentPage"),

                        Row(
                          children: [

                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: currentPage > 1
                                  ? () => setState(() => currentPage--)
                                  : null,
                            ),

                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () {
                                if ((currentPage * rowsPerPage) < list.length) {
                                  setState(() => currentPage++);
                                }
                              },
                            ),

                          ],
                        ),
                      ],
                    )

                  ],
                ),
              );
            }),
          )
        ],
      ),
    );
  }

  /// HEADER TABLE
  Widget _tableHeader() {
    return Row(
      children: const [
        Expanded(flex: 3, child: Text("Project", style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text("Company")),
        Expanded(flex: 2, child: Text("Start")),
        Expanded(flex: 2, child: Text("Status")),
        Expanded(flex: 2, child: Text("Activity")),
        Expanded(flex: 2, child: Text("Actions")),
      ],
    );
  }

  /// ROW
 Widget _row(ProjectGridData p) {

  Color? bg;

  if (p.hasBonCommande) {
    bg = Colors.green.withOpacity(0.08);
  } else if (p.hasDevis) {
    bg = Colors.red.withOpacity(0.08);
  }

  return InkWell(
   onTap: () {
      if (p.canEdit) {
        context.go(_editUrl(p.id));
      } else {
        _goToComment(context, p);
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),

      decoration: BoxDecoration(
        color: bg, // ✅ CORRECT ICI
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),

      child: Row(
        children: [

          /// PROJECT
          Expanded(
            flex: 3,
            child: Row(
              children: [

                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(p.nomProjet.isNotEmpty ? p.nomProjet[0] : "P"),
                ),

                const SizedBox(width: 10),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nomProjet,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("By ${p.ownerName}",
                        style: const TextStyle(fontSize: 11)),
                  ],
                )
              ],
            ),
          ),

          /// COMPANY
          Expanded(flex: 2, child: Text(p.entreprise)),

          /// DATE
          Expanded(flex: 2, child: Text(p.dateDemarrage)),

          /// STATUS
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (p.hasBonCommande
                        ? Colors.green
                        : (p.hasDevis ? Colors.red : Colors.blue))
                    .withOpacity(.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                p.statut,
                style: TextStyle(
                  color: p.hasBonCommande
                      ? Colors.green
                      : (p.hasDevis ? Colors.red : Colors.blue),
                ),
              ),
            ),
          ),

          /// ACTIVITY
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _iconBadge(Icons.event, p.taskCount),
                const SizedBox(width: 6),
                _iconBadge(Icons.comment, p.commentCount),
              ],
            ),
          ),

          /// ACTIONS
          Expanded(
            flex: 2,
            child: Row(
              children: [

                IconButton(
                  icon: const Icon(Icons.timeline),
                  onPressed: () {
                    context.go("/forms/project-timeline?projectId=${p.id}");
                  },
                ),

                if (p.canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => context.go(_editUrl(p.id)),
                  ),

                PopupMenuButton(
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: "delete",
                      child: Text("Delete"),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == "delete") {
                      controller.deleteProject(p.id);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  /// ICON BADGE
  Widget _iconBadge(IconData icon, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text("$count"),
        ],
      ),
    );
  }
String _editUrl(String id) {
    return Uri(
      path: MyRoute.projectFormScreen,
      queryParameters: {'id': id},
    ).toString();
  }
  Future<void> _goToComment(BuildContext context, ProjectGridData p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectCommentScreen(
          projectId: p.id,
          projectName: p.nomProjet,
        ),
      ),
    );

    controller.loadProjects();
  }
}