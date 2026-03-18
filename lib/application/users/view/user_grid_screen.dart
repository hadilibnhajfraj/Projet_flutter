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
  late final UserGridController controller;
  late final ThemeController themeController;

  @override
  void initState() {
    super.initState();

    controller = Get.isRegistered<UserGridController>()
        ? Get.find<UserGridController>()
        : Get.put(UserGridController(), permanent: true);

    themeController = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>()
        : Get.put(ThemeController(), permanent: true);
  }
Widget _sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
@override
Widget build(BuildContext context) {
  final lang = AppLocalizations.of(context);
  final theme = Theme.of(context);

  return Scaffold(
    backgroundColor: themeController.isDarkMode ? colorGrey900 : colorWhite,
    body: SingleChildScrollView(
      padding: EdgeInsets.all(
        rf.ResponsiveValue<double>(
          context,
          conditionalValues: const [
            rf.Condition.between(start: 0, end: 340, value: 10),
            rf.Condition.between(start: 341, end: 992, value: 10),
          ],
          defaultValue: 10,
        ).value,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// SEARCH
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 10, end: 10),
            child: CommonSearchField(
              controller: controller.searchController,
              focusNode: controller.f1,
              isDarkMode: themeController.isDarkMode,
              onChanged: controller.searchProject,
              inputDecoration: inputDecoration(
                context,
                borderColor: Colors.transparent,
                prefixIcon: searchIcon,
                fillColor: Colors.transparent,
                prefixIconColor: colorGrey400,
                hintText: (lang.translate("search") ?? "Search"),
                borderRadius: 8,
                topContentPadding: 0,
                bottomContentPadding: 0,
              ),
            ),
          ),

          const SizedBox(height: 15),

          /// PROJECTS
          Obx(() {

            if (controller.loading.value) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (controller.filtered.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text("No projects found."),
              );
            }

            /// CRM PIPELINE GROUPING
            final preparationProjects =
                controller.filtered.where((p) => !p.hasDevis && !p.hasBonCommande).toList();

            final devisProjects =
                controller.filtered.where((p) => p.hasDevis && !p.hasBonCommande).toList();

            final bonCommandeProjects =
                controller.filtered.where((p) => p.hasBonCommande).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// PREPARATION
                if (preparationProjects.isNotEmpty) ...[
                  _sectionTitle("🔵 Projects in preparation"),
                  ResponsiveGridRow(
                    children: preparationProjects.map((p) {
                      return ResponsiveGridCol(
                        lg: 4,
                        xl: 4,
                        md: 6,
                        xs: 12,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _buildProjectCard(context, p, theme),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),
                ],

                /// DEVIS
                if (devisProjects.isNotEmpty) ...[
                  _sectionTitle("🔴 Projects with quotation"),
                  ResponsiveGridRow(
                    children: devisProjects.map((p) {
                      return ResponsiveGridCol(
                        lg: 4,
                        xl: 4,
                        md: 6,
                        xs: 12,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _buildProjectCard(context, p, theme),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),
                ],

                /// BON COMMANDE
                if (bonCommandeProjects.isNotEmpty) ...[
                  _sectionTitle("🟢 Projects confirmed"),
                  ResponsiveGridRow(
                    children: bonCommandeProjects.map((p) {
                      return ResponsiveGridCol(
                        lg: 4,
                        xl: 4,
                        md: 6,
                        xs: 12,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _buildProjectCard(context, p, theme),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            );
          }),

          const SizedBox(height: 15),
        ],
      ),
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectCommentScreen(
          projectId: p.id,
          projectName: p.nomProjet,
        ),
      ),
    );

    // ✅ refresh list when coming back
    await controller.loadProjects();

    // ✅ optional: refresh notifications
    if (Get.isRegistered<NotificationController>()) {
      await Get.find<NotificationController>().fetchNotifications(silent: true);
    }
  }

Widget _buildProjectCard(BuildContext context, ProjectGridData p, ThemeData theme) {

  final Color statusColor = p.hasBonCommande
      ? Colors.green
      : (p.hasDevis ? Colors.red : Colors.blue);

  Widget _badge({
    required IconData icon,
    required int count,
    VoidCallback? onTap,
  }) {
    final widget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 5),
          Text(
            "$count",
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return widget;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: widget,
    );
  }

  return InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () {
      if (p.canEdit) {
        context.go(_editUrl(p.id));
      } else {
        _goToComment(context, p);
      }
    },
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeController.isDarkMode ? colorDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// HEADER
          Row(
            children: [

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    if (p.ownerName.trim().isNotEmpty)
                      Text(
                        "Created by ${p.ownerName}",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorGrey500,
                        ),
                      ),

                    const SizedBox(height: 4),

                    Text(
                      p.nomProjet.isEmpty ? "Project" : p.nomProjet,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              /// TASK BADGE
              _badge(
                icon: Icons.event_note,
                count: p.taskCount,
              ),

              const SizedBox(width: 6),

              /// COMMENT BADGE
              _badge(
                icon: Icons.comment,
                count: p.commentCount,
                onTap: () => _goToComment(context, p),
              ),

              const SizedBox(width: 6),

              /// MENU
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) async {
                  if (v == "comment") await _goToComment(context, p);
                  if (v == "edit") context.go(_editUrl(p.id));
                  if (v == "delete") await _confirmDelete(context, p);
                },
                itemBuilder: (_) => [

                  PopupMenuItem(
                    value: "comment",
                    child: Row(
                      children: [
                        const Icon(Icons.comment, size: 18),
                        const SizedBox(width: 8),
                        Text("Comment (${p.commentCount})"),
                      ],
                    ),
                  ),

                  PopupMenuItem(
                    value: "tasks",
                    child: Row(
                      children: [
                        const Icon(Icons.event_note, size: 18),
                        const SizedBox(width: 8),
                        Text("Tasks (${p.taskCount})"),
                      ],
                    ),
                  ),

                  if (p.canEdit)
                    const PopupMenuItem(
                      value: "edit",
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text("Edit"),
                        ],
                      ),
                    ),

                  if (p.canDelete)
                    const PopupMenuItem(
                      value: "delete",
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text("Delete"),
                        ],
                      ),
                    ),
                ],
              )
            ],
          ),

          const SizedBox(height: 14),

          /// COMPANY
          Row(
            children: [
              const Icon(Icons.business, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  p.entreprise.isEmpty ? "Company: -" : p.entreprise,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          /// STATUS + START
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniInfo(theme, "Status", p.statut.isEmpty ? "-" : p.statut),
              _miniInfo(theme, "Start", p.dateDemarrage.isEmpty ? "-" : p.dateDemarrage),
            ],
          ),

          const SizedBox(height: 10),

          /// ADDRESS
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  p.adresse.isEmpty ? "-" : p.adresse,
                  style: theme.textTheme.bodySmall?.copyWith(color: colorGrey500),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// ACTION BUTTON
          /// ACTION BUTTONS
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [

    /// CRM TIMELINE
    ElevatedButton.icon(
      icon: const Icon(Icons.timeline, size: 16),
      label: const Text("CRM Timeline"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey,
      ),
      onPressed: () {

        context.go(
          "/forms/project-timeline?projectId=${p.id}"
        );

      },
    ),

    const SizedBox(width: 8),

    /// EDIT
    if (p.canEdit)
  ElevatedButton.icon(
    onPressed: () => context.go(_editUrl(p.id)),
    icon: const Icon(Icons.edit, size: 16),
    label: const Text("Edit"),
    style: ElevatedButton.styleFrom(
      backgroundColor: colorPrimary100,
    ),
  ),

  ],
),
          
        ],
      ),
    ),
  );
}

  Widget _miniInfo(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorGrey500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, ProjectGridData p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete project"),
        content: Text("Do you really want to delete “${p.nomProjet.isEmpty ? 'Project' : p.nomProjet}” ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete, size: 16),
            label: const Text("Delete"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await controller.deleteProject(p.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Project deleted ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete error: $e")),
      );
    }
  }
}