import 'package:dash_master_toolkit/application/users/controller/user_grid_controller.dart';
import 'package:dash_master_toolkit/application/users/model/project_grid_data.dart';
import 'package:dash_master_toolkit/constant/app_color.dart';
import 'package:dash_master_toolkit/constant/app_images.dart';
import 'package:dash_master_toolkit/localization/app_localizations.dart';
import 'package:dash_master_toolkit/route/my_route.dart';
import 'package:dash_master_toolkit/theme/theme_controller.dart';
import 'package:dash_master_toolkit/widgets/common_app_widget.dart';
import 'package:dash_master_toolkit/widgets/common_search_field.dart';
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
  final UserGridController controller = Get.put(UserGridController());
  final ThemeController themeController = Get.put(ThemeController());

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
            conditionalValues: [
              const rf.Condition.between(start: 0, end: 340, value: 10),
              const rf.Condition.between(start: 341, end: 992, value: 10),
            ],
            defaultValue: 10,
          ).value,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  hintText: lang.translate("search"),
                  borderRadius: 8,
                  topContentPadding: 0,
                  bottomContentPadding: 0,
                ),
              ),
            ),
            const SizedBox(height: 15),

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
                  child: Text("Aucun projet trouvé."),
                );
              }

              return ResponsiveGridRow(
                children: List.generate(
                  controller.filtered.length,
                  (index) {
                    return ResponsiveGridCol(
                      lg: 4,
                      xl: 4,
                      md: 4,
                      xs: 12,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: 20,
                          start: 10,
                          end: 10,
                        ),
                        child: _buildProjectCard(
                          context,
                          controller.filtered[index],
                          theme,
                        ),
                      ),
                    );
                  },
                ),
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
      path: MyRoute.projectFormScreen, // "/forms/project"
      queryParameters: {'id': id},
    ).toString();
  }

  Widget _buildProjectCard(
    BuildContext context,
    ProjectGridData p,
    ThemeData theme,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go(_editUrl(p.id)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: themeController.isDarkMode ? colorDark : colorWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.nomProjet.isEmpty ? "Projet" : p.nomProjet,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.more_vert),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              p.entreprise.isEmpty ? "Entreprise: -" : "Entreprise: ${p.entreprise}",
              style: theme.textTheme.bodyMedium?.copyWith(color: colorGrey500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniInfo(theme, "Statut", p.statut.isEmpty ? "-" : p.statut),
                _miniInfo(theme, "Démarrage", p.dateDemarrage.isEmpty ? "-" : p.dateDemarrage),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              p.adresse.isEmpty ? "Adresse: -" : "Adresse: ${p.adresse}",
              style: theme.textTheme.bodySmall?.copyWith(color: colorGrey500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 14),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => context.go(_editUrl(p.id)),
                icon: const Icon(Icons.edit, size: 16),
                label: Text(
                  "Edit",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrimary100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
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
}
