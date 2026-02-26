import 'package:dash_master_toolkit/application/calendar/calendar_imports.dart';

class CalendarControllerX extends GetxController {
  var selectedDate = DateTime.now().obs;

  final calendarController = CalendarController();
  var currentView = CalendarView.week.obs;

  var appointments = <Appointment>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadAppointments();

    calendarController.addPropertyChangedListener((String property) {
      if (property == 'displayDate') {
        Future.microtask(() {
          selectedDate.value = calendarController.displayDate ?? DateTime.now();
        });
      }
    });

    calendarController.view = CalendarView.week;
  }

  void changeView(CalendarView view) {
    calendarController.view = view;
    currentView.value = view;
  }

  void goToPrevious() => calendarController.backward?.call();
  void goToNext() => calendarController.forward?.call();

  // ✅ AJOUT TASK (commercial)
  void addTask({
    required String title,
    required DateTime start,
    String description = "",
  }) {
    // endTime obligatoire pour Syncfusion -> on met +30 min (ou +1h)
    final end = start.add(const Duration(minutes: 30));

    appointments.add(
      Appointment(
        startTime: start,
        endTime: end,
        subject: description.trim().isEmpty ? title : "$title\n$description",
        color: colorPrimary100, // ou Colors.blue
      ),
    );
  }

  // (optionnel) demo
  void loadAppointments() {
    final today = DateTime.now();
    appointments.assignAll([
      Appointment(
        startTime: DateTime(today.year, today.month, today.day, 9, 0),
        endTime: DateTime(today.year, today.month, today.day, 10, 0),
        subject: 'Daily Sync',
        color: Colors.green,
      ),
    ]);
  }
}