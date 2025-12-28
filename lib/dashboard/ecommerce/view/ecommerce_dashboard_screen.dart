import 'package:dash_master_toolkit/dashboard/ecommerce/ecommerce_imports.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;

class EcommerceDashboardScreen extends StatefulWidget {
  const EcommerceDashboardScreen({super.key});

  @override
  EcommerceDashboardScreenState createState() =>
      EcommerceDashboardScreenState();
}

class EcommerceDashboardScreenState extends State<EcommerceDashboardScreen> {
  EcommerceDashboardController controller = EcommerceDashboardController();

  // late ThemeData theme;

  @override
  void initState() {
    super.initState();
    // theme = Get.isDarkMode ? Styles.darkTheme : Styles.lightTheme;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final screenWidth = MediaQuery.sizeOf(context).width;
    AppLocalizations lang = AppLocalizations.of(context);
    // final desktopView = screenWidth >= 1200;

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
        // theme: theme,
        builder: (controller) {
          return Scaffold(
            backgroundColor: controller.themeController.isDarkMode
                ? colorGrey900
                : colorWhite,
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
                  _topCommonCard(
                    _buildTopCardsWidget(lang, theme, pieChartIcon,
                        lang.translate('TotalSales'), '120,452', '80'),
                  ),
                  //Total Sales
                  _topCommonCard(
                    _buildTopCardsWidget(lang, theme, customersIcon,
                        lang.translate('Customers'), '21,675.01', '90'),
                  ),
                  //Customers
                  _topCommonCard(
                    _buildTopCardsWidget(lang, theme, cartIcon,
                        lang.translate('Product'), '1.423', '88'),
                  ),
                  //Product
                  _topCommonCard(
                    _buildTopCardsWidget(lang, theme, dollarIcon,
                        lang.translate('Revenue'), '220,745,00', '88'),
                  ),
                  //Revenue
                  _commonCard(8,
                      _buildRevenueReportWidget(lang, theme, isMobileScreen)),
                  _commonCard(4,
                      _buildCustomerGrowthWidget(lang, theme, isMobileScreen)),
                  _commonCard(
                      12, _buildOrderListWidget(lang, theme, isMobileScreen)),
                ],
              ),
            ),
          );
        });
  }

  Widget _buildRevenueReportWidget(
      AppLocalizations lang, ThemeData theme, bool isMobileScreen) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lang.translate('RevenueReport'),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: colorPrimary50),
                      const SizedBox(width: 4),
                      Text(
                        lang.translate("Earning"),
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorPrimary50),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Icon(Icons.circle,
                          size: 10, color: colorPrimary100),
                      const SizedBox(width: 4),
                      Text(
                        lang.translate("Expense"),
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorPrimary100),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
          SizedBox(
            height: 5,
          ),
          Text(
            '\$220,745,00',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontSize: 32, fontWeight: FontWeight.w600),
          ),
          SizedBox(
            height: 5,
          ),
          _buildProfitWidget('80', theme, lang),
          SizedBox(
            height: 30,
          ),
          SizedBox(
            height: 396,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              tween: Tween(begin: 0, end: 1),
              builder: (context, animationValue, _) {
                return Obx(() {
                  double maxY = controller.revenueList
                          .map((e) =>
                              e.earning > e.expense ? e.earning : e.expense)
                          .reduce((a, b) => a > b ? a : b) +
                      10;

                  return BarChart(
                    BarChartData(
                      maxY: maxY,
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
                                      color:
                                          controller.themeController.isDarkMode
                                              ? colorGrey500
                                              : colorGrey400,
                                      fontWeight: FontWeight.w500),
                                );
                              } else {
                                return const Text('');
                              }
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            // enough space for text like '50'
                            interval: 10,
                            // <-- important: show label every 10 units
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: controller.themeController.isDarkMode
                                        ? colorGrey500
                                        : colorGrey400,
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
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
                      barGroups:
                          controller.revenueList.asMap().entries.map((entry) {
                        int index = entry.key;
                        RevenueData data = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: data.earning * animationValue,
                              width: isMobileScreen ? 10 :20,
                              color: colorPrimary50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            BarChartRodData(
                              toY: data.expense * animationValue,
                              width:isMobileScreen ? 10 : 20,
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
          )
        ],
      ),
    );
  }

  Widget _buildOrderListWidget(
      AppLocalizations lang, ThemeData theme, bool isMobileScreen) {
    var titleTextStyle = theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        color: controller.themeController.isDarkMode
            ? colorGrey500
            : colorGrey400);

    var rowTextStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.translate('OrderList'),
            style: theme.textTheme.titleLarge
                ?.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(
            height: 10,
          ),
          Text(
            lang.translate('TrackOrdersListAcrossYourStore'),
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: controller.themeController.isDarkMode
                    ? colorGrey500
                    : colorGrey400),
          ),
          SizedBox(
            height: 10,
          ),
          SizedBox(
            // height: 396,
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
                        checkboxTheme: CheckboxThemeData(
                          side: BorderSide(
                            color: colorGrey500,
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: controller.themeController.isDarkMode
                                ? colorGrey700
                                : colorGrey100,
                            width: 1.0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                                controller.themeController.isDarkMode
                                    ? colorGrey700
                                    : colorGrey50),
                            border: TableBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              horizontalInside: BorderSide(
                                  color: controller.themeController.isDarkMode
                                      ? colorGrey700
                                      : colorGrey100,
                                  width: 0.8),
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
                                      onChanged: (value) {
                                        controller
                                            .selectAllRows(value ?? false);
                                      },
                                    ),
                                    const SizedBox(width: 12.0),
                                    Text('${lang.translate('')}.'),
                                  ],
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("ORDER"),
                                  style: titleTextStyle,
                                ),
                                onSort: (columnIndex, ascending) => controller
                                    .sort((d) => d.id, columnIndex, ascending),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("DATE"),
                                  style: titleTextStyle,
                                ),
                                onSort: (columnIndex, ascending) => controller
                                    .sort((d) => d.date, columnIndex, ascending),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("CUSTOMER"),
                                  style: titleTextStyle,
                                ),
                                // numeric: true,
                                onSort: (columnIndex, ascending) =>
                                    controller.sort((d) => d.customerName,
                                        columnIndex, ascending),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("PAYMENT"),
                                  style: titleTextStyle,
                                ),
                                // numeric: true,
                                onSort: (columnIndex, ascending) =>
                                    controller.sort((d) => d.paymentStatus,
                                        columnIndex, ascending),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("STATUS"),
                                  style: titleTextStyle,
                                ),
                                // numeric: true,
                                onSort: (columnIndex, ascending) =>
                                    controller.sort((d) => d.orderStatus,
                                        columnIndex, ascending),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("METHOD"),
                                  style: titleTextStyle,
                                ),
                                // numeric: true,
                                onSort: (columnIndex, ascending) =>
                                    controller.sort((d) => d.paymentMethod,
                                        columnIndex, ascending),
                              ),
                              DataColumn(
                                label: Text(
                                  lang.translate("ACTION"),
                                  style: titleTextStyle,
                                ),
                                // numeric: true,
                              ),
                            ],
                            rows: List.generate(controller.orders.length,
                                (index) {
                              final row = controller.orders[index];
                              return DataRow.byIndex(
                                index: index,
                                cells: [
                                  DataCell(
                                    Checkbox(
                                      activeColor: colorPrimary100,
                                      value: row.isSelected,
                                      onChanged: (selected) {
                                        setState(
                                          () {
                                            row.isSelected = selected ?? false;
                                            controller.selectAll.value =
                                                controller.orders
                                                    .every((u) => u.isSelected);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      row.id.toString(),
                                      style: rowTextStyle,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      DateFormat('MMM dd, yyyy, HH:mm')
                                          .format(row.date),
                                      style: rowTextStyle,
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        ClipOval(
                                          child: commonCacheImageWidget(
                                              row.customerAvatarUrl, 36,
                                              width: 36),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              row.customerName,
                                              style: rowTextStyle,
                                            ),
                                            Text(
                                              row.customerEmail,
                                              style: titleTextStyle?.copyWith(
                                                  fontSize: 12),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                  DataCell(Row(
                                    children: [
                                      Icon(Icons.circle,
                                          color: colorEcommerceGreen, size: 10),
                                      const SizedBox(width: 4),
                                      Text(
                                        row.paymentStatus,
                                        style: rowTextStyle?.copyWith(
                                            color: colorEcommerceGreen),
                                      ),
                                    ],
                                  ),),
                                  DataCell(statusBadge(row.orderStatus)),
                                  DataCell(Row(
                                    children: [
                                      getPaymentIcon(row.paymentMethod),
                                      const SizedBox(width: 6),
                                      Text(
                                        "...${row.paymentLast4}",
                                        style: rowTextStyle?.copyWith(
                                            color: controller
                                                    .themeController.isDarkMode
                                                ? colorGrey500
                                                : colorGrey400),
                                      ),
                                    ],
                                  )),
                                  DataCell(Icon(
                                    Icons.more_vert,
                                    color: colorGrey500,
                                  )),
                                ],
                                onSelectChanged: (selected) {},
                                color: WidgetStateProperty.resolveWith<Color?>(
                                    (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.pressed)) {
                                    return Colors
                                        .transparent; // Clicked/pressed state
                                  } else if (states
                                      .contains(WidgetState.hovered)) {
                                    return controller.themeController.isDarkMode
                                        ? colorGrey800
                                        : colorGrey25;
                                  }
                                  return null;
                                }),
                                // onSelectChanged: (_) {},
                                // Use MouseRegion to simulate hover
                                selected: row.isSelected,
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
          )
        ],
      ),
    );
  }

  Widget statusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case "Scheduled":
        bgColor = Color(0xffFFFAE5);
        textColor = Color(0xffFFCC00);
        break;
      case "Delivered":
        bgColor = colorEcommerceLightGreen;
        textColor = colorEcommerceGreen;
        break;
      case "Cancel":
        bgColor = Color(0xffFFEBEA);
        textColor = Color(0xffFF3333);
        break;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.black;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(status,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: textColor)),
    );
  }

  Widget getPaymentIcon(String method) {
    switch (method) {
      case "Mastercard":
        return SvgPicture.asset(mastercardIcon, height: 24);
      case "PayPal":
        return SvgPicture.asset(paypalIcon, height: 24);
      default:
        return Icon(Icons.payment);
    }
  }

  Widget _buildCustomerGrowthWidget(
      AppLocalizations lang, ThemeData theme, bool isMobileScreen) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.translate('CustomerGrowth'),
            style: theme.textTheme.titleLarge
                ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(
            height: 20,
          ),
          SizedBox(
            height: 480,
            child: Obx(() {
              return SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: controller.customers.map((customer) {
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
                                    customer.flag,
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  customer.country,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 15,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: customer.percentage / 100,
                                  borderRadius: BorderRadius.circular(12),
                                  backgroundColor:
                                      controller.themeController.isDarkMode
                                          ? colorGrey700
                                          : colorGrey100,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      colorPrimary100),
                                  minHeight: 8,
                                ),
                              ),
                              SizedBox(
                                width: 15,
                              ),
                              Text(
                                "${customer.percentage.toStringAsFixed(1)}%",
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
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

  _buildTopCardsWidget(AppLocalizations lang, ThemeData theme, String assetName,
      String data, String totalCount, String profitPer) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildContainerCircleView(assetName),
              SizedBox(
                width: 10,
              ),
              Text(
                data,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: controller.themeController.isDarkMode
                      ? colorGrey500
                      : colorGrey400,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 15,
          ),
          Text(
            totalCount,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(
            height: 10,
          ),
          _buildProfitWidget(profitPer, theme, lang),
        ],
      ),
    );
  }

  _buildProfitWidget(String profitPer, ThemeData theme, AppLocalizations lang) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: colorEcommerceLightGreen),
          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: Row(
            children: [
              SvgPicture.asset(arrowUpIcon),
              SizedBox(
                width: 5,
              ),
              Text(
                '$profitPer%',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colorEcommerceGreen, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 5,
        ),
        Text(
          lang.translate("last7Days"),
          style: theme.textTheme.bodyMedium?.copyWith(
              color: controller.themeController.isDarkMode
                  ? colorGrey500
                  : colorGrey400,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  _buildContainerCircleView(String assetName) {
    // Get screen width
    double screenWidth = MediaQuery.of(context).size.width;

    // Define size based on screen width
    double size;
    if (screenWidth >= 768) {
      // md breakpoint
      size = 56;
    } else if (screenWidth >= 640) {
      // ss (smaller screen)
      size = 44;
    } else {
      size = 38;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: controller.themeController.isDarkMode
                ? colorGrey700
                : colorGrey100),
      ),
      child: Center(
        child: SvgPicture.asset(
          assetName,
          colorFilter: ColorFilter.mode(
              controller.themeController.isDarkMode ? colorWhite : colorGrey900,
              BlendMode.srcIn),
        ), // Or any child you want inside
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
        child: _commonBg(child));
  }

  ResponsiveGridCol _topCommonCard(
    Widget child,
  ) {
    return ResponsiveGridCol(
        xs: 12, sm: 12, md: 6, lg: 3, xl: 3, child: _commonBg(child));
  }

  _commonBg(
    Widget child,
  ) {
    return Container(
      margin: EdgeInsetsDirectional.only(start: 8, end: 8, top: 15),
      // width: screenWidth,
      padding: EdgeInsets.all(7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color:
            controller.themeController.isDarkMode ? colorGrey900 : Colors.white,
        boxShadow: [
          if (!controller.themeController.isDarkMode)
            BoxShadow(
                color: colorG1.withValues(alpha: 0.24),
                blurRadius: 2,
                offset: Offset(0, 1),
                spreadRadius: 0),
        ],
        border: Border.all(
            color: controller.themeController.isDarkMode
                ? colorGrey700
                : colorGrey100),
      ),
      child: child,
    );
  }
}
