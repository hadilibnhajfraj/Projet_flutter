import 'dart:convert';
import 'package:dash_master_toolkit/dashboard/sales/sales_imports.dart';
import 'package:http/http.dart' as http;
import 'package:dash_master_toolkit/providers/auth_service.dart';

class SalesDashboardController extends GetxController {
  // ================== UI DEMO DATA (charts) ==================
  final visitors = <VisitorData>[
    VisitorData(0, 300, 280, 310),
    VisitorData(1, 290, 260, 330),
    VisitorData(2, 280, 220, 340),
    VisitorData(3, 270, 200, 330),
    VisitorData(4, 280, 230, 310),
    VisitorData(5, 320, 290, 300),
    VisitorData(6, 350, 360, 290),
    VisitorData(7, 310, 330, 310),
    VisitorData(8, 270, 250, 330),
    VisitorData(9, 240, 210, 320),
    VisitorData(10, 220, 190, 300),
    VisitorData(11, 200, 180, 280),
  ].obs;

  final topProductData = <ProductData>[
    ProductData(name: 'Home Decor Range', popularity: 70, sales: 45, color: '0195FF'),
    ProductData(name: 'Disney Princess Pink Bag', popularity: 60, sales: 29, color: '18E2A0'),
    ProductData(name: 'Bathroom Essentials', popularity: 50, sales: 18, color: '884DFF'),
    ProductData(name: 'Apple Smartwatch', popularity: 20, sales: 25, color: 'FF8F0E'),
  ].obs;

  // ================== KPI PROJECT DATA ==================
  static const String baseUrl = "http://localhost:4000";

  final isLoadingKpi = false.obs;
  final kpiError = "".obs;

  // summary
  final projectValidationKpi = <String, dynamic>{}.obs;

  // ✅ typage strict
  final projectSurfaceKpi = <Map<String, dynamic>>[].obs; // from /validation-by-surface
  final projectLocationKpi = <Map<String, dynamic>>[].obs; // mapProjects
  final projectValidationStatus = <Map<String, dynamic>>[].obs; // validationStatusCount
  final topUsers = <Map<String, dynamic>>[].obs;
  final latestProjects = <Map<String, dynamic>>[].obs;
// ================== ✅ PAGINATION (Surface table) ==================
final surfacePage = 1.obs;
final surfacePerPage = 4.obs; // ✅ 4 rows per page

int get surfaceTotalPages {
  final total = projectSurfaceKpi.length;
  final per = surfacePerPage.value <= 0 ? 4 : surfacePerPage.value;
  final pages = (total / per).ceil();
  return pages <= 0 ? 1 : pages;
}

List<Map<String, dynamic>> get surfacePagedRows {
  final all = projectSurfaceKpi;
  if (all.isEmpty) return [];

  final per = surfacePerPage.value <= 0 ? 4 : surfacePerPage.value;
  final page = surfacePage.value <= 0 ? 1 : surfacePage.value;

  final start = (page - 1) * per;
  if (start < 0 || start >= all.length) return [];

  final end = (start + per).clamp(0, all.length);
  return all.sublist(start, end);
}

void nextSurfacePage() {
  if (surfacePage.value < surfaceTotalPages) surfacePage.value++;
}

void prevSurfacePage() {
  if (surfacePage.value > 1) surfacePage.value--;
}

void resetSurfacePagination() {
  surfacePage.value = 1;
}

  @override
  void onInit() {
    super.onInit();
    fetchProjectKpis();
  }

  // ================== Helpers parsing ==================
  double _toDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  List<Map<String, dynamic>> _asListOfMap(dynamic raw) {
    if (raw == null) return <Map<String, dynamic>>[];
    if (raw is List) {
      return raw
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, String>> _headers() async {
    final token = AuthService().accessToken;
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // ================== ✅ KPI: dashboard + surface endpoint ==================
  Future<void> fetchProjectKpis() async {
    try {
      isLoadingKpi.value = true;
      kpiError.value = "";

      final headers = await _headers();

      // 1) dashboard
      final dashboardReq = http.get(
        Uri.parse("$baseUrl/projects/kpi/dashboard"),
        headers: headers,
      );

      // 2) surface (endpoint qui contient avgReussite)
      final surfaceReq = http.get(
        Uri.parse("$baseUrl/projects/kpi/validation-by-surface"),
        headers: headers,
      );

      final results = await Future.wait([dashboardReq, surfaceReq]);
      final dashRes = results[0];
      final surfRes = results[1];

      if (dashRes.statusCode != 200) {
        throw Exception("dashboard: ${dashRes.statusCode} ${dashRes.body}");
      }
      if (surfRes.statusCode != 200) {
        throw Exception("surface: ${surfRes.statusCode} ${surfRes.body}");
      }

      final dashData = json.decode(dashRes.body);
      final surfData = json.decode(surfRes.body);

      // --- dashboard parse
      final summaryRaw = (dashData is Map) ? dashData["summary"] : null;
      projectValidationKpi.value =
          (summaryRaw is Map) ? Map<String, dynamic>.from(summaryRaw) : <String, dynamic>{};

      projectValidationStatus.assignAll(_asListOfMap((dashData is Map) ? dashData["validationStatusCount"] : null));
      projectLocationKpi.assignAll(_asListOfMap((dashData is Map) ? dashData["mapProjects"] : null));
      topUsers.assignAll(_asListOfMap((dashData is Map) ? dashData["topUsers"] : null));
      latestProjects.assignAll(_asListOfMap((dashData is Map) ? dashData["latestProjects"] : null));

      // --- surface parse (LIST DIRECTE)
      // surfData = [ {surfaceProspectee, totalProjects, validatedProjects, validatedPercentage, avgReussite}, ... ]
      projectSurfaceKpi.assignAll(_asListOfMap(surfData));
      // ✅ reset pagination after refresh
resetSurfacePagination();

      update(["sales_dashboard"]);
    } catch (e) {
      kpiError.value = "KPI error: $e";
      update(["sales_dashboard"]);
    } finally {
      isLoadingKpi.value = false;
      update(["sales_dashboard"]);
    }
  }

  // ================== UI summary ==================
  int get totalProjects => _toInt(projectValidationKpi["totalProjects"]);
  int get validatedProjects => _toInt(projectValidationKpi["validatedProjects"]);
  double get validatedPercentage => _toDouble(projectValidationKpi["validatedPercentage"]);
  int get nonValidatedProjects => totalProjects - validatedProjects;

  String pctText(dynamic v) => "${_toDouble(v).toStringAsFixed(2)}%";

  // ================== surface helpers ==================
  String surfaceLabel(Map<String, dynamic> item) => (item["surfaceProspectee"] ?? "—").toString();
  int surfaceTotal(Map<String, dynamic> item) => _toInt(item["totalProjects"]);
  int surfaceValidated(Map<String, dynamic> item) => _toInt(item["validatedProjects"]);

  // ✅ on affiche avgReussite (92,95,60,48...) en priorité
  double surfaceAvgReussite(Map<String, dynamic> item) => _toDouble(
        item["avgReussite"] ??
            item["avg_reussite"] ??
            item["validatedPercentage"] ??
            item["validated_percentage"],
        fallback: 0,
      );

  // ================== map helpers ==================
  double mapLat(Map<String, dynamic> item) => _toDouble(item["latitude"]);
  double mapLng(Map<String, dynamic> item) => _toDouble(item["longitude"]);
  String mapTitle(Map<String, dynamic> item) => (item["nomProjet"] ?? "Projet").toString();
  
}
