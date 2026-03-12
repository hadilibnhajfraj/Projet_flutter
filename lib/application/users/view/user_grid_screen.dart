import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:csv/csv.dart';

import '../controller/user_grid_controller.dart';
import '../model/project_grid_data.dart';

class UserGridScreen extends StatefulWidget {
  const UserGridScreen({super.key});

  @override
  State<UserGridScreen> createState() => _UserGridScreenState();
}

class _UserGridScreenState extends State<UserGridScreen> {

  final controller = Get.put(UserGridController());

  String? selectedOwner;
  DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Obx(() {

          final projects = controller.filtered;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text(
                "users & projects management",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              /// FILTER BAR
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [

                  /// SEARCH
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: controller.searchController,
                      decoration: const InputDecoration(
                        hintText: "Search project",
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => controller.searchProject(v),
                    ),
                  ),

                  /// OWNER FILTER
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedOwner,
                      hint: const Text("Created by"),
                      items: controller.projects
                          .map((e) => e.ownerName)
                          .toSet()
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedOwner = value;
                        });
                      },
                    ),
                  ),

                  /// DATE FILTER
                  SizedBox(
                    width: 200,
                    child: TextField(
                      readOnly: true,
                      decoration: const InputDecoration(
                        hintText: "Start date",
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {

                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                          initialDate: DateTime.now(),
                        );

                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                    ),
                  ),

                  /// APPLY FILTER
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text("Apply Filters"),
                    onPressed: _applyFilters,
                  ),

                  /// RESET
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Reset"),
                    onPressed: _resetFilters,
                  ),

                  /// EXPORT
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text("Export CSV"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                    ),
                    onPressed: _exportCSV,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// TABLE
              Expanded(
                child: Card(
                  elevation: 2,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 40,
                      headingRowColor: MaterialStateProperty.all(
                        Colors.grey.shade100,
                      ),
                      columns: const [

                        DataColumn(label: Text("Project")),
                        DataColumn(label: Text("Company")),
                        DataColumn(label: Text("Status")),
                        DataColumn(label: Text("Start")),
                        DataColumn(label: Text("Created by")),
                        DataColumn(label: Text("Tasks")),
                        DataColumn(label: Text("Comments")),
                        DataColumn(label: Text("Actions")),
                      ],
                      rows: projects.map((p) {

                        Color? rowColor;

                        if (p.hasBonCommande) {
                          rowColor = const Color(0xFFC8E6C9);
                        } else if (p.hasDevis) {
                          rowColor = const Color(0xFFFFCDD2);
                        }

                        return DataRow(
                          color: MaterialStateProperty.all(rowColor),
                          cells: [

                            DataCell(Text(p.nomProjet)),

                            DataCell(Text(p.entreprise)),

                            DataCell(_statusBadge(p.statut)),

                            DataCell(Text(p.dateDemarrage)),

                            DataCell(Text(p.ownerName)),

                            const DataCell(
                              Row(
                                children: [
                                  Icon(Icons.event_note),
                                  SizedBox(width: 6),
                                  Text("0")
                                ],
                              ),
                            ),

                            DataCell(
                              Row(
                                children: [
                                  const Icon(Icons.comment),
                                  const SizedBox(width: 6),
                                  Text("${p.commentCount}")
                                ],
                              ),
                            ),

                            DataCell(
                              Row(
                                children: [

                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {},
                                  ),

                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () {},
                                  ),

                                  IconButton(
                                    icon: const Icon(Icons.comment),
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// APPLY FILTER
  void _applyFilters() {

    List<ProjectGridData> list = controller.projects.toList();

    if (selectedOwner != null) {
      list = list.where((p) => p.ownerName == selectedOwner).toList();
    }

    if (selectedDate != null) {

      final d = selectedDate.toString().substring(0, 10);

      list =
          list.where((p) => p.dateDemarrage.startsWith(d)).toList();
    }

    controller.filtered.assignAll(list);
  }

  /// RESET FILTER
  void _resetFilters() {

    setState(() {
      selectedOwner = null;
      selectedDate = null;
    });

    controller.filtered.assignAll(controller.projects);
  }

  /// EXPORT CSV
  void _exportCSV() {

    List<List<dynamic>> rows = [];

    rows.add([
      "Project",
      "Company",
      "Status",
      "Start",
      "Created By",
      "Comments"
    ]);

    for (var p in controller.filtered) {

      rows.add([
        p.nomProjet,
        p.entreprise,
        p.statut,
        p.dateDemarrage,
        p.ownerName,
        p.commentCount
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    final bytes = utf8.encode(csv);

    final blob = html.Blob([bytes]);

    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute("download", "projects.csv")
      ..click();
  }

  /// STATUS BADGE
  Widget _statusBadge(String status) {

    Color color = Colors.grey;

    if (status == "Préparation") color = Colors.orange;
    if (status == "En cours") color = Colors.blue;
    if (status == "Terminé") color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}