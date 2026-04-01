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
import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dash_master_toolkit/application/users/model/user_projects_response.dart';
import 'dart:html' as html;
import 'package:excel/excel.dart' as excel;
class UserGridScreen extends StatefulWidget {
  const UserGridScreen({super.key});

  @override
  State<UserGridScreen> createState() => _UserGridScreenState();
}

class _UserGridScreenState extends State<UserGridScreen> {

  final controller = Get.put(UserGridController());
String? selectedStatusFilter;
String? selectedUser;
List<String> users = [];
  UserProjectsResponse? _response;
Future<void> loadUsers() async {
  try {
    final res = await ApiClient.instance.dio.get("/users");

    final data = res.data as List;

    setState(() {
      users = data
          .map((u) => u["email"].toString()) // ou u["id"]
          .toList();
    });

  } catch (e) {
    print("❌ LOAD USERS ERROR: $e");
  }
}
String safe(dynamic v) {
  if (v == null || v.toString().trim().isEmpty || v.toString() == "null") {
    return "-";
  }
  return v.toString();
}
void _exportExcelFull() {
  final items = controller.filtered;

  var excelFile = excel.Excel.createExcel();
  excel.Sheet sheet = excelFile['Projects'];

  final headers = [
    'Project Name',   // 0
    'Start Date',     // 1
    'Engineer',       // 2
    'Company',        // 3
    'Status',         // 4
    'Validation',     // 5
    'Surface',        // 6 ✅ NUMBER
    'Réussite %',     // 7 ✅ NUMBER
  ];

  /// HEADER
  sheet.appendRow(headers);

  for (int i = 0; i < headers.length; i++) {
    sheet
        .cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .cellStyle = excel.CellStyle(
      bold: true,
      backgroundColorHex: "#111827",
      fontColorHex: "#FFFFFF",
      horizontalAlign: excel.HorizontalAlign.Center,
    );
  }

  /// GROUP BY USER
  Map<String, List<ProjectGridData>> grouped = {};

  for (var p in items) {
    final user = p.ownerName ?? "Unknown";
    grouped.putIfAbsent(user, () => []).add(p);
  }

  List<String> userColors = [
    "#DBEAFE",
    "#FEF3C7",
    "#DCFCE7",
    "#FCE7F3",
  ];

  int rowIndex = 1;
  int colorIndex = 0;

  grouped.forEach((user, projects) {
    String userColor = userColors[colorIndex % userColors.length];
    colorIndex++;

    /// 🔥 USER HEADER
    sheet.appendRow([
      "👤 $user (${projects.length})",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
    ]);

    for (int col = 0; col < headers.length; col++) {
      sheet
          .cell(excel.CellIndex.indexByColumnRow(
              columnIndex: col, rowIndex: rowIndex))
          .cellStyle = excel.CellStyle(
        backgroundColorHex: userColor,
        bold: true,
      );
    }

    rowIndex++;

    /// 🔥 PROJECTS
    for (var p in projects) {
      /// ✅ CONVERSION EN DOUBLE (IMPORTANT)
      double? surface =
          double.tryParse(p.surfaceProspectee ?? "");

      double? success =
          double.tryParse(p.pourcentageReussite ?? "");

      sheet.appendRow([
        safe(p.nomProjet),
        safe(p.dateDemarrage),
        safe(p.ingenieurResponsable),
        safe(p.entreprise),
        "  ${safe(p.statut)}  ",
        "  ${safe(p.validationStatut)}  ",
        surface ?? "",   // ✅ NUMBER
        success ?? "",   // ✅ NUMBER
      ]);

      /// 🎨 STATUS
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .cellStyle = excel.CellStyle(
        backgroundColorHex: _getStatusColorHex(p.statut),
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );

      /// 🎨 VALIDATION
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .cellStyle = excel.CellStyle(
        backgroundColorHex: _getValidationColorHex(p.validationStatut),
        fontColorHex: "#FFFFFF",
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );

      /// 🎨 COLOR SUCCESS
      String color;
      if (success != null && success >= 80) {
        color = "#22C55E";
      } else if (success != null && success >= 50) {
        color = "#F59E0B";
      } else {
        color = "#EF4444";
      }

      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
          .cellStyle = excel.CellStyle(
        backgroundColorHex: color,
        fontColorHex: "#FFFFFF",
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );

      rowIndex++;
    }

    /// ESPACE ENTRE USERS
    sheet.appendRow([""]);
    rowIndex++;
  });

  /// LARGEUR
  for (int i = 0; i < headers.length; i++) {
    sheet.setColWidth(i, 30);
  }

  /// SAVE
  final bytes = excelFile.encode();
  if (bytes == null) return;

  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', 'projects_grouped_advanced.xlsx')
    ..click();

  html.Url.revokeObjectUrl(url);
}
String _getModelColorHex(String? model) {
  switch (model) {
    case "project":
      return "#DBEAFE";
    case "revendeur":
      return "#FEF3C7";
    case "applicateur":
      return "#DCFCE7";
    default:
      return "#E5E7EB";
  }
}
String _getStatusColorHex(String? status) {
  switch (status) {
    case "Identification":
      return "#DBEAFE";
    case "Préparation":
      return "#E0F2FE";
    case "Proposition technique":
      return "#FEF3C7";
    case "Proposition commerciale":
      return "#E9D5FF";
    case "Négociation":
      return "#FECACA";
    case "Livraison":
      return "#DCFCE7";
    default:
      return "#F3F4F6";
  }
}

String _getValidationColorHex(String? value) {
  if (value == "Validé") return "#22C55E"; // vert fort
  if (value == "Non validé") return "#F59E0B"; // orange
  return "#E5E7EB";
}
@override
void initState() {
  super.initState();
  loadUsers();
}
  int currentPage = 1;
  int rowsPerPage = 5;
final List<Map<String, String>> STATUS_LIST = [
  {"label": "Identification", "value": "Identification"},
  {"label": "Technical Proposal", "value": "Proposition technique"},
  {"label": "Commercial Proposal", "value": "Proposition commerciale"},
  {"label": "Negotiation", "value": "Négociation"},
  {"label": "Delivery", "value": "Livraison"},
  {"label": "Loyalty", "value": "Fidélisation"},
];
Color getStatusColor(String status) {
  switch (status) {
    case "Identification":
      return Colors.blue;

    case "Proposition technique":
      return Colors.orange;

    case "Proposition commerciale":
      return Colors.purple;

    case "Négociation":
      return Colors.red;

    case "Livraison":
      return Colors.green;

    case "Fidélisation":
      return Colors.teal;

    default:
      return Colors.grey;
  }
}

Future<void> updateStatus(String projectId, String newStatus) async {
  try {
    await ApiClient.instance.dio.put(
      "/projects/$projectId",
      data: {
        "statut": newStatus,
      },
    );

    controller.loadProjects(); // refresh

  } catch (e) {
    print("❌ STATUS UPDATE ERROR: $e");
  }
}
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

  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [

      /// TITLE
      const Text(
        "Projects Table",
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),

      /// BUTTONS
      Wrap(
        spacing: 8,
  runSpacing: 8, // ✅ IMPORTANT
        children: [

          /// 🔵 PIPELINE
          ElevatedButton.icon(
            onPressed: () {
              context.go("/forms/pipeline");
            },
            icon: const Icon(Icons.view_kanban),
            label: const Text("Pipeline"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),

          const SizedBox(width: 10),

          /// 🟢 ADD PROJECT
          ElevatedButton.icon(
            onPressed: () {
              context.go(MyRoute.projectFormScreen);
            },
            icon: const Icon(Icons.add),
            label: const Text("Add Project"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
 ElevatedButton.icon(
                        onPressed: _exportExcelFull,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Export CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111827),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
        ],
      )
    ],
  ),
),

          /// SEARCH
         Padding(
  padding: const EdgeInsets.all(15),
  child: Row(
    children: [

      /// 🔍 SEARCH
      Expanded(
        flex: 3,
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

      const SizedBox(width: 10),

      /// 🔥 STATUS FILTER
      Expanded(
        flex: 2,
        child: DropdownButtonFormField<String>(
          value: selectedStatusFilter,
          decoration: InputDecoration(
            hintText: "Filter status",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text("All"),
            ),
            ...STATUS_LIST.map((s) => DropdownMenuItem(
                  value: s["value"],
                  child: Text(s["label"]!),
                ))
          ],
          onChanged: (value) {
            setState(() {
              selectedStatusFilter = value;
            });
          },
        ),
      ),
      Expanded(
  flex: 2,
  child: DropdownButtonFormField<String>(
    value: selectedUser,
    decoration: InputDecoration(
      hintText: "Filter user",
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    items: [
      const DropdownMenuItem(
        value: "ALL",
        child: Text("All Users"),
      ),
      ...users.map((u) => DropdownMenuItem(
            value: u,
            child: Text(u),
          ))
    ],
    onChanged: (value) {
      setState(() {
        selectedUser = value == "ALL" ? null : value;
        currentPage = 1;
      });
    },
  ),
),
    ],
  ),
),

          /// TABLE
          Expanded(
            child: Obx(() {

    final all = controller.filtered;

List<ProjectGridData> list = all;

/// 🔥 FILTER STATUS
if (selectedStatusFilter != null) {
  list = list.where((p) {
    final statut = (p.statut ?? "").toLowerCase().trim();
    final filter = selectedStatusFilter!.toLowerCase().trim();
    return statut == filter;
  }).toList();
}

/// 🔥 FILTER USER
if (selectedUser != null) {
  list = list.where((p) {
    return p.ownerName == selectedUser;
  }).toList();
}
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
  bool isArchived = p.isArchived == true;

  Color? bg;

  if (p.hasBonCommande) {
    bg = Colors.green.withOpacity(0.08);
  } else if (p.hasDevis) {
    bg = Colors.red.withOpacity(0.08);
  }

  // 🔥 override couleur si archivé
  final rowColor = isArchived
      ? Colors.grey.withOpacity(0.15)
      : bg;

  String safeValue = STATUS_LIST.any((s) => s["value"] == p.statut)
      ? p.statut
      : "Identification";

  return InkWell(
    onTap: () {
      if (isArchived) return; // ❌ bloc si archivé

      if (p.canEdit) {
        context.go(_editUrl(p.id));
      } else {
        _goToComment(context, p);
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: rowColor,
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
                  child: Text(
                    p.nomProjet.isNotEmpty ? p.nomProjet[0] : "P",
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// 🔥 NOM + BADGE ARCHIVE
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.nomProjet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: isArchived
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),

                          if (isArchived)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "ARCHIVED",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      Text(
                        "By ${p.ownerName}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          /// COMPANY
          Expanded(
            flex: 2,
            child: Text(
              p.entreprise,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          /// DATE
          Expanded(
            flex: 2,
            child: Text(
              p.dateDemarrage,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          /// STATUS
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (p.hasBonCommande
                        ? Colors.green
                        : (p.hasDevis ? Colors.red : getStatusColor(p.statut)))
                    .withOpacity(.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButton<String>(
                value: safeValue,
                isExpanded: true,
                underline: const SizedBox(),

                style: TextStyle(
                  color: (p.canEdit && !isArchived) ? Colors.black : Colors.grey,
                ),

                iconEnabledColor:
                    (p.canEdit && !isArchived) ? Colors.black : Colors.grey,

                items: STATUS_LIST.map((status) {
                  return DropdownMenuItem<String>(
                    value: status["value"],
                    child: Text(status["label"]!),
                  );
                }).toList(),

                onChanged: (p.canEdit && !isArchived)
                    ? (value) async {
                        if (value == null) return;

                        await ApiClient.instance.dio.put(
                          "/projects/${p.id}",
                          data: {
                            "statut": value,
                          },
                        );

                        controller.loadProjects();
                      }
                    : null,
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

                if (p.canEdit && !isArchived)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => context.go(_editUrl(p.id)),
                  ),

                if (!isArchived)
                  PopupMenuButton(
                    itemBuilder: (_) => const [
                      PopupMenuItem(
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