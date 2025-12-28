import 'package:dash_master_toolkit/dashboard/ecommerce/ecommerce_imports.dart';
import 'package:dash_master_toolkit/dashboard/ecommerce/model/order_model.dart';

class EcommerceDashboardController extends GetxController {
  ThemeController themeController = Get.put(ThemeController());
  TextEditingController searchController = TextEditingController();
  FocusNode f1 = FocusNode();

  var revenueList = <RevenueData>[
    RevenueData(month: "Jan", earning: 30, expense: 55),
    RevenueData(month: "Feb", earning: 55, expense: 45),
    RevenueData(month: "Mar", earning: 30, expense: 32),
    RevenueData(month: "Apr", earning: 40, expense: 20),
    RevenueData(month: "May", earning: 2, expense: 50),
    RevenueData(month: "Jun", earning: 45, expense: 22),
    RevenueData(month: "Jul", earning: 45, expense: 28),
    RevenueData(month: "Aug", earning: 48, expense: 40),
    RevenueData(month: "Sep", earning: 34, expense: 28),
    RevenueData(month: "Oct", earning: 18, expense: 45),
    RevenueData(month: "Nov", earning: 48, expense: 55),
    RevenueData(month: "Dec", earning: 42, expense: 50),
  ].obs;

  final customers = <CustomerGrowth>[
    CustomerGrowth(
        country: 'United States', flag: unitedStatesIcon, percentage: 56.2),
    CustomerGrowth(country: 'Brazil', flag: brazilIcon, percentage: 40.2),
    CustomerGrowth(country: 'Qatar', flag: qatarIcon, percentage: 35.8),
    CustomerGrowth(country: 'India', flag: indiaIcon, percentage: 21.7),
    CustomerGrowth(country: 'China', flag: chinaIcon, percentage: 12.3),
    CustomerGrowth(country: 'Australia', flag: australiaIcon, percentage: 8.2),
  ].obs;

  var orders = <OrderModel>[].obs;

  RxBool selectAll = false.obs;

  void selectAllRows(bool select) {
    selectAll.value = select;
    for (var order in orders) {
      order.isSelected = select;
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchOrders();
  }

  void fetchOrders() {
    orders.value = [
      OrderModel(
          id: "#345918",
          date: DateTime.parse("2024-04-15 10:21:00"),
          customerName: "Ahmad Lipshutz",
          customerEmail: "ahmadlipshutz@gmail.com",
          customerAvatarUrl: "https://i.ibb.co/BrPBtpS/48px.png",
          paymentStatus: "Successful",
          orderStatus: "Scheduled",
          paymentMethod: "Mastercard",
          paymentLast4: "234",
          isSelected: false),
      OrderModel(
          id: "#345817",
          date: DateTime.parse("2024-04-15 10:21:00"),
          customerName: "Kadin Kenter",
          customerEmail: "kadinkenter@gmail.com",
          customerAvatarUrl: "https://i.ibb.co/Fq6q4sj/48px-4.png",
          paymentStatus: "Successful",
          orderStatus: "Scheduled",
          paymentMethod: "PayPal",
          paymentLast4: "...@gmail.com",
          isSelected: false),
      OrderModel(
          id: "#345716",
          date: DateTime.parse("2024-04-15 10:21:00"),
          customerName: "Ryan Mango",
          customerEmail: "ryanmango@gmail.com",
          customerAvatarUrl: "https://i.ibb.co/dkPm54q/1.png",
          paymentStatus: "Successful",
          orderStatus: "Cancel",
          paymentMethod: "Mastercard",
          paymentLast4: "234",
          isSelected: false),
      OrderModel(
          id: "#345615",
          date: DateTime.parse("2024-04-15 10:21:00"),
          customerName: "Charlien Botosh",
          customerEmail: "charlienbotosh@gmail.com",
          customerAvatarUrl: "https://i.ibb.co/z2yqRrZ/48px-3.png",
          paymentStatus: "Successful",
          orderStatus: "Delivered",
          paymentMethod: "PayPal",
          paymentLast4: "...@gmail.com",
          isSelected: false),
      OrderModel(
          id: "#345614",
          date: DateTime.parse("2024-04-15 10:21:00"),
          customerName: "Phillip Culhane",
          customerEmail: "phillipculhane@gmail.com",
          customerAvatarUrl: "https://i.ibb.co/cTfVpXs/48px-2.png",
          paymentStatus: "Successful",
          orderStatus: "Delivered",
          paymentMethod: "PayPal",
          paymentLast4: "...@gmail.com",
          isSelected: false),
      OrderModel(
          id: "#345613",
          date: DateTime.parse("2024-04-15 10:21:00"),
          customerName: "Adison Schleifer",
          customerEmail: "adisonschleifer@gmail.com",
          customerAvatarUrl: "https://i.ibb.co/QfgMZKf/Ellipse-430-2.png",
          paymentStatus: "Successful",
          orderStatus: "Delivered",
          paymentMethod: "Mastercard",
          paymentLast4: "234",
          isSelected: false),
      OrderModel(
          id: "#345612",
          date: DateTime.parse("2024-04-15 10:21:00"),
          customerName: "Giana Aminoff",
          customerEmail: "gianaaminoff@gmail.com",
          customerAvatarUrl: "https://i.ibb.co/gm02qRY/Rectangle-2554-1.png",
          paymentStatus: "Successful",
          orderStatus: "Delivered",
          paymentMethod: "PayPal",
          paymentLast4: "...@gmail.com",
          isSelected: false),
    ];
  }

  RxInt sortColumnIndex = 0.obs;
  RxBool sortAscending = true.obs;

  void sort<T>(Comparable<T> Function(OrderModel d) getField, int columnIndex,
      bool ascending) {
    orders.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });

    sortColumnIndex.value = columnIndex;
    sortAscending.value = ascending;
  }
}
