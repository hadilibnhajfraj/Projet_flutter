import 'dart:convert';
import 'package:dash_master_toolkit/dashboard/ecommerce/ecommerce_imports.dart';
import 'package:dash_master_toolkit/dashboard/ecommerce/model/order_model.dart';
import 'package:http/http.dart' as http;

import '../../../providers/auth_service.dart';

class EcommerceDashboardController extends GetxController {
  ThemeController themeController = Get.put(ThemeController());
  TextEditingController searchController = TextEditingController();
  FocusNode f1 = FocusNode();

  // ✅ Web (Chrome) => localhost ok
  // ✅ Android emulator => 10.0.2.2
  // ✅ real device => http://PC_IP:4000
  final String baseUrl = "http://localhost:4000";

  // ✅ TOP CARDS
  final RxInt totalProjects = 0.obs;
  final RxInt totalUsers = 0.obs;
  final RxInt validatedProjects = 0.obs;
  final RxInt nonValidatedProjects = 0.obs;

  // ✅ CHART DATA
  var revenueList = <RevenueData>[].obs;

  // ✅ RIGHT PANEL
  final customers = <CustomerGrowth>[].obs;

  // ✅ TABLE
  var orders = <OrderModel>[].obs;

  RxBool selectAll = false.obs;
  RxInt sortColumnIndex = 0.obs;
  RxBool sortAscending = true.obs;

  Map<String, String> _headers() {
    final token = AuthService().accessToken ?? "";
    return {
      "Content-Type": "application/json",
      if (token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  @override
  void onInit() {
    super.onInit();
    fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    await Future.wait([
      fetchSummary(),
      fetchUsersKpi(),
      fetchProjectsByMonth(),
      fetchProjectsTable(),
    ]);

    // ✅ CustomerGrowth built from orders (top 6)
    // 🔥 Remplacer l’icône chariot par icône projet
    const String projectIcon = pieChartIcon;

    final list = orders.map((o) {
      final pct = _parsePercent(o.paymentLast4);
      final fallback = (o.paymentStatus == "Validé") ? 100.0 : 0.0;

      return CustomerGrowth(
        country: o.customerName,
        flag: projectIcon,
        percentage: pct ?? fallback,
      );
    }).toList()
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    customers.value = list.take(6).toList();
  }

  // ---------------- API CALLS ----------------

  Future<void> fetchSummary() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/projects/kpi/dashboard"),
        headers: _headers(),
      );
      if (res.statusCode != 200) return;

      final j = jsonDecode(res.body);
      final summary = j["summary"] ?? {};

      totalProjects.value = (summary["totalProjects"] ?? 0);
      validatedProjects.value = (summary["validatedProjects"] ?? 0);
      nonValidatedProjects.value = (summary["nonValidatedProjects"] ?? 0);
    } catch (_) {}
  }

  Future<void> fetchUsersKpi() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/projects/user-kpi"),
        headers: _headers(),
      );
      if (res.statusCode != 200) return;

      final j = jsonDecode(res.body);
      totalUsers.value = (j["totalUsers"] ?? 0);
    } catch (_) {}
  }

  Future<void> fetchProjectsByMonth() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/projects/kpi/projects-by-month"),
        headers: _headers(),
      );
      if (res.statusCode != 200) return;

      final List data = jsonDecode(res.body);

      revenueList.value = data.map((e) {
        final monthKey = (e["month"] ?? "").toString();
        return RevenueData(
          month: _monthLabel(monthKey),
          earning: (e["validatedPercentage"] ?? 0).toDouble(),
          expense: (e["avgReussite"] ?? 0).toDouble(),
        );
      }).toList();
    } catch (_) {}
  }

  Future<void> fetchProjectsTable() async {
    try {
      // ✅ utiliser la nouvelle route qui renvoie owner + members
      final res = await http.get(
        Uri.parse("$baseUrl/projects/projectsusers"),
        headers: _headers(),
      );
      if (res.statusCode != 200) return;

      final List list = jsonDecode(res.body);

      final myEmail = (AuthService().userEmail ?? "").trim().toLowerCase();

      orders.value = list.take(15).map((p) {
        final id = (p["id"] ?? "").toString();
        final nomProjet = (p["nomProjet"] ?? "").toString();

        final date = DateTime.tryParse((p["dateDemarrage"] ?? "").toString()) ?? DateTime.now();

        final validation = (p["validationStatut"] ?? "Non validé").toString();
        final statut = (p["statut"] ?? "—").toString();

        // ✅ owner venant du backend
        final owner = (p["owner"] is Map) ? p["owner"] as Map : null;
        final ownerEmail = (owner?["email"] ?? "—").toString();

        // ✅ members venant du backend
        final members = (p["members"] is List) ? (p["members"] as List) : const [];
        String permission = "viewer";

        // 🔥 permission du user connecté (si présent dans members)
        for (final m in members) {
          if (m is Map) {
            final email = (m["email"] ?? "").toString().trim().toLowerCase();
            if (email == myEmail) {
              permission = (m["permission"] ?? "viewer").toString().trim().toLowerCase();
              break;
            }
          }
        }

        final pr = p["pourcentageReussite"];
        final prText = pr == null ? "" : pr.toString();

        return OrderModel(
          id: id,
          date: date,
          customerName: nomProjet,
          // ✅ Afficher le vrai user (owner)
          customerEmail: ownerEmail,
          customerAvatarUrl: "https://i.ibb.co/BrPBtpS/48px.png",
          paymentStatus: validation,
          orderStatus: statut,

          // ✅ paymentMethod = permission (owner/editor/viewer)
          paymentMethod: permission,

          // ✅ % réussite (string)
          paymentLast4: prText,

          isSelected: false,
        );
      }).toList();
    } catch (_) {}
  }

  // ---------------- HELPERS ----------------

  String _monthLabel(String yyyyMM) {
    final parts = yyyyMM.split("-");
    if (parts.length != 2) return yyyyMM;
    final m = int.tryParse(parts[1]) ?? 1;
    const names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return names[(m - 1).clamp(0, 11)];
  }

  double? _parsePercent(String raw) {
    if (raw.trim().isEmpty) return null;
    return double.tryParse(raw.replaceAll("%", "").trim());
  }

  bool canEdit(OrderModel p) => p.paymentMethod == "owner" || p.paymentMethod == "editor";

  void selectAllRows(bool select) {
    selectAll.value = select;
    for (var order in orders) {
      order.isSelected = select;
    }
    update();
  }

  void sort<T>(Comparable<T> Function(OrderModel d) getField, int columnIndex, bool ascending) {
    orders.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
    });

    sortColumnIndex.value = columnIndex;
    sortAscending.value = ascending;
    update();
  }
}
