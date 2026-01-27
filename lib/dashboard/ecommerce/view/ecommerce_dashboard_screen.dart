import 'package:dash_master_toolkit/dashboard/ecommerce/ecommerce_imports.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;

class EcommerceDashboardScreen extends StatefulWidget {
  const EcommerceDashboardScreen({super.key});

  @override
  EcommerceDashboardScreenState createState() => EcommerceDashboardScreenState();
}

class EcommerceDashboardScreenState extends State<EcommerceDashboardScreen> {
  EcommerceDashboardController controller = EcommerceDashboardController();

  // ✅ icône projet (utilise un asset existant chez toi)
  static const String projectIcon = pieChartIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    AppLocalizations lang = AppLocalizations.of(context);

    final isMobileScreen = responsiveValue<bool>(
      context,
      xs: true,
      sm: true,
      md: false,
      lg: false,
      xl: false,
    );

    return GetBuilder<EcommerceDashboardController>(
      init: controller,
      tag: 'ecommerce_dashboard',
      builder: (controller) {
        return Scaffold(
          backgroundColor: controller.themeController.isDarkMode ? colorGrey900 : colorWhite,
          body: SingleChildScrollView(
            padding: EdgeInsets.all(
              rf.ResponsiveValue<double>(
                context,
                conditionalValues: [
                  const rf.Condition.between(start: 0, end: 340, value: 2),
                  const rf.Condition.between(start: 341, end: 992, value: 8),
                ],
                defaultValue: 16,
              ).value,
            ),
            child: ResponsiveGridRow(
              children: [
                // ✅ Tous les projets réalisés
                _topCommonCard(
                  Obx(() => _buildTopCardsWidget(
                    lang, theme, pieChartIcon,
                    "Tous les projets réalisés",
                    controller.totalProjects.value.toString(),
                    "",
                  )),
                ),

                // ✅ Tous les users
                _topCommonCard(
                  Obx(() => _buildTopCardsWidget(
                    lang, theme, customersIcon,
                    "Tous les users",
                    controller.totalUsers.value.toString(),
                    "",
                  )),
                ),

                // ✅ projets non validés (remplacer chariot par icône projet)
                _topCommonCard(
                  Obx(() => _buildTopCardsWidget(
                    lang, theme, projectIcon,
                    "Projets non validés",
                    controller.nonValidatedProjects.value.toString(),
                    "",
                  )),
                ),

                // ✅ projets validés (remplacer money par icône projet)
                _topCommonCard(
                  Obx(() => _buildTopCardsWidget(
                    lang, theme, projectIcon,
                    "Projets validés",
                    controller.validatedProjects.value.toString(),
                    "",
                  )),
                ),

                _commonCard(8, _buildRevenueReportWidget(lang, theme, isMobileScreen)),
                _commonCard(4, _buildCustomerGrowthWidget(lang, theme, isMobileScreen)),
                _commonCard(12, _buildOrderListWidget(lang, theme, isMobileScreen)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===================== Revenue Report =====================
  Widget _buildRevenueReportWidget(AppLocalizations lang, ThemeData theme, bool isMobileScreen) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Projets par période",
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
              Row(
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: colorPrimary50),
                      const SizedBox(width: 4),
                      Text("% Validés",
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: colorPrimary50),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: colorPrimary100),
                      const SizedBox(width: 4),
                      Text("% Réussite",
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: colorPrimary100),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 10),

          Obx(() {
            final total = controller.totalProjects.value;
            final validated = controller.validatedProjects.value;
            final pct = total == 0 ? 0 : ((validated / total) * 100);
            return Text(
              "${pct.toStringAsFixed(1)}%",
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.w600),
            );
          }),

          const SizedBox(height: 8),
          Text("Taux de projets validés (global)",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: controller.themeController.isDarkMode ? colorGrey500 : colorGrey400,
                fontWeight: FontWeight.w500,
              )),

          const SizedBox(height: 20),

          SizedBox(
            height: 396,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              tween: Tween(begin: 0, end: 1),
              builder: (context, animationValue, _) {
                return Obx(() {
                  return BarChart(
                    BarChartData(
                      maxY: 100,
                      minY: 0,
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index < controller.revenueList.length) {
                                return Text(
                                  controller.revenueList[index].month,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: controller.themeController.isDarkMode ? colorGrey500 : colorGrey400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 20,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: controller.themeController.isDarkMode ? colorGrey500 : colorGrey400,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: controller.revenueList.asMap().entries.map((entry) {
                        int index = entry.key;
                        RevenueData data = entry.value;

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: data.earning * animationValue,
                              width: isMobileScreen ? 10 : 20,
                              color: colorPrimary50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            BarChartRodData(
                              toY: data.expense * animationValue,
                              width: isMobileScreen ? 10 : 20,
                              color: colorPrimary100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                          barsSpace: 4,
                        );
                      }).toList(),
                    ),
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===================== Table =====================
  Widget _buildOrderListWidget(AppLocalizations lang, ThemeData theme, bool isMobileScreen) {
    var titleTextStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w400,
      color: controller.themeController.isDarkMode ? colorGrey500 : colorGrey400,
    );

    var rowTextStyle = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Liste des projets",
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Text("Suivi des projets et permissions",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: controller.themeController.isDarkMode ? colorGrey500 : colorGrey400,
              )),
          const SizedBox(height: 10),

          SizedBox(
            child: LayoutBuilder(builder: (context, constraints) {
              return Obx(() => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      dividerTheme: const DividerThemeData(color: Colors.transparent, space: 0, thickness: 0),
                      checkboxTheme: CheckboxThemeData(
                        side: BorderSide(color: colorGrey500, width: 1.0),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: controller.themeController.isDarkMode ? colorGrey700 : colorGrey100,
                          width: 1.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            controller.themeController.isDarkMode ? colorGrey700 : colorGrey50,
                          ),
                          border: TableBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            horizontalInside: BorderSide(
                              color: controller.themeController.isDarkMode ? colorGrey700 : colorGrey100,
                              width: 0.8,
                            ),
                          ),
                          dividerThickness: 1.0,
                          headingRowHeight: 50,
                          dataRowHeight: 70,
                          showCheckboxColumn: false,
                          sortColumnIndex: controller.sortColumnIndex.value,
                          sortAscending: controller.sortAscending.value,
                          columns: [
                            DataColumn(
                              label: Row(
                                children: [
                                  Checkbox(
                                    activeColor: colorPrimary100,
                                    value: controller.selectAll.value,
                                    onChanged: (value) => controller.selectAllRows(value ?? false),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text("."),
                                ],
                              ),
                            ),
                            DataColumn(
                              label: Text("PROJET", style: titleTextStyle),
                              onSort: (i, asc) => controller.sort((d) => d.customerName, i, asc),
                            ),
                            DataColumn(
                              label: Text("DATE", style: titleTextStyle),
                              onSort: (i, asc) => controller.sort((d) => d.date, i, asc),
                            ),
                            DataColumn(
                              label: Text("USER", style: titleTextStyle),
                              onSort: (i, asc) => controller.sort((d) => d.customerEmail, i, asc),
                            ),
                            DataColumn(
                              label: Text("VALIDATION", style: titleTextStyle),
                              onSort: (i, asc) => controller.sort((d) => d.paymentStatus, i, asc),
                            ),
                            DataColumn(
                              label: Text("STATUT", style: titleTextStyle),
                              onSort: (i, asc) => controller.sort((d) => d.orderStatus, i, asc),
                            ),
                            // ✅ Reserve width to ensure buttons are visible
                            DataColumn(
                              label: SizedBox(
                                width: 160,
                                child: Text("ACTION", style: titleTextStyle),
                              ),
                            ),
                          ],
                          rows: List.generate(controller.orders.length, (index) {
                            final row = controller.orders[index];
                            final canEdit = controller.canEdit(row);

                            return DataRow.byIndex(
                              index: index,
                              cells: [
                                DataCell(
                                  Checkbox(
                                    activeColor: colorPrimary100,
                                    value: row.isSelected,
                                    onChanged: (selected) {
                                      setState(() {
                                        row.isSelected = selected ?? false;
                                        controller.selectAll.value =
                                            controller.orders.every((u) => u.isSelected);
                                      });
                                    },
                                  ),
                                ),
                                DataCell(Text(row.customerName, style: rowTextStyle)),
                                DataCell(Text(DateFormat('MMM dd, yyyy').format(row.date), style: rowTextStyle)),
                                DataCell(Text(row.customerEmail, style: rowTextStyle)),
                                DataCell(_validationBadge(row.paymentStatus)),
                                DataCell(_projectStatusBadge(row.orderStatus)),

                                // ✅ ACTION (fix Web) -> Wrap always visible
                                DataCell(
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      spacing: 8,
                                      children: [
                                        if (canEdit) ...[
                                          IconButton(
                                            tooltip: "Editer",
                                            icon: Icon(Icons.edit, color: colorGrey600),
                                            onPressed: () {
                                              // TODO: navigate to edit screen
                                            },
                                          ),
                                          IconButton(
                                            tooltip: "Supprimer",
                                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                                            onPressed: () {
                                              // TODO: call delete
                                            },
                                          ),
                                        ] else ...[
                                          IconButton(
                                            tooltip: "Commenter",
                                            icon: Icon(Icons.comment_outlined, color: colorGrey600),
                                            onPressed: () {
                                              // TODO: open comments
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              color: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.pressed)) return Colors.transparent;
                                if (states.contains(WidgetState.hovered)) {
                                  return controller.themeController.isDarkMode ? colorGrey800 : colorGrey25;
                                }
                                return null;
                              }),
                              selected: row.isSelected,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ));
            }),
          )
        ],
      ),
    );
  }

  Widget _validationBadge(String v) {
    final ok = (v == "Validé");
    final bg = ok ? colorEcommerceLightGreen : const Color(0xffFFEBEA);
    final tx = ok ? colorEcommerceGreen : const Color(0xffFF3333);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(v, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tx)),
    );
  }

  Widget _projectStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case "En cours":
        bgColor = const Color(0xffFFFAE5);
        textColor = const Color(0xffFFCC00);
        break;
      case "Terminé":
        bgColor = colorEcommerceLightGreen;
        textColor = colorEcommerceGreen;
        break;
      case "Préparation":
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue;
        break;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.black;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor)),
    );
  }

  // ===================== CustomerGrowth => Projects list =====================
  Widget _buildCustomerGrowthWidget(AppLocalizations lang, ThemeData theme, bool isMobileScreen) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Projets & pourcentage",
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          SizedBox(
            height: 480,
            child: Obx(() {
              return SingleChildScrollView(
                child: Column(
                  children: controller.customers.map((p) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: ClipOval(
                                  child: SvgPicture.asset(
                                    p.flag,
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  p.country,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: (p.percentage / 100).clamp(0, 1),
                                  borderRadius: BorderRadius.circular(12),
                                  backgroundColor: controller.themeController.isDarkMode ? colorGrey700 : colorGrey100,
                                  valueColor: AlwaysStoppedAnimation<Color>(colorPrimary100),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Text("${p.percentage.toStringAsFixed(1)}%",
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                            ],
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ===================== Top cards =====================
  Widget _buildTopCardsWidget(
    AppLocalizations lang,
    ThemeData theme,
    String assetName,
    String data,
    String totalCount,
    String profitPer,
  ) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildContainerCircleView(assetName),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: controller.themeController.isDarkMode ? colorGrey500 : colorGrey400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(totalCount, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildContainerCircleView(String assetName) {
    double screenWidth = MediaQuery.of(context).size.width;
    double size;
    if (screenWidth >= 768) size = 56;
    else if (screenWidth >= 640) size = 44;
    else size = 38;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: controller.themeController.isDarkMode ? colorGrey700 : colorGrey100),
      ),
      child: Center(
        child: SvgPicture.asset(
          assetName,
          colorFilter: ColorFilter.mode(
            controller.themeController.isDarkMode ? colorWhite : colorGrey900,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  ResponsiveGridCol _commonCard(int count, Widget child) {
    return ResponsiveGridCol(xs: 12, sm: 12, md: count, lg: count, xl: count, child: _commonBg(child));
  }

  ResponsiveGridCol _topCommonCard(Widget child) {
    return ResponsiveGridCol(xs: 12, sm: 12, md: 6, lg: 3, xl: 3, child: _commonBg(child));
  }

  Widget _commonBg(Widget child) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 8, end: 8, top: 15),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: controller.themeController.isDarkMode ? colorGrey900 : Colors.white,
        boxShadow: [
          if (!controller.themeController.isDarkMode)
            BoxShadow(
              color: colorG1.withValues(alpha: 0.24),
              blurRadius: 2,
              offset: const Offset(0, 1),
              spreadRadius: 0,
            ),
        ],
        border: Border.all(color: controller.themeController.isDarkMode ? colorGrey700 : colorGrey100),
      ),
      child: child,
    );
  }
}
