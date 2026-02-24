import 'package:dash_master_toolkit/application/calendar/calendar_imports.dart';
import 'package:dash_master_toolkit/services/project_api.dart';  // Import ProjectApi
import 'package:dash_master_toolkit/application/users/model/project_grid_data.dart';  // Import ProjectGridData
import 'package:flutter/material.dart';
import 'package:dash_master_toolkit/application/services/api_client.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';  // Add import for AuthService
class CalendarControllerX extends GetxController {
  var selectedDate = DateTime.now().obs;
  final calendarController = CalendarController();
  var currentView = CalendarView.week.obs;
  var appointments = <Appointment>[].obs;

  Dio get dio => ApiClient.instance.dio;
  String? token;

  @override
  void onInit() {
    super.onInit();
    _loadToken();  // Fetch token when the controller initializes

    calendarController.addPropertyChangedListener((String property) {
      if (property == 'displayDate') {
        Future.microtask(() {
          selectedDate.value = calendarController.displayDate ?? DateTime.now();
        });
      }
    });
    calendarController.view = CalendarView.month;  // Set default view to month
  }

  // Fetch the token from the AuthService or other storage mechanisms
  Future<void> _loadToken() async {
    token = AuthService().accessToken;
    if (token != null && token!.isNotEmpty) {
      loadAppointments(token!);  // Fetch the appointments after the token is loaded
    } else {
      print('Token is missing or invalid');
    }
  }

  void changeView(CalendarView view) {
    calendarController.view = view;
    currentView.value = view; 
  }

  void goToPrevious() {
    calendarController.backward?.call();
  }

  void goToNext() {
    calendarController.forward?.call();
  }

  // Method to load appointments from the API
  Future<void> loadAppointments(String token) async {
    try {
      final response = await Dio().get(
        'http://localhost:4000/projects/calendar',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final data = response.data;
      if (data is List) {
        appointments.assignAll(data.map((e) {
          final startTime = DateTime.parse(e["dateDemarrage"]);
          return Appointment(
            startTime: startTime,
            endTime: startTime.add(Duration(hours: 2)),  // Adjust duration as necessary
            subject: e["nomProjet"],
            color: getColorForProjectStatus(e["statut"], e["validationStatut"]),  // Apply color
          );
        }).toList());
        update();  // Update the UI after appointments are loaded
      }
    } catch (e) {
      print('Error loading appointments: $e');
      throw Exception('Failed to load calendar projects');
    }
  }

  // Get color based on project status
  Color getColorForProjectStatus(String statut, String validationStatut) {
    if (statut == 'En cours') {
      return Colors.red;
    } else if (statut == 'Préparation') {
      return Colors.blue;
    } else if (statut == 'Terminé' && validationStatut == 'Validé') {
      return Colors.green;
    } else if (statut == 'Terminé' && validationStatut == 'Non validé') {
      return Colors.orange;
    }
    return Colors.grey; // Default color for other cases
  }

  @override
  void onClose() {
    super.onClose();
  }
}