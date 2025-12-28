import 'package:dash_master_toolkit/dashboard/sales/sales_imports.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;
import 'package:syncfusion_flutter_maps/maps.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  ThemeController themeController = Get.put(ThemeController());
  SalesDashboardController controller = Get.put(SalesDashboardController());

  @override
  Widget build(BuildContext context) {
    AppLocalizations lang = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);

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
        // theme: theme,
        builder: (controller) {
          return Scaffold(
            backgroundColor:
                themeController.isDarkMode ? colorGrey900 : colorWhite,
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
                  _commonCard(
                      7, _buildVisitorChart(lang, theme, isMobileScreen)),
                  _commonCard(
                      5, _buildRevenueChart(lang, theme, isMobileScreen)),
                  _commonCard(
                      4, _buildCustomerStratificationChart(lang, theme,isMobileScreen)),
                  _commonCard(3, _buildTargetRealityChart(lang)),
                  _commonCard(5, _buildTopProductsWidget(lang, theme)),
                  _commonCard(4, _buildCountryMapSalesWidget(lang)),
                  _commonCard(3, _buildVolumeSeriesChart(lang)),
                ],
              ),
            ),
          );
        });
  }

  _buildCountryMapSalesWidget(AppLocalizations lang) {
    final Map<String, Color> countryColors = {
      'US': Colors.orange, // United States
      'BR': Colors.red, // Brazil
      'CN': Colors.purple, // China
      'ID': Colors.green, // Indonesia
      'NG': Colors.blue, // Nigeria
      'SA': Colors.teal, // Saudi Arabia
    };

    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleTextStyle(
            lang.translate('SalesMappingByCountry'),
          ),
          SizedBox(
            height: 30,
          ),
          SizedBox(
            height: 280,
            child: SfMaps(
              layers: [
                MapShapeLayer(
                  source: MapShapeSource.asset(
                    '${salesDataPath}world_map.json',
                    shapeDataField: 'name',
                    dataCount: controller.countrySales.length,
                    primaryValueMapper: (index) =>
                        controller.countrySales[index].country,
                    shapeColorValueMapper: (index) =>
                        controller.countrySales[index].color,
                  ),
                  strokeColor: colorGrey500,
                  strokeWidth: 0,
                  color:
                      themeController.isDarkMode ? colorGrey700 : colorGrey100,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  _buildVolumeSeriesChart(AppLocalizations lang) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleTextStyle(
            lang.translate('VolumeVsServiceLevel'),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              // Static sample data for volume and services
              final data = [
                {'volume': 6.0, 'services': 4.0},
                {'volume': 7.5, 'services': 5.0},
                {'volume': 6.5, 'services': 4.5},
                {'volume': 6.0, 'services': 4.0},
                {'volume': 4.5, 'services': 3.5},
                {'volume': 5.0, 'services': 4.0},
              ];

              final barGroups = List.generate(data.length, (index) {
                final volume = data[index]['volume']! * value;
                final services = volume + data[index]['services']! * value;

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: services,
                      rodStackItems: [
                        BarChartRodStackItem(0, volume, Colors.blue),
                        // Volume
                        BarChartRodStackItem(volume, services, Colors.green),
                        // Services
                      ],
                      width: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              });

              return SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    barGroups: barGroups,
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    maxY: 15,
                  ),
                ),
              );
            },
          ),
          SizedBox(
            height: 15,
          ),
          Divider(
            color: themeController.isDarkMode ? colorGrey700 : colorGrey100,
          ),
          SizedBox(
            height: 20,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LegendDot(
                  color: colorLightBlue,
                  label: lang.translate('Volume'),
                  value: '1,135'),
              SizedBox(width: 6),
              SizedBox(
                  height: 25,
                  child: VerticalDivider(
                    color: themeController.isDarkMode
                        ? colorGrey700
                        : colorGrey100,
                    thickness: 2,
                    width: 15,
                  )),
              SizedBox(width: 6),
              LegendDot(
                  color: colorLightGreen,
                  label: lang.translate('Services'),
                  value: '635'),
            ],
          )
        ],
      ),
    );
  }

  _buildTopProductsWidget(AppLocalizations lang, ThemeData theme) {
    var titleTextStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    var rowTextStyle = theme.textTheme.bodyLarge
        ?.copyWith(fontWeight: FontWeight.w500, fontSize: isMobile ? 14 : 16);

    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleTextStyle(
            lang.translate('TopProducts'),
          ),
          SizedBox(
            height: 10,
          ),
          SizedBox(
            height: 300,
            child: LayoutBuilder(builder: (context, constraints) {
              return Obx(
                () => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        dividerTheme: const DividerThemeData(
                          color: Colors.transparent,
                          space: 0,
                          thickness: 0,
                          indent: 0,
                          endIndent: 0,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadiusDirectional.circular(8.0),
                          /*border: Border.all(
                            color: themeController.isDarkMode
                                ? colorGrey700
                                : colorGrey100,
                            width: 1.0,
                          ),*/
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadiusDirectional.circular(8.0),
                          child: DataTable(
                            border: TableBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              horizontalInside: BorderSide(
                                color: themeController.isDarkMode
                                    ? colorGrey700
                                    : colorGrey100,
                              ),
                            ),
                            dividerThickness: 1.0,
                            horizontalMargin: 16.0,
                            headingRowColor: WidgetStateColor.transparent,
                            // col: WidgetStatePropertyAll(themeController.isDarkMode ? colorGrey700 : colorGrey100),
                            columnSpacing: 24,
                            dataRowMaxHeight: 65,
                            columns: [
                              DataColumn(
                                label: Text(
                                  lang.translate("#"),
                                  style: titleTextStyle,
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("name"),
                                  style: titleTextStyle,
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("Popularity"),
                                  style: titleTextStyle,
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("Sales"),
                                  style: titleTextStyle,
                                ),
                              ),
                            ],
                            rows: List.generate(
                                controller.topProductData.length, (index) {
                              ProductData data =
                                  controller.topProductData[index];
                              String color = '0xff${data.color}';
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      (index + 1).toString(),
                                      style: rowTextStyle,
                                    ),
                                  ),
                                  DataCell(Text(
                                    data.name,
                                    style: rowTextStyle,
                                  )),
                                  DataCell(
                                    LinearProgressIndicator(
                                      borderRadius: BorderRadius.circular(8),
                                      value: data.popularity / 100,
                                      backgroundColor: Color(int.parse(color))
                                          .withValues(alpha: 0.1),
                                      color: Color(
                                        int.parse(color),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: 100,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Color(
                                            int.parse(color),
                                          ),
                                        ),
                                        color: Color(int.parse(color))
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${data.sales}%',
                                        style: rowTextStyle?.copyWith(
                                          color: Color(
                                            int.parse(color),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  _buildTargetRealityChart(AppLocalizations lang) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleTextStyle(
            lang.translate('TargetVsReality'),
          ),
          SizedBox(
            height: 10,
          ),
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
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const months = [
                              'Jan',
                              'Feb',
                              'Mar',
                              'Apr',
                              'May',
                              'June',
                              'July'
                            ];
                            return Text(
                              months[value.toInt()],
                              style: const TextStyle(fontSize: 12),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: _buildTargetRealityBarGroups(
                        animationValue: animationValue),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 20,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LegendWithIcon(
                icon: HugeIcons.strokeRoundedShoppingBag03,
                label: "Reality Sales",
                subLabel: "Global",
                color: Color(0xFF31C48D),
                value: "8,823",
              ),
              const SizedBox(height: 16),
              LegendWithIcon(
                icon: HugeIcons.strokeRoundedCouponPercent,
                label: "Target Sales",
                subLabel: "Commercial",
                color: const Color(0xFFFFC300),
                value: "12,122",
              ),
            ],
          )
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildTargetRealityBarGroups(
      {double animationValue = 1.0}) {
    final realitySales = [8000, 8200, 9000, 8800, 9500, 9700, 8800];
    final targetSales = [10000, 10200, 12000, 11000, 13000, 12800, 12122];

    return List.generate(realitySales.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: realitySales[index] * animationValue,
            width: 10,
            color: const Color(0xFF31C48D), // Green
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: targetSales[index] * animationValue,
            width: 10,
            color: const Color(0xFFFFC300), // Yellow/Orange
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        barsSpace: 4,
      );
    });
  }

  _buildCustomerStratificationChart(AppLocalizations lang, ThemeData theme, bool isMobileScreen) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleTextStyle(
            lang.translate('CustomerStratification'),
          ),
          if(isMobileScreen)
          SizedBox(
            height: 30,
          ),
          SizedBox(
            height: 200,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              tween: Tween(begin: 0, end: 1),
              builder: (context, animationValue, _) {
                return LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 6000,
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      _lineBarDataForCustomerStratification(
                        data: [3000, 4000, 3500, 3700, 3600, 3800, 4504],
                        color: colorLightGreen,
                        gradient: LinearGradient(
                          colors: [
                            colorLightGreen.withValues(alpha: 0.02),
                            themeController.isDarkMode
                                ? colorGrey700
                                : Colors.white,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        animationValue: animationValue,
                      ),
                      _lineBarDataForCustomerStratification(
                        data: [3004, 3900, 2800, 2800, 3000, 3100, 3004],
                        color: colorLightBlue,
                        gradient: LinearGradient(
                          colors: [
                            colorLightBlue.withValues(alpha: 0.01),
                            themeController.isDarkMode
                                ? colorGrey700
                                : Colors.white,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        animationValue: animationValue,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 15,
          ),
          Divider(
            color: themeController.isDarkMode ? colorGrey700 : colorGrey100,
          ),
          SizedBox(
            height: 20,
          ),
          _buildCustomerStratificationLegend(lang),
        ],
      ),
    );
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
      belowBarData: BarAreaData(
        show: true,
        gradient: gradient,
      ),
      dotData: FlDotData(show: true),
    );
  }

  _buildCustomerStratificationLegend(AppLocalizations lang) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LegendItem(
          color: colorLightBlue,
          label: lang.translate("LastMonth"),
          amount: "\$3,004",
        ),
        SizedBox(width: 6),
        SizedBox(
          height: 25,
          child: VerticalDivider(
            color: themeController.isDarkMode ? colorGrey700 : colorGrey100,
            thickness: 2,
            width: 15,
          ),
        ),
        SizedBox(width: 6),
        LegendItem(
          color: colorLightGreen,
          label: lang.translate("ThisMonth"),
          amount: "\$5,004",
        ),
      ],
    );
  }

  _buildRevenueChart(
      AppLocalizations lang, ThemeData theme, bool isMobileScreen) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleTextStyle(
            lang.translate('TotalRevenue'),
          ),
          SizedBox(
            height: 30,
          ),
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
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const days = [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun'
                            ];
                            return Padding(
                              padding: EdgeInsets.only(top: 8),
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
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      drawHorizontalLine: true,
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups:
                        _getRevenueBarGroups(animationValue: animationValue),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 20,
          ),
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
      LegendItem(
        color: colorLightBlue,
        label: lang.translate("OfflineSales"),
      ),
      LegendItem(
        color: colorLightGreen,
        label: lang.translate("OfflineSales"),
      ),
    ];
    return isMobileScreen
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .expand((item) => [item, const SizedBox(height: 5)])
                .toList()
              ..removeLast(),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: items
                .expand((item) => [item, const SizedBox(width: 10)])
                .toList()
              ..removeLast(),
          );
  }

  _buildVisitorChart(
      AppLocalizations lang, ThemeData theme, bool isMobileScreen) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleTextStyle(
            lang.translate('VisitorInsights'),
          ),
          SizedBox(
            height: 30,
          ),
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
                                const months = [
                                  'Jan',
                                  'Feb',
                                  'Mar',
                                  'Apr',
                                  'May',
                                  'Jun',
                                  'Jul',
                                  'Aug',
                                  'Sept',
                                  'Oct',
                                  'Nov',
                                  'Dec'
                                ];
                                return Text(
                                  months[value.toInt()],
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500),
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
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.left,
                                );
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        lineBarsData: [
                          _line(data, (e) => e.loyal, Colors.purple, 'Loyal',
                              animationValue: animationValue),
                          _line(data, (e) => e.newCustomer, Colors.red, 'New',
                              animationValue: animationValue),
                          _line(data, (e) => e.unique, Colors.green, 'Unique',
                              animationValue: animationValue),
                        ],
                        gridData: FlGridData(
                          drawHorizontalLine: true,
                          drawVerticalLine: false,
                        ),
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
              )),
          const SizedBox(height: 20),
          _buildLegend(lang, isMobileScreen),
          SizedBox(
            height: 15,
          ),
        ],
      ),
    );
  }

  LineChartBarData _animatedLine(
    List<VisitorData> data,
    int Function(VisitorData) valueSelector,
    Color color,
    String label,
    double animationValue,
  ) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      dotData: FlDotData(show: false),
      barWidth: 3,
      belowBarData: BarAreaData(show: false),
      spots: List.generate(data.length, (index) {
        final y = valueSelector(data[index]).toDouble() * animationValue;
        return FlSpot(index.toDouble(), y);
      }),
    );
  }

  LineChartBarData _line(
    List<VisitorData> data,
    double Function(VisitorData) valueSelector,
    Color color,
    String label, {
    double animationValue = 1.0, // default to 1 for non-animated usage
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
        checkToShowDot: (spot, _) => spot.x == 6, // Highlight July
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
            children: items
                .expand((item) => [item, const SizedBox(height: 5)])
                .toList()
              ..removeLast(),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: items
                .expand((item) => [item, const SizedBox(width: 5)])
                .toList()
              ..removeLast(),
          );
  }

  _buildTodaySaleWidget(AppLocalizations lang, ThemeData theme) {
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
                  _titleTextStyle(
                    lang.translate('TodaySales'),
                  ),
                  SizedBox(
                    height: 3,
                  ),
                  Text(
                    lang.translate('SalesSummery'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: themeController.isDarkMode
                            ? colorGrey500
                            : colorGrey400),
                  ),
                ],
              ),
              SizedBox(
                width: 5,
              ),
              ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor:
                      themeController.isDarkMode ? colorGrey900 : colorWhite,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: themeController.isDarkMode
                          ? colorGrey700
                          : colorGrey100,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  Icons.file_upload_outlined,
                  color: themeController.isDarkMode ? colorWhite : colorGrey900,
                ),
                label: Text(
                  lang.translate("Export"),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            ],
          ),
        ),
        SizedBox(
          height: 10,
        ),
        ResponsiveGridRow(
            // childAspectRatio: 2.5,
            children: [
              _commonSaleCardWidget(
                  cardBgColor: Color(0xffFFE2E6),
                  iconBgColor: Color(0xffFA5A7E),
                  theme: theme,
                  icon: chartSalesIcon,
                  totalCount: '\$1K',
                  title: lang.translate('TotalSales'),
                  profit: '+8% ${lang.translate('fromYesterday')}',
                  index: 0),
              _commonSaleCardWidget(
                  cardBgColor: Color(0xffFFF4DE),
                  iconBgColor: Color(0xffFF947A),
                  theme: theme,
                  icon: fileMinusIcon,
                  totalCount: '300',
                  title: lang.translate('TotalOrder'),
                  profit: '+5% ${lang.translate('fromYesterday')}',
                  index: 1),
              _commonSaleCardWidget(
                  cardBgColor: Color(0xffDCFCE7),
                  iconBgColor: Color(0xff3BD755),
                  theme: theme,
                  icon: tagIcon,
                  totalCount: '5',
                  title: lang.translate('ProductSold'),
                  profit: '1,2% ${lang.translate('fromYesterday')}',
                  index: 2),
              _commonSaleCardWidget(
                  cardBgColor: Color(0xffF4E8FF),
                  iconBgColor: Color(0xffBF83FE),
                  theme: theme,
                  icon: addUserIcon,
                  totalCount: '8',
                  title: lang.translate('NewCustomers'),
                  profit: '0,5% ${lang.translate('fromYesterday')}',
                  index: 3),
            ]),
        SizedBox(
          height: 10,
        ),
      ],
    );
  }

  _commonSaleCardWidget(
      {required Color cardBgColor,
      required Color iconBgColor,
      required ThemeData theme,
      required int index,
      required String icon,
      required String totalCount,
      required String title,
      required String profit}) {
    return ResponsiveGridCol(
      xs: 6,
      sm: 6,
      md: 6,
      lg: 6,
      xl: 6,
      child: IntrinsicHeight(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          // margin: EdgeInsetsDirectional.only(
          //     start: index > 0 ? 8 : 0, end: index == 3 ? 8 : 0),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10), color: cardBgColor),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: iconBgColor),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SvgPicture.asset(
                    icon,
                    colorFilter:
                        ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                totalCount,
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600, color: colorGrey900),
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500, color: colorGrey900),
              ),
              SizedBox(
                height: 8,
              ),
              Text(
                profit,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w400, color: colorPrimary100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ResponsiveGridCol _commonCard(
    int count,
    Widget child,
  ) {
    return ResponsiveGridCol(
      xs: 12,
      sm: 12,
      md: count,
      lg: count,
      xl: count,
      child: Container(
        margin: EdgeInsetsDirectional.only(start: 8, end: 8, top: 15),
        // width: screenWidth,
        padding: EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: themeController.isDarkMode ? colorDark : colorWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
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
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w600),
    );
  }
}
