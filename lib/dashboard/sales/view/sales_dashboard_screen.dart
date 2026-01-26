import 'package:dash_master_toolkit/dashboard/sales/sales_imports.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;
import 'package:syncfusion_flutter_maps/maps.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  final ThemeController themeController = Get.put(ThemeController());
  final SalesDashboardController controller = Get.put(SalesDashboardController());

  // ✅ UN SEUL helper (doublon supprimé)
  double _toDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final isMobileScreen = responsiveValue<bool>(
      context,
      xs: true,
      sm: true,
      md: false,
      lg: false,
      xl: false,
    );

    return GetBuilder<SalesDashboardController>(
      init: controller,
      tag: 'sales_dashboard',
      builder: (_) {
        return Scaffold(
          backgroundColor: themeController.isDarkMode ? colorGrey900 : colorWhite,
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
                _commonCard(5, _buildTodaySaleWidget(lang, theme)),
                _commonCard(7, _buildVisitorChart(lang, theme, isMobileScreen)),
                _commonCard(5, _buildRevenueChart(lang, theme, isMobileScreen)),
                _commonCard(3, _buildTargetRealityChart(lang)),
                _commonCard(5, _buildTopProductsWidget(lang, theme)),
                _commonCard(7, _buildCountryMapSalesWidget(lang)),
               
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================
  // MAP KPI (Projects mapping)
  // =========================
  Widget _buildCountryMapSalesWidget(AppLocalizations lang) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleTextStyle("Projects Mapping (lat/lng)"),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: Obx(() {
              final rows = controller.projectLocationKpi;

              if (controller.isLoadingKpi.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.kpiError.value.isNotEmpty) {
                return Center(
                  child: Text(
                    controller.kpiError.value,
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              if (rows.isEmpty) {
                return const Center(child: Text("No location KPI data"));
              }

              final first = rows.first as Map;
              final centerLat = _toDouble(first["latitude"], fallback: 36.8);
              final centerLng = _toDouble(first["longitude"], fallback: 10.2);

              return SfMaps(
                layers: [
                  MapTileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    initialFocalLatLng: MapLatLng(centerLat, centerLng),
                    initialZoomLevel: 6,
                    initialMarkersCount: rows.length,

                    markerBuilder: (context, index) {
                      final d = rows[index] as Map;

                      final name = (d["nomProjet"] ?? "Projet").toString();
                      final lat = _toDouble(d["latitude"]);
                      final lng = _toDouble(d["longitude"]);
                      final status = (d["validationStatut"] ?? "Non validé").toString();

                      final isValid = status == "Validé";

                      return MapMarker(
                        latitude: lat,
                        longitude: lng,
                        size: const Size(160, 36),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isValid ? Colors.green.shade600 : Colors.red.shade600,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(blurRadius: 6, color: Colors.black26),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isValid ? Icons.verified : Icons.error, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },

                    // ✅ Tooltip global du layer (bonne place)
                    markerTooltipBuilder: (context, index) {
                      final d = rows[index] as Map;

                      final name = (d["nomProjet"] ?? "").toString();
                      final status = (d["validationStatut"] ?? "").toString();
                      final adr = (d["adresse"] ?? d["localisationCommentaire"] ?? "").toString();

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DefaultTextStyle(
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text("Status: $status"),
                              if (adr.trim().isNotEmpty) Text("Adresse: $adr"),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // =========================
  // Validation status list
  // =========================
  Widget _buildValidationStatusWidget(AppLocalizations lang, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleTextStyle("Validation Status Count"),
          const SizedBox(height: 10),
          Obx(() {
            final rows = controller.projectValidationStatus;

            if (controller.isLoadingKpi.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.kpiError.value.isNotEmpty) {
              return Text(controller.kpiError.value, style: const TextStyle(color: Colors.red));
            }
            if (rows.isEmpty) return const Text("No status data");

            return Column(
              children: rows.map((e) {
                final d = e as Map;
                return ListTile(
                  dense: true,
                  title: Text("${d["validationStatut"]}"),
                  trailing: Text("${d["projectCount"]}"),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  // =========================
  // Surface KPI table
  // =========================
Widget _buildTopProductsWidget(AppLocalizations lang, ThemeData theme) {
  final titleTextStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
  final rowTextStyle = theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500, fontSize: 14);

  return Padding(
    padding: const EdgeInsets.all(7.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleTextStyle("Validation by Surface (m²)"),
        const SizedBox(height: 10),
        SizedBox(
          height: 300,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Obx(() {
                final rows = controller.surfacePagedRows;

                if (controller.isLoadingKpi.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.kpiError.value.isNotEmpty) {
                  return Center(
                    child: Text(controller.kpiError.value, style: const TextStyle(color: Colors.red)),
                  );
                }
                if (rows.isEmpty) {
                  return const Center(child: Text("No surface KPI data"));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        dividerTheme: const DividerThemeData(color: Colors.transparent, space: 0, thickness: 0),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: DataTable(
                          border: TableBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            horizontalInside: BorderSide(
                              color: themeController.isDarkMode ? colorGrey700 : colorGrey100,
                            ),
                          ),
                          dividerThickness: 1.0,
                          horizontalMargin: 16.0,
                          headingRowColor: WidgetStateColor.transparent,
                          columnSpacing: 24,
                          dataRowMaxHeight: 65,
                          columns: [
                            DataColumn(label: Text("#", style: titleTextStyle)),
                            DataColumn(label: Text("Surface", style: titleTextStyle)),
                            DataColumn(label: Text("Total", style: titleTextStyle)),
                            DataColumn(label: Text("Validé", style: titleTextStyle)),
                            DataColumn(label: Text("%", style: titleTextStyle)),
                          ],
                          rows: List.generate(rows.length, (index) {
                            final d = rows[index];

                            final surface = controller.surfaceLabel(d);
                            final total = controller.surfaceTotal(d).toString();
                            final valid = controller.surfaceValidated(d).toString();
                            final pctNum = controller.surfaceAvgReussite(d); 

                            return DataRow(
                              cells: [
                                DataCell(Text("${index + 1}", style: rowTextStyle)),
                                DataCell(Text(surface, style: rowTextStyle)),
                                DataCell(Text(total, style: rowTextStyle)),
                                DataCell(Text(valid, style: rowTextStyle)),
                                DataCell(Text("${pctNum.toStringAsFixed(2)}%", style: rowTextStyle)),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                );
              });
            },
          ),
        ),
        // Pagination Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: controller.prevSurfacePage,
            ),
            Text("Page ${controller.surfacePage} of ${controller.surfaceTotalPages}"),
            IconButton(
              icon: Icon(Icons.arrow_forward),
              onPressed: controller.nextSurfacePage,
            ),
          ],
        ),
      ],
    ),
  );
}
  // =========================
  // Target vs Reality
  // =========================
  Widget _buildTargetRealityChart(AppLocalizations lang) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleTextStyle(lang.translate('TargetVsReality')),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              tween: Tween(begin: 0, end: 1),
              builder: (context, animationValue, _) {
                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 15000,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'June', 'July'];
                            return Text(months[value.toInt()], style: const TextStyle(fontSize: 12));
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: _buildTargetRealityBarGroups(animationValue: animationValue),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              // (les widgets LegendWithIcon doivent exister dans sales_imports.dart)
            ],
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildTargetRealityBarGroups({double animationValue = 1.0}) {
    final realitySales = [8000, 8200, 9000, 8800, 9500, 9700, 8800];
    final targetSales = [10000, 10200, 12000, 11000, 13000, 12800, 12122];

    return List.generate(realitySales.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: realitySales[index] * animationValue,
            width: 10,
            color: const Color(0xFF31C48D),
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: targetSales[index] * animationValue,
            width: 10,
            color: const Color(0xFFFFC300),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        barsSpace: 4,
      );
    });
  }

  LineChartBarData _lineBarDataForCustomerStratification({
    required List<double> data,
    required Color color,
    required Gradient gradient,
    double animationValue = 1.0,
  }) {
    return LineChartBarData(
      spots: List.generate(
        data.length,
        (index) => FlSpot(index.toDouble(), data[index] * animationValue),
      ),
      isCurved: true,
      barWidth: 3,
      color: color,
      belowBarData: BarAreaData(show: true, gradient: gradient),
      dotData: FlDotData(show: true),
    );
  }

  Widget _buildCustomerStratificationLegend(AppLocalizations lang) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LegendItem(color: colorLightBlue, label: lang.translate("LastMonth"), amount: "\$3,004"),
        const SizedBox(width: 6),
        SizedBox(
          height: 25,
          child: VerticalDivider(
            color: themeController.isDarkMode ? colorGrey700 : colorGrey100,
            thickness: 2,
            width: 15,
          ),
        ),
        const SizedBox(width: 6),
        LegendItem(color: colorLightGreen, label: lang.translate("ThisMonth"), amount: "\$5,004"),
      ],
    );
  }

  // =========================
  // Revenue chart (demo)
  // =========================
  Widget _buildRevenueChart(AppLocalizations lang, ThemeData theme, bool isMobileScreen) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleTextStyle(lang.translate('TotalRevenue')),
          const SizedBox(height: 30),
          SizedBox(
            height: 250,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              tween: Tween(begin: 0, end: 1),
              builder: (context, animationValue, _) {
                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 25000,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 5000,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${(value ~/ 1000)}k',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                days[value.toInt()],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(drawHorizontalLine: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    barGroups: _getRevenueBarGroups(animationValue: animationValue),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildRevenueLegend(lang, isMobileScreen),
        ],
      ),
    );
  }

  List<BarChartGroupData> _getRevenueBarGroups({double animationValue = 1.0}) {
    final online = [12000, 15000, 5000, 14000, 11000, 13000, 20000];
    final offline = [10000, 10000, 20000, 7000, 9000, 11000, 9000];

    return List.generate(7, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: online[index] * animationValue,
            color: colorLightBlue,
            width: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: offline[index] * animationValue,
            color: colorLightGreen,
            width: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        barsSpace: 4,
      );
    });
  }

  Widget _buildRevenueLegend(AppLocalizations lang, bool isMobileScreen) {
    final items = [
      LegendItem(color: colorLightBlue, label: lang.translate("OnlineSales")),
      LegendItem(color: colorLightGreen, label: lang.translate("OfflineSales")),
    ];

    return isMobileScreen
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.expand((item) => [item, const SizedBox(height: 5)]).toList()
              ..removeLast(),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: items.expand((item) => [item, const SizedBox(width: 10)]).toList()
              ..removeLast(),
          );
  }

  // =========================
  // Visitors chart (uses controller.visitors)
  // =========================
  Widget _buildVisitorChart(AppLocalizations lang, ThemeData theme, bool isMobileScreen) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleTextStyle(lang.translate('VisitorInsights')),
          const SizedBox(height: 30),
          SizedBox(
            height: 300,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: 1),
              builder: (context, animationValue, _) {
                return Obx(() {
                  final data = controller.visitors;

                  return LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 400,
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, _) {
                              const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sept','Oct','Nov','Dec'];
                              return Text(
                                months[value.toInt()],
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, fontWeight: FontWeight.w500),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 100,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                                textAlign: TextAlign.left,
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineBarsData: [
                        _line(data, (e) => e.loyal, Colors.purple, animationValue: animationValue),
                        _line(data, (e) => e.newCustomer, Colors.red, animationValue: animationValue),
                        _line(data, (e) => e.unique, Colors.green, animationValue: animationValue),
                      ],
                      gridData: FlGridData(drawHorizontalLine: true, drawVerticalLine: false),
                      extraLinesData: ExtraLinesData(
                        verticalLines: [
                          VerticalLine(
                            x: 6,
                            color: Colors.red.withValues(alpha: 0.5),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ],
                      ),
                    ),
                  );
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildLegend(lang, isMobileScreen),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  LineChartBarData _line(
    List<VisitorData> data,
    double Function(VisitorData) valueSelector,
    Color color, {
    double animationValue = 1.0,
  }) {
    return LineChartBarData(
      spots: data
          .map((e) => FlSpot(
                e.month.toDouble(),
                valueSelector(e) * animationValue,
              ))
          .toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      belowBarData: BarAreaData(show: false),
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, _) => spot.x == 6,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 6,
          color: Colors.white,
          strokeWidth: 3,
          strokeColor: color,
        ),
      ),
    );
  }

  Widget _buildLegend(AppLocalizations lang, bool isMobileScreen) {
    final items = [
      LegendItem(color: Colors.purple, label: lang.translate("LoyalCustomers")),
      LegendItem(color: Colors.red, label: lang.translate("NewCustomers")),
      LegendItem(color: Colors.green, label: lang.translate("UniqueCustomers")),
    ];

    return isMobileScreen
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.expand((item) => [item, const SizedBox(height: 5)]).toList()
              ..removeLast(),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: items.expand((item) => [item, const SizedBox(width: 5)]).toList()
              ..removeLast(),
          );
  }

  // =========================
  // Today Sales (Projects KPI)
  // =========================
  Widget _buildTodaySaleWidget(AppLocalizations lang, ThemeData theme) {
    final total = controller.totalProjects;
    final validated = controller.validatedProjects;
    final nonValidated = controller.nonValidatedProjects;
    final pct = controller.validatedPercentage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(7.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titleTextStyle(lang.translate('TodaySales')),
                  const SizedBox(height: 3),
                  Text(
                    "Projects KPI Summary",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: themeController.isDarkMode ? colorGrey500 : colorGrey400,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => controller.fetchProjectKpis(),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: themeController.isDarkMode ? colorGrey900 : colorWhite,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: themeController.isDarkMode ? colorGrey700 : colorGrey100,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(Icons.refresh, color: themeController.isDarkMode ? colorWhite : colorGrey900),
                label: Text(
                  "Refresh",
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              )
            ],
          ),
        ),

        // ✅ IMPORTANT: Rx affiché via Obx
        Obx(() {
          if (controller.isLoadingKpi.value) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            );
          }
          if (controller.kpiError.value.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text(controller.kpiError.value, style: const TextStyle(color: Colors.red)),
            );
          }
          return const SizedBox.shrink();
        }),

        const SizedBox(height: 10),

        ResponsiveGridRow(
          children: [
            _commonSaleCardWidget(
              cardBgColor: const Color(0xffFFE2E6),
              iconBgColor: const Color(0xffFA5A7E),
              theme: theme,
              icon: chartSalesIcon,
              totalCount: total.toString(),
              title: "Total Projects",
              profit: "All created projects",
              index: 0,
            ),
            _commonSaleCardWidget(
              cardBgColor: const Color(0xffDCFCE7),
              iconBgColor: const Color(0xff3BD755),
              theme: theme,
              icon: tagIcon,
              totalCount: validated.toString(),
              title: "Validated",
              profit: "Status = Validé",
              index: 1,
            ),
            _commonSaleCardWidget(
              cardBgColor: const Color(0xffFFF4DE),
              iconBgColor: const Color(0xffFF947A),
              theme: theme,
              icon: fileMinusIcon,
              totalCount: controller.pctText(pct),
              title: "Validation %",
              profit: "Validated / Total",
              index: 2,
            ),
            _commonSaleCardWidget(
              cardBgColor: const Color(0xffF4E8FF),
              iconBgColor: const Color(0xffBF83FE),
              theme: theme,
              icon: addUserIcon,
              totalCount: nonValidated.toString(),
              title: "Non Validé",
              profit: "Total - Validated",
              index: 3,
            ),
          ],
        ),

        const SizedBox(height: 10),
      ],
    );
  }

  ResponsiveGridCol _commonSaleCardWidget({
    required Color cardBgColor,
    required Color iconBgColor,
    required ThemeData theme,
    required int index,
    required String icon,
    required String totalCount,
    required String title,
    required String profit,
  }) {
    return ResponsiveGridCol(
      xs: 6,
      sm: 6,
      md: 6,
      lg: 6,
      xl: 6,
      child: IntrinsicHeight(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: cardBgColor),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: iconBgColor),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SvgPicture.asset(
                    icon,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                totalCount,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: colorGrey900),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500, color: colorGrey900),
              ),
              const SizedBox(height: 8),
              Text(
                profit,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w400, color: colorPrimary100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ResponsiveGridCol _commonCard(int count, Widget child) {
    return ResponsiveGridCol(
      xs: 12,
      sm: 12,
      md: count,
      lg: count,
      xl: count,
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 8, end: 8, top: 15),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: themeController.isDarkMode ? colorDark : colorWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
        ),
        child: child,
      ),
    );
  }

  Widget _titleTextStyle(String title) {
    final isMobile = responsiveValue<bool>(
      context,
      xs: true,
      sm: true,
      md: false,
      lg: false,
      xl: false,
    );

    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
