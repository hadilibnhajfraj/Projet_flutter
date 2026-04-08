import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:dash_master_toolkit/providers/auth_service.dart';
import 'package:dash_master_toolkit/dashboard/sales/sales_imports.dart';

class SalesDashboardController extends GetxController {
  // ================== UI DEMO DATA (charts) ==================
  final visitors = <VisitorData>[].obs;
  final topProductData = <ProductData>[].obs;

  // ================== BASE URL ==================
  String get baseUrl {
    if (kIsWeb) return "http://localhost:4000";
    if (Platform.isAndroid) return "http://10.0.2.2:4000"; // Android emulator
    return "http://localhost:4000"; // Windows / iOS / macOS
  }

  // ================== STATE ==================
  final isLoadingKpi = false.obs;
  final kpiError = "".obs;

  final projectValidationKpi = <String, dynamic>{}.obs;

  final projectSurfaceKpi = <Map<String, dynamic>>[].obs;
  final projectLocationKpi = <Map<String, dynamic>>[].obs;
  final projectValidationStatus = <Map<String, dynamic>>[].obs;
  final topUsers = <Map<String, dynamic>>[].obs;
  final latestProjects = <Map<String, dynamic>>[].obs;

  final projectStatusData = <Map<String, dynamic>>[].obs;
  final projectStatusAndDateData = <Map<String, dynamic>>[].obs;

  // ================== PAGINATION ==================
  final surfacePage = 1.obs;
  final surfacePerPage = 4.obs;

  int get surfaceTotalPages {
    final total = projectSurfaceKpi.length;
    final per = surfacePerPage.value <= 0 ? 4 : surfacePerPage.value;
    return (total / per).ceil().clamp(1, total);
  }

  List<Map<String, dynamic>> get surfacePagedRows {
    final all = projectSurfaceKpi;
    final per = surfacePerPage.value <= 0 ? 4 : surfacePerPage.value;
    final page = surfacePage.value <= 0 ? 1 : surfacePage.value;
    final start = (page - 1) * per;
    final end = (start + per).clamp(0, all.length);
    return all.sublist(start, end);
  }

  void nextSurfacePage() {
    if (surfacePage.value < surfaceTotalPages) surfacePage.value++;
  }

  void prevSurfacePage() {
    if (surfacePage.value > 1) surfacePage.value--;
  }

  void resetSurfacePagination() => surfacePage.value = 1;

  // ================== INIT ==================
  @override
  void onInit() {
    super.onInit();
    fetchProjectKpis();
    fetchProjectsByStatus();
  }

  // ================== HELPERS ==================
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
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService().accessToken;
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // ================== KPI FETCH ==================
  Future<void> fetchProjectKpis() async {
    try {
      isLoadingKpi.value = true;
      kpiError.value = "";

      final headers = await _headers();

      final dashboardRes = await http.get(
        Uri.parse("$baseUrl/projects/kpi/dashboard"),
        headers: headers,
      );

      final surfaceRes = await http.get(
        Uri.parse("$baseUrl/projects/kpi/validation-by-surface"),
        headers: headers,
      );

      if (dashboardRes.statusCode != 200) {
        throw Exception("Dashboard error: ${dashboardRes.statusCode}");
      }
      if (surfaceRes.statusCode != 200) {
        throw Exception("Surface error: ${surfaceRes.statusCode}");
      }

      final dashData = json.decode(dashboardRes.body);
      final surfData = json.decode(surfaceRes.body);

      projectValidationKpi.value =
          Map<String, dynamic>.from(dashData["summary"] ?? {});

      projectValidationStatus.assignAll(
        _asListOfMap(dashData["validationStatusCount"]),
      );
      projectLocationKpi.assignAll(_asListOfMap(dashData["mapProjects"]));
      topUsers.assignAll(_asListOfMap(dashData["topUsers"]));
      latestProjects.assignAll(_asListOfMap(dashData["latestProjects"]));

      projectSurfaceKpi.assignAll(_asListOfMap(surfData));
      resetSurfacePagination();
    } catch (e) {
      kpiError.value = e.toString();
    } finally {
      isLoadingKpi.value = false;
      update(["sales_dashboard"]);
    }
  }

  // ================== PROJECTS BY STATUS ==================
  Future<void> fetchProjectsByStatus() async {
    try {
      isLoadingKpi.value = true;
      final headers = await _headers();
      final res = await http.get(
        Uri.parse("$baseUrl/projects/kpi/projects-by-status"),
        headers: headers,
      );

      if (res.statusCode != 200) {
        throw Exception("Projects by status error: ${res.statusCode}");
      }

      final data = json.decode(res.body);
      projectStatusData.assignAll(_asListOfMap(data));
    } catch (e) {
      kpiError.value = e.toString();
    } finally {
      isLoadingKpi.value = false;
      update(["sales_dashboard"]);
    }
  }

  // ================== ADMIN / USER FILTER ==================
  List<Map<String, dynamic>> filterProjectsForUser(String userId) {
    // Si admin, retourne tout
    if (AuthService().isAdmin) return projectSurfaceKpi;

    // Sinon, filtre uniquement les projets assignés à l’utilisateur
    return projectSurfaceKpi.where((p) => p["ownerId"] == userId).toList();
  }

  // ================== UI GETTERS ==================
  int get totalProjects => _toInt(projectValidationKpi["totalProjects"]);
  int get validatedProjects => _toInt(projectValidationKpi["validatedProjects"]);
  double get validatedPercentage => _toDouble(projectValidationKpi["validatedPercentage"]);
  int get nonValidatedProjects => totalProjects - validatedProjects;

  String pctText(dynamic v) => "${_toDouble(v).toStringAsFixed(2)}%";

  String surfaceLabel(Map<String, dynamic> item) => (item["surfaceProspectee"] ?? "—").toString();
  int surfaceTotal(Map<String, dynamic> item) => _toInt(item["totalProjects"]);
  int surfaceValidated(Map<String, dynamic> item) => _toInt(item["validatedProjects"]);
  double surfaceAvgReussite(Map<String, dynamic> item) =>
      _toDouble(item["avgReussite"] ?? item["validatedPercentage"], fallback: 0);

  double mapLat(Map<String, dynamic> item) => _toDouble(item["latitude"]);
  double mapLng(Map<String, dynamic> item) => _toDouble(item["longitude"]);
  String mapTitle(Map<String, dynamic> item) => (item["nomProjet"] ?? "Projet").toString();
}